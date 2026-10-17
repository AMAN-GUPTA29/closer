-- Usernames (product rule 2026-10-17): every person picks a unique username.
-- Lowercase letters, digits, "." and "_", 3–20 characters, starting with a
-- letter or digit and not ending with "."; unique; some names reserved.
-- Email sign-ups pass it in their sign-up metadata; anyone without one
-- (Google sign-in, older accounts, or a name taken in the meantime) is asked
-- to choose one before using the app.

alter table public.profiles
  add column username text
    check (username is null or (
      username ~ '^[a-z0-9][a-z0-9._]{1,18}[a-z0-9_]$'
      and username !~ '\.\.'
    ));

create unique index profiles_username_key on public.profiles (username);

-- Clients cannot write it directly (column grants only cover display_name and
-- avatar_path); set_username() validates and reports friendly errors.

create function public.username_reserved(p text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p = any (array[
    'admin', 'administrator', 'closer', 'closerapp', 'support', 'help',
    'root', 'system', 'moderator', 'official', 'team', 'staff', 'security',
    'null', 'undefined', 'me', 'you', 'everyone'
  ]);
$$;

-- Normalises input ("@Alex.Kim " -> "alex.kim"); null when malformed.
create function public.normalize_username(p_input text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when v ~ '^[a-z0-9][a-z0-9._]{1,18}[a-z0-9_]$' and v !~ '\.\.' then v
  end
  from (select lower(btrim(ltrim(btrim(coalesce(p_input, '')), '@'))) as v) s;
$$;

-- Signed-in users only (no enumeration by anonymous callers).
create function public.username_available(p_username text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := public.require_user();
  v text := public.normalize_username(p_username);
begin
  if v is null or public.username_reserved(v) then
    return false;
  end if;
  return not exists (
    select 1 from public.profiles p where p.username = v and p.id <> v_uid
  );
end;
$$;

create function public.set_username(p_username text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := public.require_user();
  v text := public.normalize_username(p_username);
begin
  if v is null then
    raise exception 'closer:invalid_username' using errcode = 'P0001';
  end if;
  if public.username_reserved(v) then
    raise exception 'closer:username_taken' using errcode = 'P0001';
  end if;
  begin
    update public.profiles set username = v where id = v_uid;
  exception when unique_violation then
    raise exception 'closer:username_taken' using errcode = 'P0001';
  end;
  return v;
end;
$$;

-- New users: name from email sign-up metadata or Google ("full_name"/"name"),
-- username from sign-up metadata when valid and free (never fails sign-up).
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text;
  v_username text;
begin
  v_name := btrim(coalesce(
    nullif(new.raw_user_meta_data ->> 'display_name', ''),
    nullif(new.raw_user_meta_data ->> 'full_name', ''),
    nullif(new.raw_user_meta_data ->> 'name', ''),
    ''));
  if v_name = '' then
    v_name := split_part(coalesce(new.email, 'Closer friend'), '@', 1);
  end if;
  v_username := public.normalize_username(new.raw_user_meta_data ->> 'username');
  if v_username is not null and (
       public.username_reserved(v_username)
       or exists (select 1 from public.profiles p where p.username = v_username)) then
    v_username := null;
  end if;
  insert into public.profiles (id, display_name, username)
  values (new.id, left(v_name, 40), v_username)
  on conflict (id) do nothing;
  return new;
exception when unique_violation then
  -- Username taken in a race: create the profile without it.
  insert into public.profiles (id, display_name)
  values (new.id, left(v_name, 40))
  on conflict (id) do nothing;
  return new;
end;
$$;

revoke execute on function public.username_reserved(text),
  public.normalize_username(text),
  public.username_available(text),
  public.set_username(text),
  public.handle_new_user()
  from public, anon, authenticated;
grant execute on function public.username_available(text),
  public.set_username(text)
  to authenticated;
