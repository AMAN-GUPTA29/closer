-- Reporting a photo: hidden for the reporter on every path, secret from
-- everyone else, and the evidence kept until the report is closed.
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

create function pg_temp.upload(p_key text)
returns uuid language plpgsql as $$
declare v uuid;
begin
  select photo_id into v from public.request_photo_upload(pg_temp.id('g'), gen_random_uuid(), p_key);
  insert into storage.objects (bucket_id, name)
  select 'photos', unnest(array[p.storage_path, p.thumb_path]) from public.photos p where p.id = v;
  perform public.finalize_photo(v);
  perform set_config('t.' || p_key, v::text, true);
  return v;
end $$;

create function pg_temp.report_of(p_photo text)
returns uuid language sql as $$
  select r.id from public.photo_reports r where r.photo_id = pg_temp.id(p_photo) limit 1
$$;

-- How many files of a photo the cleanup worker would be given.
create function pg_temp.claimable(p_photo text)
returns integer language sql as $$
  select count(*)::int from public.claim_cleanup_jobs(200) j where j.photo_id = pg_temp.id(p_photo)
$$;

select pg_temp.mk_user(u) from unnest(array['riya', 'rahul', 'dev', 'eve']) u;
select pg_temp.claims('rahul');
set local role authenticated;
do $$ begin
  perform set_config('t.g', public.create_group('College Friends', 'friends')::text, true);
end $$;
reset role;
insert into public.group_members (group_id, user_id)
values (pg_temp.id('g'), pg_temp.id('riya')), (pg_temp.id('g'), pg_temp.id('dev'));

select pg_temp.claims('rahul');
select pg_temp.upload(k) from unnest(array['bad', 'fine', 'gone', 'illegal']) k;
update public.groups set cover_photo_id = pg_temp.id('bad') where id = pg_temp.id('g');
insert into public.milestones (group_id, created_by, title, event_date, cover_photo_id)
values (pg_temp.id('g'), pg_temp.id('rahul'), 'Farewell', current_date, pg_temp.id('bad'));
select set_config('t.bad_path', storage_path, true),
       set_config('t.bad_thumb', thumb_path, true)
from public.photos where id = pg_temp.id('bad');

select set_config('t.rahul_notes',
  (select count(*) from public.notifications where user_id = pg_temp.id('rahul'))::text, true);

-- ---------------------------------------------------------------- who may
select pg_temp.claims('rahul');
set local role authenticated;
select throws_ok($$select public.report_photo(current_setting('t.bad')::uuid, 'other')$$,
  'P0001', 'closer:report_own_photo', 'nobody reports their own photo');
reset role;

select pg_temp.claims('eve');
set local role authenticated;
select throws_ok($$select public.report_photo(current_setting('t.bad')::uuid, 'other')$$,
  'P0001', 'closer:photo_not_found', 'outsiders cannot report or probe photos');
reset role;

select pg_temp.claims('riya');
set local role authenticated;
select throws_ok($$select public.report_photo(current_setting('t.bad')::uuid, 'boring')$$,
  'P0001', 'closer:invalid_report', 'the reason must be one of the four');
select lives_ok($$select public.report_photo(current_setting('t.bad')::uuid, 'harassment')$$,
  'a member reports a photo');
select lives_ok($$select public.report_photo(current_setting('t.bad')::uuid, 'other')$$,
  'reporting twice is harmless');

-- ---------------------------------------------------------- hidden for her
select is((select count(*)::int from public.photos where id = current_setting('t.bad')::uuid),
  0, 'the photo is hidden in the grid and pins');
select is(
  (select count(*)::int from public.journal_entries(current_setting('t.g')::uuid) j
   where j ->> 'id' = current_setting('t.bad')),
  0, 'the photo is hidden in the journal');
select is(
  (select j -> 'milestone' ->> 'cover_thumb_path'
   from public.journal_entries(current_setting('t.g')::uuid) j
   where j ->> 'kind' = 'milestone'),
  null, 'the photo is hidden as a milestone cover');
select is(
  (select count(*)::int from storage.objects
   where name in (current_setting('t.bad_path'), current_setting('t.bad_thumb'))),
  0, 'neither file can be read or signed');
select is((select count(*)::int from public.notifications where photo_id = current_setting('t.bad')::uuid),
  0, 'its notification is gone');
select isnt(
  (select latest_thumb_path from public.group_summaries where id = current_setting('t.g')::uuid),
  current_setting('t.bad_thumb'), 'it is no longer the group cover she sees');
select is((select photo_count from public.group_summaries where id = current_setting('t.g')::uuid),
  4, 'the group count still includes it');
reset role;

select is((select count(*)::int from public.photo_reports where photo_id = pg_temp.id('bad')),
  1, 'one report per person and photo');
select is((select reason from public.photo_reports where photo_id = pg_temp.id('bad')),
  'harassment', 'the first reason is kept');

-- -------------------------------------------------------- secret from others
select pg_temp.claims('rahul');
set local role authenticated;
select is((select count(*)::int from public.photos where id = current_setting('t.bad')::uuid),
  1, 'the uploader still sees the photo');
