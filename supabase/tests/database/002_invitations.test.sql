-- Group-specific invitations: creation, preview, redemption, scope, expiry,
-- revocation, limits, rate limiting and couple capacity.
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

select pg_temp.mk_user(u) from unnest(array[
  'alice', 'bob', 'carol', 'dave', 'erin', 'frank', 'grace', 'heidi', 'ivan', 'judy']) u;

-- Alice: a friends group and a couple group. Bob: his own family group.
select pg_temp.claims('alice');
set local role authenticated;
do $$
declare r record;
begin
  perform set_config('t.friends', public.create_group('Travel Crew', 'friends')::text, true);
  perform set_config('t.couple', public.create_group('Us', 'couple')::text, true);
  select * into r from public.create_invitation(current_setting('t.friends')::uuid);
  perform set_config('t.code', r.code, true);
  perform set_config('t.token', r.token, true);
  perform set_config('t.inv', r.invitation_id::text, true);
end $$;

select matches(current_setting('t.code'), '^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{8}$',
  'codes are 8 unambiguous characters');
select ok(char_length(current_setting('t.token')) >= 32, 'link tokens are long random strings');
select is(
  (select code_hint from public.invitations where id = current_setting('t.inv')::uuid),
  right(current_setting('t.code'), 2), 'members see only a 2-character hint');
select ok(
  (select expires_at between now() + interval '167 hours' and now() + interval '169 hours'
   from public.invitations where id = current_setting('t.inv')::uuid),
  'invitations expire after 7 days by default');
select throws_ok(
  $$ select code_hash from public.invitations $$,
  '42501', null, 'code hashes are not readable');
select throws_ok(
  $$ select token_hash from public.invitations $$,
  '42501', null, 'token hashes are not readable');
reset role;

select is(
  (select count(*)::int from public.invitations
   where code_hash = public.hash_secret(current_setting('t.code'))),
  1, 'only the hash of the code is stored');
select is(
  (select count(*)::int from public.invitations
   where encode(code_hash, 'escape') like '%' || current_setting('t.code') || '%'),
  0, 'the plaintext code is not stored');

select pg_temp.claims('bob');
set local role authenticated;
do $$ begin
  perform set_config('t.family', public.create_group('Bob Family', 'family')::text, true);
end $$;
select is(
  (select count(*)::int from public.invitations where group_id = current_setting('t.friends')::uuid),
  0, 'non-members cannot list a group''s invitations');
reset role;

-- Carol previews, then redeems with sloppy formatting.
select pg_temp.claims('carol');
set local role authenticated;
select is(
  public.preview_invitation(lower(current_setting('t.code'))) ->> 'status', 'valid',
  'preview of a valid code');
select is(
  public.preview_invitation(current_setting('t.code')) ->> 'group_name', 'Travel Crew',
  'preview shows the group name');
select ok(
  (public.preview_invitation(current_setting('t.code')) -> 'group_id') = 'null'::jsonb,
  'preview does not reveal the group id to non-members');
select is((select count(*)::int from public.groups), 0, 'preview grants no access');

select is(
  public.redeem_invitation(
    ' ' || lower(left(current_setting('t.code'), 4)) || '-' || right(current_setting('t.code'), 4) || ' '
  ) ->> 'status',
  'joined', 'redeeming with lower case, spaces and a dash works');
select is(
  (select array_agg(id order by id) from public.groups),
  array[current_setting('t.friends')::uuid],
  'the invitation grants access to its group only');
select is(
  public.redeem_invitation(current_setting('t.code')) ->> 'status', 'already_member',
  'redeeming twice is safe');
select is(
  public.preview_invitation(current_setting('t.code')) ->> 'status', 'already_member',
  'preview recognises existing members');
reset role;

select is(
  (select redemption_count from public.invitations where id = current_setting('t.inv')::uuid),
  1, 'a duplicate redemption is not counted');
select is(
  (select count(*)::int from public.group_members where group_id = current_setting('t.friends')::uuid),
  2, 'duplicate redemption does not duplicate membership');
select is(
  (select count(*)::int from public.invitation_redemptions where invitation_id = current_setting('t.inv')::uuid),
  1, 'redemptions are recorded');

-- Dave joins through the link token.
select pg_temp.claims('dave');
set local role authenticated;
select is(public.redeem_invitation(current_setting('t.token')) ->> 'status', 'joined',
  'link tokens can be redeemed');
select is(
  public.redeem_invitation(current_setting('t.token')) ->> 'group_id',
  current_setting('t.friends'), 'redeem returns the joined group id');
reset role;

-- Expired invitation.
select pg_temp.claims('alice');
set local role authenticated;
do $$
declare r record;
begin
  select * into r from public.create_invitation(current_setting('t.friends')::uuid, 1);
  perform set_config('t.exp_code', r.code, true);
  perform set_config('t.exp_id', r.invitation_id::text, true);
  select * into r from public.create_invitation(current_setting('t.friends')::uuid);
  perform set_config('t.rev_code', r.code, true);
  perform set_config('t.rev_id', r.invitation_id::text, true);
  select * into r from public.create_invitation(current_setting('t.friends')::uuid, 24, 1);
  perform set_config('t.one_code', r.code, true);
end $$;
reset role;

