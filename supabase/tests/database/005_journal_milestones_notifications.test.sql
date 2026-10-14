-- Milestones, journal feed, covers, notifications, avatars, account deletion.
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

create function pg_temp.upload(p_key text, p_group text, p_taken timestamptz default null)
returns uuid language plpgsql as $$
declare v uuid;
begin
  perform pg_temp.claims(p_key);
  select photo_id into v from public.request_photo_upload(
    current_setting('t.' || p_group)::uuid, gen_random_uuid(), 'secret caption', p_taken);
  insert into storage.objects (bucket_id, name)
    select 'photos', unnest(array[storage_path, thumb_path]) from public.photos where id = v;
  perform public.finalize_photo(v);
  return v;
end $$;

select pg_temp.mk_user(u) from unnest(array['alice', 'bob', 'carol', 'eve']) u;

select pg_temp.claims('alice');
set local role authenticated;
do $$ begin
  perform set_config('t.g', public.create_group('Us', 'couple', current_date - 200)::text, true);
  perform set_config('t.other', public.create_group('Other', 'friends')::text, true);
end $$;
reset role;
insert into public.group_members (group_id, user_id) values
  (current_setting('t.g')::uuid, current_setting('t.bob')::uuid),
  (current_setting('t.other')::uuid, current_setting('t.carol')::uuid);

-- ------------------------------------------------------------ notifications
select is(
  (select count(*)::int from public.notifications
   where user_id = current_setting('t.alice')::uuid and kind = 'member_joined'
     and group_id = current_setting('t.g')::uuid),
  1, 'existing members are told when someone joins');
select is(
  (select count(*)::int from public.notifications where user_id = current_setting('t.bob')::uuid),
  0, 'the joiner is not notified about themselves');

do $$ begin
  perform set_config('t.p_old', pg_temp.upload('bob', 'g', now() - interval '30 days')::text, true);
  perform set_config('t.p_new', pg_temp.upload('bob', 'g')::text, true);
  perform set_config('t.p_other', pg_temp.upload('alice', 'other')::text, true);
end $$;

select is(
  (select count(*)::int from public.notifications
   where user_id = current_setting('t.alice')::uuid and kind = 'photo_added'),
  2, 'members are notified about new photos');
select is(
  (select count(*)::int from public.notifications
   where user_id = current_setting('t.bob')::uuid and kind = 'photo_added'),
  0, 'uploaders are not notified about their own photos');

-- Preferences are respected.
select pg_temp.claims('alice');
set local role authenticated;
insert into public.notification_preferences (user_id, photos)
values (current_setting('t.alice')::uuid, false);
select throws_ok(
  format($$insert into public.notification_preferences (user_id) values (%L)$$, current_setting('t.bob')),
  '42501', null, 'users cannot write someone else''s preferences');
reset role;
do $$ begin perform pg_temp.upload('bob', 'g'); end $$;
select is(
  (select count(*)::int from public.notifications
   where user_id = current_setting('t.alice')::uuid and kind = 'photo_added'),
  2, 'muted photo notifications are not created');

-- Recipients read only their own; notifications contain ids, not captions.
select pg_temp.claims('bob');
set local role authenticated;
select is((select count(*)::int from public.notifications), 0, 'users see only their notifications');
reset role;
select pg_temp.claims('alice');
set local role authenticated;
select ok((select count(*) > 0 from public.notifications), 'recipients see their notifications');
select throws_ok($$ select * from public.notifications where false and caption is null $$,
  '42703', null, 'notifications have no caption column');
select lives_ok($$ select public.mark_notifications_read() $$, 'mark all read');
select is((select count(*)::int from public.notifications where read_at is null), 0, 'all marked read');
select throws_ok($$ delete from public.notifications $$, '42501', null, 'notifications cannot be deleted by clients');
reset role;

-- ------------------------------------------------------------- milestones
select pg_temp.claims('bob');
set local role authenticated;
select lives_ok(
  format($$insert into public.milestones (group_id, title, type, event_date, theme, cover_photo_id)
          values (%L, '  100 days together ', 'days_together', current_date - 101, 'heart', %L)$$,
         current_setting('t.g'), current_setting('t.p_old')),
  'members create milestones');
select is(
  (select title || '|' || created_by::text from public.milestones where type = 'days_together'),
  '100 days together|' || current_setting('t.bob'), 'titles are trimmed and the creator is recorded');
select throws_ok(
  format($$insert into public.milestones (group_id, title, event_date, created_by)
          values (%L, 'Forged', current_date, %L)$$, current_setting('t.g'), current_setting('t.alice')),
  '42501', null, 'created_by cannot be chosen by the client');
