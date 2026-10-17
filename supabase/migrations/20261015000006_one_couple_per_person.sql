-- A person can belong to at most one couple group at a time (product rule,
-- 2026-10-15). Enforced on group_members so every path is covered: creating a
-- couple group, joining by invitation, and anything added later. To start a
-- new couple group, leave the current one first.

create function public.enforce_one_couple_per_person()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select g.type from public.groups g where g.id = new.group_id) <> 'couple' then
    return new;
  end if;
  -- Serialise concurrent joins/creates by the same person.
  perform 1 from public.profiles p where p.id = new.user_id for update;
  if exists (
    select 1
    from public.group_members m
    join public.groups g on g.id = m.group_id
    where m.user_id = new.user_id
      and g.type = 'couple'
      and m.group_id <> new.group_id
  ) then
    raise exception 'closer:already_in_couple' using errcode = 'P0001';
  end if;
  return new;
end;
$$;

create trigger group_members_one_couple
  before insert on public.group_members
  for each row execute function public.enforce_one_couple_per_person();

revoke execute on function public.enforce_one_couple_per_person()
  from public, anon, authenticated;

-- Tell people before they try to join a second couple group.
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

  update public.invitations i
    set redemption_count = i.redemption_count + 1
    where i.id = v_inv.id;

  update public.groups g set last_activity_at = now() where g.id = v_inv.group_id;

  return jsonb_build_object('status', 'joined', 'group_id', v_inv.group_id);
end;
$$;
