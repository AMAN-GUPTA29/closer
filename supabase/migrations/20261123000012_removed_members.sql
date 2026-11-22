-- A removed member can't walk back in (ISSUES E26).
--
-- When the owner removes someone:
--   * every invitation that person created for the group is cancelled;
--   * they can't rejoin with any invitation made before the removal, or with
--     one made afterwards by anyone other than the owner;
--   * an invitation the owner creates after the removal lets them back in,
--     which also clears the bar.
-- People who leave on their own are not barred.

create table public.group_removals (
  group_id uuid not null references public.groups (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  removed_at timestamptz not null default clock_timestamp(),
  removed_by uuid references auth.users (id) on delete set null,
  primary key (group_id, user_id)
);

alter table public.group_removals enable row level security;
revoke all on public.group_removals from anon, authenticated;

-- True when p_uid was removed from the invitation's group and this
-- invitation can't let them back in.
create function public.blocked_by_removal(p_inv public.invitations, p_uid uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.group_removals r
    where r.group_id = p_inv.group_id and r.user_id = p_uid
      and not (
        p_inv.created_at > r.removed_at
        and exists (select 1 from public.group_members m
                    where m.group_id = p_inv.group_id and m.user_id = p_inv.created_by
                      and m.role = 'owner')
      )
  );
$$;

create or replace function public.remove_member(p_group_id uuid, p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := public.require_user();
begin
  if not public.is_group_owner(p_group_id) then
    raise exception 'closer:not_allowed' using errcode = 'P0001';
  end if;
  if p_user_id = v_uid then
    raise exception 'closer:use_leave_group' using errcode = 'P0001';
  end if;
  delete from public.group_members m
  where m.group_id = p_group_id and m.user_id = p_user_id;
  if not found then
    raise exception 'closer:not_a_member' using errcode = 'P0001';
  end if;

  insert into public.group_removals (group_id, user_id, removed_by)
  values (p_group_id, p_user_id, v_uid)
  on conflict (group_id, user_id) do update
    set removed_at = clock_timestamp(), removed_by = excluded.removed_by;

  update public.invitations i
    set revoked_at = now()
    where i.group_id = p_group_id and i.created_by = p_user_id and i.revoked_at is null;
end;
$$;

create or replace function public.preview_invitation(p_secret text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := public.require_user();
  v_inv public.invitations;
  v_status text;
  v_group public.groups%rowtype;
  v_members integer;
  v_cap integer;
begin
  if not public.invite_attempts_allowed(v_uid) then
    return jsonb_build_object('status', 'rate_limited');
  end if;

  v_inv := public.find_invitation(p_secret, false);
  v_status := public.invitation_status(v_inv);
  if v_status = 'invalid' then
    insert into public.invitation_attempts (user_id) values (v_uid);
    return jsonb_build_object('status', 'invalid');
  end if;
  if v_status <> 'valid' then
    return jsonb_build_object('status', v_status);
  end if;
  if public.blocked_by_removal(v_inv, v_uid) then
    return jsonb_build_object('status', 'removed');
  end if;

  select * into v_group from public.groups g where g.id = v_inv.group_id;
  select count(*) into v_members from public.group_members m where m.group_id = v_group.id;
  v_cap := public.group_capacity(v_group.type);

  if exists (select 1 from public.group_members m
             where m.group_id = v_group.id and m.user_id = v_uid) then
    v_status := 'already_member';
  elsif v_cap is not null and v_members >= v_cap then
    v_status := 'full';
  elsif v_group.type = 'couple' and exists (
    select 1 from public.group_members m join public.groups g on g.id = m.group_id
    where m.user_id = v_uid and g.type = 'couple'
  ) then
    v_status := 'already_in_couple';
  end if;

  return jsonb_build_object(
    'status', v_status,
    'group_id', case when v_status = 'already_member' then v_group.id end,
    'group_name', v_group.name,
    'group_type', v_group.type,
    'member_count', v_members,
    'relationship_start_date', v_group.relationship_start_date,
    'expires_at', v_inv.expires_at
  );
end;
$$;

create or replace function public.redeem_invitation(p_secret text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := public.require_user();
  v_inv public.invitations;
  v_status text;
begin
  if not public.invite_attempts_allowed(v_uid) then
    return jsonb_build_object('status', 'rate_limited');
  end if;

  v_inv := public.find_invitation(p_secret, true);
  v_status := public.invitation_status(v_inv);
  if v_status = 'invalid' then
    insert into public.invitation_attempts (user_id) values (v_uid);
    return jsonb_build_object('status', 'invalid');
  end if;

  if exists (select 1 from public.group_members m
             where m.group_id = v_inv.group_id and m.user_id = v_uid) then
    return jsonb_build_object('status', 'already_member', 'group_id', v_inv.group_id);
  end if;

  if v_status <> 'valid' then
    return jsonb_build_object('status', v_status);
  end if;
  if public.blocked_by_removal(v_inv, v_uid) then
    return jsonb_build_object('status', 'removed');
  end if;

  begin
    insert into public.group_members (group_id, user_id, role)
    values (v_inv.group_id, v_uid, 'member');
  exception when raise_exception then
    if sqlerrm = 'closer:group_full' then
      return jsonb_build_object('status', 'full');
    elsif sqlerrm = 'closer:already_in_couple' then
      return jsonb_build_object('status', 'already_in_couple');
    end if;
    raise;
  end;

  insert into public.invitation_redemptions (invitation_id, group_id, user_id)
  values (v_inv.id, v_inv.group_id, v_uid);

  -- Let back in by the owner: the bar is lifted.
  delete from public.group_removals r
  where r.group_id = v_inv.group_id and r.user_id = v_uid;

  update public.invitations i
    set redemption_count = i.redemption_count + 1
    where i.id = v_inv.id;

  update public.groups g set last_activity_at = now() where g.id = v_inv.group_id;

  return jsonb_build_object('status', 'joined', 'group_id', v_inv.group_id);
end;
$$;

revoke all on function public.blocked_by_removal(public.invitations, uuid)
  from public, anon, authenticated;
