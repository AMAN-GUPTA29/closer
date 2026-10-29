-- Keeploom Memories as a yearly pass per group: stacking renewals, the
-- 30-day grace after a pass ends, refunds taking back one year.
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

create function pg_temp.grant(p_tx text)
returns jsonb language sql as $$
  select public.grant_group_entitlement(current_setting('t.g')::uuid,
    current_setting('t.alice')::uuid, 'test', 'keeploom_memories_year', p_tx)
$$;

create function pg_temp.expires()
returns timestamptz language sql as $$
  select expires_at from public.group_entitlements where group_id = current_setting('t.g')::uuid
$$;

select pg_temp.mk_user('alice');
select pg_temp.claims('alice');
set local role authenticated;
do $$ begin
  perform set_config('t.g', public.create_group('Us', 'friends')::text, true);
end $$;
reset role;

-- First year.
select is(pg_temp.grant('tx-a') ->> 'status', 'granted', 'a purchase unlocks the group');
select ok(pg_temp.expires() between now() + interval '1 year' - interval '1 minute'
                               and now() + interval '1 year' + interval '1 minute',
  'the pass runs for one year');
select ok(public.is_group_premium(current_setting('t.g')::uuid), 'the group is Premium');
select is(pg_temp.grant('tx-a') ->> 'status', 'already_granted', 'replays do not add time');
select ok(pg_temp.expires() < now() + interval '13 months', 'a replay did not extend the pass');

-- Renewing early stacks on the current end date.
select is(pg_temp.grant('tx-b') ->> 'status', 'granted', 'renewing early works');
select ok(pg_temp.expires() > now() + interval '23 months', 'an early renewal adds a second year');

-- A refund takes back one year; the rest stays.
select is(public.revoke_group_entitlement('test', 'tx-b') ->> 'status', 'revoked',
  'refunding the renewal');
select ok(pg_temp.expires() < now() + interval '13 months', 'the refunded year is removed');
select is((select status::text from public.group_entitlements
           where group_id = current_setting('t.g')::uuid), 'active',
  'paid time remains, so the pass stays active');

-- The pass ends: 30 days of grace, then Basic.
update public.group_entitlements set expires_at = now() - interval '10 days'
  where group_id = current_setting('t.g')::uuid;
select ok(public.is_group_premium(current_setting('t.g')::uuid),
  'inside the 30-day grace after the pass ends the group is still Premium');
update public.group_entitlements set expires_at = now() - interval '31 days'
  where group_id = current_setting('t.g')::uuid;
select ok(not public.is_group_premium(current_setting('t.g')::uuid),
  'after the grace period the group is Basic');

-- Renewing after it lapsed starts a fresh year from now.
select is(pg_temp.grant('tx-c') ->> 'status', 'granted', 'renewing after a lapse works');
select ok(pg_temp.expires() between now() + interval '1 year' - interval '1 minute'
                               and now() + interval '1 year' + interval '1 minute',
  'a lapsed pass restarts from today');

-- Refunding the only remaining year: refund grace, nothing deleted.
select is(public.revoke_group_entitlement('test', 'tx-c') ->> 'status', 'revoked',
  'refunding the last year');
select is((select status::text from public.group_entitlements
           where group_id = current_setting('t.g')::uuid), 'revoked',
  'no paid time left, so the pass is revoked');
select ok(public.is_group_premium(current_setting('t.g')::uuid),
  'the refund grace period still applies');

-- Members can read when the pass ends.
select pg_temp.claims('alice');
set local role authenticated;
select ok((select premium_expires_at from public.group_summaries
           where id = current_setting('t.g')::uuid) is not null,
  'members see when the pass ends');
reset role;

select * from finish();
rollback;
