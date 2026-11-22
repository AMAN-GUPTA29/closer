-- Report a photo (owner decision 2026-11-23, ISSUES E16).
--
--   * a member reports someone else's photo with a reason; from then on the
--     photo, its files and its notification are hidden from the reporter,
--     enforced by RLS and storage policies;
--   * the uploader and the other members are never told, and clients cannot
--     read reports at all;
--   * the app owner reads photo_report_queue() and closes each report with
--     resolve_photo_report() (docs/moderation.md);
--   * while a report is open or held, the photo's files are not erased, even
--     if the photo, group or uploader's account is deleted meanwhile.

create table public.photo_reports (
  id uuid primary key default gen_random_uuid(),
  -- No foreign keys to photo, group or uploader: a report outlives all three.
  photo_id uuid not null,
  group_id uuid not null,
  uploader_id uuid,
  reporter_id uuid references public.profiles (id) on delete set null,
  reason text not null check (reason in ('harassment', 'sexual', 'child', 'other')),
  storage_path text not null,
  -- As it was when reported; cleared when the report is closed.
  caption text,
  status text not null default 'open'
    check (status in ('open', 'held', 'dismissed', 'removed')),
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  constraint photo_reports_once unique (photo_id, reporter_id)
);

create index photo_reports_reporter_idx on public.photo_reports (reporter_id, created_at);

alter table public.photo_reports enable row level security;
revoke all on public.photo_reports from anon, authenticated;

-- ---------------------------------------------------------------------------
-- Hidden for the reporter
-- ---------------------------------------------------------------------------

-- Only ever answers for the caller, so nobody can learn who reported what.
create function public.has_reported(p_photo_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.photo_reports r
    where r.photo_id = p_photo_id and r.reporter_id = (select auth.uid())
  );
$$;

-- Covers every query that reads photos: grid, journal, pins, milestone and
-- group covers, notification thumbnails and realtime.
alter policy "photos: members read active photos" on public.photos
  using (status = 'active' and public.is_group_member(group_id)
         and not public.has_reported(id));

-- Covers signed URLs and downloads (including the home-screen widget).
create or replace function public.can_read_photo_object(p_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.photos p
    where (p.storage_path = p_name or p.thumb_path = p_name)
      and p.status = 'active'
      and public.is_group_member(p.group_id)
      and not public.has_reported(p.id)
  );
$$;

-- A hidden photo still takes one of the group's 10 places, so the count that
-- drives the app's limit warnings must not follow the reporter's view.
create function public.group_photo_count(p_group_id uuid)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer from public.photos p
  where p.group_id = p_group_id and p.status = 'active'
    and public.is_group_member(p_group_id);
$$;

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
  public.group_photo_count(g.id) as photo_count,
  public.is_group_premium(g.id) as is_premium,
  coalesce(
    (select p.thumb_path from public.photos p
      where p.id = g.cover_photo_id and p.status = 'active'),
    (select p.thumb_path from public.photos p
      where p.group_id = g.id and p.status = 'active'
      order by p.uploaded_at desc, p.id desc limit 1)
  ) as latest_thumb_path,
  g.cover_photo_id,
  (select case when e.status = 'revoked' then e.revoked_at else e.expires_at end
    from public.group_entitlements e
    where e.group_id = g.id) as premium_expires_at,
  (exists (select 1 from public.group_entitlements e where e.group_id = g.id)
    and not public.is_group_premium(g.id)) as pass_ended
from public.groups g;

revoke all on public.group_summaries from anon, authenticated;
grant select on public.group_summaries to authenticated;

-- ---------------------------------------------------------------------------
-- Reporting
-- ---------------------------------------------------------------------------

