-- A pass that ends never causes automatic photo deletion (owner decision
-- 2026-11-23, ISSUES E15). For a group that has had a pass, including one
-- that was refunded:
--
--   * for premium_grace_days (30) after it ends nothing changes, and the app
--     warns the members;
--   * after that the group is "pass ended": every photo stays, and new photos
--     are accepted only while it has fewer than basic_photo_limit (10);
--   * photos above the limit wait in photo_deletion_queue() for the app
--     owner's approval. Nothing here deletes them. Renewing takes the group
--     out of the queue.
--
-- Groups that never had a pass keep the Basic rule (the newest 10 stay).
-- A group "had a pass" when it has a group_entitlements row: rows are written
-- only by verified purchases. The one reason to delete a row is the app
-- owner's approval (interface to be built): that turns the group into a
-- normal unpaid group. purchase_records keep the history.

-- Retention only ever trims groups that never had a pass.
create or replace function public.apply_retention(p_group_id uuid)
returns uuid[]
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_excess integer;
  v_removed uuid[] := '{}';
  v_photo public.photos;
begin
  if exists (select 1 from public.group_entitlements e where e.group_id = p_group_id) then
    return v_removed;
  end if;

  select count(*) - public.basic_photo_limit() into v_excess
  from public.photos p
  where p.group_id = p_group_id and p.status = 'active';

  if v_excess <= 0 then
    return v_removed;
  end if;

  for v_photo in
    select * from public.photos p
    where p.group_id = p_group_id and p.status = 'active'
    order by p.is_pinned, p.uploaded_at, p.id
    limit v_excess
    for update
  loop
    update public.photos
      set status = 'removed', removed_at = now(), removed_reason = 'retention'
      where id = v_photo.id;
    perform public.enqueue_photo_cleanup(v_photo, 'retention');
    v_removed := v_removed || v_photo.id;
  end loop;

  return v_removed;
end;
$$;

-- Raises when a group whose pass ended has no room for another photo.
create function public.assert_upload_allowed(p_group_id uuid)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if exists (select 1 from public.group_entitlements e where e.group_id = p_group_id)
     and not public.is_group_premium(p_group_id)
     and (select count(*) from public.photos p
          where p.group_id = p_group_id and p.status = 'active') >= public.basic_photo_limit()
  then
    raise exception 'closer:renewal_required' using errcode = 'P0001';
  end if;
end;
$$;

-- Same as before, plus the check for new uploads, so nothing is sent to
-- storage only to be refused.
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

-- Same as before, plus the check under the group lock: an upload can start
-- before a pass ends and finish after, and several can finish at once.
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

-- Groups waiting for the app owner's decision (service role / SQL editor
-- only). Derived on every call, so a renewal or a manual delete is reflected
-- at once. Whatever deletes after an approval must check this again while
-- holding the group lock. Counts and sizes only: no photo content.
create function public.photo_deletion_queue()
returns table (
  group_id uuid,
  group_name text,
  photo_count integer,
  photos_over_limit integer,
  storage_bytes bigint,
  pass_ended_at timestamptz,
  waiting_since timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    g.id,
    g.name::text,
    c.n,
    c.n - public.basic_photo_limit(),
    coalesce((
      select sum((o.metadata ->> 'size')::bigint)
      from public.photos p
      join storage.objects o
        on o.bucket_id = 'photos' and o.name in (p.storage_path, p.thumb_path)
      where p.group_id = g.id and p.status = 'active'
    ), 0)::bigint,
    case when e.status = 'revoked' then e.revoked_at else e.expires_at end,
    case when e.status = 'revoked' then e.grace_until
         else e.expires_at + make_interval(days => public.premium_grace_days()) end
  from public.group_entitlements e
  join public.groups g on g.id = e.group_id
  cross join lateral (
    select count(*)::integer as n from public.photos p
    where p.group_id = g.id and p.status = 'active'
  ) c
  where c.n > public.basic_photo_limit()
    and not public.is_group_premium(g.id)
  order by 7, 1;
$$;

-- Read model. A refunded pass ends when it was revoked, so that date + 30
-- days is always the last day of grace. `pass_ended` is appended.
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
  (select case when e.status = 'revoked' then e.revoked_at else e.expires_at end
    from public.group_entitlements e
    where e.group_id = g.id) as premium_expires_at,
  (exists (select 1 from public.group_entitlements e where e.group_id = g.id)
    and not public.is_group_premium(g.id)) as pass_ended
from public.groups g;

revoke all on public.group_summaries from anon, authenticated;
grant select on public.group_summaries to authenticated;

-- `create or replace` keeps the grants of the replaced functions.
revoke all on function public.assert_upload_allowed(uuid) from public, anon, authenticated;
revoke all on function public.photo_deletion_queue() from public, anon, authenticated;
grant execute on function public.photo_deletion_queue() to service_role;
