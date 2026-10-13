-- Groups, profiles and Row Level Security.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

create function pg_temp.mk_user(p_key text, p_name text default null)
returns uuid language plpgsql as $$
declare v uuid := gen_random_uuid();
begin
  insert into auth.users (id, email, raw_user_meta_data, aud, role)
  values (v, p_key || '@test.local',
          case when p_name is null then '{}'::jsonb
               else jsonb_build_object('display_name', p_name) end,
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

select pg_temp.mk_user('alice', 'Alice Kim');
select pg_temp.mk_user('bob', 'Bob');
select pg_temp.mk_user('noname');

-- Profiles are created by the auth trigger.
select is(
  (select display_name from public.profiles where id = current_setting('t.alice')::uuid),
  'Alice Kim', 'profile uses display_name from sign-up metadata');
select is(
  (select display_name from public.profiles where id = current_setting('t.noname')::uuid),
  'noname', 'profile falls back to the email local part');

-- Alice creates groups.
select pg_temp.claims('alice');
set local role authenticated;

do $$ begin
  perform set_config('t.couple', public.create_group('Us', 'couple', current_date - 100)::text, true);
  perform set_config('t.friends', public.create_group('  Travel Crew  ', 'friends')::text, true);
end $$;

select is((select count(*)::int from public.group_summaries), 2, 'creator sees both groups');
select is(
  (select my_role::text from public.group_summaries where id = current_setting('t.couple')::uuid),
  'owner', 'creator is the owner');
select is(
  (select member_count from public.group_summaries where id = current_setting('t.couple')::uuid),
  1, 'creator is the only member');
select is(
  (select name from public.groups where id = current_setting('t.friends')::uuid),
  'Travel Crew', 'group names are trimmed');

select throws_ok(
  $$ select public.create_group('Pals', 'friends', current_date) $$,
  'P0001', 'closer:relationship_date_couples_only',
  'only couple groups take a relationship start date');
select throws_ok(
  $$ select public.create_group('Future', 'couple', current_date + 1) $$,
  'P0001', 'closer:relationship_date_in_future',
  'relationship start date cannot be in the future');
select throws_ok(
  $$ select public.create_group('   ', 'friends') $$,
  '23514', null, 'blank group names are rejected');

select is(
  (with u as (update public.groups set name = 'Us two'
              where id = current_setting('t.couple')::uuid returning 1)
   select count(*)::int from u),
  1, 'owner can rename the group');

select throws_ok(
  $$ update public.groups set created_by = null where id = current_setting('t.couple')::uuid $$,
  '42501', null, 'created_by is not client-writable');
select throws_ok(
  $$ insert into public.groups (name, type) values ('Sneaky', 'friends') $$,
  '42501', null, 'groups cannot be inserted directly');
select throws_ok(
  $$ insert into public.group_members (group_id, user_id, role)
     values (current_setting('t.couple')::uuid, current_setting('t.bob')::uuid, 'member') $$,
  '42501', null, 'memberships cannot be inserted directly');
select throws_ok(
  $$ update public.group_members set role = 'member'
     where group_id = current_setting('t.couple')::uuid $$,
  '42501', null, 'roles cannot be changed directly');

reset role;

-- Bob is not a member of anything.
select pg_temp.claims('bob');
set local role authenticated;

select is((select count(*)::int from public.groups), 0, 'non-member sees no groups');
select is((select count(*)::int from public.group_summaries), 0, 'non-member sees no summaries');
select is((select count(*)::int from public.group_members), 0, 'non-member sees no memberships');
select is(
  (select count(*)::int from public.profiles where id = current_setting('t.alice')::uuid),
  0, 'non-member cannot read a stranger''s profile');
select is((select count(*)::int from public.profiles), 1, 'user can read only their own profile');
select is(
  (with u as (update public.groups set name = 'Hacked'
              where id = current_setting('t.couple')::uuid returning 1)
   select count(*)::int from u),
  0, 'non-member cannot rename a group');
select is(
  (with d as (delete from public.group_members
              where group_id = current_setting('t.couple')::uuid returning 1)
   select count(*)::int from d),
  0, 'non-member cannot delete memberships');
select throws_ok(
  $$ select public.delete_group(current_setting('t.couple')::uuid) $$,
  'P0001', 'closer:not_allowed', 'non-member cannot delete a group');
select throws_ok(
  $$ select * from public.create_invitation(current_setting('t.couple')::uuid) $$,
  'P0001', 'closer:not_a_member', 'non-member cannot create invitations');
select is(
  (with u as (update public.profiles set display_name = 'Robert'
              where id = current_setting('t.bob')::uuid returning 1)
   select count(*)::int from u),
  1, 'users can update their own profile');
select is(
  (with u as (update public.profiles set display_name = 'Not Alice'
              where id = current_setting('t.alice')::uuid returning 1)
   select count(*)::int from u),
  0, 'users cannot update someone else''s profile');

reset role;

-- Unauthenticated (anon) access.
set local role anon;
select throws_ok($$ select * from public.groups $$, '42501', null, 'anon cannot read groups');
select throws_ok($$ select * from public.group_members $$, '42501', null, 'anon cannot read memberships');
select throws_ok($$ select * from public.profiles $$, '42501', null, 'anon cannot read profiles');
select throws_ok($$ select * from public.invitations $$, '42501', null, 'anon cannot read invitations');
select throws_ok($$ select * from public.group_summaries $$, '42501', null, 'anon cannot read summaries');
select throws_ok(
  $$ select public.create_group('x', 'friends') $$,
  '42501', null, 'anon cannot call create_group');
select throws_ok(
  $$ select public.redeem_invitation('ABCDEFGH') $$,
  '42501', null, 'anon cannot redeem invitations');
reset role;

-- An authenticated role without a user id is rejected by trusted functions.
select set_config('request.jwt.claims', '{}', true);
set local role authenticated;
select throws_ok(
  $$ select public.create_group('Ghost', 'friends') $$,
  'P0001', 'closer:not_authenticated', 'functions require a signed-in user');
reset role;

-- RLS is enabled on every table in public.
select is(
  (select count(*)::int from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity),
  0, 'row level security is enabled on every public table');

select * from finish();
rollback;
