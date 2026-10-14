-- Closer — Phase 3: photos, private storage, Basic retention, Premium entitlements,
-- purchase records and a durable storage-cleanup queue.
--
-- Upload protocol (keeps PostgreSQL and Storage consistent):
--   1. request_photo_upload()  → creates a `pending` photo row with fixed object paths.
--                               Idempotent per (uploader, client_upload_id).
--   2. client uploads original + thumbnail to the private `photos` bucket. Storage RLS
--      only accepts objects whose path belongs to the caller's pending photo.
--   3. finalize_photo()         → verifies both objects exist, marks the photo `active`,
--                               then (Basic groups only) removes the oldest eligible
--                               active photos above the limit and queues their objects
--                               for deletion. Runs under a per-group row lock.
-- A failed or abandoned upload never touches existing photos: retention only runs in
-- step 3, after the new photo is safely stored. Abandoned pending rows are expired by
-- expire_stale_uploads() and their objects queued for cleanup.
--
-- Storage objects are deleted only by the `cleanup-storage` Edge Function (service
-- role) working through storage_cleanup_jobs with leases, retries and backoff.

-- ---------------------------------------------------------------------------
-- Configuration
-- ---------------------------------------------------------------------------

create function public.basic_photo_limit()
returns integer
language sql
immutable
set search_path = ''
as $$ select 10 $$;

-- Days a refunded/revoked Premium group keeps Premium behaviour.
create function public.premium_grace_days()
returns integer
language sql
immutable
set search_path = ''
as $$ select 30 $$;

-- ---------------------------------------------------------------------------
-- Private storage bucket
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('photos', 'photos', false, 15 * 1024 * 1024, array['image/jpeg'])
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- ---------------------------------------------------------------------------
-- Photos
-- ---------------------------------------------------------------------------

create type public.photo_status as enum ('pending', 'active', 'removed');
create type public.photo_removal_reason as enum (
  'retention', 'deleted', 'upload_abandoned', 'group_deleted'
);

create table public.photos (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id) on delete cascade,
  -- Keep the photo for the group if the uploader deletes their account.
  uploader_id uuid references public.profiles (id) on delete set null,
  client_upload_id uuid not null,
  storage_path text not null unique,
  thumb_path text not null unique,
  caption text check (caption is null or char_length(caption) <= 500),
  -- When the photo was taken (from EXIF or chosen by the user); may be null.
  taken_at timestamptz,
  width integer check (width is null or width between 1 and 20000),
  height integer check (height is null or height between 1 and 20000),
  byte_size integer check (byte_size is null or byte_size between 1 and 15728640),
  status public.photo_status not null default 'pending',
  created_at timestamptz not null default now(),
  -- When the upload was finalized (null while pending).
  uploaded_at timestamptz,
  removed_at timestamptz,
  removed_reason public.photo_removal_reason,
  is_pinned boolean not null default false,
  constraint photos_client_upload_unique unique (uploader_id, client_upload_id),
  constraint photos_active_has_upload_time check (status <> 'active' or uploaded_at is not null),
  constraint photos_removed_has_reason check (
    (status = 'removed') = (removed_at is not null and removed_reason is not null)
  )
);

create index photos_group_active_idx
  on public.photos (group_id, uploaded_at desc, id desc)
  where status = 'active';
create index photos_pending_idx on public.photos (created_at) where status = 'pending';

-- ---------------------------------------------------------------------------
-- Entitlements and purchases
-- ---------------------------------------------------------------------------

create type public.entitlement_status as enum ('active', 'revoked');

-- Authoritative Premium state per group. Written only by trusted code.
create table public.group_entitlements (
  group_id uuid primary key references public.groups (id) on delete cascade,
  tier text not null default 'memories' check (tier = 'memories'),
  status public.entitlement_status not null default 'active',
  granted_at timestamptz not null default now(),
  revoked_at timestamptz,
  -- Premium behaviour continues until this instant after a revocation.
  grace_until timestamptz,
  purchase_id uuid,
  updated_at timestamptz not null default now()
);

