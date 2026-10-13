-- Closer — Phase 2: profiles, groups, memberships, invitations.
--
-- Security model
--   * RLS is enabled on every table. Clients read through RLS and mutate only
--     through the security-definer functions below (plus a few narrowly granted
--     column updates). Nothing here trusts client-supplied membership, roles,
--     capacity or counts.
--   * Invitation codes and link tokens are stored only as SHA-256 hashes. The
--     plaintext secret is returned once, from create_invitation().
--   * Couple capacity (2 members) is enforced by a trigger that locks the group
--     row, so concurrent joins are serialised and can never exceed the cap.
--
-- All functions use `set search_path = ''` and fully-qualified names.

create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------------------
-- Types
-- ---------------------------------------------------------------------------

create type public.group_type as enum ('couple', 'friends', 'family');
create type public.member_role as enum ('owner', 'member');

-- ---------------------------------------------------------------------------
-- Profiles
-- ---------------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null
    check (char_length(btrim(display_name)) between 1 and 40),
  avatar_path text check (avatar_path is null or char_length(avatar_path) <= 512),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.profiles is 'Public-to-group-members profile for each auth user.';

create function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger profiles_touch_updated_at
  before update on public.profiles
  for each row execute function public.touch_updated_at();

-- Create a profile for every new auth user.
create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text;
begin
  v_name := btrim(coalesce(new.raw_user_meta_data ->> 'display_name', ''));
  if v_name = '' then
    v_name := split_part(coalesce(new.email, 'Closer friend'), '@', 1);
  end if;
  insert into public.profiles (id, display_name)
  values (new.id, left(v_name, 40))
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Groups and memberships
-- ---------------------------------------------------------------------------

create table public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) between 1 and 60),
  type public.group_type not null,
  created_by uuid references auth.users (id) on delete set null,
  cover_path text check (cover_path is null or char_length(cover_path) <= 512),
  relationship_start_date date,
  show_relationship_counter boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_activity_at timestamptz not null default now(),
  constraint relationship_date_only_for_couples
    check (type = 'couple' or relationship_start_date is null)
);

create trigger groups_touch_updated_at
  before update on public.groups
  for each row execute function public.touch_updated_at();

create table public.group_members (
  group_id uuid not null references public.groups (id) on delete cascade,
  -- References profiles (which cascade from auth.users) so PostgREST can
  -- embed member profiles: group_members?select=*,profiles(*)
  user_id uuid not null references public.profiles (id) on delete cascade,
  role public.member_role not null default 'member',
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);

create index group_members_user_idx on public.group_members (user_id);
-- Exactly one owner per group (at most one here; "at least one" is kept by triggers).
create unique index group_members_one_owner on public.group_members (group_id)
  where role = 'owner';

-- Capacity per group type; null = unlimited.
create function public.group_capacity(p_type public.group_type)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case p_type when 'couple' then 2 else null end;
$$;

-- Serialises joins per group and enforces capacity atomically.
create function public.enforce_group_capacity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_type public.group_type;
  v_cap integer;
  v_count integer;
begin
  select g.type into v_type
  from public.groups g
  where g.id = new.group_id
  for update;

  v_cap := public.group_capacity(v_type);
  if v_cap is not null then
    select count(*) into v_count
    from public.group_members m
    where m.group_id = new.group_id;
    if v_count >= v_cap then
      raise exception 'closer:group_full' using errcode = 'P0001';
    end if;
  end if;
  return new;
end;
$$;

create trigger group_members_capacity
  before insert on public.group_members
  for each row execute function public.enforce_group_capacity();

-- Keeps groups consistent after any membership removal (leave, removal,
-- account deletion): the last member leaving deletes the group; an ownerless
-- group promotes its longest-standing member.
create function public.after_member_removed()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_next uuid;
begin
  -- The group itself is being deleted (cascade): nothing to repair.
  if not exists (select 1 from public.groups g where g.id = old.group_id) then
    return null;
  end if;

  select m.user_id into v_next
  from public.group_members m
  where m.group_id = old.group_id
  order by m.joined_at, m.user_id
  limit 1;

  if v_next is null then
    delete from public.groups g where g.id = old.group_id;
  elsif not exists (
    select 1 from public.group_members m
    where m.group_id = old.group_id and m.role = 'owner'
  ) then
    update public.group_members m
      set role = 'owner'
      where m.group_id = old.group_id and m.user_id = v_next;
  end if;
  return null;
end;
$$;

