-- Photos, private storage access, Basic retention, Premium entitlements,
-- purchase idempotency and the storage cleanup queue.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

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

create function pg_temp.claims(p_key text)
returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    jsonb_build_object('sub', current_setting('t.' || p_key), 'role', 'authenticated')::text,
    true);
end $$;

-- Simulates the storage upload of both objects for a photo (as the test superuser).
create function pg_temp.store_objects(p_photo uuid)
returns void language sql as $$
  insert into storage.objects (bucket_id, name)
  select 'photos', unnest(array[p.storage_path, p.thumb_path])
  from public.photos p where p.id = p_photo;
$$;

-- Full upload as user p_key: request → store objects → finalize. Returns photo id.
-- Runs as superuser but with the user's claims, so auth.uid() is the uploader.
create function pg_temp.upload(p_key text, p_group text)
returns uuid language plpgsql as $$
declare v uuid;
begin
  perform pg_temp.claims(p_key);
  select photo_id into v from public.request_photo_upload(
    current_setting('t.' || p_group)::uuid, gen_random_uuid(), 'photo', null, 100, 100, 1000);
  perform pg_temp.store_objects(v);
  perform public.finalize_photo(v);
  return v;
end $$;

create function pg_temp.active(p_group text)
returns integer language sql as $$
  select count(*)::int from public.photos
  where group_id = current_setting('t.' || p_group)::uuid and status = 'active';
$$;

select pg_temp.mk_user(u) from unnest(array['alice', 'bob', 'eve']) u;

select pg_temp.claims('alice');
set local role authenticated;
do $$ begin
  perform set_config('t.basic', public.create_group('Basic', 'friends')::text, true);
  perform set_config('t.premium', public.create_group('Premium', 'family')::text, true);
end $$;
reset role;
insert into public.group_members (group_id, user_id) values
  (current_setting('t.basic')::uuid, current_setting('t.bob')::uuid);

-- ---------------------------------------------------------------- uploads
select ok(
  (select bucket.public = false from storage.buckets bucket where bucket.id = 'photos'),
  'the photos bucket is private');

select pg_temp.claims('alice');
set local role authenticated;
do $$
declare r record;
begin
  perform set_config('t.cid', gen_random_uuid()::text, true);
  select * into r from public.request_photo_upload(
    current_setting('t.basic')::uuid, current_setting('t.cid')::uuid, '  Sunset  ',
    now() - interval '3 days', 2000, 1500, 500000);
  perform set_config('t.p1', r.photo_id::text, true);
  perform set_config('t.p1_path', r.storage_path, true);
end $$;
select is(
  (select photo_id::text from public.request_photo_upload(
     current_setting('t.basic')::uuid, current_setting('t.cid')::uuid)),
  current_setting('t.p1'), 'retrying an upload request returns the same photo');
select matches(current_setting('t.p1_path'),
  '^' || current_setting('t.basic') || '/[0-9a-f-]{36}/original\.jpg$',
  'objects live under the group folder');
select throws_ok(
  format('select public.finalize_photo(%L)', current_setting('t.p1')),
  'P0001', 'closer:upload_incomplete', 'cannot finalize before the objects are stored');
select is((select count(*)::int from public.photos), 0, 'pending photos are not visible');

-- Storage RLS: the uploader may write only their pending photo's paths.
select lives_ok(
  format($$insert into storage.objects (bucket_id, name) values ('photos', %L)$$,
         current_setting('t.p1_path')),
  'uploader can store the original');
select lives_ok(
  format($$insert into storage.objects (bucket_id, name)
          select 'photos', thumb_path from public.request_photo_upload(%L, %L)$$,
         current_setting('t.basic'), current_setting('t.cid')),
  'uploader can store the thumbnail');
select throws_ok(
  format($$insert into storage.objects (bucket_id, name) values ('photos', %L)$$,
         current_setting('t.basic') || '/someone-else/original.jpg'),
  '42501', null, 'arbitrary paths are rejected');