create table public.purchase_records (
  id uuid primary key default gen_random_uuid(),
  store text not null check (store in ('app_store', 'play_store', 'test')),
  product_id text not null check (char_length(product_id) <= 200),
  transaction_id text not null check (char_length(transaction_id) <= 200),
  user_id uuid references public.profiles (id) on delete set null,
  group_id uuid references public.groups (id) on delete set null,
  status text not null default 'verified' check (status in ('verified', 'refunded')),
  purchased_at timestamptz not null default now(),
  refunded_at timestamptz,
  created_at timestamptz not null default now(),
  -- Idempotency: one record per store transaction.
  constraint purchase_records_transaction_unique unique (store, transaction_id)
);

create index purchase_records_user_idx on public.purchase_records (user_id);
create index purchase_records_group_idx on public.purchase_records (group_id);

-- Premium if entitled, or still inside the grace period after revocation.
create function public.is_group_premium(p_group_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.group_entitlements e
    where e.group_id = p_group_id
      and (e.status = 'active' or (e.grace_until is not null and e.grace_until > now()))
  );
$$;

-- ---------------------------------------------------------------------------
-- Storage cleanup queue (durable; survives failures and retries safely)
-- ---------------------------------------------------------------------------

create table public.storage_cleanup_jobs (
  id bigint generated always as identity primary key,
  bucket_id text not null default 'photos',
  object_path text not null,
  -- Kept without a foreign key so jobs outlive the group/photo they came from.
  group_id uuid,
  photo_id uuid,
  reason text not null,
  status text not null default 'queued' check (status in ('queued', 'running', 'done', 'dead')),
  attempts integer not null default 0,
  next_attempt_at timestamptz not null default now(),
  lease_until timestamptz,
  last_error text check (last_error is null or char_length(last_error) <= 500),
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  constraint storage_cleanup_jobs_unique unique (bucket_id, object_path)
);

create index storage_cleanup_jobs_due_idx
  on public.storage_cleanup_jobs (next_attempt_at)
  where status in ('queued', 'running');

create function public.enqueue_photo_cleanup(
  p_photo public.photos,
  p_reason text
)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.storage_cleanup_jobs (object_path, group_id, photo_id, reason)
  values (p_photo.storage_path, p_photo.group_id, p_photo.id, p_reason),
         (p_photo.thumb_path, p_photo.group_id, p_photo.id, p_reason)
  on conflict (bucket_id, object_path) do update
    set status = case when public.storage_cleanup_jobs.status = 'done'
                      then 'queued' else public.storage_cleanup_jobs.status end,
        next_attempt_at = least(public.storage_cleanup_jobs.next_attempt_at, now());
$$;

-- Claims up to p_limit due jobs for one worker. SKIP LOCKED lets several
-- workers run safely; the lease returns a job to the queue if a worker dies.
create function public.claim_cleanup_jobs(p_limit integer default 50)
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
    where (c.status = 'queued' and c.next_attempt_at <= now())
       or (c.status = 'running' and c.lease_until < now())
    order by c.next_attempt_at
    limit greatest(1, least(p_limit, 200))
    for update skip locked
  )
  returning j.*;
$$;