select is((select latest_thumb_path from public.group_summaries where id = current_setting('t.g')::uuid),
  current_setting('t.bad_thumb'), 'the uploader still sees it as the cover');
select ok(not public.has_reported(current_setting('t.bad')::uuid),
  'has_reported only answers for the caller');
select is((select count(*)::int from public.notifications where user_id = current_setting('t.rahul')::uuid),
  current_setting('t.rahul_notes')::int, 'the uploader is not notified');
select throws_ok($$select * from public.photo_reports$$, '42501', null,
  'members and group owners cannot read reports');
select throws_ok($$select * from public.photo_report_queue()$$, '42501', null,
  'members cannot read the queue');
select throws_ok($$select public.resolve_photo_report(gen_random_uuid(), 'dismiss')$$, '42501', null,
  'members cannot close reports');
reset role;

select pg_temp.claims('dev');
set local role authenticated;
select is((select count(*)::int from storage.objects where name = current_setting('t.bad_path')),
  1, 'other members still see the photo');
reset role;

select pg_temp.claims('eve');
set local role authenticated;
select is(public.group_photo_count(current_setting('t.g')::uuid), 0,
  'the count reveals nothing to outsiders');
reset role;

-- ------------------------------------------------------------ the app owner
select pg_temp.claims('riya');
set local role authenticated;
select lives_ok($$select public.report_photo(current_setting('t.illegal')::uuid, 'child')$$,
  'a child-safety report');
select lives_ok($$select public.report_photo(current_setting('t.gone')::uuid, 'sexual')$$,
  'a third report');
reset role;

set local role service_role;
select is((select count(*)::int from public.photo_report_queue()), 3, 'the owner sees every open report');
select is((select q.reason from public.photo_report_queue() q limit 1), 'child',
  'child safety comes first');
select is(
  (select q.reporter_name || '>' || q.uploader_name || ':' || q.caption
   from public.photo_report_queue() q where q.reason = 'harassment'),
  'Riya>Rahul:bad', 'the owner sees who, whose and what');
reset role;

-- Dismiss.
select lives_ok($$select public.resolve_photo_report(pg_temp.report_of('bad'), 'dismiss')$$,
  'a report can be dismissed');
select is((select status::text from public.photos where id = pg_temp.id('bad')), 'active',
  'dismissing leaves the photo for everyone else');
select is((select caption from public.photo_reports where photo_id = pg_temp.id('bad')), null,
  'closing clears the copied caption');
select throws_ok($$select public.resolve_photo_report(pg_temp.report_of('bad'), 'remove')$$,
  'P0001', 'closer:report_closed', 'a closed report stays closed');
select pg_temp.claims('riya');
set local role authenticated;
select is((select count(*)::int from public.photos where id = current_setting('t.bad')::uuid),
  0, 'a dismissed photo stays hidden for the reporter');
reset role;

-- The uploader deletes a photo that is under review.
select pg_temp.claims('rahul');
set local role authenticated;
select lives_ok($$select public.delete_photo(current_setting('t.gone')::uuid)$$,
  'the uploader can still delete it');
reset role;
select is(pg_temp.claimable('gone'), 0, 'its files are kept while the report is open');
select lives_ok($$select public.resolve_photo_report(pg_temp.report_of('gone'), 'remove')$$,
  'a report on a deleted photo can be closed');
select is(pg_temp.claimable('gone'), 2, 'closing releases the files');

-- Hold for the police, then remove.
select lives_ok($$select public.resolve_photo_report(pg_temp.report_of('illegal'), 'hold')$$,
  'a photo can be held');
select is((select status::text from public.photos where id = pg_temp.id('illegal')), 'removed',
  'holding takes it away from everyone at once');
select is(pg_temp.claimable('illegal'), 0, 'holding keeps the files');
select throws_ok($$select public.resolve_photo_report(pg_temp.report_of('illegal'), 'dismiss')$$,
  'P0001', 'closer:report_held', 'a held report cannot be dismissed');
select lives_ok($$select public.resolve_photo_report(pg_temp.report_of('illegal'), 'remove')$$,
  'a held photo can be released for erasing');
select is(pg_temp.claimable('illegal'), 2, 'then the files are erased');

-- Evidence survives deleting the whole group.
select pg_temp.claims('riya');
set local role authenticated;
select lives_ok($$select public.report_photo(current_setting('t.fine')::uuid, 'other')$$,
  'one more report');
reset role;
select pg_temp.claims('rahul');
set local role authenticated;
select lives_ok($$select public.delete_group(current_setting('t.g')::uuid)$$,
  'the group owner deletes the group');
reset role;
select is(pg_temp.claimable('fine'), 0, 'reported files survive deleting the group');
select is((select count(*)::int from public.photo_report_queue()), 1, 'and so does the report');

-- And the reporter deleting their account.
delete from auth.users where id = pg_temp.id('riya');
select is((select count(*)::int from public.photo_report_queue() q where q.reporter_id is null), 1,
  'the report stays, without the reporter');

select * from finish();
rollback;