reset role;
select is(
  (select count(*)::int from pg_policies
   where schemaname = 'storage' and tablename = 'objects'
     and cmd in ('UPDATE', 'DELETE', 'ALL') and policyname like 'photos bucket%'),
  0, 'clients have no update or delete access to photo objects');

-- A different member cannot write into Alice's pending photo.
select pg_temp.claims('bob');
set local role authenticated;
select throws_ok(
  format($$insert into storage.objects (bucket_id, name) values ('photos', %L)$$,
         replace(current_setting('t.p1_path'), 'original', 'other')),
  '42501', null, 'members cannot write into someone else''s upload');
select throws_ok(
  format('select public.finalize_photo(%L)', current_setting('t.p1')),
  'P0001', 'closer:photo_not_found', 'only the uploader can finalize');
reset role;

select pg_temp.claims('alice');
set local role authenticated;
select is(
  public.finalize_photo(current_setting('t.p1')::uuid) ->> 'status', 'active',
  'finalize makes the photo active');
select is(
  (select caption from public.photos where id = current_setting('t.p1')::uuid),
  'Sunset', 'captions are trimmed');
select ok(
  (select uploaded_at > taken_at from public.photos where id = current_setting('t.p1')::uuid),
  'upload time is recorded separately from capture time');
select throws_ok(
  format('update public.photos set status = %L where id = %L', 'removed', current_setting('t.p1')),
  '42501', null, 'photo status is not client-writable');
reset role;

-- Members (and only members) can read the objects.
select pg_temp.claims('bob');
set local role authenticated;
select is(
  (select count(*)::int from storage.objects where bucket_id = 'photos'
     and name = current_setting('t.p1_path')),
  1, 'members can read active photo objects');
select is((select count(*)::int from public.photos), 1, 'members see the group''s photos');
reset role;

select pg_temp.claims('eve');
set local role authenticated;
select is((select count(*)::int from public.photos), 0, 'non-members see no photos');
select is((select count(*)::int from storage.objects where bucket_id = 'photos'),
  0, 'non-members cannot read photo objects');
select throws_ok(
  format('select * from public.request_photo_upload(%L, %L)', current_setting('t.basic'), gen_random_uuid()),
  'P0001', 'closer:not_a_member', 'non-members cannot upload');
reset role;

set local role anon;
select throws_ok($$ select * from public.photos $$, '42501', null, 'anon cannot read photos');
reset role;

-- --------------------------------------------------------------- retention
-- Upload 9 more (10 total) with increasing timestamps.
do $$ begin
  for i in 1..9 loop
    perform pg_temp.upload('alice', 'basic');
  end loop;
end $$;
reset role;
-- Make upload order unambiguous: p1 is the oldest.
update public.photos set uploaded_at = now() - make_interval(mins => 100)
  where id = current_setting('t.p1')::uuid;
select is(pg_temp.active('basic'), 10, 'a Basic group holds 10 photos');

-- A failed upload (objects never stored) must not remove anything.
do $$
declare v uuid;
begin
  perform pg_temp.claims('bob');
  select photo_id into v from public.request_photo_upload(
    current_setting('t.basic')::uuid, gen_random_uuid());
  begin
    perform public.finalize_photo(v);
  exception when others then null;
  end;
end $$;
select is(pg_temp.active('basic'), 10, 'a failed upload does not delete existing photos');
select is(
  (select status::text from public.photos where id = current_setting('t.p1')::uuid),
  'active', 'the oldest photo survives a failed upload');

-- The 11th successful upload removes the oldest, not the newest.
do $$ begin perform set_config('t.p11', pg_temp.upload('bob', 'basic')::text, true); end $$;
select is(pg_temp.active('basic'), 10, 'retention keeps at most 10 active photos');
select is(
  (select status::text || ':' || removed_reason::text from public.photos
   where id = current_setting('t.p1')::uuid),
  'removed:retention', 'the oldest photo was removed');
select is(
  (select status::text from public.photos where id = current_setting('t.p11')::uuid),
  'active', 'the new photo is kept');