create trigger group_members_after_delete
  after delete on public.group_members
  for each row execute function public.after_member_removed();

-- ---------------------------------------------------------------------------
-- Invitations
-- ---------------------------------------------------------------------------

create table public.invitations (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id) on delete cascade,
  code_hash bytea not null unique,
  token_hash bytea not null unique,
  -- Last two characters of the code, so members can tell invitations apart
  -- without the code itself being recoverable.
  code_hint text not null check (char_length(code_hint) = 2),
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  expires_at timestamptz,
  revoked_at timestamptz,
  max_redemptions integer check (max_redemptions is null or max_redemptions > 0),
  redemption_count integer not null default 0 check (redemption_count >= 0),
  constraint expiry_after_creation check (expires_at is null or expires_at > created_at)
);

create index invitations_group_idx on public.invitations (group_id, created_at desc);

create table public.invitation_redemptions (
  invitation_id uuid not null references public.invitations (id) on delete cascade,
  group_id uuid not null references public.groups (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  redeemed_at timestamptz not null default now(),
  primary key (invitation_id, user_id)
);

create index invitation_redemptions_group_idx on public.invitation_redemptions (group_id);

-- Failed lookups, for rate limiting code guessing. Not readable by clients.
create table public.invitation_attempts (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  attempted_at timestamptz not null default now()
);

create index invitation_attempts_user_idx
  on public.invitation_attempts (user_id, attempted_at desc);

-- ---------------------------------------------------------------------------
-- Membership helpers (security definer to avoid RLS recursion)
-- ---------------------------------------------------------------------------

create function public.is_group_member(p_group_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.group_members m
    where m.group_id = p_group_id and m.user_id = (select auth.uid())
  );
$$;

create function public.is_group_owner(p_group_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.group_members m
    where m.group_id = p_group_id
      and m.user_id = (select auth.uid())
      and m.role = 'owner'
  );
$$;

create function public.shares_group_with(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.group_members mine
    join public.group_members theirs on theirs.group_id = mine.group_id
    where mine.user_id = (select auth.uid()) and theirs.user_id = p_user_id
  );
$$;

-- ---------------------------------------------------------------------------
-- Row Level Security and privileges
-- ---------------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.invitations enable row level security;
alter table public.invitation_redemptions enable row level security;
alter table public.invitation_attempts enable row level security;

-- Start from nothing; grant only what each role needs.
revoke all on public.profiles, public.groups, public.group_members,
  public.invitations, public.invitation_redemptions, public.invitation_attempts
  from anon, authenticated;

grant select on public.profiles to authenticated;
grant update (display_name, avatar_path) on public.profiles to authenticated;

grant select on public.groups to authenticated;
grant update (name, cover_path, relationship_start_date, show_relationship_counter)
  on public.groups to authenticated;

grant select, delete on public.group_members to authenticated;

-- Hashes are never selectable by clients.
grant select (id, group_id, code_hint, created_by, created_at, expires_at,
  revoked_at, max_redemptions, redemption_count)
  on public.invitations to authenticated;

grant select on public.invitation_redemptions to authenticated;

create policy "profiles: read self and group co-members"
  on public.profiles for select to authenticated
  using (id = (select auth.uid()) or public.shares_group_with(id));

create policy "profiles: update self"
  on public.profiles for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

create policy "groups: members read"
  on public.groups for select to authenticated
  using (public.is_group_member(id));

create policy "groups: owner updates settings"
  on public.groups for update to authenticated
  using (public.is_group_owner(id))
  with check (public.is_group_owner(id));

create policy "group_members: members read"
  on public.group_members for select to authenticated
  using (public.is_group_member(group_id));

create policy "group_members: leave"
  on public.group_members for delete to authenticated
  using (user_id = (select auth.uid()));

create policy "invitations: members read"
  on public.invitations for select to authenticated
  using (public.is_group_member(group_id));

create policy "invitation_redemptions: members read"
  on public.invitation_redemptions for select to authenticated
  using (public.is_group_member(group_id));

-- invitation_attempts: no policies → no client access.

-- ---------------------------------------------------------------------------
-- Read model for the Home screen (RLS applies: security_invoker)
-- ---------------------------------------------------------------------------

create view public.group_summaries
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
    where m.group_id = g.id and m.user_id = (select auth.uid())) as my_role
from public.groups g;

revoke all on public.group_summaries from anon, authenticated;
grant select on public.group_summaries to authenticated;

-- ---------------------------------------------------------------------------
-- Trusted operations
-- ---------------------------------------------------------------------------