update public.invitations
  set created_at = now() - interval '2 hours', expires_at = now() - interval '1 minute'
  where id = current_setting('t.exp_id')::uuid;

select pg_temp.claims('erin');
set local role authenticated;
select is(public.preview_invitation(current_setting('t.exp_code')) ->> 'status', 'expired',
  'preview reports expired invitations');
select is(public.redeem_invitation(current_setting('t.exp_code')) ->> 'status', 'expired',
  'expired invitations cannot be redeemed');
select is((select count(*)::int from public.groups), 0, 'expired invitation grants nothing');
reset role;

-- Revocation: Carol (member, not creator) may not revoke; Alice (owner) may.
select pg_temp.claims('carol');
set local role authenticated;
select throws_ok(
  format('select public.revoke_invitation(%L)', current_setting('t.rev_id')),
  'P0001', 'closer:not_allowed', 'ordinary members cannot revoke others'' invitations');
reset role;
select pg_temp.claims('bob');
set local role authenticated;
select throws_ok(
  format('select public.revoke_invitation(%L)', current_setting('t.rev_id')),
  'P0001', 'closer:invitation_not_found', 'non-members cannot revoke invitations');
reset role;
select pg_temp.claims('alice');
set local role authenticated;
select lives_ok(
  format('select public.revoke_invitation(%L)', current_setting('t.rev_id')),
  'the owner can revoke an invitation');
reset role;

select pg_temp.claims('erin');
set local role authenticated;
select is(public.redeem_invitation(current_setting('t.rev_code')) ->> 'status', 'revoked',
  'revoked invitations cannot be redeemed');
select is((select count(*)::int from public.groups), 0, 'revoked invitation grants nothing');

-- Redemption limit.
select is(public.redeem_invitation(current_setting('t.one_code')) ->> 'status', 'joined',
  'single-use invitation works once');
reset role;
select pg_temp.claims('frank');
set local role authenticated;
select is(public.redeem_invitation(current_setting('t.one_code')) ->> 'status', 'exhausted',
  'single-use invitation cannot be reused by someone else');
reset role;

-- Invalid codes and rate limiting.
select pg_temp.claims('grace');
set local role authenticated;
select is(public.redeem_invitation('ZZZZ-ZZZZ') ->> 'status', 'invalid', 'unknown codes are invalid');
select is(public.redeem_invitation('') ->> 'status', 'invalid', 'empty input is invalid');
do $$ begin
  for i in 1..8 loop perform public.redeem_invitation('NOPE' || i); end loop;
end $$;
select is(public.redeem_invitation(current_setting('t.code')) ->> 'status', 'rate_limited',
  'too many failed attempts are rate limited, even for a valid code');
select is(public.preview_invitation(current_setting('t.code')) ->> 'status', 'rate_limited',
  'preview is rate limited too');
reset role;

-- Couple capacity.
select pg_temp.claims('alice');
set local role authenticated;
do $$
declare r record;
begin
  select * into r from public.create_invitation(current_setting('t.couple')::uuid, 24, 5);
  perform set_config('t.c1', r.code, true);
  perform set_config('t.c1_id', r.invitation_id::text, true);
  select * into r from public.create_invitation(current_setting('t.couple')::uuid);
  perform set_config('t.c2', r.code, true);
end $$;
select is(
  (select max_redemptions from public.invitations where id = current_setting('t.c1_id')::uuid),
  1, 'couple invitations admit at most one person');
reset role;

select pg_temp.claims('heidi');
set local role authenticated;
select is(public.redeem_invitation(current_setting('t.c1')) ->> 'status', 'joined',
  'the partner joins the couple group');
reset role;

select pg_temp.claims('ivan');
set local role authenticated;
select is(public.preview_invitation(current_setting('t.c2')) ->> 'status', 'full',
  'preview reports a full couple group');
select is(public.redeem_invitation(current_setting('t.c2')) ->> 'status', 'full',
  'a third person cannot join a couple group');
select is((select count(*)::int from public.groups), 0, 'the rejected joiner gets no access');
reset role;

select pg_temp.claims('alice');
set local role authenticated;
select throws_ok(
  $$ select * from public.create_invitation(current_setting('t.couple')::uuid) $$,
  'P0001', 'closer:group_full', 'no new invitations for a full couple group');
reset role;

select is(
  (select count(*)::int from public.group_members where group_id = current_setting('t.couple')::uuid),
  2, 'the couple group has exactly two members');
select throws_ok(
  $$ insert into public.group_members (group_id, user_id)
     values (current_setting('t.couple')::uuid, current_setting('t.judy')::uuid) $$,
  'P0001', 'closer:group_full', 'capacity is enforced even for trusted inserts');

-- Expiry and limit validation.
select pg_temp.claims('alice');
set local role authenticated;
select throws_ok(
  $$ select * from public.create_invitation(current_setting('t.friends')::uuid, 0) $$,
  'P0001', 'closer:invalid_expiry', 'expiry must be at least an hour');
select throws_ok(
  $$ select * from public.create_invitation(current_setting('t.friends')::uuid, 24, 0) $$,
  'P0001', 'closer:invalid_max_redemptions', 'redemption limit must be positive');
select lives_ok(
  $$ select * from public.create_invitation(current_setting('t.friends')::uuid, null) $$,
  'invitations may be created without expiry');
reset role;

select * from finish();
rollback;
