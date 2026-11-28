-- Storage abuse limits (ISSUES E27). The app is not the only client: anyone
-- with an account can call these functions directly, so the server caps
-- what one account can store:
--
--   * a file in the photos bucket is at most 10 MB (was 15), a thumbnail
--     at most 2 MB; the app sends about 1 MB and 0.1 MB;
--   * at most 10 unfinished uploads at once, and they expire after one
--     hour instead of a day (their files are then deleted);
--   * at most 300 photo uploads per account per 24 hours;
--   * at most 10 groups created per account, and at most 30 groups in total
--     (owner decision 2026-11-23), counting the ones it created;
--   * at most 3 profile-photo files per account; files no profile points to
--     are deleted after an hour;
--   * a daily storage check the app owner can read (storage_usage_log,
--     storage_by_user()).
--
-- Limits live in functions so they can be changed in one place.

create function public.max_upload_bytes() returns bigint
language sql immutable set search_path = '' as $$ select 10 * 1024 * 1024::bigint $$;

create function public.max_thumbnail_bytes() returns bigint
language sql immutable set search_path = '' as $$ select 2 * 1024 * 1024::bigint $$;

create function public.max_pending_uploads() returns integer
language sql immutable set search_path = '' as $$ select 10 $$;

create function public.max_uploads_per_day() returns integer
language sql immutable set search_path = '' as $$ select 300 $$;

create function public.max_groups_per_user() returns integer
language sql immutable set search_path = '' as $$ select 10 $$;

create function public.max_memberships_per_user() returns integer
language sql immutable set search_path = '' as $$ select 30 $$;

create function public.max_avatar_files() returns integer
language sql immutable set search_path = '' as $$ select 3 $$;