select is(
  (select count(*)::int from public.storage_cleanup_jobs
   where photo_id = current_setting('t.p1')::uuid and status = 'queued'),
  2, 'both objects of the removed photo are queued for deletion');

-- Removed photos and their objects are no longer readable.
select pg_temp.claims('bob');
set local role authenticated;
select is(
  (select count(*)::int from storage.objects where name = current_setting('t.p1_path')),
  0, 'removed photo objects are no longer readable');
reset role;

-- Pinning is Premium-only.
select pg_temp.claims('alice');
set local role authenticated;
select throws_ok(
  format('select public.set_photo_pinned(%L, true)', current_setting('t.p11')),
  'P0001', 'closer:premium_required', 'pinning needs Closer Memories');
-- Client-side Premium cannot be forged.
select throws_ok(
  format($$insert into public.group_entitlements (group_id) values (%L)$$, current_setting('t.basic')),
  '42501', null, 'clients cannot grant themselves Premium');
select throws_ok(
  format($$select public.grant_group_entitlement(%L, %L, 'test', 'p', 'tx-forged')$$,
         current_setting('t.basic'), current_setting('t.alice')),
  '42501', null, 'clients cannot call the entitlement function');
reset role;

-- ----------------------------------------------------------------- premium
set local role service_role;
select is(
  public.grant_group_entitlement(current_setting('t.premium')::uuid, current_setting('t.alice')::uuid,
    'test', 'closer_memories_group', 'tx-1') ->> 'status',
  'granted', 'a verified purchase grants Premium');
select is(
  public.grant_group_entitlement(current_setting('t.premium')::uuid, current_setting('t.alice')::uuid,
    'test', 'closer_memories_group', 'tx-1') ->> 'status',
  'already_granted', 'processing the same purchase twice is idempotent');
select throws_ok(
  format($$select public.grant_group_entitlement(%L, %L, 'test', 'p', 'tx-1')$$,
         current_setting('t.basic'), current_setting('t.alice')),
  'P0001', 'closer:transaction_already_used', 'one transaction cannot unlock two groups');
reset role;
select is((select count(*)::int from public.purchase_records where transaction_id = 'tx-1'),
  1, 'one purchase record per transaction');

do $$ begin
  for i in 1..12 loop perform pg_temp.upload('alice', 'premium'); end loop;
end $$;
reset role;
select is(pg_temp.active('premium'), 12, 'Premium groups keep more than 10 photos');
select is(pg_temp.active('basic'), 10, 'Premium is isolated to the purchased group');

select pg_temp.claims('alice');
set local role authenticated;
select is(
  (select is_premium from public.group_summaries where id = current_setting('t.premium')::uuid),
  true, 'members see the group as Premium');
select is(
  (select is_premium from public.group_summaries where id = current_setting('t.basic')::uuid),
  false, 'other groups stay Basic');
reset role;

-- New members inherit the group's Premium.
insert into public.group_members (group_id, user_id) values
  (current_setting('t.premium')::uuid, current_setting('t.bob')::uuid);
select pg_temp.claims('bob');
set local role authenticated;
select is(
  (select is_premium from public.group_summaries where id = current_setting('t.premium')::uuid),
  true, 'new members inherit Premium');
reset role;

-- Refund: grace period first, nothing deleted.
set local role service_role;
select is(public.revoke_group_entitlement('test', 'tx-1') ->> 'status', 'revoked', 'refunds revoke Premium');
select is(public.revoke_group_entitlement('test', 'tx-1') ->> 'status', 'already_revoked', 'refund processing is idempotent');
reset role;
select is(pg_temp.active('premium'), 12, 'revocation does not delete photos');
do $$ begin perform pg_temp.upload('alice', 'premium'); end $$;
reset role;
select is(pg_temp.active('premium'), 13, 'during the grace period the group is still Premium');

update public.group_entitlements set grace_until = now() - interval '1 second'
  where group_id = current_setting('t.premium')::uuid;
do $$ begin perform pg_temp.upload('alice', 'premium'); end $$;
reset role;
select is(pg_temp.active('premium'), 10, 'after the grace period Basic retention applies on the next upload');

