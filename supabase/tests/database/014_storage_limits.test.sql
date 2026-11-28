-- Storage abuse limits: groups, uploads, thumbnail size, profile photos,
-- abandoned uploads and the storage watch.
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

create function pg_temp.id(p_key text)
returns uuid language sql as $$ select current_setting('t.' || p_key)::uuid $$;

create function pg_temp.request()
returns uuid language sql as $$
  select photo_id from public.request_photo_upload(pg_temp.id('g'), gen_random_uuid())
$$;

create function pg_temp.store(p_photo uuid, p_thumb_bytes bigint default 1000)
returns void language sql as $$
  insert into storage.objects (bucket_id, name, metadata)
  select 'photos', p.storage_path, '{"size": 900000}'::jsonb from public.photos p where p.id = p_photo
  union all
  select 'photos', p.thumb_path, jsonb_build_object('size', p_thumb_bytes) from public.photos p where p.id = p_photo;
$$;

select pg_temp.mk_user(u) from unnest(array['alice', 'bob']) u;
select pg_temp.claims('alice');
set local role authenticated;
do $$ begin
  perform set_config('t.g', public.create_group('Crew', 'friends')::text, true);
end $$;
reset role;

select is((select file_size_limit from storage.buckets where id = 'photos'),
  10 * 1024 * 1024::bigint, 'a photo file is at most 10 MB');

-- ------------------------------------------------------------------ groups
insert into public.groups (name, type, created_by)
select 'Filler ' || i, 'friends', pg_temp.id('alice') from generate_series(1, 9) i;
set local role authenticated;
select throws_ok($$select public.create_group('One too many', 'friends')$$,
  'P0001', 'closer:group_limit', 'an account can create at most 10 groups');
reset role;

-- At most 30 groups in total, joined or created.
select pg_temp.mk_user('carol');
insert into public.groups (name, type, created_by)
select 'Carol ' || i, 'friends', pg_temp.id('carol') from generate_series(1, 31) i;
-- Bob already owns one group; fill up to 30.
insert into public.group_members (group_id, user_id)
select g.id, pg_temp.id('bob') from public.groups g
where g.created_by = pg_temp.id('carol') and g.name <> 'Carol 31'
order by g.name
limit 30 - (select count(*) from public.group_members where user_id = pg_temp.id('bob'));
select is((select count(*)::int from public.group_members where user_id = pg_temp.id('bob')),
  30, 'a member of 30 groups');
select throws_ok(
  $$insert into public.group_members (group_id, user_id)
    select id, current_setting('t.bob')::uuid from public.groups where name = 'Carol 31'$$,
  'P0001', 'closer:membership_limit', 'cannot join a 31st group');
select pg_temp.claims('bob');
set local role authenticated;
select throws_ok($$select public.create_group('Mine', 'friends')$$,
  'P0001', 'closer:membership_limit', 'nor create one, which is also a membership');
reset role;
delete from public.group_members where user_id = pg_temp.id('bob')
  and group_id = (select id from public.groups where name = 'Carol 1');
select pg_temp.claims('bob');
set local role authenticated;
select lives_ok($$select public.create_group('Bob''s', 'friends')$$,
  'the limit is per account');
reset role;

-- ----------------------------------------------------------------- uploads
select pg_temp.claims('alice');
do $$ begin
  for i in 1..10 loop perform pg_temp.request(); end loop;
end $$;
select throws_ok($$select pg_temp.request()$$,
  'P0001', 'closer:too_many_uploads', 'at most 10 unfinished uploads at once');
select is(
  (select count(*)::int from public.request_photo_upload(pg_temp.id('g'),
     (select client_upload_id from public.photos where status = 'pending' limit 1))),
  1, 'retrying an unfinished upload still works at the limit');

