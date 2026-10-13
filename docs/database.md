# Database

**Status:** Phase 1 — no migrations yet. Supabase Auth is the only backend piece used.
The schema below is the plan for Phase 2–5 and will be replaced with the real migration
details as each table lands.

## Conventions (all phases)

- Migrations in `supabase/migrations/<timestamp>_<name>.sql`, applied with the Supabase CLI.
- `timestamptz` for instants, `date` for calendar dates, `uuid` primary keys.
- Foreign keys with explicit `on delete` rules; unique and check constraints; indexes for every
  access path used by RLS and pagination.
- RLS enabled on every table holding private data; trusted operations as `security definer`
  functions with a fixed `search_path`, or Edge Functions using the service role.

## Planned entities

| Table | Phase | Purpose |
|---|---|---|
| `profiles` | 2 | display name, avatar path; 1:1 with `auth.users` |
| `groups` | 2 | name, type, creator, cover, relationship start date, settings |
| `group_members` | 2 | unique (group, user), role, joined_at; couple cap enforced atomically |
| `invitations` | 2 | group, token hash, code, expiry, revoked_at, max/used redemptions |
| `invitation_redemptions` | 2 | audit of redemptions |
| `photos` | 3 | group, uploader, storage paths, caption, taken_at, uploaded_at, status |
| `storage_cleanup_jobs` | 3 | durable retry queue for storage deletions |
| `group_entitlements` | 3 | authoritative Premium state per group |
| `purchase_records` | 3/5 | verified store transactions, idempotency keys |
| `milestones` | 4 | title, type, event date, description, cover photo (nullable FK), theme, pinned |
| `notifications`, `notification_preferences` | 4/5 | in-app feed and preferences |
| `device_registrations` | 5 | push tokens per user/device |

## Migration & seeding commands

Documented in Phase 2 once `supabase/` exists.
