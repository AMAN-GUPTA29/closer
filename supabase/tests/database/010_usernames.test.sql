-- Usernames: format, uniqueness, reserved names, sign-up metadata, access.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

create function pg_temp.mk_user(p_key text, p_meta jsonb)
returns uuid language plpgsql as $$
declare v uuid := gen_random_uuid();
begin
  insert into auth.users (id, email, raw_user_meta_data, aud, role)
  values (v, p_key || '@test.local', p_meta, 'authenticated', 'authenticated');
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

-- Sign-up metadata.
select pg_temp.mk_user('ann', '{"display_name": "Ann", "username": "Ann.Lee"}');
select pg_temp.mk_user('bob', '{"display_name": "Bob", "username": "ann.lee"}');
select pg_temp.mk_user('gia', '{"full_name": "Gia Rossi"}');
select pg_temp.mk_user('rex', '{"display_name": "Rex", "username": "admin"}');

select is((select username from public.profiles where id = current_setting('t.ann')::uuid),
  'ann.lee', 'sign-up username is stored normalised');
select is((select username from public.profiles where id = current_setting('t.bob')::uuid),
  null, 'a taken username does not block sign-up (chosen later)');
select is((select display_name from public.profiles where id = current_setting('t.gia')::uuid),
  'Gia Rossi', 'Google full_name becomes the display name');
select is((select username from public.profiles where id = current_setting('t.rex')::uuid),
  null, 'reserved names are not assigned');

-- Choosing a username.
select pg_temp.claims('bob');
set local role authenticated;
select ok(not public.username_available('ann.lee'), 'taken names are unavailable');
select ok(not public.username_available('Admin'), 'reserved names are unavailable');
select ok(not public.username_available('ab'), 'too short');
select ok(not public.username_available('bad name'), 'spaces are not allowed');
select ok(not public.username_available('dots..twice'), 'double dots are not allowed');
select ok(not public.username_available('ends.'), 'cannot end with a dot');
select ok(public.username_available('@Bob_1'), 'valid and free (with @ and capitals)');
select throws_ok($$ select public.set_username('ann.lee') $$,
  'P0001', 'closer:username_taken', 'cannot take someone else''s name');
select throws_ok($$ select public.set_username('x') $$,
  'P0001', 'closer:invalid_username', 'malformed names are refused');
select is(public.set_username('@Bob_1'), 'bob_1', 'set_username normalises and saves');
select ok(public.username_available('bob_1'), 'your own name counts as available');
select throws_ok($$ update public.profiles set username = 'hacked' where id = auth.uid() $$,
  '42501', null, 'the column cannot be written directly');
reset role;
-- Checked as admin: RLS rightly hides Ann's profile from Bob (no shared group).
select is((select username from public.profiles where id = current_setting('t.ann')::uuid),
  'ann.lee', 'other people''s usernames are untouched');

select ok(not has_function_privilege('anon', 'public.username_available(text)', 'execute'),
  'anonymous callers cannot probe usernames');

select * from finish();
rollback;