create function public.require_user()
returns uuid
language plpgsql
stable
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
begin
  if v_uid is null then
    raise exception 'closer:not_authenticated' using errcode = 'P0001';
  end if;
  return v_uid;
end;
$$;

create function public.create_group(
  p_name text,
  p_type public.group_type,
  p_relationship_start_date date default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := public.require_user();
  v_id uuid;
begin
  if p_type <> 'couple' and p_relationship_start_date is not null then
    raise exception 'closer:relationship_date_couples_only' using errcode = 'P0001';
  end if;
  if p_relationship_start_date is not null and p_relationship_start_date > current_date then
    raise exception 'closer:relationship_date_in_future' using errcode = 'P0001';
  end if;

  insert into public.groups (name, type, created_by, relationship_start_date)
  values (btrim(p_name), p_type, v_uid, p_relationship_start_date)
  returning id into v_id;

  insert into public.group_members (group_id, user_id, role)
  values (v_id, v_uid, 'owner');

  return v_id;
end;
$$;

-- Human-friendly code alphabet without look-alikes (no 0/O, 1/I/L).
create function public.generate_invite_code()
returns text
language plpgsql
volatile
set search_path = ''
as $$
declare
  v_alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  v_bytes bytea := extensions.gen_random_bytes(8);
  v_code text := '';
  i integer;
begin
  -- 31 symbols; rejection sampling keeps the distribution uniform.
  i := 0;
  while char_length(v_code) < 8 loop
    if i >= length(v_bytes) then
      v_bytes := extensions.gen_random_bytes(8);
      i := 0;
    end if;
    if get_byte(v_bytes, i) < 248 then
      v_code := v_code || substr(v_alphabet, (get_byte(v_bytes, i) % 31) + 1, 1);
    end if;
    i := i + 1;
  end loop;
  return v_code;
end;
$$;

create function public.normalize_invite_code(p_input text)
returns text
language sql
immutable
set search_path = ''
as $$
  select upper(regexp_replace(coalesce(p_input, ''), '[^A-Za-z0-9]', '', 'g'));
$$;

create function public.hash_secret(p_secret text)
returns bytea
language sql
immutable
set search_path = ''
as $$
  select extensions.digest(convert_to(p_secret, 'UTF8'), 'sha256');
$$;

-- Creates an invitation and returns its plaintext code and token ONCE.
create function public.create_invitation(
  p_group_id uuid,
  p_expires_in_hours integer default 168,
  p_max_redemptions integer default null
)
returns table (invitation_id uuid, code text, token text, expires_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := public.require_user();
  v_group public.groups%rowtype;
  v_cap integer;
  v_members integer;
  v_code text;
  v_token text;
  v_expires timestamptz;
  v_id uuid;
  v_max integer := p_max_redemptions;
begin
  if not public.is_group_member(p_group_id) then
    raise exception 'closer:not_a_member' using errcode = 'P0001';
  end if;
  if p_expires_in_hours is not null and (p_expires_in_hours < 1 or p_expires_in_hours > 24 * 90) then
    raise exception 'closer:invalid_expiry' using errcode = 'P0001';
  end if;
  if v_max is not null and (v_max < 1 or v_max > 100) then
    raise exception 'closer:invalid_max_redemptions' using errcode = 'P0001';
  end if;

  select * into v_group from public.groups g where g.id = p_group_id;
  v_cap := public.group_capacity(v_group.type);
  if v_cap is not null then
    select count(*) into v_members from public.group_members m where m.group_id = p_group_id;
    if v_members >= v_cap then
      raise exception 'closer:group_full' using errcode = 'P0001';
    end if;
    -- A couple invite can only ever admit one more person.
    v_max := least(coalesce(v_max, v_cap - v_members), v_cap - v_members);
  end if;

  v_expires := case when p_expires_in_hours is null then null
                    else now() + make_interval(hours => p_expires_in_hours) end;
  v_token := translate(
    encode(extensions.gen_random_bytes(24), 'base64'), '+/=', '-_'
  );

  loop
    v_code := public.generate_invite_code();
    begin
      insert into public.invitations
        (group_id, code_hash, token_hash, code_hint, created_by, expires_at, max_redemptions)
      values
        (p_group_id, public.hash_secret(v_code), public.hash_secret(v_token),
         right(v_code, 2), v_uid, v_expires, v_max)
      returning id into v_id;
      exit;
    exception when unique_violation then
      -- Astronomically unlikely code collision: try another code.
    end;
  end loop;

  return query select v_id, v_code, v_token, v_expires;
end;
$$;

-- Owner, or the member who created it, can revoke an invitation.
create function public.revoke_invitation(p_invitation_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := public.require_user();
  v_inv public.invitations%rowtype;
begin
  select * into v_inv from public.invitations i where i.id = p_invitation_id;
  if not found or not public.is_group_member(v_inv.group_id) then
    raise exception 'closer:invitation_not_found' using errcode = 'P0001';
  end if;
  if not (public.is_group_owner(v_inv.group_id) or v_inv.created_by = v_uid) then
    raise exception 'closer:not_allowed' using errcode = 'P0001';
  end if;
  update public.invitations i
    set revoked_at = coalesce(i.revoked_at, now())
    where i.id = p_invitation_id;
end;
$$;

-- Finds an invitation by code (8 chars, any formatting) or link token.
create function public.find_invitation(p_secret text, p_lock boolean)
returns public.invitations
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_inv public.invitations;
  v_code text := public.normalize_invite_code(p_secret);
  v_raw text := btrim(coalesce(p_secret, ''));
begin
  if v_raw = '' then
    return null;
  end if;
  if p_lock then
    select * into v_inv from public.invitations i
    where i.code_hash = public.hash_secret(v_code)
       or i.token_hash = public.hash_secret(v_raw)
    limit 1
    for update;
  else
    select * into v_inv from public.invitations i
    where i.code_hash = public.hash_secret(v_code)
       or i.token_hash = public.hash_secret(v_raw)
    limit 1;
  end if;
  return v_inv;
end;
$$;

create function public.invitation_status(p_inv public.invitations)
returns text
language sql
stable
set search_path = ''
as $$
  select case
    when p_inv.id is null then 'invalid'
    when p_inv.revoked_at is not null then 'revoked'
    when p_inv.expires_at is not null and p_inv.expires_at <= now() then 'expired'
    when p_inv.max_redemptions is not null
         and p_inv.redemption_count >= p_inv.max_redemptions then 'exhausted'
    else 'valid'
  end;
$$;

-- Returns true (and records nothing) when the user may try again; false when
-- too many failed lookups happened recently.
create function public.invite_attempts_allowed(p_uid uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select count(*) < 10
  from public.invitation_attempts a
  where a.user_id = p_uid and a.attempted_at > now() - interval '15 minutes';
$$;

-- Shows what a valid invitation would join, without granting any access.
-- Only the group's name, type and size are revealed.
create function public.preview_invitation(p_secret text)
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

-- Joins the invitation's group. Atomic: locks the invitation (redemption
-- count) and, through the capacity trigger, the group row.
create function public.redeem_invitation(p_secret text)
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

create function public.leave_group(p_group_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := public.require_user();
begin
  delete from public.group_members m
  where m.group_id = p_group_id and m.user_id = v_uid;
  if not found then
    raise exception 'closer:not_a_member' using errcode = 'P0001';
  end if;
  -- after_member_removed() hands ownership on or deletes the empty group.
end;
$$;

create function public.transfer_ownership(p_group_id uuid, p_new_owner uuid)
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
  if p_new_owner = v_uid then
    return;
  end if;
  if not exists (select 1 from public.group_members m
                 where m.group_id = p_group_id and m.user_id = p_new_owner) then
    raise exception 'closer:not_a_member' using errcode = 'P0001';
  end if;
  update public.group_members m set role = 'member'
    where m.group_id = p_group_id and m.user_id = v_uid;
  update public.group_members m set role = 'owner'
    where m.group_id = p_group_id and m.user_id = p_new_owner;
end;
$$;

create function public.remove_member(p_group_id uuid, p_user_id uuid)
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
end;
$$;

create function public.delete_group(p_group_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.require_user();
  if not public.is_group_owner(p_group_id) then
    raise exception 'closer:not_allowed' using errcode = 'P0001';
  end if;
  -- Cascades to memberships, invitations and redemptions.
  -- Phase 3 adds storage cleanup jobs for the group's photos here.
  delete from public.groups g where g.id = p_group_id;
end;
$$;

-- Function privileges: nothing for anon; trusted entry points for users.
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
  public.delete_group(uuid)
to authenticated;

-- RLS helper functions are called inside policies as the querying role.
grant execute on function
  public.is_group_member(uuid),
  public.is_group_owner(uuid),
  public.shares_group_with(uuid)
to authenticated;

alter default privileges in schema public revoke execute on functions from public, anon;