select throws_ok(
  format($$insert into public.milestones (group_id, title, event_date, cover_photo_id)
          values (%L, 'Wrong cover', current_date, %L)$$, current_setting('t.g'), current_setting('t.p_other')),
  'P0001', 'closer:invalid_cover_photo', 'covers must be photos of the same group');
select throws_ok(
  format($$insert into public.milestones (group_id, title, event_date) values (%L, 'Sneaky', current_date)$$,
         current_setting('t.other')),
  '42501', null, 'non-members cannot add milestones');
select lives_ok(
  format($$insert into public.milestones (group_id, title, type, event_date)
          values (%L, 'Our anniversary', 'anniversary', current_date + 30)$$, current_setting('t.g')),
  'future milestones are allowed (countdowns)');
reset role;

select pg_temp.claims('eve');
set local role authenticated;
select is((select count(*)::int from public.milestones), 0, 'non-members see no milestones');
select is((select count(*)::int from public.journal_entries()), 0, 'non-members get an empty journal');
reset role;

-- Only the creator or the owner edits.
insert into public.group_members (group_id, user_id) values
  (current_setting('t.other')::uuid, current_setting('t.bob')::uuid);
select pg_temp.claims('carol');
set local role authenticated;
do $$ begin
  insert into public.milestones (group_id, title, event_date)
  values (current_setting('t.other')::uuid, 'Carol''s trip', current_date - 5);
end $$;
reset role;
select pg_temp.claims('bob');
set local role authenticated;
update public.milestones set title = 'Hijacked' where title = 'Carol''s trip';
reset role;
select is((select title from public.milestones where group_id = current_setting('t.other')::uuid),
  'Carol''s trip', 'other members cannot edit someone''s milestone');
select pg_temp.claims('alice');
set local role authenticated;
update public.milestones set is_pinned = true where title = 'Carol''s trip';
reset role;
select is((select is_pinned from public.milestones where title = 'Carol''s trip'),
  true, 'the owner can pin any milestone');

-- ---------------------------------------------------------------- journal
select pg_temp.claims('alice');
set local role authenticated;
select is(
  (select array_agg(e ->> 'kind' order by ord) from public.journal_entries(current_setting('t.g')::uuid)
     with ordinality as j(e, ord)),
  array['photo', 'photo', 'photo', 'milestone'],
  'journal mixes photos and milestones, newest first by date');
select is(
  (select count(*)::int from public.journal_entries(current_setting('t.g')::uuid) e
   where e ->> 'kind' = 'milestone' and e -> 'milestone' ->> 'type' = 'anniversary'),
  0, 'future milestones are not in the journal');
select is((select count(*)::int from public.journal_entries()), 6,
  'the all-groups journal covers every group the user is in');
do $$
declare
  first_page jsonb[];
  cursor_at timestamptz;
  cursor_id uuid;
begin
  select array_agg(e) into first_page from public.journal_entries(current_setting('t.g')::uuid, null, null, 2) e;
  cursor_at := (first_page[2] ->> 'occurred_at')::timestamptz;
  cursor_id := (first_page[2] ->> 'id')::uuid;
  perform set_config('t.page2', (
    select string_agg(e ->> 'id', ',')
    from public.journal_entries(current_setting('t.g')::uuid, cursor_at, cursor_id, 10) e), true);
  perform set_config('t.page1', first_page[1] ->> 'id' || ',' || (first_page[2] ->> 'id'), true);
end $$;
select is(array_length(string_to_array(current_setting('t.page2'), ','), 1), 2,
  'the second page continues after the cursor');
select ok(not (string_to_array(current_setting('t.page1'), ',') && string_to_array(current_setting('t.page2'), ',')),
  'pages do not overlap');
reset role;

-- ------------------------------------------- deleted photos & references (§14)
select pg_temp.claims('alice');
set local role authenticated;
select lives_ok(format('select public.set_group_cover(%L, %L)', current_setting('t.g'), current_setting('t.p_old')),
  'the owner chooses a cover photo');
select is(
  (select latest_thumb_path from public.group_summaries where id = current_setting('t.g')::uuid),
  (select thumb_path from public.photos where id = current_setting('t.p_old')::uuid),
  'the chosen cover wins over the newest photo');
select throws_ok(format('select public.set_group_cover(%L, %L)', current_setting('t.g'), current_setting('t.p_other')),
  'P0001', 'closer:invalid_cover_photo', 'covers must come from the group');