create function public.report_photo(p_photo_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := public.require_user();
  v_photo public.photos;
begin
  if p_reason is null or p_reason not in ('harassment', 'sexual', 'child', 'other') then
    raise exception 'closer:invalid_report' using errcode = 'P0001';
  end if;

  -- A repeated tap or retry is not an error.
  if public.has_reported(p_photo_id) then
    return;
  end if;

  -- The lock orders this against a delete of the same photo: either the
  -- report exists before the files are queued, or the photo is already gone.
  select * into v_photo from public.photos p where p.id = p_photo_id for update;
  if not found or v_photo.status <> 'active'
     or not public.is_group_member(v_photo.group_id) then
    raise exception 'closer:photo_not_found' using errcode = 'P0001';
  end if;
  if v_photo.uploader_id = v_uid then
    raise exception 'closer:report_own_photo' using errcode = 'P0001';
  end if;
  if (select count(*) from public.photo_reports r
      where r.reporter_id = v_uid and r.created_at > now() - interval '1 day') >= 50 then
    raise exception 'closer:report_limit' using errcode = 'P0001';
  end if;

  insert into public.photo_reports
    (photo_id, group_id, uploader_id, reporter_id, reason, storage_path, caption)
  values (v_photo.id, v_photo.group_id, v_photo.uploader_id, v_uid, p_reason,
          v_photo.storage_path, v_photo.caption)
  on conflict (photo_id, reporter_id) do nothing;

  -- Also stops a push about this photo that hasn't been sent yet.
  delete from public.notifications n
  where n.user_id = v_uid and n.photo_id = v_photo.id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Keep the files while a report is open or held
-- ---------------------------------------------------------------------------

create or replace function public.claim_cleanup_jobs(p_limit integer default 50)
returns setof public.storage_cleanup_jobs
language sql
security definer
set search_path = ''
as $$
  update public.storage_cleanup_jobs j
  set status = 'running',
      attempts = j.attempts + 1,
      lease_until = now() + interval '5 minutes'
  where j.id in (
    select c.id from public.storage_cleanup_jobs c
    where ((c.status = 'queued' and c.next_attempt_at <= now())
        or (c.status = 'running' and c.lease_until < now()))
      and not exists (
        select 1 from public.photo_reports r
        where r.photo_id = c.photo_id and r.status in ('open', 'held'))
    order by c.next_attempt_at
    limit greatest(1, least(p_limit, 200))
    for update skip locked
  )
  returning j.*;
$$;

-- ---------------------------------------------------------------------------
-- For the app owner (service role / SQL editor only)
-- ---------------------------------------------------------------------------

-- Only what was reported: no access to the rest of the group.
create function public.photo_report_queue()
returns table (
  report_id uuid,
  reported_at timestamptz,
  reason text,
  status text,
  still_visible boolean,
  storage_path text,
  caption text,
  reporter_id uuid,
  reporter_name text,
  uploader_id uuid,
  uploader_name text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    r.id,
    r.created_at,
    r.reason,
    r.status,
    exists (select 1 from public.photos p where p.id = r.photo_id and p.status = 'active'),
    r.storage_path,
    r.caption,
    r.reporter_id,
    rp.display_name::text,
    r.uploader_id,
    up.display_name::text
  from public.photo_reports r
  left join public.profiles rp on rp.id = r.reporter_id
  left join public.profiles up on up.id = r.uploader_id
  where r.status in ('open', 'held')
  order by (r.reason = 'child') desc, r.created_at;
$$;

-- 'dismiss': nothing wrong; it stays hidden for the reporter only.
-- 'hold':    remove it for everyone now but keep the files (for the police).
-- 'remove':  remove it for everyone and let the files be erased.
create function public.resolve_photo_report(p_report_id uuid, p_action text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_report public.photo_reports;
  v_photo public.photos;
begin
  if p_action is null or p_action not in ('dismiss', 'hold', 'remove') then
    raise exception 'closer:invalid_action' using errcode = 'P0001';
  end if;

  -- Photo first, then report: the same lock order as report_photo.
  select * into v_report from public.photo_reports r where r.id = p_report_id;
  if not found then
    raise exception 'closer:report_not_found' using errcode = 'P0001';
  end if;
  select * into v_photo from public.photos p where p.id = v_report.photo_id for update;
  select * into v_report from public.photo_reports r where r.id = p_report_id for update;

  if v_report.status not in ('open', 'held') then
    raise exception 'closer:report_closed' using errcode = 'P0001';
  end if;

  if p_action = 'dismiss' then
    if v_report.status = 'held' then
      raise exception 'closer:report_held' using errcode = 'P0001';
    end if;
    update public.photo_reports
      set status = 'dismissed', resolved_at = now(), caption = null
      where id = p_report_id;
    return;
  end if;

  if v_photo.status = 'active' then
    update public.photos
      set status = 'removed', removed_at = now(), removed_reason = 'deleted'
      where id = v_photo.id;
    perform public.enqueue_photo_cleanup(v_photo, 'reported');
  end if;

  -- Removing a photo settles every report about it.
  if p_action = 'hold' then
    update public.photo_reports r
      set status = 'held'
      where r.photo_id = v_report.photo_id and r.status in ('open', 'held');
  else
    update public.photo_reports r
      set status = 'removed', resolved_at = now(), caption = null
      where r.photo_id = v_report.photo_id and r.status in ('open', 'held');
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Privileges (`create or replace` keeps those of the replaced functions)
-- ---------------------------------------------------------------------------

revoke all on function
  public.has_reported(uuid),
  public.group_photo_count(uuid),
  public.report_photo(uuid, text),
  public.photo_report_queue(),
  public.resolve_photo_report(uuid, text)
from public, anon, authenticated;

grant execute on function
  public.has_reported(uuid),
  public.group_photo_count(uuid),
  public.report_photo(uuid, text)
to authenticated;

grant execute on function
  public.photo_report_queue(),
  public.resolve_photo_report(uuid, text)
to service_role;
