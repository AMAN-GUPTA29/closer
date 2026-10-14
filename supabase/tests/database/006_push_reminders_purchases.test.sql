-- Device registrations, push queue, milestone reminders, unassigned purchases.
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

select pg_temp.mk_user(u) from unnest(array['alice', 'bob', 'eve']) u;

-- Notifications from before this test should not interfere.
update public.notifications set push_status = 'skipped';

select pg_temp.claims('alice');
set local role authenticated;
do $$ begin
  perform set_config('t.g', public.create_group('Us', 'friends')::text, true);
  perform set_config('t.other', public.create_group('Other', 'friends')::text, true);
end $$;
reset role;

-- ------------------------------------------------------------- devices
select pg_temp.claims('bob');
set local role authenticated;
select lives_ok($$ select public.register_device('bob-token-0123456789-abcdef', 'android', '1.0.0') $$,
  'users register their device token');
select lives_ok($$ select public.register_device('bob-token-0123456789-abcdef', 'android', '1.0.1') $$,
  'registering again refreshes the same token');
select is((select count(*)::int from public.device_registrations), 1, 'one row per token');
select throws_ok($$ select token from public.device_registrations $$, '42501', null,
  'tokens are not readable by clients');
select throws_ok($$ select public.register_device('short', 'android') $$, '23514', null,
  'implausible tokens are rejected');
select throws_ok($$ select public.register_device('bob-token-0123456789-zzzzzz', 'windows') $$, '23514', null,
  'only android and ios are accepted');
select throws_ok($$ insert into public.device_registrations (user_id, token, platform)
  values (auth.uid(), 'direct-insert-token-1234567890', 'ios') $$, '42501', null,
  'no direct writes');
reset role;

select pg_temp.claims('eve');
set local role authenticated;
select is((select count(*)::int from public.device_registrations), 0, 'users see only their devices');
-- Eve signs in on Bob's phone: the token moves to Eve.
select lives_ok($$ select public.register_device('bob-token-0123456789-abcdef', 'android') $$,
  'a token can move to another account');
reset role;
select is((select user_id from public.device_registrations where token = 'bob-token-0123456789-abcdef'),
  current_setting('t.eve')::uuid, 'the token now belongs to the new account only');

select pg_temp.claims('eve');
set local role authenticated;
select lives_ok($$ select public.unregister_device('bob-token-0123456789-abcdef') $$, 'sign-out unregisters');
reset role;
select is((select count(*)::int from public.device_registrations), 0, 'the device is gone');

select pg_temp.claims('bob');
set local role authenticated;
do $$ begin
  for i in 1..12 loop
    perform public.register_device('bob-device-' || i || '-0123456789abcdef', 'ios');
  end loop;
end $$;
select is((select count(*)::int from public.device_registrations), 10, 'at most 10 devices per user');
reset role;

-- ----------------------------------------------------------- push queue
insert into public.group_members (group_id, user_id) values
  (current_setting('t.g')::uuid, current_setting('t.bob')::uuid);

set local role service_role;
select is(
  (select count(*)::int from public.claim_push_batch(100) where user_id = current_setting('t.alice')::uuid
     and kind = 'member_joined' and actor_name = 'Bob' and group_name = 'Us'),
  1, 'the dispatcher claims new notifications with names but no content');
select is((select count(*)::int from public.claim_push_batch(100)), 0,
  'claimed notifications are leased, not handed out twice');
reset role;

select is(
  (select push_status from public.notifications where user_id = current_setting('t.alice')::uuid
     and kind = 'member_joined'),
  'sending', 'claimed notifications are marked sending');

do $$
declare v bigint;
begin
  select id into v from public.notifications
  where user_id = current_setting('t.alice')::uuid and kind = 'member_joined';
  perform set_config('t.n', v::text, true);
end $$;

set local role service_role;
select lives_ok(format($$select public.complete_push(%s, 'retry', array['bob-device-12-0123456789abcdef'])$$,
  current_setting('t.n')), 'a transient failure is recorded');
reset role;
select ok((select push_status = 'pending' and push_next_at > now() from public.notifications
  where id = current_setting('t.n')::bigint), 'retries are scheduled with backoff');
select ok((select invalidated_at is not null from public.device_registrations
  where token = 'bob-device-12-0123456789abcdef'), 'invalid tokens are retired');

update public.notifications set push_next_at = now() - interval '1 second'
  where id = current_setting('t.n')::bigint;
set local role service_role;
select is((select count(*)::int from public.claim_push_batch(100)), 1, 'due retries are claimed again');
select lives_ok(format($$select public.complete_push(%s, 'sent')$$, current_setting('t.n')), 'delivery recorded');
reset role;
select is((select push_status from public.notifications where id = current_setting('t.n')::bigint),
  'sent', 'sent notifications are not sent again');