-- Records the outcome of a claimed job. Failures back off exponentially
-- (1, 2, 4 … minutes, capped at 6 hours); after 10 attempts a job is 'dead'
-- and kept for inspection.
create function public.complete_cleanup_job(
  p_job_id bigint,
  p_success boolean,
  p_error text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_attempts integer;
begin
  select attempts into v_attempts from public.storage_cleanup_jobs where id = p_job_id for update;
  if not found then
    return;
  end if;
  if p_success then
    update public.storage_cleanup_jobs
      set status = 'done', completed_at = now(), lease_until = null, last_error = null
      where id = p_job_id;
  else
    update public.storage_cleanup_jobs
      set status = case when v_attempts >= 10 then 'dead' else 'queued' end,
          lease_until = null,
          last_error = left(coalesce(p_error, 'unknown error'), 500),
          next_attempt_at = now() + least(
            interval '6 hours',
            make_interval(mins => power(2, greatest(v_attempts - 1, 0))::integer)
          )
      where id = p_job_id;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Retention
-- ---------------------------------------------------------------------------

-- Removes the oldest active photos above the Basic limit. Caller must hold the
-- group row lock. Pinned photos are never chosen while another photo is
-- eligible; Premium groups are never trimmed. Returns removed photo ids.
create function public.apply_retention(p_group_id uuid)
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
  if public.is_group_premium(p_group_id) then
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

-- ---------------------------------------------------------------------------
-- Upload functions
-- ---------------------------------------------------------------------------

create function public.request_photo_upload(
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

-- Makes an uploaded photo visible and applies Basic retention atomically.
create function public.finalize_photo(p_photo_id uuid)
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

-- Removes a photo (uploader or group owner). Storage objects are queued.
create function public.delete_photo(p_photo_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := public.require_user();
  v_photo public.photos;
begin
  select * into v_photo from public.photos p where p.id = p_photo_id for update;
  if not found or v_photo.status = 'removed' or not public.is_group_member(v_photo.group_id) then
    raise exception 'closer:photo_not_found' using errcode = 'P0001';
  end if;
  if v_photo.uploader_id is distinct from v_uid and not public.is_group_owner(v_photo.group_id) then
    raise exception 'closer:not_allowed' using errcode = 'P0001';
  end if;
  update public.photos
    set status = 'removed', removed_at = now(), removed_reason = 'deleted'
    where id = v_photo.id;
  perform public.enqueue_photo_cleanup(v_photo, 'deleted');
end;
$$;

-- Pin/unpin (Premium feature; pinned photos are also protected from retention).
create function public.set_photo_pinned(p_photo_id uuid, p_pinned boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_photo public.photos;
begin
  perform public.require_user();
  select * into v_photo from public.photos p where p.id = p_photo_id;
  if not found or v_photo.status <> 'active' or not public.is_group_member(v_photo.group_id) then
    raise exception 'closer:photo_not_found' using errcode = 'P0001';
  end if;
  if p_pinned and not public.is_group_premium(v_photo.group_id) then
    raise exception 'closer:premium_required' using errcode = 'P0001';
  end if;
  update public.photos set is_pinned = p_pinned where id = p_photo_id;
end;
$$;

-- Expires uploads that were never finalized (trusted maintenance).
create function public.expire_stale_uploads(p_older_than interval default interval '24 hours')
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
-- Entitlement functions (service role only: called by verified purchase flows)
-- ---------------------------------------------------------------------------

-- Idempotent: the same (store, transaction) grants once.
create function public.grant_group_entitlement(
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
  v_created boolean := false;
begin
  if not exists (select 1 from public.groups g where g.id = p_group_id) then
    raise exception 'closer:group_not_found' using errcode = 'P0001';
  end if;
  if not exists (select 1 from public.group_members m
                 where m.group_id = p_group_id and m.user_id = p_user_id) then
    raise exception 'closer:not_a_member' using errcode = 'P0001';
  end if;

  insert into public.purchase_records
    (store, product_id, transaction_id, user_id, group_id, purchased_at)
  values (p_store, p_product_id, p_transaction_id, p_user_id, p_group_id, p_purchased_at)
  on conflict (store, transaction_id) do nothing
  returning * into v_purchase;
  v_created := v_purchase.id is not null;

  if not v_created then
    select * into v_purchase from public.purchase_records r
    where r.store = p_store and r.transaction_id = p_transaction_id;
    if v_purchase.group_id is distinct from p_group_id then
      raise exception 'closer:transaction_already_used' using errcode = 'P0001';
    end if;
    return jsonb_build_object('status', 'already_granted', 'purchase_id', v_purchase.id);
  end if;

  insert into public.group_entitlements (group_id, status, granted_at, purchase_id)
  values (p_group_id, 'active', now(), v_purchase.id)
  on conflict (group_id) do update
    set status = 'active', revoked_at = null, grace_until = null,
        purchase_id = excluded.purchase_id, updated_at = now();

  return jsonb_build_object('status', 'granted', 'purchase_id', v_purchase.id);
end;
$$;

-- Refund/revocation: Premium continues through the grace period, photos are
-- never deleted at revocation time. After grace, Basic retention applies on
-- the next upload. Idempotent.
create function public.revoke_group_entitlement(p_store text, p_transaction_id text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_purchase public.purchase_records;
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

  update public.group_entitlements e
    set status = 'revoked', revoked_at = now(),
        grace_until = now() + make_interval(days => public.premium_grace_days()),
        updated_at = now()
    where e.group_id = v_purchase.group_id and e.purchase_id = v_purchase.id;

  return jsonb_build_object('status', 'revoked');
end;
$$;

-- ---------------------------------------------------------------------------
-- Any group deletion (delete_group, last member leaving, account deletion)
-- queues the group's photo objects before the rows cascade away.
-- ---------------------------------------------------------------------------

create function public.before_group_delete()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_photo public.photos;
begin
  for v_photo in select * from public.photos p where p.group_id = old.id loop
    perform public.enqueue_photo_cleanup(v_photo, 'group_deleted');
  end loop;
  return old;
end;
$$;

create trigger groups_before_delete_cleanup
  before delete on public.groups
  for each row execute function public.before_group_delete();

-- ---------------------------------------------------------------------------
-- Read models
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
  (select p.thumb_path from public.photos p
    where p.group_id = g.id and p.status = 'active'
    order by p.uploaded_at desc, p.id desc limit 1) as latest_thumb_path
from public.groups g;

-- ---------------------------------------------------------------------------
-- RLS and privileges
-- ---------------------------------------------------------------------------

alter table public.photos enable row level security;
alter table public.group_entitlements enable row level security;
alter table public.purchase_records enable row level security;
alter table public.storage_cleanup_jobs enable row level security;

revoke all on public.photos, public.group_entitlements, public.purchase_records,
  public.storage_cleanup_jobs from anon, authenticated;

grant select on public.photos to authenticated;
grant update (caption, taken_at) on public.photos to authenticated;
grant select (group_id, tier, status, granted_at, revoked_at, grace_until)
  on public.group_entitlements to authenticated;
grant select (id, store, product_id, group_id, status, purchased_at, refunded_at)
  on public.purchase_records to authenticated;

create policy "photos: members read active photos"
  on public.photos for select to authenticated
  using (status = 'active' and public.is_group_member(group_id));

create policy "photos: uploader edits caption and date"
  on public.photos for update to authenticated
  using (status = 'active' and uploader_id = (select auth.uid())
         and public.is_group_member(group_id))
  with check (status = 'active' and uploader_id = (select auth.uid()));

create policy "group_entitlements: members read"
  on public.group_entitlements for select to authenticated
  using (public.is_group_member(group_id));

create policy "purchase_records: purchaser reads own"
  on public.purchase_records for select to authenticated
  using (user_id = (select auth.uid()));

-- storage_cleanup_jobs: no client access.

-- Storage object access, decided by trusted helpers.
create function public.can_read_photo_object(p_name text)
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
  );
$$;

create function public.can_upload_photo_object(p_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.photos p
    where (p.storage_path = p_name or p.thumb_path = p_name)
      and p.status = 'pending'
      and p.uploader_id = (select auth.uid())
      and public.is_group_member(p.group_id)
  );
$$;

create policy "photos bucket: members read active photos"
  on storage.objects for select to authenticated
  using (bucket_id = 'photos' and public.can_read_photo_object(name));

create policy "photos bucket: uploader writes pending objects"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'photos' and public.can_upload_photo_object(name));

-- No update/delete policies on the bucket: clients can never overwrite or delete
-- objects. Deletion happens only through the cleanup queue (service role).

revoke all on public.group_summaries from anon, authenticated;
grant select on public.group_summaries to authenticated;

-- Function privileges.
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
  public.is_group_member(uuid),
  public.is_group_owner(uuid),
  public.shares_group_with(uuid),
  public.is_group_premium(uuid),
  public.can_read_photo_object(text),
  public.can_upload_photo_object(text)
to authenticated;

-- Trusted maintenance and purchase functions: service role only.
grant execute on function
  public.claim_cleanup_jobs(integer),
  public.complete_cleanup_job(bigint, boolean, text),
  public.expire_stale_uploads(interval),
  public.grant_group_entitlement(uuid, uuid, text, text, text, timestamptz),
  public.revoke_group_entitlement(text, text)
to service_role;
