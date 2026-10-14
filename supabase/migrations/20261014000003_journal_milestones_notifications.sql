-- Closer — Phase 4: milestones, journal feed, chosen group covers, avatars,
-- in-app notifications with preferences, and account deletion support.

-- ---------------------------------------------------------------------------
-- Milestones
-- ---------------------------------------------------------------------------

create type public.milestone_type as enum (
  'days_together', 'anniversary', 'first_date', 'first_trip', 'birthday',
  'holiday', 'graduation', 'reunion', 'custom'
);
create type public.milestone_theme as enum ('heart', 'celebration', 'neutral');

create table public.milestones (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id) on delete cascade,
  created_by uuid references public.profiles (id) on delete set null
    default auth.uid(),
  title text not null check (char_length(btrim(title)) between 1 and 80),
  type public.milestone_type not null default 'custom',
  event_date date not null,
  description text check (description is null or char_length(description) <= 1000),
  -- Must be an active photo of the same group (trigger); cleared automatically
  -- when that photo is removed, so milestones never point at missing photos.
  cover_photo_id uuid references public.photos (id) on delete set null,
  theme public.milestone_theme not null default 'neutral',
  is_pinned boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index milestones_group_date_idx on public.milestones (group_id, event_date desc, id desc);

create trigger milestones_touch_updated_at
  before update on public.milestones
  for each row execute function public.touch_updated_at();

create function public.validate_milestone()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.title := btrim(new.title);
  new.description := nullif(btrim(coalesce(new.description, '')), '');
  if tg_op = 'UPDATE' and new.group_id <> old.group_id then
    raise exception 'closer:invalid_milestone' using errcode = 'P0001';
  end if;
  if new.cover_photo_id is not null and not exists (
    select 1 from public.photos p
    where p.id = new.cover_photo_id and p.group_id = new.group_id and p.status = 'active'
  ) then
    raise exception 'closer:invalid_cover_photo' using errcode = 'P0001';
  end if;
  return new;
end;
$$;

create trigger milestones_validate
  before insert or update on public.milestones
  for each row execute function public.validate_milestone();

-- ---------------------------------------------------------------------------
-- Chosen group covers
-- ---------------------------------------------------------------------------

alter table public.groups
  add column cover_photo_id uuid references public.photos (id) on delete set null;

create function public.set_group_cover(p_group_id uuid, p_photo_id uuid)
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
  if p_photo_id is not null and not exists (
    select 1 from public.photos p
    where p.id = p_photo_id and p.group_id = p_group_id and p.status = 'active'
  ) then
    raise exception 'closer:invalid_cover_photo' using errcode = 'P0001';
  end if;
  update public.groups g set cover_photo_id = p_photo_id where g.id = p_group_id;
end;
$$;

-- When a photo stops being active, drop every reference to it.
create function public.after_photo_removed()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'removed' and old.status <> 'removed' then
    update public.milestones m set cover_photo_id = null where m.cover_photo_id = new.id;
    update public.groups g set cover_photo_id = null where g.cover_photo_id = new.id;
  end if;
  return null;
end;
$$;

create trigger photos_after_removed
  after update of status on public.photos
  for each row execute function public.after_photo_removed();

-- ---------------------------------------------------------------------------
-- Avatars (private bucket, visible to the user and people they share a group with)
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', false, 2 * 1024 * 1024, array['image/jpeg'])
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- Objects live at <user_id>/<random>.jpg; a new file per change avoids stale caches.
create function public.can_read_avatar_object(p_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles pr
    where pr.avatar_path = p_name
      and (pr.id = (select auth.uid()) or public.shares_group_with(pr.id))
  );
$$;

create function public.can_upload_avatar_object(p_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select auth.uid()) is not null
    and split_part(p_name, '/', 1) = (select auth.uid())::text
    and p_name ~ '^[0-9a-f-]{36}/[A-Za-z0-9_-]{8,64}\.jpg$'
    and not exists (select 1 from storage.objects o
                    where o.bucket_id = 'avatars' and o.name = p_name);
$$;

create policy "avatars bucket: read self and group co-members"
  on storage.objects for select to authenticated
  using (bucket_id = 'avatars' and public.can_read_avatar_object(name));

create policy "avatars bucket: users write their own folder"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and public.can_upload_avatar_object(name));