-- Expired leases are reclaimed (a dispatcher crashed mid-send).
select pg_temp.claims('bob');
set local role authenticated;
do $$ begin
  insert into public.milestones (group_id, title, event_date)
  values (current_setting('t.g')::uuid, 'Picnic', current_date + 1);
end $$;
reset role;
set local role service_role;
select is((select count(*)::int from public.claim_push_batch(100)), 1, 'milestone notification claimed');
reset role;
update public.notifications set push_lease_until = now() - interval '1 minute' where push_status = 'sending';
set local role service_role;
select is((select count(*)::int from public.claim_push_batch(100)), 1, 'expired leases are reclaimed');
reset role;

set local role authenticated;
select throws_ok($$ select * from public.claim_push_batch(1) $$, '42501', null, 'clients cannot claim pushes');
select throws_ok($$ select push_status from public.notifications $$, '42501', null,
  'push bookkeeping is not visible to clients');
reset role;

-- ------------------------------------------------------------ reminders
insert into public.notification_preferences (user_id, reminders)
values (current_setting('t.bob')::uuid, false);
set local role service_role;
select is(public.enqueue_milestone_reminders(), 1, 'members get a reminder the day before');
select is(public.enqueue_milestone_reminders(), 0, 'reminders are not duplicated');
reset role;
select is(
  (select count(*)::int from public.notifications where kind = 'milestone_upcoming'
     and user_id = current_setting('t.bob')::uuid),
  0, 'members who turned reminders off are skipped');

-- ------------------------------------------------------------ purchases
set local role service_role;
select is(
  public.record_store_purchase(current_setting('t.alice')::uuid, 'app_store', 'closer_memories_group', 'tx-u1') ->> 'status',
  'recorded', 'a webhook purchase without a group is recorded as unassigned');
select is(
  public.record_store_purchase(current_setting('t.alice')::uuid, 'app_store', 'closer_memories_group', 'tx-u1') ->> 'status',
  'already_recorded', 'webhook replays are idempotent');
select is(
  public.record_store_purchase(gen_random_uuid(), 'app_store', 'closer_memories_group', 'tx-ghost') ->> 'status',
  'unknown_user', 'purchases for unknown users are ignored');
reset role;

select pg_temp.claims('alice');
set local role authenticated;
select is(
  (select status from public.purchase_records where transaction_id = 'tx-u1'),
  'unassigned', 'the buyer can see their unassigned purchase');
select is((select is_premium from public.group_summaries where id = current_setting('t.g')::uuid),
  false, 'an unassigned purchase unlocks nothing');
reset role;

set local role service_role;
select throws_ok(
  format($$select public.grant_group_entitlement(%L, %L, 'app_store', 'closer_memories_group', 'tx-u1')$$,
         current_setting('t.g'), current_setting('t.bob')),
  'P0001', 'closer:transaction_already_used', 'someone else cannot apply another user''s purchase');
select is(
  public.grant_group_entitlement(current_setting('t.g')::uuid, current_setting('t.alice')::uuid,
    'app_store', 'closer_memories_group', 'tx-u1') ->> 'status',
  'granted', 'the buyer applies the unassigned purchase to a group');
select is(
  public.grant_group_entitlement(current_setting('t.g')::uuid, current_setting('t.alice')::uuid,
    'app_store', 'closer_memories_group', 'tx-u1') ->> 'status',
  'already_granted', 'applying it twice is idempotent');
select throws_ok(
  format($$select public.grant_group_entitlement(%L, %L, 'app_store', 'closer_memories_group', 'tx-u1')$$,
         current_setting('t.other'), current_setting('t.alice')),
  'P0001', 'closer:transaction_already_used', 'one purchase unlocks one group');
reset role;

select pg_temp.claims('bob');
set local role authenticated;
select is((select is_premium from public.group_summaries where id = current_setting('t.g')::uuid),
  true, 'every member of the group gets Premium');
select is((select count(*)::int from public.purchase_records), 0,
  'members cannot see other people''s purchases');
reset role;

-- Refunded unassigned purchases cannot be applied later.
set local role service_role;
select public.record_store_purchase(current_setting('t.alice')::uuid, 'play_store', 'closer_memories_group', 'tx-u2');
select is(public.revoke_group_entitlement('play_store', 'tx-u2') ->> 'status', 'revoked',
  'refunds of unassigned purchases are recorded');
select throws_ok(
  format($$select public.grant_group_entitlement(%L, %L, 'play_store', 'closer_memories_group', 'tx-u2')$$,
         current_setting('t.other'), current_setting('t.alice')),
  'P0001', 'closer:purchase_refunded', 'refunded purchases cannot unlock a group');
reset role;

set local role authenticated;
select throws_ok(
  $$ select public.record_store_purchase(auth.uid(), 'test', 'p', 'tx-forged') $$,
  '42501', null, 'clients cannot record purchases');
reset role;

select * from finish();
rollback;