-- --------------------------------------------------------- delete & groups
select pg_temp.claims('bob');
set local role authenticated;
select throws_ok(
  format('select public.delete_photo(%L)', (select id from public.photos
    where group_id = current_setting('t.premium')::uuid and status = 'active' limit 1)),
  'P0001', 'closer:not_allowed', 'members cannot delete other people''s photos');
select lives_ok(
  format('select public.delete_photo(%L)', current_setting('t.p11')),
  'uploaders can delete their own photos');
reset role;
select is(
  (select removed_reason::text from public.photos where id = current_setting('t.p11')::uuid),
  'deleted', 'deleted photos are marked removed');

-- Abandoned uploads expire and are cleaned up.
update public.photos set created_at = now() - interval '2 days' where status = 'pending';
set local role service_role;
select ok(public.expire_stale_uploads() >= 1, 'stale pending uploads expire');
reset role;
select is((select count(*)::int from public.photos where status = 'pending'), 0, 'no pending uploads remain');

-- Deleting a group queues all its photo objects.
select pg_temp.claims('alice');
set local role authenticated;
select lives_ok(format('select public.delete_group(%L)', current_setting('t.premium')), 'owner deletes a group');
reset role;
select ok(
  (select count(*) >= 28 from public.storage_cleanup_jobs
   where group_id = current_setting('t.premium')::uuid),
  'a deleted group''s objects are queued for cleanup');

-- ------------------------------------------------------------ cleanup queue
set local role authenticated;
select throws_ok($$ select * from public.storage_cleanup_jobs $$, '42501', null,
  'clients cannot read the cleanup queue');
select throws_ok($$ select * from public.claim_cleanup_jobs(1) $$, '42501', null,
  'clients cannot claim cleanup jobs');
reset role;

set local role service_role;
do $$
declare j record;
begin
  select * into j from public.claim_cleanup_jobs(1);
  perform set_config('t.job', j.id::text, true);
end $$;
select is(
  (select status || ':' || attempts from public.storage_cleanup_jobs where id = current_setting('t.job')::bigint),
  'running:1', 'claiming leases a job');
select lives_ok(
  format($$select public.complete_cleanup_job(%s, false, 'storage timeout')$$, current_setting('t.job')),
  'a failed cleanup is recorded');
reset role;
select ok(
  (select status = 'queued' and next_attempt_at > now() and last_error = 'storage timeout'
   from public.storage_cleanup_jobs where id = current_setting('t.job')::bigint),
  'failed cleanups are retried later with backoff');
update public.storage_cleanup_jobs set next_attempt_at = now() - interval '1 second'
  where id = current_setting('t.job')::bigint;
set local role service_role;
select ok(
  current_setting('t.job')::bigint in (select id from public.claim_cleanup_jobs(500)),
  'retries can be claimed again');
select lives_ok(
  format('select public.complete_cleanup_job(%s, true)', current_setting('t.job')),
  'a successful cleanup completes the job');
reset role;
select is(
  (select status from public.storage_cleanup_jobs where id = current_setting('t.job')::bigint),
  'done', 'completed jobs are marked done');

-- Expired leases return jobs to workers.
update public.storage_cleanup_jobs set status = 'running', lease_until = now() - interval '1 minute'
  where id = (select min(id) from public.storage_cleanup_jobs where status = 'queued');
set local role service_role;
select ok((select count(*) from public.claim_cleanup_jobs(500)) > 0,
  'jobs whose worker died are reclaimed after the lease');
reset role;

-- Jobs become dead after 10 failed attempts.
update public.storage_cleanup_jobs set attempts = 10, status = 'running'
  where id = current_setting('t.job')::bigint;
set local role service_role;
select public.complete_cleanup_job(current_setting('t.job')::bigint, false, 'gone');
reset role;
select is(
  (select status from public.storage_cleanup_jobs where id = current_setting('t.job')::bigint),
  'dead', 'jobs stop retrying after 10 attempts');

select * from finish();
rollback;
