-- Closer — Phase 5: device registrations, push delivery queue, milestone
-- reminders, store purchases that are not yet assigned to a group, and
-- realtime publication for foreground sync.

-- ---------------------------------------------------------------------------
-- Device registrations (push tokens)
-- ---------------------------------------------------------------------------

create table public.device_registrations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  token text not null unique check (char_length(token) between 20 and 4096),
  platform text not null check (platform in ('android', 'ios')),
  app_version text check (app_version is null or char_length(app_version) <= 40),
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  -- Set when the push provider reports the token as no longer valid.
  invalidated_at timestamptz
);

create index device_registrations_user_idx
  on public.device_registrations (user_id) where invalidated_at is null;

-- Registers (or refreshes) this device's token for the signed-in user. A token
-- that moves to another account (shared phone, re-login) is reassigned.
create function public.register_device(
  p_token text,
  p_platform text,
  p_app_version text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := public.require_user();
begin
  -- clock_timestamp(): distinct even within one transaction, so "newest" is exact.
  insert into public.device_registrations (user_id, token, platform, app_version, last_seen_at)
  values (v_uid, p_token, p_platform, p_app_version, clock_timestamp())
  on conflict (token) do update
    set user_id = v_uid,
        platform = excluded.platform,
        app_version = excluded.app_version,
        last_seen_at = clock_timestamp(),
        invalidated_at = null;

  -- Keep at most 10 active devices per user (oldest dropped).
  delete from public.device_registrations d
  where d.user_id = v_uid
    and d.id in (
      select id from public.device_registrations
      where user_id = v_uid
      order by last_seen_at desc
      offset 10
    );
end;
$$;

create function public.unregister_device(p_token text)
returns void
language sql
security definer
set search_path = ''
as $$
  delete from public.device_registrations d
  where d.token = p_token and d.user_id = (select auth.uid());
$$;

-- ---------------------------------------------------------------------------
-- Preferences: push on/off and reminders
-- ---------------------------------------------------------------------------

alter table public.notification_preferences
  add column push boolean not null default true,
  add column reminders boolean not null default true;

-- ---------------------------------------------------------------------------
-- Push delivery queue (state lives on each notification row)
-- ---------------------------------------------------------------------------

alter type public.notification_kind add value if not exists 'milestone_upcoming';

alter table public.notifications
  add column push_status text not null default 'pending'
    check (push_status in ('pending', 'sending', 'sent', 'skipped', 'failed')),
  add column push_attempts integer not null default 0,
  add column push_next_at timestamptz not null default now(),
  add column push_lease_until timestamptz;

-- Notifications created before push existed are never pushed retroactively.
update public.notifications set push_status = 'skipped';

create index notifications_push_due_idx
  on public.notifications (push_next_at)
  where push_status in ('pending', 'sending');

-- Leases due notifications for one dispatcher run (SKIP LOCKED: safe with
-- several workers). Returns everything needed to build the message, without
-- captions or photo content.
create function public.claim_push_batch(p_limit integer default 100)
returns table (
  notification_id bigint,
  user_id uuid,
  kind text,
  group_id uuid,
  group_name text,
  actor_name text,
  milestone_title text,
  push_enabled boolean,
  tokens text[]
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  return query
  with claimed as (
    update public.notifications n
    set push_status = 'sending',
        push_attempts = n.push_attempts + 1,
        push_lease_until = now() + interval '2 minutes'
    where n.id in (
      select c.id from public.notifications c
      where (c.push_status = 'pending' and c.push_next_at <= now())
         or (c.push_status = 'sending' and c.push_lease_until < now())
      order by c.push_next_at
      limit greatest(1, least(p_limit, 500))
      for update skip locked
    )
    returning n.*
  )
  select c.id, c.user_id, c.kind::text, c.group_id, g.name, a.display_name, m.title,
         coalesce(np.push, true),
         coalesce(
           (select array_agg(d.token order by d.last_seen_at desc)
            from public.device_registrations d
            where d.user_id = c.user_id and d.invalidated_at is null),
           '{}'::text[])
  from claimed c
  join public.groups g on g.id = c.group_id
  left join public.profiles a on a.id = c.actor_id
  left join public.milestones m on m.id = c.milestone_id
  left join public.notification_preferences np on np.user_id = c.user_id;
end;
$$;

-- Records a dispatch outcome: 'sent' | 'skipped' | 'retry' | 'failed'.
-- Retries back off 1, 2, 4 … minutes; after 6 attempts the push is 'failed'
-- (the in-app notification is unaffected). Invalid tokens are retired.
create function public.complete_push(
  p_notification_id bigint,
  p_outcome text,
  p_invalid_tokens text[] default '{}'
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_attempts integer;
begin
  if p_invalid_tokens is not null and cardinality(p_invalid_tokens) > 0 then
    update public.device_registrations d
      set invalidated_at = now()
      where d.token = any (p_invalid_tokens) and d.invalidated_at is null;
  end if;

  select push_attempts into v_attempts from public.notifications
  where id = p_notification_id for update;
  if not found then
    return;
  end if;

  update public.notifications n
  set push_status = case
        when p_outcome in ('sent', 'skipped', 'failed') then p_outcome
        when v_attempts >= 6 then 'failed'
        else 'pending' end,
      push_lease_until = null,
      push_next_at = case when p_outcome = 'retry'
        then now() + make_interval(mins => power(2, greatest(v_attempts - 1, 0))::integer)
        else n.push_next_at end
  where n.id = p_notification_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Milestone reminders (run daily by a scheduled job)
-- ---------------------------------------------------------------------------

-- Creates one reminder per member for milestones happening tomorrow.
-- Idempotent: the notification uniqueness constraint absorbs re-runs.
create function public.enqueue_milestone_reminders(p_on date default current_date + 1)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  insert into public.notifications (user_id, group_id, actor_id, kind, milestone_id)
  select gm.user_id, m.group_id, null, 'milestone_upcoming'::public.notification_kind, m.id
  from public.milestones m
  join public.group_members gm on gm.group_id = m.group_id
  left join public.notification_preferences np on np.user_id = gm.user_id
  where m.event_date = p_on
    and coalesce(np.reminders, true)
  on conflict do nothing;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- ---------------------------------------------------------------------------
-- Purchases not yet assigned to a group
-- ---------------------------------------------------------------------------

-- A store webhook can arrive before the app tells us which group a purchase
-- was for (or the app may have been closed mid-purchase). Such purchases are
-- kept as 'unassigned' and can be applied to a group later ("restore").
alter table public.purchase_records drop constraint purchase_records_status_check;
alter table public.purchase_records add constraint purchase_records_status_check
  check (status in ('verified', 'refunded', 'unassigned'));
alter table public.purchase_records add constraint purchase_records_group_when_verified
  check (status <> 'verified' or group_id is not null);

-- Called by the store webhook (service role). Idempotent.
create function public.record_store_purchase(
  p_user_id uuid,
  p_store text,
  p_product_id text,
  p_transaction_id text,
  p_purchased_at timestamptz default now()
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_existing public.purchase_records;
begin
  select * into v_existing from public.purchase_records r
  where r.store = p_store and r.transaction_id = p_transaction_id;
  if found then
    return jsonb_build_object('status', 'already_recorded', 'purchase_status', v_existing.status);
  end if;
  if not exists (select 1 from public.profiles p where p.id = p_user_id) then
    return jsonb_build_object('status', 'unknown_user');
  end if;
  insert into public.purchase_records
    (store, product_id, transaction_id, user_id, group_id, status, purchased_at)
  values (p_store, p_product_id, p_transaction_id, p_user_id, null, 'unassigned', p_purchased_at);
  return jsonb_build_object('status', 'recorded');
end;
$$;

-- Same signature as Phase 3; now also assigns a previously unassigned
-- purchase of the same user to the group.
create or replace function public.grant_group_entitlement(
  p_group_id uuid,
  p_user_id uuid,
  p_store text,
  p_product_id text,
  p_transaction_id text,
  p_purchased_at timestamptz default now()
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_purchase public.purchase_records;
begin
  if not exists (select 1 from public.groups g where g.id = p_group_id) then
    raise exception 'closer:group_not_found' using errcode = 'P0001';
  end if;
  if not exists (select 1 from public.group_members m
                 where m.group_id = p_group_id and m.user_id = p_user_id) then
    raise exception 'closer:not_a_member' using errcode = 'P0001';
  end if;

  select * into v_purchase from public.purchase_records r
  where r.store = p_store and r.transaction_id = p_transaction_id
  for update;

  if found then
    if v_purchase.status = 'refunded' then
      raise exception 'closer:purchase_refunded' using errcode = 'P0001';
    end if;
    if v_purchase.status = 'verified' then
      if v_purchase.group_id is distinct from p_group_id then
        raise exception 'closer:transaction_already_used' using errcode = 'P0001';
      end if;
      return jsonb_build_object('status', 'already_granted', 'purchase_id', v_purchase.id);
    end if;
    -- 'unassigned': only its buyer can apply it.
    if v_purchase.user_id is distinct from p_user_id then
      raise exception 'closer:transaction_already_used' using errcode = 'P0001';
    end if;
    update public.purchase_records
      set status = 'verified', group_id = p_group_id
      where id = v_purchase.id
      returning * into v_purchase;
  else
    insert into public.purchase_records
      (store, product_id, transaction_id, user_id, group_id, purchased_at)
    values (p_store, p_product_id, p_transaction_id, p_user_id, p_group_id, p_purchased_at)
    returning * into v_purchase;
  end if;

  insert into public.group_entitlements (group_id, status, granted_at, purchase_id)
  values (p_group_id, 'active', now(), v_purchase.id)
  on conflict (group_id) do update
    set status = 'active', revoked_at = null, grace_until = null,
        purchase_id = excluded.purchase_id, updated_at = now();

  return jsonb_build_object('status', 'granted', 'purchase_id', v_purchase.id);
end;
$$;

-- ---------------------------------------------------------------------------
-- Realtime: members receive changes to rows they can read (RLS applies)
-- ---------------------------------------------------------------------------

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime
      add table public.photos, public.milestones, public.notifications, public.group_members;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- RLS and privileges
-- ---------------------------------------------------------------------------

alter table public.device_registrations enable row level security;
revoke all on public.device_registrations from anon, authenticated;
grant select (id, platform, app_version, created_at, last_seen_at, invalidated_at)
  on public.device_registrations to authenticated;

create policy "device_registrations: own devices"
  on public.device_registrations for select to authenticated
  using (user_id = (select auth.uid()));

-- Push bookkeeping columns are internal.
revoke select on public.notifications from authenticated;
grant select (id, user_id, group_id, actor_id, kind, photo_id, milestone_id, created_at, read_at)
  on public.notifications to authenticated;

grant select (id, store, product_id, group_id, status, purchased_at, refunded_at, transaction_id)
  on public.purchase_records to authenticated;

revoke execute on all functions in schema public from public, anon, authenticated;

grant execute on function
  public.create_group(text, public.group_type, date),
  public.create_invitation(uuid, integer, integer),
  public.revoke_invitation(uuid),
  public.preview_invitation(text),
  public.redeem_invitation(text),
  public.leave_group(uuid),
  public.transfer_ownership(uuid, uuid),
  public.remove_member(uuid, uuid),
  public.delete_group(uuid),
  public.request_photo_upload(uuid, uuid, text, timestamptz, integer, integer, integer),
  public.finalize_photo(uuid),
  public.delete_photo(uuid),
  public.set_photo_pinned(uuid, boolean),
  public.set_group_cover(uuid, uuid),
  public.set_avatar(text),
  public.mark_notifications_read(bigint[]),
  public.journal_entries(uuid, timestamptz, uuid, integer),
  public.register_device(text, text, text),
  public.unregister_device(text),
  public.is_group_member(uuid),
  public.is_group_owner(uuid),
  public.shares_group_with(uuid),
  public.is_group_premium(uuid),
  public.can_read_photo_object(text),
  public.can_upload_photo_object(text),
  public.can_read_avatar_object(text),
  public.can_upload_avatar_object(text)
to authenticated;

grant execute on function
  public.claim_cleanup_jobs(integer),
  public.complete_cleanup_job(bigint, boolean, text),
  public.expire_stale_uploads(interval),
  public.grant_group_entitlement(uuid, uuid, text, text, text, timestamptz),
  public.revoke_group_entitlement(text, text),
  public.record_store_purchase(uuid, text, text, text, timestamptz),
  public.prepare_account_deletion(uuid),
  public.claim_push_batch(integer),
  public.complete_push(bigint, text, text[]),
  public.enqueue_milestone_reminders(date)
to service_role;
