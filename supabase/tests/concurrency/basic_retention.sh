#!/usr/bin/env bash
# Concurrent uploads to a full Basic group must never leave more than 10
# active photos, and must remove exactly as many old photos as were added.
# In a group whose pass ended they stop at 10 and remove nothing.
#
# Usage: DB_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres \
#          bash supabase/tests/concurrency/basic_retention.sh
set -euo pipefail

DB_URL="${DB_URL:-postgresql://postgres:postgres@127.0.0.1:54322/postgres}"
psql_q() { psql "$DB_URL" -v ON_ERROR_STOP=1 -qtA "$@"; }
claims() { echo "{\"sub\":\"$1\",\"role\":\"authenticated\"}"; }

run_id="br$(date +%s)$RANDOM"
owner=$(psql_q -c "select gen_random_uuid()")
psql_q -c "insert into auth.users (id, email, aud, role)
           values ('$owner', '${run_id}@test.local', 'authenticated', 'authenticated')"

group_id=$(psql_q <<SQL
set request.jwt.claims = '$(claims "$owner")';
set role authenticated;
select public.create_group('Retention $run_id', 'friends');
SQL
)

# request + store objects (as superuser, objects simulate a finished upload)
new_upload() {
  psql_q <<SQL
set request.jwt.claims = '$(claims "$owner")';
select photo_id from public.request_photo_upload('$group_id', gen_random_uuid());
SQL
}
store() {
  psql_q -c "insert into storage.objects (bucket_id, name)
             select 'photos', unnest(array[storage_path, thumb_path])
             from public.photos where id = '$1'"
}
finalize() {
  psql_q <<SQL
set request.jwt.claims = '$(claims "$owner")';
select public.finalize_photo('$1') ->> 'status';
SQL
}

# Fill the group to the limit.
for _ in $(seq 1 10); do
  id=$(new_upload); store "$id"; finalize "$id" > /dev/null
done

# Three uploads finalize at the same time.
ids=()
for _ in 1 2 3; do id=$(new_upload); store "$id"; ids+=("$id"); done
tmp=$(mktemp -d)
for i in 0 1 2; do
  psql_q > "$tmp/$i.out" <<SQL &
begin;
set local request.jwt.claims = '$(claims "$owner")';
set local role authenticated;
select public.finalize_photo('${ids[$i]}') ->> 'status';
select pg_sleep(1);
commit;
SQL
done
wait

active=$(psql_q -c "select count(*) from public.photos where group_id = '$group_id' and status = 'active'")
removed=$(psql_q -c "select count(*) from public.photos where group_id = '$group_id' and removed_reason = 'retention'")
new_active=$(psql_q -c "select count(*) from public.photos where id in ('${ids[0]}','${ids[1]}','${ids[2]}') and status = 'active'")
echo "active=$active removed_by_retention=$removed new_uploads_active=$new_active"

# Same race in a group whose pass ended: 9 photos, room for exactly one.
group_id=$(psql_q <<SQL
set request.jwt.claims = '$(claims "$owner")';
set role authenticated;
select public.create_group('Lapsed $run_id', 'friends');
SQL
)
for _ in $(seq 1 9); do
  id=$(new_upload); store "$id"; finalize "$id" > /dev/null
done
ids2=()
for _ in 1 2 3; do id=$(new_upload); store "$id"; ids2+=("$id"); done
psql_q -c "insert into public.group_entitlements (group_id, expires_at)
           values ('$group_id', now() - interval '31 days')"
for i in 0 1 2; do
  psql_q > "$tmp/lapsed$i.out" 2>&1 <<SQL &
begin;
set local request.jwt.claims = '$(claims "$owner")';
set local role authenticated;
select public.finalize_photo('${ids2[$i]}') ->> 'status';
select pg_sleep(1);
commit;
SQL
done
wait
lapsed_active=$(psql_q -c "select count(*) from public.photos where group_id = '$group_id' and status = 'active'")
lapsed_removed=$(psql_q -c "select count(*) from public.photos where group_id = '$group_id' and status = 'removed'")
lapsed_refused=$( (grep -l renewal_required "$tmp"/lapsed*.out || true) | wc -l | tr -d ' ')
echo "lapsed_active=$lapsed_active lapsed_removed=$lapsed_removed lapsed_refused=$lapsed_refused"

psql_q -c "delete from auth.users where email like '${run_id}%'"
rm -rf "$tmp"

if [[ "$lapsed_active" == "10" && "$lapsed_removed" == "0" && "$lapsed_refused" == "2" ]]; then
  echo "ok - a lapsed group stopped at 10 and removed nothing"
else
  echo "not ok - expected lapsed_active=10 lapsed_removed=0 lapsed_refused=2"
  exit 1
fi

if [[ "$active" == "10" && "$removed" == "3" && "$new_active" == "3" ]]; then
  echo "ok - concurrent uploads kept exactly 10 photos and removed the 3 oldest"
else
  echo "not ok - expected active=10 removed=3 new_uploads_active=3"
  exit 1
fi
