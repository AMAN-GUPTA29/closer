-- A person can be in at most one couple group; other group types are unlimited.
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

select pg_temp.mk_user(u) from unnest(array['ann', 'ben', 'cat', 'dan']) u;

-- Ann creates a couple group and invites.
select pg_temp.claims('ann');
set local role authenticated;
do $$
declare r record;
begin
  perform set_config('t.ann_couple', public.create_group('Ann + ?', 'couple')::text, true);
  select * into r from public.create_invitation(current_setting('t.ann_couple')::uuid);
  perform set_config('t.ann_code', r.code, true);
end $$;

select throws_ok(
  $$ select public.create_group('Second couple', 'couple') $$,
  'P0001', 'closer:already_in_couple', 'a second couple group cannot be created');
select lives_ok(
  $$ select public.create_group('Ann friends', 'friends') $$,
  'friends groups are unlimited');
select lives_ok(
  $$ select public.create_group('Ann family', 'family') $$,
  'family groups are unlimited');
reset role;

-- Ben has his own couple group, so he cannot join Ann's.
select pg_temp.claims('ben');
set local role authenticated;
select lives_ok($$ select public.create_group('Ben + ?', 'couple') $$, 'Ben creates his couple group');
select is(public.preview_invitation(current_setting('t.ann_code')) ->> 'status',
  'already_in_couple', 'the preview warns before joining');
select is(public.redeem_invitation(current_setting('t.ann_code')) ->> 'status',
  'already_in_couple', 'redeeming is refused');
select is(
  (select count(*)::int from public.group_members
   where group_id = current_setting('t.ann_couple')::uuid),
  1, 'Ann''s group still has only Ann');
reset role;

-- Cat is in no couple group and can join.
select pg_temp.claims('cat');
set local role authenticated;
select is(public.preview_invitation(current_setting('t.ann_code')) ->> 'status',
  'valid', 'someone without a couple group sees a valid invitation');
select is(public.redeem_invitation(current_setting('t.ann_code')) ->> 'status',
  'joined', 'and can join');
select throws_ok(
  $$ select public.create_group('Cat second', 'couple') $$,
  'P0001', 'closer:already_in_couple', 'after joining, a new couple group is refused');
-- Leaving frees the slot.
select lives_ok(
  $$ select public.leave_group(current_setting('t.ann_couple')::uuid) $$,
  'Cat leaves the couple group');
select lives_ok(
  $$ select public.create_group('Cat new couple', 'couple') $$,
  'after leaving, a new couple group can be created');
reset role;

-- Direct inserts (e.g. future code paths) are covered by the trigger too.
select throws_ok(
  format($$ insert into public.group_members (group_id, user_id, role)
            values (%L, %L, 'member') $$,
         current_setting('t.ann_couple'), current_setting('t.ben')),
  'P0001', 'closer:already_in_couple', 'the rule holds below the functions');

select ok(not has_function_privilege('authenticated',
  'public.enforce_one_couple_per_person()', 'execute'),
  'the trigger function is not callable by clients');

select * from finish();
rollback;
