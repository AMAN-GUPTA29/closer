-- Leaving, removing, transferring ownership, deleting groups and accounts:
-- never leaves orphaned or ownerless groups.
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

-- Adds a member directly (test setup only), with a deterministic join order.
create function pg_temp.add(p_group text, p_user text, p_minutes integer)
returns void language sql as $$
  insert into public.group_members (group_id, user_id, role, joined_at)
  values (current_setting('t.' || p_group)::uuid, current_setting('t.' || p_user)::uuid,
          'member', now() + make_interval(mins => p_minutes));
$$;

create function pg_temp.owner_of(p_group text)
returns uuid language sql as $$
  select user_id from public.group_members
  where group_id = current_setting('t.' || p_group)::uuid and role = 'owner';
$$;

create function pg_temp.integrity()
returns table (orphans integer, ownerless integer) language sql as $$
  select
    (select count(*)::int from public.groups g
      where not exists (select 1 from public.group_members m where m.group_id = g.id)),
    (select count(*)::int from public.groups g
      where not exists (select 1 from public.group_members m
                        where m.group_id = g.id and m.role = 'owner'));
$$;

select pg_temp.mk_user(u) from unnest(array['alice', 'bob', 'carol', 'dave', 'erin']) u;

select pg_temp.claims('alice');
set local role authenticated;
do $$ begin
  perform set_config('t.fam', public.create_group('Family', 'family')::text, true);
  perform set_config('t.solo', public.create_group('Just me', 'friends')::text, true);
  perform set_config('t.crew', public.create_group('Crew', 'friends')::text, true);
end $$;
reset role;

select pg_temp.add('fam', 'bob', 1);
select pg_temp.add('fam', 'carol', 2);
select pg_temp.add('crew', 'dave', 1);

-- Members cannot manage others.
select pg_temp.claims('bob');
set local role authenticated;
select throws_ok(
  format('select public.remove_member(%L, %L)', current_setting('t.fam'), current_setting('t.carol')),
  'P0001', 'closer:not_allowed', 'members cannot remove others');
select throws_ok(
  format('select public.transfer_ownership(%L, %L)', current_setting('t.fam'), current_setting('t.bob')),
  'P0001', 'closer:not_allowed', 'members cannot take ownership');
select throws_ok(
  format('select public.delete_group(%L)', current_setting('t.fam')),
  'P0001', 'closer:not_allowed', 'members cannot delete the group');
reset role;

-- Owner transfers ownership.
select pg_temp.claims('alice');
set local role authenticated;
select throws_ok(
  format('select public.transfer_ownership(%L, %L)', current_setting('t.fam'), current_setting('t.erin')),
  'P0001', 'closer:not_a_member', 'ownership goes only to a member');
select lives_ok(
  format('select public.transfer_ownership(%L, %L)', current_setting('t.fam'), current_setting('t.carol')),
  'owner transfers ownership');
reset role;
select is(pg_temp.owner_of('fam'), current_setting('t.carol')::uuid, 'carol is the new owner');
select is(
  (select role::text from public.group_members
   where group_id = current_setting('t.fam')::uuid and user_id = current_setting('t.alice')::uuid),
  'member', 'the previous owner becomes a member');

-- Owner removes a member, who loses access.
select pg_temp.claims('carol');
set local role authenticated;
select throws_ok(
  format('select public.remove_member(%L, %L)', current_setting('t.fam'), current_setting('t.carol')),
  'P0001', 'closer:use_leave_group', 'owners leave instead of removing themselves');
select lives_ok(
  format('select public.remove_member(%L, %L)', current_setting('t.fam'), current_setting('t.bob')),
  'owner removes a member');
reset role;
select pg_temp.claims('bob');
set local role authenticated;
select is((select count(*)::int from public.groups), 0, 'removed members lose access');
select throws_ok(
  format('select public.leave_group(%L)', current_setting('t.fam')),
  'P0001', 'closer:not_a_member', 'cannot leave a group you are not in');
reset role;

-- The owner leaving hands ownership to the longest-standing member.
select pg_temp.claims('carol');
set local role authenticated;
select lives_ok(format('select public.leave_group(%L)', current_setting('t.fam')), 'owner can leave');
reset role;
select is(pg_temp.owner_of('fam'), current_setting('t.alice')::uuid,
  'ownership passes to the longest-standing member');

-- The last member leaving deletes the group (and its invitations).
select pg_temp.claims('alice');
set local role authenticated;
do $$ begin perform public.create_invitation(current_setting('t.solo')::uuid); end $$;
select lives_ok(format('select public.leave_group(%L)', current_setting('t.solo')),
  'last member leaves');
reset role;
select is((select count(*)::int from public.groups where id = current_setting('t.solo')::uuid),
  0, 'an empty group is deleted');
select is((select count(*)::int from public.invitations where group_id = current_setting('t.solo')::uuid),
  0, 'its invitations are deleted too');

-- Deleting a group removes everything for everyone.
select pg_temp.claims('alice');
set local role authenticated;
select lives_ok(format('select public.delete_group(%L)', current_setting('t.crew')),
  'owner deletes a group');
reset role;
select is((select count(*)::int from public.group_members where group_id = current_setting('t.crew')::uuid),
  0, 'memberships are removed with the group');
select pg_temp.claims('dave');
set local role authenticated;
select is((select count(*)::int from public.groups), 0, 'former members see nothing');
reset role;

-- Account deletion never orphans a group.
select pg_temp.claims('dave');
set local role authenticated;
do $$ begin
  perform set_config('t.d1', public.create_group('Dave and Erin', 'friends')::text, true);
  perform set_config('t.d2', public.create_group('Dave alone', 'friends')::text, true);
end $$;
reset role;
select pg_temp.add('d1', 'erin', 5);
delete from auth.users where id = current_setting('t.dave')::uuid;
select is(pg_temp.owner_of('d1'), current_setting('t.erin')::uuid,
  'deleting the owner''s account promotes the next member');
select is((select count(*)::int from public.groups where id = current_setting('t.d2')::uuid),
  0, 'deleting the only member''s account deletes the group');
select is((select orphans from pg_temp.integrity()), 0, 'no groups without members');
select is((select ownerless from pg_temp.integrity()), 0, 'no groups without an owner');
select is((select count(*)::int from public.profiles where id = current_setting('t.dave')::uuid),
  0, 'the profile is deleted with the account');

select * from finish();
rollback;
