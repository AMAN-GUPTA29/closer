# Database

Supabase Postgres 17. Migrations live in `supabase/migrations/` and are applied in filename order.

| Migration | Phase | Contents |
|---|---|---|
| `20261014000001_core_groups.sql` | 2 | profiles, groups, memberships, invitations, RLS, trusted functions |
| `20261014000003_journal_milestones_notifications.sql` | 4 | milestones, journal feed RPC, chosen covers, avatars bucket, notifications + preferences, account-deletion helper |
| `20261014000002_photos_retention_entitlements.sql` | 3 | private `photos` bucket + storage policies, photos, retention, entitlements, purchases, cleanup queue |

## Running locally

Requires Docker (Docker Desktop on Windows) and the Supabase CLI (`npx supabase@2.120.0 …` works without installing).

```bash
npx supabase@2.120.0 db start        # Postgres only, applies all migrations
npx supabase@2.120.0 test db         # pgTAP suites in supabase/tests/database
DB_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres \
  bash supabase/tests/concurrency/couple_capacity.sh
npx supabase@2.120.0 db lint --level warning
npx supabase@2.120.0 db reset        # re-apply migrations from scratch
```

The **Database tests** job in `.github/workflows/ci.yml` runs exactly these steps on every push.

### Applying to a hosted project (owner action, needs credentials)

```bash
npx supabase@2.120.0 login                      # opens a browser
npx supabase@2.120.0 link --project-ref <ref>   # asks for the DB password
npx supabase@2.120.0 db push                    # applies pending migrations
```

There is no seed data: users and groups are created through the app.

## Schema (Phase 2)

| Table | Key columns | Notes |
|---|---|---|
| `profiles` | `id` → `auth.users` (cascade), `display_name` 1–40, `avatar_path` | Created by trigger `on_auth_user_created` from sign-up metadata (`display_name`) or the email local part |
| `groups` | `id`, `name` 1–60 (trimmed), `type` (`couple`/`friends`/`family`), `created_by`, `cover_path`, `relationship_start_date date`, `show_relationship_counter`, `created_at`, `updated_at`, `last_activity_at` | Check: only couples have a start date |
| `group_members` | PK (`group_id`, `user_id`), `role` (`owner`/`member`), `joined_at` | `user_id` → `profiles` (cascade) so PostgREST can embed profiles; unique partial index = one owner per group |
| `invitations` | `id`, `group_id`, `code_hash` (unique), `token_hash` (unique), `code_hint` (last 2 chars), `created_by`, `expires_at`, `revoked_at`, `max_redemptions`, `redemption_count` | Plaintext code/token never stored |
| `invitation_redemptions` | PK (`invitation_id`, `user_id`), `group_id`, `redeemed_at` | Audit of joins |
| `invitation_attempts` | `user_id`, `attempted_at` | Failed lookups for rate limiting; not client-readable |
| view `group_summaries` | group columns + `member_count`, `my_role` | `security_invoker`, so RLS applies |

### Triggers

- `group_members_capacity` (before insert): locks the group row (`for update`) and rejects the insert with `closer:group_full` when a couple already has 2 members. Because the lock serialises concurrent joins per group, the cap holds under concurrency, and it also applies to trusted/service inserts.
- `group_members_after_delete`: if the group lost its last member → delete the group; if it lost its owner → promote the longest-standing member. Covers leaving, removal and account deletion, so no orphaned or ownerless groups.
- `touch_updated_at` on `profiles` and `groups`.

## Trusted functions (security definer, `search_path = ''`)

| Function | Who | Behaviour |
|---|---|---|
| `create_group(name, type, start_date?)` | signed-in | Creates group + owner membership atomically; rejects start dates for non-couples and future dates |
| `create_invitation(group, expires_in_hours = 168, max_redemptions?)` | any member | Returns `code`, `token`, `expires_at` **once**. 1 h – 90 days or `null` = no expiry. Couples: limited to the free seat(s); full couple → `closer:group_full` |
| `revoke_invitation(id)` | owner or the invitation's creator | Sets `revoked_at` |
| `preview_invitation(secret)` | signed-in | Returns `status` + group name/type/size/start date. No group id unless already a member, no photos, no member list |
| `redeem_invitation(secret)` | signed-in | Locks the invitation row, checks status, inserts membership (capacity trigger), records redemption, increments count. Returns `joined` / `already_member` / `invalid` / `expired` / `revoked` / `exhausted` / `full` / `rate_limited` |
| `leave_group(group)` | member | Delete own membership; trigger hands over or deletes |
| `transfer_ownership(group, user)` | owner | New owner must be a member; old owner becomes member |
| `remove_member(group, user)` | owner | Cannot remove self (use leave) |
| `delete_group(group)` | owner | Cascades memberships, invitations, redemptions |

`secret` is either the 8-character code (any case, spaces/dashes ignored) or the link token.

**Rate limiting:** 10 failed lookups per user per 15 minutes; afterwards preview/redeem return `rate_limited`, even for valid codes.

**Codes:** 8 characters from `ABCDEFGHJKMNPQRSTUVWXYZ23456789` (31 symbols, no 0/O/1/I/L; uniform by rejection sampling) ≈ 8.5 × 10¹¹ combinations. **Tokens:** 24 random bytes, URL-safe base64. Both hashed with SHA-256.

## Schema (Phase 3)