-- Warn above this much stored (80 % of the free plan's 1 GB).
create function public.storage_alert_bytes() returns bigint
language sql immutable set search_path = '' as $$ select 800 * 1024 * 1024::bigint $$;

update storage.buckets set file_size_limit = public.max_upload_bytes() where id = 'photos';

-- ---------------------------------------------------------------------------
-- Groups
-- ---------------------------------------------------------------------------

create or replace function public.create_group(
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
  if (select count(*) from public.groups g where g.created_by = v_uid)
     >= public.max_groups_per_user() then
    raise exception 'closer:group_limit' using errcode = 'P0001';
  end if;

  insert into public.groups (name, type, created_by, relationship_start_date)
  values (btrim(p_name), p_type, v_uid, p_relationship_start_date)
  returning id into v_id;

  insert into public.group_members (group_id, user_id, role)
  values (v_id, v_uid, 'owner');

  return v_id;
end;
$$;

-- Every way into a group (creating, joining) inserts here, so the total is
-- enforced in one place.
create function public.enforce_membership_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Serialise concurrent joins/creates by the same person.
  perform 1 from public.profiles p where p.id = new.user_id for update;
  if (select count(*) from public.group_members m where m.user_id = new.user_id)
     >= public.max_memberships_per_user() then
    raise exception 'closer:membership_limit' using errcode = 'P0001';
  end if;
  return new;
end;
$$;

create trigger group_members_limit
  before insert on public.group_members
  for each row execute function public.enforce_membership_limit();

-- ---------------------------------------------------------------------------
-- Photos
-- ---------------------------------------------------------------------------

create or replace function public.request_photo_upload(
  p_group_id uuid,
  p_client_upload_id uuid,
  p_caption text default null,
  p_taken_at timestamptz default null,
  p_width integer default null,
  p_height integer default null,
  p_byte_size integer default null
)
returns table (photo_id uuid, storage_path text, thumb_path text, status public.photo_status)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := public.require_user();
  v_photo public.photos;
  v_id uuid := gen_random_uuid();
  v_caption text := nullif(btrim(coalesce(p_caption, '')), '');
begin
  if not public.is_group_member(p_group_id) then
    raise exception 'closer:not_a_member' using errcode = 'P0001';
  end if;
  if p_client_upload_id is null then
    raise exception 'closer:invalid_upload' using errcode = 'P0001';
  end if;
  if p_taken_at is not null and p_taken_at > now() + interval '1 day' then
    raise exception 'closer:taken_in_future' using errcode = 'P0001';
  end if;

  -- Retrying the same upload returns the same row (duplicate-submit protection).
  select * into v_photo from public.photos p
  where p.uploader_id = v_uid and p.client_upload_id = p_client_upload_id;
  if found then
    if v_photo.group_id <> p_group_id then
      raise exception 'closer:invalid_upload' using errcode = 'P0001';
    end if;
    return query select v_photo.id, v_photo.storage_path, v_photo.thumb_path, v_photo.status;
    return;
  end if;

  perform public.assert_upload_allowed(p_group_id);

  -- Removed and expired uploads count too, so retrying can't get round it.
  if (select count(*) from public.photos p
      where p.uploader_id = v_uid and p.created_at > now() - interval '1 day')
     >= public.max_uploads_per_day() then
    raise exception 'closer:upload_limit' using errcode = 'P0001';
  end if;
  if (select count(*) from public.photos p
      where p.uploader_id = v_uid and p.status = 'pending')
     >= public.max_pending_uploads() then
    raise exception 'closer:too_many_uploads' using errcode = 'P0001';
  end if;

  insert into public.photos (
    id, group_id, uploader_id, client_upload_id, storage_path, thumb_path,
    caption, taken_at, width, height, byte_size
  ) values (
    v_id, p_group_id, v_uid, p_client_upload_id,
    p_group_id || '/' || v_id || '/original.jpg',
    p_group_id || '/' || v_id || '/thumb.jpg',
    v_caption, p_taken_at, p_width, p_height, p_byte_size
  )
  returning * into v_photo;

  return query select v_photo.id, v_photo.storage_path, v_photo.thumb_path, v_photo.status;
end;
$$;

create or replace function public.finalize_photo(p_photo_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := public.require_user();
  v_photo public.photos;
  v_removed uuid[] := '{}';
begin
  select * into v_photo from public.photos p where p.id = p_photo_id;
  if not found or v_photo.uploader_id is distinct from v_uid
     or not public.is_group_member(v_photo.group_id) then
    raise exception 'closer:photo_not_found' using errcode = 'P0001';
  end if;

  if v_photo.status = 'active' then
    return jsonb_build_object('photo_id', v_photo.id, 'status', 'active', 'removed', '[]'::jsonb);
  end if;
  if v_photo.status = 'removed' then
    raise exception 'closer:upload_expired' using errcode = 'P0001';
  end if;

  -- Both objects must really be in storage before the photo goes live.
  if (select count(*) from storage.objects o
      where o.bucket_id = 'photos'
        and o.name in (v_photo.storage_path, v_photo.thumb_path)) < 2 then
    raise exception 'closer:upload_incomplete' using errcode = 'P0001';
  end if;

  -- The bucket caps each file; a "thumbnail" must also really be small.
  if exists (select 1 from storage.objects o
             where o.bucket_id = 'photos' and o.name = v_photo.thumb_path
               and coalesce((o.metadata ->> 'size')::bigint, 0) > public.max_thumbnail_bytes()) then
    raise exception 'closer:upload_too_large' using errcode = 'P0001';
  end if;

  -- Serialise finalization and retention per group.
  perform 1 from public.groups g where g.id = v_photo.group_id for update;

  -- A duplicate call may have finished while this one waited for the lock.
  select * into v_photo from public.photos p where p.id = p_photo_id;
  if v_photo.status = 'active' then
    return jsonb_build_object('photo_id', v_photo.id, 'status', 'active', 'removed', '[]'::jsonb);
  end if;
  if v_photo.status = 'removed' then
    raise exception 'closer:upload_expired' using errcode = 'P0001';
  end if;

  perform public.assert_upload_allowed(v_photo.group_id);

  update public.photos
    set status = 'active', uploaded_at = now()
    where id = v_photo.id;

  v_removed := public.apply_retention(v_photo.group_id);

  update public.groups g set last_activity_at = now() where g.id = v_photo.group_id;

  return jsonb_build_object(
    'photo_id', v_photo.id,
    'status', 'active',
    'removed', to_jsonb(v_removed)
  );
end;
$$;

-- Unfinished uploads now expire after an hour (the cleanup worker calls this
-- without arguments every 10 minutes).
drop function public.expire_stale_uploads(interval);
create function public.expire_stale_uploads(p_older_than interval default interval '1 hour')
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_photo public.photos;
  v_count integer := 0;
begin
  for v_photo in
    select * from public.photos p
    where p.status = 'pending' and p.created_at < now() - p_older_than
    for update skip locked
  loop
    update public.photos
      set status = 'removed', removed_at = now(), removed_reason = 'upload_abandoned'
      where id = v_photo.id;
    perform public.enqueue_photo_cleanup(v_photo, 'upload_abandoned');
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

-- ---------------------------------------------------------------------------
-- Profile photos
-- ---------------------------------------------------------------------------

create or replace function public.can_upload_avatar_object(p_name text)
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
                    where o.bucket_id = 'avatars' and o.name = p_name)
    and (select count(*) from storage.objects o
         where o.bucket_id = 'avatars'
           and o.name like (select auth.uid())::text || '/%') < public.max_avatar_files();
$$;

-- Queues profile-photo files that no profile points to (uploads that were
-- never set, or extra copies). Run daily; the hour's grace covers an upload
-- whose set_avatar() call is still on its way.
create function public.queue_orphan_avatars()
returns integer
language sql
security definer
set search_path = ''
as $$
  with orphans as (
    insert into public.storage_cleanup_jobs (bucket_id, object_path, reason)
    select 'avatars', o.name, 'avatar_orphan'
    from storage.objects o
    where o.bucket_id = 'avatars'
      and o.created_at < now() - interval '1 hour'
      and not exists (select 1 from public.profiles p where p.avatar_path = o.name)
    on conflict (bucket_id, object_path) do nothing
    returning 1
  )
  select count(*)::integer from orphans;
$$;

-- ---------------------------------------------------------------------------
-- Storage watch (app owner)
-- ---------------------------------------------------------------------------

create table public.storage_usage_log (
  day date primary key default current_date,
  bytes bigint not null,
  objects integer not null,
  over_alert boolean not null,
  checked_at timestamptz not null default now()
);

alter table public.storage_usage_log enable row level security;
revoke all on public.storage_usage_log from anon, authenticated;

-- Records today's total; over_alert marks days above storage_alert_bytes().
create function public.check_storage_usage()
returns public.storage_usage_log
language sql
security definer
set search_path = ''
as $$
  insert into public.storage_usage_log (day, bytes, objects, over_alert)
  select current_date, coalesce(sum((o.metadata ->> 'size')::bigint), 0), count(*)::integer,
         coalesce(sum((o.metadata ->> 'size')::bigint), 0) > public.storage_alert_bytes()
  from storage.objects o
  on conflict (day) do update
    set bytes = excluded.bytes, objects = excluded.objects,
        over_alert = excluded.over_alert, checked_at = now()
  returning *;
$$;

-- Who stores the most, to spot abuse. Sizes and counts only.
create function public.storage_by_user(p_limit integer default 20)
returns table (user_id uuid, display_name text, photos integer, bytes bigint, uploads_last_day integer)
language sql
stable
security definer
set search_path = ''
as $$
  select p.uploader_id, pr.display_name::text,
         count(*) filter (where p.status = 'active')::integer,
         coalesce(sum((o.metadata ->> 'size')::bigint), 0)::bigint,
         count(*) filter (where p.created_at > now() - interval '1 day')::integer
  from public.photos p
  left join public.profiles pr on pr.id = p.uploader_id
  left join storage.objects o
    on o.bucket_id = 'photos' and o.name in (p.storage_path, p.thumb_path)
  where p.status <> 'removed'
  group by 1, 2
  order by 4 desc
  limit greatest(1, least(coalesce(p_limit, 20), 200));
$$;

-- Daily at 04:00 UTC, where pg_cron exists (it does on the hosted project;
-- local test databases call the functions directly).
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('closer-storage-watch', '0 4 * * *',
      'select public.queue_orphan_avatars(); select public.check_storage_usage();');
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Privileges (`create or replace` keeps those of the replaced functions;
-- expire_stale_uploads was recreated, so it is granted again)
-- ---------------------------------------------------------------------------

revoke all on function
  public.max_upload_bytes(), public.max_thumbnail_bytes(), public.max_pending_uploads(),
  public.max_uploads_per_day(), public.max_groups_per_user(), public.max_avatar_files(),
  public.max_memberships_per_user(), public.enforce_membership_limit(),
  public.storage_alert_bytes(), public.expire_stale_uploads(interval),
  public.queue_orphan_avatars(), public.check_storage_usage(), public.storage_by_user(integer)
from public, anon, authenticated;

grant execute on function
  public.expire_stale_uploads(interval),
  public.queue_orphan_avatars(),
  public.check_storage_usage(),
  public.storage_by_user(integer)
to service_role;