-- Points the profile at an uploaded avatar (or clears it) and queues the old file.
create function public.set_avatar(p_path text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := public.require_user();
  v_old text;
begin
  if p_path is not null and (
    split_part(p_path, '/', 1) <> v_uid::text
    or not exists (select 1 from storage.objects o
                   where o.bucket_id = 'avatars' and o.name = p_path)
  ) then
    raise exception 'closer:invalid_avatar' using errcode = 'P0001';
  end if;
  select avatar_path into v_old from public.profiles where id = v_uid for update;
  update public.profiles set avatar_path = p_path where id = v_uid;
  if v_old is not null and v_old is distinct from p_path then
    insert into public.storage_cleanup_jobs (bucket_id, object_path, reason)
    values ('avatars', v_old, 'avatar_replaced')
    on conflict (bucket_id, object_path) do nothing;
  end if;
end;
$$;

-- Avatars are changed only through set_avatar().
revoke update (avatar_path) on public.profiles from authenticated;

-- ---------------------------------------------------------------------------
-- Notifications and preferences
-- ---------------------------------------------------------------------------

create type public.notification_kind as enum (
  'photo_added', 'member_joined', 'milestone_added'
);

create table public.notification_preferences (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  photos boolean not null default true,
  members boolean not null default true,
  milestones boolean not null default true,
  updated_at timestamptz not null default now()
);

create trigger notification_preferences_touch
  before update on public.notification_preferences
  for each row execute function public.touch_updated_at();

create table public.notifications (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  group_id uuid not null references public.groups (id) on delete cascade,
  actor_id uuid references public.profiles (id) on delete set null,
  kind public.notification_kind not null,
  photo_id uuid references public.photos (id) on delete cascade,
  milestone_id uuid references public.milestones (id) on delete cascade,
  created_at timestamptz not null default now(),
  read_at timestamptz,
  -- One notification per event per recipient (idempotent fan-out).
  constraint notifications_event_unique unique nulls not distinct
    (user_id, kind, group_id, actor_id, photo_id, milestone_id)
);

create index notifications_user_idx on public.notifications (user_id, created_at desc, id desc);

-- Fans an event out to the other members of the group who want it.
-- Notifications carry ids only: never captions or photo content.
create function public.notify_group(
  p_group_id uuid,
  p_actor_id uuid,
  p_kind public.notification_kind,
  p_photo_id uuid default null,
  p_milestone_id uuid default null
)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.notifications (user_id, group_id, actor_id, kind, photo_id, milestone_id)
  select m.user_id, p_group_id, p_actor_id, p_kind, p_photo_id, p_milestone_id
  from public.group_members m
  left join public.notification_preferences np on np.user_id = m.user_id
  where m.group_id = p_group_id
    and m.user_id is distinct from p_actor_id
    and case p_kind
          when 'photo_added' then coalesce(np.photos, true)
          when 'member_joined' then coalesce(np.members, true)
          when 'milestone_added' then coalesce(np.milestones, true)
        end
  on conflict do nothing;
$$;

create function public.on_photo_activated()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'active' and old.status = 'pending' then
    perform public.notify_group(new.group_id, new.uploader_id, 'photo_added', new.id, null);
  end if;
  return null;
end;
$$;

create trigger photos_notify_activated
  after update of status on public.photos
  for each row execute function public.on_photo_activated();

create function public.on_member_joined()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- The creator becoming owner of a new group is not news for anyone.
  if new.role = 'member' then
    perform public.notify_group(new.group_id, new.user_id, 'member_joined', null, null);
  end if;
  return null;
end;
$$;

create trigger group_members_notify_joined
  after insert on public.group_members
  for each row execute function public.on_member_joined();

create function public.on_milestone_added()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.notify_group(new.group_id, new.created_by, 'milestone_added', null, new.id);
  return null;
end;
$$;

create trigger milestones_notify_added
  after insert on public.milestones
  for each row execute function public.on_milestone_added();

create function public.mark_notifications_read(p_ids bigint[] default null)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.notifications n
  set read_at = now()
  where n.user_id = (select auth.uid())
    and n.read_at is null
    and (p_ids is null or n.id = any (p_ids));
$$;

-- Removing a member's access also removes their notifications for that group.
create function public.after_member_left_notifications()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.notifications n
  where n.user_id = old.user_id and n.group_id = old.group_id;
  return null;
end;
$$;

create trigger group_members_clear_notifications
  after delete on public.group_members
  for each row execute function public.after_member_left_notifications();

-- ---------------------------------------------------------------------------
-- Journal feed: photos and past milestones, newest first, keyset paginated
-- ---------------------------------------------------------------------------

-- SECURITY INVOKER: RLS on photos, milestones and profiles applies.
create function public.journal_entries(
  p_group_id uuid default null,
  p_before_at timestamptz default null,
  p_before_id uuid default null,
  p_limit integer default 30
)
returns setof jsonb
language sql
stable
set search_path = ''
as $$
  select e.entry
  from (
    select p.id,
           coalesce(p.taken_at, p.uploaded_at) as at,
           jsonb_build_object(
             'kind', 'photo',
             'id', p.id,
             'group_id', p.group_id,
             'occurred_at', coalesce(p.taken_at, p.uploaded_at),
             'photo', jsonb_build_object(
               'id', p.id, 'group_id', p.group_id, 'uploader_id', p.uploader_id,
               'storage_path', p.storage_path, 'thumb_path', p.thumb_path,
               'caption', p.caption, 'taken_at', p.taken_at,
               'uploaded_at', p.uploaded_at, 'width', p.width, 'height', p.height,
               'is_pinned', p.is_pinned,
               'profiles', jsonb_build_object('display_name', pr.display_name)
             )
           ) as entry
    from public.photos p
    left join public.profiles pr on pr.id = p.uploader_id
    where p.status = 'active'
      and (p_group_id is null or p.group_id = p_group_id)
    union all
    select m.id,
           (m.event_date + 1)::timestamptz - interval '1 second' as at,
           jsonb_build_object(
             'kind', 'milestone',
             'id', m.id,
             'group_id', m.group_id,
             'occurred_at', (m.event_date + 1)::timestamptz - interval '1 second',
             'milestone', to_jsonb(m)
           ) as entry
    from public.milestones m
    where m.event_date <= current_date
      and (p_group_id is null or m.group_id = p_group_id)
  ) e
  where p_before_at is null or (e.at, e.id) < (p_before_at, p_before_id)
  order by e.at desc, e.id desc
  limit least(greatest(coalesce(p_limit, 30), 1), 100);
$$;

-- ---------------------------------------------------------------------------
-- Account deletion (called by the delete-account Edge Function, service role)
-- ---------------------------------------------------------------------------

-- Queues the user's avatar for deletion. Afterwards the Edge Function deletes
-- the auth user; cascades remove the profile, memberships (with ownership
-- hand-over / empty-group deletion), notifications and preferences. Photos the
-- user shared stay with their groups (uploader becomes null).
create function public.prepare_account_deletion(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_avatar text;
begin
  select avatar_path into v_avatar from public.profiles where id = p_user_id;
  if v_avatar is not null then
    insert into public.storage_cleanup_jobs (bucket_id, object_path, reason)
    values ('avatars', v_avatar, 'account_deleted')
    on conflict (bucket_id, object_path) do nothing;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Read model: chosen cover wins over the newest photo
-- ---------------------------------------------------------------------------

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
  g.cover_photo_id
from public.groups g;

-- ---------------------------------------------------------------------------
-- RLS and privileges
-- ---------------------------------------------------------------------------

alter table public.milestones enable row level security;
alter table public.notifications enable row level security;
alter table public.notification_preferences enable row level security;

revoke all on public.milestones, public.notifications, public.notification_preferences
  from anon, authenticated;

grant select on public.milestones to authenticated;
grant insert (group_id, title, type, event_date, description, cover_photo_id, theme, is_pinned)
  on public.milestones to authenticated;
grant update (title, type, event_date, description, cover_photo_id, theme, is_pinned)
  on public.milestones to authenticated;
grant delete on public.milestones to authenticated;

create policy "milestones: members read"
  on public.milestones for select to authenticated
  using (public.is_group_member(group_id));

create policy "milestones: members create as themselves"
  on public.milestones for insert to authenticated
  with check (public.is_group_member(group_id) and created_by = (select auth.uid()));

create policy "milestones: creator or owner edits"
  on public.milestones for update to authenticated
  using (public.is_group_member(group_id)
         and (created_by = (select auth.uid()) or public.is_group_owner(group_id)))
  with check (public.is_group_member(group_id));

create policy "milestones: creator or owner deletes"
  on public.milestones for delete to authenticated
  using (public.is_group_member(group_id)
         and (created_by = (select auth.uid()) or public.is_group_owner(group_id)));

grant select (id, user_id, group_id, actor_id, kind, photo_id, milestone_id, created_at, read_at)
  on public.notifications to authenticated;

create policy "notifications: recipients read their own"
  on public.notifications for select to authenticated
  using (user_id = (select auth.uid()) and public.is_group_member(group_id));

grant select, insert, update on public.notification_preferences to authenticated;

create policy "notification_preferences: own row"
  on public.notification_preferences for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

revoke all on public.group_summaries from anon, authenticated;
grant select on public.group_summaries to authenticated;

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
  public.prepare_account_deletion(uuid)
to service_role;