| Table | Key columns | Notes |
|---|---|---|
| `photos` | `id`, `group_id`, `uploader_id` → profiles (set null), `client_upload_id`, `storage_path`, `thumb_path`, `caption` ≤ 500, `taken_at`, `uploaded_at`, `width`, `height`, `byte_size`, `status` (`pending`/`active`/`removed`), `removed_at`, `removed_reason`, `is_pinned` | Unique `(uploader_id, client_upload_id)` = duplicate-submit protection. Keyset index on `(group_id, uploaded_at desc, id desc)` for active photos |
| `group_entitlements` | `group_id` PK, `tier`, `status`, `granted_at`, `revoked_at`, `grace_until`, `purchase_id` | Authoritative Premium; members read, nobody writes from clients |
| `purchase_records` | `id`, `store`, `product_id`, `transaction_id`, `user_id`, `group_id`, `status`, `purchased_at`, `refunded_at` | Unique `(store, transaction_id)` = idempotency |
| `storage_cleanup_jobs` | `object_path`, `group_id`, `photo_id`, `reason`, `status`, `attempts`, `next_attempt_at`, `lease_until`, `last_error` | Durable deletion queue; no client access |
| storage bucket `photos` | private, 15 MB, `image/jpeg` only | Paths: `<group_id>/<photo_id>/original.jpg` and `thumb.jpg` |

`group_summaries` gained `photo_count`, `is_premium` and `latest_thumb_path` (cover).

Photo functions: `request_photo_upload`, `finalize_photo`, `delete_photo`, `set_photo_pinned`
(signed-in members); `expire_stale_uploads`, `claim_cleanup_jobs`, `complete_cleanup_job`,
`grant_group_entitlement`, `revoke_group_entitlement` (service role only). Behaviour and the
upload protocol are described in `docs/purchases-and-retention.md`.

## Schema (Phase 4)

| Table / object | Key columns | Notes |
|---|---|---|
| `milestones` | `id`, `group_id`, `created_by` (defaults to `auth.uid()`), `title` 1–80, `type`, `event_date date`, `description` ≤ 1000, `cover_photo_id`, `theme` (`heart`/`celebration`/`neutral`), `is_pinned` | Members create; creator or owner edits/deletes (RLS + column grants). Cover must be an active photo of the same group (trigger) |
| `groups.cover_photo_id` | photo chosen by the owner via `set_group_cover` | `group_summaries.latest_thumb_path` prefers it over the newest photo |
| `notifications` | `user_id`, `group_id`, `actor_id`, `kind` (`photo_added`/`member_joined`/`milestone_added`), `photo_id`, `milestone_id`, `created_at`, `read_at` | Written only by triggers; recipients read their own; unique per event+recipient; **no captions** |
| `notification_preferences` | `user_id`, `photos`, `members`, `milestones` | Own row only |
| storage bucket `avatars` | private, 2 MB JPEG, `<user_id>/<random>.jpg` | Readable by the user and people who share a group; set through `set_avatar` (old file queued for cleanup) |

**References to removed photos (§13.14):** trigger `photos_after_removed` clears
`milestones.cover_photo_id` and `groups.cover_photo_id` whenever a photo stops being active
(user deletion or Basic retention), so nothing points at a missing photo (tested).

**Journal:** `journal_entries(group?, before_at?, before_id?, limit)` (SECURITY INVOKER, so RLS
applies) returns active photos and milestones dated today or earlier, newest first, keyset
paginated on `(occurred_at, id)`. Photos use `coalesce(taken_at, uploaded_at)`; milestones the end
of their calendar day. Future milestones appear only in the Milestones tab (countdowns).

**Notifications fan-out:** triggers on photo activation, member join (role `member`) and milestone
insert call `notify_group`, which skips the actor and respects preferences. Leaving a group deletes
that group's notifications for the leaver.

**Account deletion:** Edge Function `delete-account` (caller identified by their own JWT, typed
"DELETE" confirmation) → `prepare_account_deletion` (queues avatar) → `auth.admin.deleteUser`.
Cascades remove the profile, memberships (ownership hand-over / empty-group deletion),
notifications and preferences; shared photos and milestones stay with their groups with a null
uploader/creator (tested).

## Schema (Phase 5)

Migration `20261014000004_push_reminders_purchases_realtime.sql`:

| Object | Notes |
|---|---|
| `device_registrations` (`token` unique, `user_id`, `platform`, `app_version`, `last_seen_at`) | Written only through `register_device` / `unregister_device`. A token moves to the newest user. At most 10 per user |
| `notification_preferences.push`, `.reminders` | Own row only |
| `notification_kind` value `milestone_upcoming` | Created by `enqueue_milestone_reminders(date)` (daily job, idempotent) |
| `notifications.push_status/attempts/next_at/lease_until` | Hidden from clients (column grants). Rows from before Phase 5 are marked `skipped` so old activity is never pushed |
| `claim_push_batch(limit)` / `complete_push(id, outcome, invalid_tokens)` | Service role only. Leased with `skip locked`, backoff 1, 2, 4 … min, `failed` after 6 attempts |
| `purchase_records.status` adds `unassigned` | `record_store_purchase` (webhook) stores purchases whose group is not known yet. `grant_group_entitlement` assigns them later; it raises `closer:purchase_refunded` / `closer:transaction_already_used` |
| Realtime publication | `photos`, `milestones`, `notifications`, `group_members` (RLS applies to subscribers) |

pgTAP: `006_push_reminders_purchases.test.sql`.

## Date and time policy

- Instants are `timestamptz`; calendar dates (relationship start) are `date`, with no time zone.
- Photos keep `taken_at` (capture time from EXIF or chosen by the uploader, optional) separate
  from `uploaded_at` (when it was shared). Journal cards show `taken_at` when known.
- "Days together" = calendar days in the device's local time zone **including the start date** (start date = day 1). Future start dates are rejected. Owners can correct the date in Group settings.

## Error contract

Functions raise `P0001` with message `closer:<key>`; the app maps keys to friendly text (`lib/core/errors/backend_errors.dart`). Redeem/preview return statuses instead of raising, so failed attempts are recorded for rate limiting.
