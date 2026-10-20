-- Keeploom Memories becomes a yearly pass per group (owner decision
-- 2026-10-20: $5 / year, ₹449 in India; the app itself is free).
--
-- Stores: an Apple non-renewing subscription and a repeatable Google Play
-- in-app product, both reported by RevenueCat as non-subscription purchases,
-- so the purchase pipeline is unchanged. What changes is what a purchase buys:
--
--   * each verified purchase adds one year to the group's pass; buying again
--     before it ends extends it from the current end date (renewals stack);
--   * when a pass ends, the group stays Premium for the grace period
--     (premium_grace_days, 30) so anyone in it can renew — nothing is
--     deleted; after that, Basic retention applies on the next upload;
--   * a refund removes the year that purchase added; if no paid time is
--     left, the existing refund grace applies.
--
-- Entitlements granted before this migration keep `expires_at = null`
-- (they were sold as permanent).

create function public.premium_period()
returns interval
language sql
immutable
set search_path = ''
as $$ select interval '1 year' $$;

alter table public.group_entitlements
  add column expires_at timestamptz;

alter table public.purchase_records
  add column period_end timestamptz;

-- Premium while the pass runs, during the grace period after it ends, or
-- during the refund grace period.
create or replace function public.is_group_premium(p_group_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.group_entitlements e
    where e.group_id = p_group_id
      and (
        (e.status = 'active'
          and (e.expires_at is null
               or e.expires_at + make_interval(days => public.premium_grace_days()) > now()))
        or (e.grace_until is not null and e.grace_until > now())
      )
  );
$$;

-- Same signature; a purchase now extends the group's pass by one year.
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
  v_current public.group_entitlements;
  v_from timestamptz;
  v_until timestamptz;
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
      return jsonb_build_object('status', 'already_granted', 'purchase_id', v_purchase.id,
                                'expires_at', v_purchase.period_end);
    end if;
    -- 'unassigned': only its buyer can apply it.
    if v_purchase.user_id is distinct from p_user_id then
      raise exception 'closer:transaction_already_used' using errcode = 'P0001';
    end if;
  end if;

  -- Extend from the current end date while the pass still runs; otherwise
  -- start now. A permanent (legacy) entitlement stays permanent.
  select * into v_current from public.group_entitlements e
  where e.group_id = p_group_id
  for update;
  if found and v_current.status = 'active' and v_current.expires_at is null then
    v_until := null;
  else
    v_from := now();
    if found and v_current.status = 'active' and v_current.expires_at > now() then
      v_from := v_current.expires_at;
    end if;
    v_until := v_from + public.premium_period();
  end if;

  if v_purchase.id is not null then
    update public.purchase_records
      set status = 'verified', group_id = p_group_id, period_end = v_until
      where id = v_purchase.id
      returning * into v_purchase;
  else
    insert into public.purchase_records
      (store, product_id, transaction_id, user_id, group_id, purchased_at, period_end)
    values (p_store, p_product_id, p_transaction_id, p_user_id, p_group_id,
            p_purchased_at, v_until)
    returning * into v_purchase;
  end if;

  insert into public.group_entitlements (group_id, status, granted_at, purchase_id, expires_at)
  values (p_group_id, 'active', now(), v_purchase.id, v_until)
  on conflict (group_id) do update
    set status = 'active', revoked_at = null, grace_until = null,
        purchase_id = excluded.purchase_id, expires_at = excluded.expires_at,
        updated_at = now();

  return jsonb_build_object('status', 'granted', 'purchase_id', v_purchase.id,
                            'expires_at', v_until);
end;
$$;

-- Refund: take back the year this purchase added. If no paid time is left,
-- Premium continues through the refund grace period (nothing is deleted).
create or replace function public.revoke_group_entitlement(p_store text, p_transaction_id text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_purchase public.purchase_records;
  v_ent public.group_entitlements;
  v_until timestamptz;
begin
  select * into v_purchase from public.purchase_records r
  where r.store = p_store and r.transaction_id = p_transaction_id
  for update;
  if not found then
    return jsonb_build_object('status', 'unknown_transaction');
  end if;
  if v_purchase.status = 'refunded' then
    return jsonb_build_object('status', 'already_revoked');
  end if;

  update public.purchase_records
    set status = 'refunded', refunded_at = now()
    where id = v_purchase.id;

  select * into v_ent from public.group_entitlements e
  where e.group_id = v_purchase.group_id
  for update;
  if not found then
    return jsonb_build_object('status', 'revoked');
  end if;

  if v_ent.expires_at is not null and v_purchase.period_end is not null then
    v_until := v_ent.expires_at - public.premium_period();
  end if;

  if v_until is not null and v_until > now() then
    -- Other paid years remain: shorten the pass.
    update public.group_entitlements
      set expires_at = v_until, updated_at = now()
      where group_id = v_ent.group_id;
  elsif v_ent.purchase_id = v_purchase.id or v_until is not null then
    update public.group_entitlements
      set status = 'revoked', revoked_at = now(),
          expires_at = coalesce(v_until, v_ent.expires_at),
          grace_until = now() + make_interval(days => public.premium_grace_days()),
          updated_at = now()
      where group_id = v_ent.group_id;
  end if;

  return jsonb_build_object('status', 'revoked');
end;
$$;

-- Read model: expose when the pass ends so the app can show "until …" and
-- ask for a renewal. Columns are only appended.
create or replace view public.group_summaries
with (security_invoker = true) as
select
  g.id,
  g.name,
  g.type,
  g.created_by,
  g.cover_path,
  g.relationship_start_date,
  g.show_relationship_counter,
  g.created_at,
  g.updated_at,
  g.last_activity_at,
  (select count(*)::integer from public.group_members m where m.group_id = g.id)
    as member_count,
  (select m.role from public.group_members m
    where m.group_id = g.id and m.user_id = (select auth.uid())) as my_role,
  (select count(*)::integer from public.photos p
    where p.group_id = g.id and p.status = 'active') as photo_count,
  public.is_group_premium(g.id) as is_premium,
  coalesce(
    (select p.thumb_path from public.photos p
      where p.id = g.cover_photo_id and p.status = 'active'),
    (select p.thumb_path from public.photos p
      where p.group_id = g.id and p.status = 'active'
      order by p.uploaded_at desc, p.id desc limit 1)
  ) as latest_thumb_path,
  g.cover_photo_id,
  (select e.expires_at from public.group_entitlements e
    where e.group_id = g.id) as premium_expires_at
from public.groups g;

revoke all on public.group_summaries from anon, authenticated;
grant select on public.group_summaries to authenticated;

grant select (expires_at) on public.group_entitlements to authenticated;

-- `create or replace` keeps the existing grants on the replaced functions
-- (is_group_premium for members; grant/revoke for the service role only).
revoke all on function public.premium_period() from public, anon, authenticated;