-- Abandoned uploads expire after an hour and their files are queued.
update public.photos set created_at = now() - interval '61 minutes' where status = 'pending';
set local role service_role;
select is(public.expire_stale_uploads(), 10, 'unfinished uploads expire after an hour');
reset role;
select is(
  (select count(*)::int from public.storage_cleanup_jobs where reason = 'upload_abandoned'),
  20, 'their files are queued for deletion');
select lives_ok($$select pg_temp.request()$$, 'then uploading works again');

-- A thumbnail must be small.
do $$
declare v uuid := pg_temp.request();
begin
  perform pg_temp.store(v, 3 * 1024 * 1024);
  perform set_config('t.big', v::text, true);
end $$;
select throws_ok($$select public.finalize_photo(current_setting('t.big')::uuid)$$,
  'P0001', 'closer:upload_too_large', 'an oversized thumbnail is refused');
do $$
declare v uuid := pg_temp.request();
begin
  perform pg_temp.store(v);
  perform set_config('t.ok', v::text, true);
end $$;
select lives_ok($$select public.finalize_photo(current_setting('t.ok')::uuid)$$,
  'a normal photo goes through');

-- 300 uploads per day, counting expired and removed ones.
update public.photos set status = 'removed', removed_at = now(), removed_reason = 'upload_abandoned'
  where status = 'pending';
insert into public.photos (group_id, uploader_id, client_upload_id, storage_path, thumb_path,
                           status, removed_at, removed_reason)
select pg_temp.id('g'), pg_temp.id('alice'), gen_random_uuid(),
       'x/' || i || '/o.jpg', 'x/' || i || '/t.jpg', 'removed', now(), 'deleted'
from generate_series(1, 300 - (select count(*)::int from public.photos
                               where uploader_id = pg_temp.id('alice'))) i;
select throws_ok($$select pg_temp.request()$$,
  'P0001', 'closer:upload_limit', 'at most 300 uploads per day, deleted ones included');
update public.photos set created_at = now() - interval '25 hours'
  where uploader_id = pg_temp.id('alice');
select lives_ok($$select pg_temp.request()$$, 'the next day uploads work again');

-- --------------------------------------------------------- profile photos
select pg_temp.claims('alice');
set local role authenticated;
select ok(public.can_upload_avatar_object(current_setting('t.alice') || '/aaaaaaaa.jpg'),
  'a first profile photo can be uploaded');
reset role;
insert into storage.objects (bucket_id, name, created_at)
select 'avatars', pg_temp.id('alice') || '/file' || i || 'xxxx.jpg', now() - interval '2 hours'
from generate_series(1, 3) i;
set local role authenticated;
select ok(not public.can_upload_avatar_object(current_setting('t.alice') || '/bbbbbbbb.jpg'),
  'at most 3 profile-photo files per account');
reset role;
update public.profiles set avatar_path = pg_temp.id('alice') || '/file1xxxx.jpg'
  where id = pg_temp.id('alice');
set local role service_role;
select is(public.queue_orphan_avatars(), 2, 'files no profile uses are queued for deletion');
select is(public.queue_orphan_avatars(), 0, 'and only once');
reset role;
select is(
  (select count(*)::int from public.storage_cleanup_jobs
   where bucket_id = 'avatars' and object_path like '%file1xxxx.jpg'),
  0, 'the current profile photo is kept');

-- ---------------------------------------------------------- storage watch
set local role service_role;
select is((public.check_storage_usage()).objects,
  (select count(*)::int from storage.objects), 'the daily check counts every file');
select is((select count(*)::int from public.storage_usage_log), 1, 'one row per day');
select is((select count(*)::int from public.storage_by_user()), 1, 'usage per uploader');
reset role;

select pg_temp.claims('alice');
set local role authenticated;
select throws_ok($$select * from public.storage_usage_log$$, '42501', null,
  'members cannot read the storage log');
select throws_ok($$select * from public.storage_by_user()$$, '42501', null,
  'members cannot see who stores what');
select throws_ok($$select public.expire_stale_uploads()$$, '42501', null,
  'members cannot expire uploads');
reset role;

select * from finish();
rollback;
