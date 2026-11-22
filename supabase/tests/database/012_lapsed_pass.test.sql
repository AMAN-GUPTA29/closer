-- A pass that ends never deletes photos by itself: 30 days of grace, then
-- uploads pause at the limit and the group waits for the app owner.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

create function pg_temp.claims(p_key text)
returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    jsonb_build_object('sub', current_setting('t.' || p_key), 'role', 'authenticated')::text,
    true);
end $$;

create function pg_temp.mk_user(p_key text)
returns uuid language plpgsql as $$
declare v uuid := gen_random_uuid();
begin
  insert into auth.users (id, email, raw_user_meta_data, aud, role)
  values (v, p_key || '@test.local', jsonb_build_object('display_name', initcap(p_key)),
          'authenticated', 'authenticated');
  perform set_config('t.' || p_key, v::text, true);
  return v;
end $$;

create function pg_temp.g()
returns uuid language sql as $$ select current_setting('t.g')::uuid $$;

-- An upload that is stored but not finalized yet.
create function pg_temp.start_upload()
returns uuid language plpgsql as $$
declare v uuid;
begin
  select photo_id into v from public.request_photo_upload(pg_temp.g(), gen_random_uuid());
  insert into storage.objects (bucket_id, name, metadata)
  select 'photos', unnest(array[p.storage_path, p.thumb_path]), '{"size": 1000}'::jsonb
  from public.photos p where p.id = v;
  return v;
end $$;

create function pg_temp.upload()
returns uuid language plpgsql as $$
declare v uuid := pg_temp.start_upload();
begin
  perform public.finalize_photo(v);
  return v;
end $$;

create function pg_temp.active()
returns integer language sql as $$
  select count(*)::int from public.photos where group_id = pg_temp.g() and status = 'active'
$$;

create function pg_temp.auto_removed()
returns integer language sql as $$
  select count(*)::int from public.photos
  where group_id = pg_temp.g() and removed_reason = 'retention'
$$;

create function pg_temp.waiting()
returns integer language sql as $$
  select count(*)::int from public.photo_deletion_queue() q where q.group_id = pg_temp.g()
$$;

select pg_temp.mk_user('alice');
select pg_temp.claims('alice');
set local role authenticated;
do $$ begin
  perform set_config('t.g', public.create_group('Us', 'friends')::text, true);
end $$;
reset role;

select public.grant_group_entitlement(pg_temp.g(), current_setting('t.alice')::uuid,
  'test', 'keeploom_memories_year', 'lapse-a');
do $$ begin
  for i in 1..15 loop perform pg_temp.upload(); end loop;
  perform set_config('t.pending', pg_temp.start_upload()::text, true);
end $$;
select is(pg_temp.active(), 15, 'a group with a pass keeps more than 10 photos');

-- Days 1-30.
update public.group_entitlements set expires_at = now() - interval '29 days'
  where group_id = pg_temp.g();
select is(pg_temp.waiting(), 0, 'nothing waits for approval during the 30 days');
set local role authenticated;
select is((select pass_ended from public.group_summaries where id = pg_temp.g()), false,
  'during the 30 days the pass has not fully ended');
reset role;

-- After day 30.
update public.group_entitlements set expires_at = now() - interval '31 days'
  where group_id = pg_temp.g();
set local role authenticated;
select is((select pass_ended from public.group_summaries where id = pg_temp.g()), true,
  'members see that the pass ended');
reset role;
select throws_ok(
  $$select * from public.request_photo_upload(pg_temp.g(), gen_random_uuid())$$,
  'P0001', 'closer:renewal_required', 'new uploads are refused at the limit');
select throws_ok(
  $$select public.finalize_photo(current_setting('t.pending')::uuid)$$,
  'P0001', 'closer:renewal_required', 'an upload started before the lapse cannot finish after it');
select is(public.apply_retention(pg_temp.g()), '{}'::uuid[], 'retention skips lapsed groups');
select is(pg_temp.active(), 15, 'every photo is still there');
select is(pg_temp.auto_removed(), 0, 'nothing was removed automatically');
select is(
  (select count(*)::int from public.storage_cleanup_jobs where group_id = pg_temp.g()),
  0, 'no file was queued for deletion');

-- The waiting list.
select is(pg_temp.waiting(), 1, 'the group waits for approval');
select results_eq(
  $$select photo_count, photos_over_limit, storage_bytes
    from public.photo_deletion_queue() where group_id = pg_temp.g()$$,
  $$values (15, 5, 30000::bigint)$$,
  'the list shows count, photos over the limit and size');
