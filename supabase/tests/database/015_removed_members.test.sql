-- A removed member can't rejoin with an old invitation, their own
-- invitations are cancelled, and only a new one from the owner lets them back.
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

-- Creates an invitation as p_key and remembers its code as t.<p_name>.
create function pg_temp.invite(p_key text, p_name text)
returns void language plpgsql as $$
declare r record;
begin
  perform pg_temp.claims(p_key);
  select * into r from public.create_invitation(current_setting('t.g')::uuid, 168, null);
  perform set_config('t.' || p_name, r.code, true);
  perform set_config('t.' || p_name || '_id', r.invitation_id::text, true);
  -- One test transaction shares now(); give each invitation its real moment.
  update public.invitations set created_at = clock_timestamp() where id = r.invitation_id;
end $$;

create function pg_temp.redeem(p_key text, p_invite text)
returns text language plpgsql as $$
begin
  perform pg_temp.claims(p_key);
  return public.redeem_invitation(current_setting('t.' || p_invite)) ->> 'status';
end $$;

create function pg_temp.preview(p_key text, p_invite text)
returns text language plpgsql as $$
begin
  perform pg_temp.claims(p_key);
  return public.preview_invitation(current_setting('t.' || p_invite)) ->> 'status';
end $$;

select pg_temp.mk_user(u) from unnest(array['alice', 'bob', 'carol']) u;
select pg_temp.claims('alice');
set local role authenticated;
do $$ begin
  perform set_config('t.g', public.create_group('Crew', 'friends')::text, true);
end $$;
reset role;

select pg_temp.invite('alice', 'old');
select is(pg_temp.redeem('bob', 'old'), 'joined', 'Bob joins');
select is(pg_temp.redeem('carol', 'old'), 'joined', 'Carol joins');
select pg_temp.invite('bob', 'bobs');

-- The owner removes Bob.
select pg_temp.claims('alice');
select public.remove_member(current_setting('t.g')::uuid, current_setting('t.bob')::uuid);

select ok((select revoked_at is not null from public.invitations
           where id = current_setting('t.bobs_id')::uuid),
  'invitations Bob created are cancelled');
select is(pg_temp.preview('bob', 'old'), 'removed', 'the old invitation shows he was removed');
select is(pg_temp.redeem('bob', 'old'), 'removed', 'and cannot be used to rejoin');
select is((select count(*)::int from public.group_members
           where group_id = current_setting('t.g')::uuid and user_id = current_setting('t.bob')::uuid),
  0, 'Bob is still out');
select is((select count(*)::int from public.invitation_attempts
           where user_id = current_setting('t.bob')::uuid),
  0, 'being barred is not counted as guessing codes');

select pg_temp.invite('carol', 'carols');
select is(pg_temp.redeem('bob', 'carols'), 'removed',
  'a new invitation from another member does not let him back');

select pg_temp.invite('alice', 'fresh');
select is(pg_temp.redeem('bob', 'fresh'), 'joined', 'a new invitation from the owner does');
select is((select count(*)::int from public.group_removals), 0, 'which lifts the bar');

-- Leaving on your own is not a removal.
select pg_temp.claims('carol');
select public.leave_group(current_setting('t.g')::uuid);
select is(pg_temp.redeem('carol', 'old'), 'joined', 'someone who left can come back');

-- Nobody but the server can see removals.
select pg_temp.claims('alice');
set local role authenticated;
select throws_ok($$select * from public.group_removals$$, '42501', null,
  'members cannot read removals');
reset role;

select * from finish();
rollback;