reset role;
select pg_temp.claims('bob');
set local role authenticated;
select throws_ok(format('select public.set_group_cover(%L, null)', current_setting('t.g')),
  'P0001', 'closer:not_allowed', 'only the owner changes the cover');
select lives_ok(format('select public.delete_photo(%L)', current_setting('t.p_old')),
  'the uploader deletes the cover photo');
reset role;
select is(
  (select cover_photo_id from public.milestones where type = 'days_together'), null,
  'a deleted photo is removed from milestone covers');
select is(
  (select cover_photo_id from public.groups where id = current_setting('t.g')::uuid), null,
  'a deleted photo is removed as group cover');
select ok(
  (select count(*) = 0 from public.milestones m join public.photos p on p.id = m.cover_photo_id
   where p.status <> 'active'),
  'no milestone points at a removed photo');

-- Retention removal clears covers too.
do $$
declare v uuid;
begin
  perform pg_temp.claims('alice');
  v := pg_temp.upload('alice', 'other');
  update public.milestones set cover_photo_id = v where title = 'Carol''s trip';
  update public.photos set uploaded_at = now() - interval '1 day' where id = v;
  for i in 1..10 loop perform pg_temp.upload('alice', 'other'); end loop;
  perform set_config('t.retained', v::text, true);
end $$;
select is((select status::text from public.photos where id = current_setting('t.retained')::uuid),
  'removed', 'retention removed the old cover photo');
select is((select cover_photo_id from public.milestones where title = 'Carol''s trip'), null,
  'retention also clears milestone covers');

-- ------------------------------------------------------------------ avatars
select pg_temp.claims('bob');
set local role authenticated;
select lives_ok(
  format($$insert into storage.objects (bucket_id, name) values ('avatars', %L)$$,
         current_setting('t.bob') || '/abcdefgh1234.jpg'),
  'users upload avatars into their own folder');
select throws_ok(
  format($$insert into storage.objects (bucket_id, name) values ('avatars', %L)$$,
         current_setting('t.alice') || '/abcdefgh1234.jpg'),
  '42501', null, 'users cannot write into someone else''s avatar folder');
select lives_ok(format('select public.set_avatar(%L)', current_setting('t.bob') || '/abcdefgh1234.jpg'),
  'set_avatar points the profile at the upload');
select throws_ok(
  format($$update public.profiles set avatar_path = 'x' where id = %L$$, current_setting('t.bob')),
  '42501', null, 'avatar_path is changed only through set_avatar');
reset role;
select pg_temp.claims('alice');
set local role authenticated;
select is((select count(*)::int from storage.objects where bucket_id = 'avatars'), 1,
  'group co-members can see each other''s avatar');
reset role;
select pg_temp.claims('eve');
set local role authenticated;
select is((select count(*)::int from storage.objects where bucket_id = 'avatars'), 0,
  'strangers cannot see avatars');
reset role;

-- ------------------------------------------------- leaving and account deletion
select pg_temp.claims('carol');
set local role authenticated;
select lives_ok(format('select public.leave_group(%L)', current_setting('t.other')), 'carol leaves');
reset role;
select is((select count(*)::int from public.notifications
   where user_id = current_setting('t.carol')::uuid and group_id = current_setting('t.other')::uuid),
  0, 'leaving a group removes its notifications');

set local role service_role;
select lives_ok(format('select public.prepare_account_deletion(%L)', current_setting('t.bob')),
  'account deletion is prepared');
reset role;
select is((select count(*)::int from public.storage_cleanup_jobs
   where bucket_id = 'avatars' and reason = 'account_deleted'), 1,
  'the avatar is queued for deletion');
delete from auth.users where id = current_setting('t.bob')::uuid;
select is((select count(*)::int from public.photos where id = current_setting('t.p_new')::uuid and uploader_id is null),
  1, 'photos shared by a deleted account stay with the group');
select is((select count(*)::int from public.milestones where created_by is null), 2,
  'milestones created by a deleted account stay with the group');
select is((select count(*)::int from public.notifications where actor_id = current_setting('t.bob')::uuid),
  0, 'no notification still names the deleted account');
select pg_temp.claims('alice');
set local role authenticated;
select is((select member_count from public.group_summaries where id = current_setting('t.g')::uuid),
  1, 'the deleted account is no longer a member');
reset role;

set local role authenticated;
select throws_ok(format('select public.prepare_account_deletion(%L)', current_setting('t.alice')),
  '42501', null, 'clients cannot call account deletion helpers');
reset role;

select * from finish();
rollback;