select ok(
  (select waiting_since = pass_ended_at + interval '30 days'
   from public.photo_deletion_queue() where group_id = pg_temp.g()),
  'waiting starts 30 days after the pass ended');
set local role authenticated;
select throws_ok($$select * from public.photo_deletion_queue()$$, '42501', null,
  'members, including the group owner, cannot read the waiting list');
select throws_ok($$select public.assert_upload_allowed(pg_temp.g())$$, '42501', null,
  'the upload check is internal');
reset role;
set local role service_role;
select lives_ok($$select * from public.photo_deletion_queue()$$,
  'the server can read the waiting list');
reset role;

-- Renewing.
select is(
  public.grant_group_entitlement(pg_temp.g(), current_setting('t.alice')::uuid,
    'test', 'keeploom_memories_year', 'lapse-b') ->> 'status',
  'granted', 'renewing works after day 30');
select is(pg_temp.waiting(), 0, 'renewing leaves the waiting list');
select lives_ok($$select public.finalize_photo(current_setting('t.pending')::uuid)$$,
  'uploads work again after renewing');
select is(pg_temp.active(), 16, 'renewing kept every photo');

-- A refund follows the same rule.
select is(public.revoke_group_entitlement('test', 'lapse-b') ->> 'status', 'revoked',
  'the renewal is refunded');
select is(pg_temp.waiting(), 0, 'a refund also gets 30 days');
set local role authenticated;
select ok(
  (select s.premium_expires_at = e.revoked_at
   from public.group_summaries s join public.group_entitlements e on e.group_id = s.id
   where s.id = pg_temp.g()),
  'a refunded pass is shown as ending on the refund date');
reset role;
update public.group_entitlements
  set revoked_at = now() - interval '31 days', grace_until = now() - interval '1 day'
  where group_id = pg_temp.g();
select is(pg_temp.waiting(), 1, 'after a refund and 30 days the group waits for approval');
select throws_ok(
  $$select * from public.request_photo_upload(pg_temp.g(), gen_random_uuid())$$,
  'P0001', 'closer:renewal_required', 'refunded groups cannot upload at the limit');
select is(pg_temp.auto_removed(), 0, 'a refund deletes nothing');

-- Deleting down to fewer than 10.
do $$
declare v uuid;
begin
  for v in select id from public.photos where group_id = pg_temp.g() and status = 'active' limit 6
  loop perform public.delete_photo(v); end loop;
end $$;
select is(pg_temp.active(), 10, 'members deleted down to 10');
select is(pg_temp.waiting(), 0, 'with nothing over the limit there is nothing to approve');
select throws_ok(
  $$select * from public.request_photo_upload(pg_temp.g(), gen_random_uuid())$$,
  'P0001', 'closer:renewal_required', 'exactly 10 is still full');
do $$
begin
  perform public.delete_photo((select id from public.photos
    where group_id = pg_temp.g() and status = 'active' limit 1));
end $$;
select lives_ok($$select pg_temp.upload()$$, 'with fewer than 10 an upload works');
select is(pg_temp.active(), 10, 'the group is back at the limit');
select is(pg_temp.auto_removed(), 0, 'and still nothing was removed automatically');

-- After the app owner approves, the group becomes a normal unpaid group
-- (owner decision 2026-11-23). The approval does that by deleting this row.
delete from public.group_entitlements where group_id = pg_temp.g();
set local role authenticated;
select is((select pass_ended or is_premium from public.group_summaries where id = pg_temp.g()),
  false, 'a converted group is a normal unpaid group');
select is((select premium_expires_at from public.group_summaries where id = pg_temp.g()),
  null::timestamptz, 'a converted group shows no pass date');
reset role;
select is(pg_temp.waiting(), 0, 'a converted group is not on the waiting list');
select lives_ok($$select pg_temp.upload()$$, 'a converted group can upload at the limit');
select is(pg_temp.active(), 10, 'a converted group keeps its latest 10');
select is(pg_temp.auto_removed(), 1, 'the oldest photo makes room, as in any unpaid group');
select is(
  public.grant_group_entitlement(pg_temp.g(), current_setting('t.alice')::uuid,
    'test', 'keeploom_memories_year', 'lapse-c') ->> 'status',
  'granted', 'a converted group can buy a pass again');
select ok(public.is_group_premium(pg_temp.g()), 'and is Premium again');

select * from finish();
rollback;
