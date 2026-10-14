#!/usr/bin/env bash
# Concurrent Couple joins must never exceed two members.
#
# Five users try to redeem five different invitations to the same couple group
# at the same moment, each in its own connection, holding the transaction open
# for a second so the attempts overlap. Exactly one may join.
#
# Usage: DB_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres \
#          bash supabase/tests/concurrency/couple_capacity.sh
set -euo pipefail

DB_URL="${DB_URL:-postgresql://postgres:postgres@127.0.0.1:54322/postgres}"
psql_q() { psql "$DB_URL" -v ON_ERROR_STOP=1 -qtA "$@"; }

run_id="cc$(date +%s)$RANDOM"
owner=$(psql_q -c "select gen_random_uuid()")
psql_q -c "insert into auth.users (id, email, aud, role)
           values ('$owner', '${run_id}-owner@test.local', 'authenticated', 'authenticated')"

claims() { echo "{\"sub\":\"$1\",\"role\":\"authenticated\"}"; }

group_id=$(psql_q <<SQL
set request.jwt.claims = '$(claims "$owner")';
set role authenticated;
select public.create_group('Concurrency $run_id', 'couple');
SQL
)

joiners=()
codes=()
for i in 1 2 3 4 5; do
  uid=$(psql_q -c "select gen_random_uuid()")
  psql_q -c "insert into auth.users (id, email, aud, role)
             values ('$uid', '${run_id}-j$i@test.local', 'authenticated', 'authenticated')"
  code=$(psql_q <<SQL
set request.jwt.claims = '$(claims "$owner")';
set role authenticated;
select code from public.create_invitation('$group_id');
SQL
)
  joiners+=("$uid")
  codes+=("$code")
done

tmp=$(mktemp -d)
for i in 0 1 2 3 4; do
  psql_q > "$tmp/$i.out" <<SQL &
begin;
set local request.jwt.claims = '$(claims "${joiners[$i]}")';
set local role authenticated;
select public.redeem_invitation('${codes[$i]}') ->> 'status';
select pg_sleep(1);
commit;
SQL
done
wait

statuses=$(cat "$tmp"/*.out | grep -E '^[a-z_]+$' | sort | uniq -c | tr -s ' ')
members=$(psql_q -c "select count(*) from public.group_members where group_id = '$group_id'")

echo "redeem statuses:${statuses}"
echo "members in couple group: $members"

# Clean up (cascades to profiles, memberships and the group).
psql_q -c "delete from auth.users where email like '${run_id}-%'"
rm -rf "$tmp"

joined=$(echo "$statuses" | grep -oE '[0-9]+ joined' | cut -d' ' -f1 || true)
if [[ "$members" == "2" && "${joined:-0}" == "1" ]]; then
  echo "ok - concurrent couple joins respected the 2-member limit"
else
  echo "not ok - expected 2 members and 1 successful join"
  exit 1
fi
