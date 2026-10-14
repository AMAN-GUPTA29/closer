# Security

## Principles

- The client is never trusted for membership, roles, group capacity, photo counts or Premium.
- Private data is protected by Postgres Row Level Security plus trusted server code.
- Photo storage buckets are private; access through authenticated requests or short-lived signed URLs.
- Push payloads carry only identifiers; the app fetches authoritative data.
- Logs never include captions, photos, tokens, passwords or secrets.

## Secrets handling

| Value | Where it lives | In the app? |
|---|---|---|
| Supabase URL, publishable/anon key | `.env` locally, GitHub repo *variables* in CI | Yes (client-safe by design) |
| Supabase service-role key | Supabase Edge Function secrets / GitHub Secrets | **Never** |
| `CLAUDE_CODE_OAUTH_TOKEN` | GitHub Secret | Never |
| Store / RevenueCat secrets, APNs key, FCM service account, signing keys | GitHub Secrets / Codemagic / Supabase secrets | Never |

`.gitignore` blocks `.env*` (except `.env.example`), keystores, `key.properties`, `*.p8`, `*.p12`,
provisioning profiles, `google-services.json`, `GoogleService-Info.plist`, service-account JSON.

## Row Level Security (Phase 2)

Every table in `public` has RLS enabled (a pgTAP test fails otherwise). Grants start from
nothing (`revoke all ... from anon, authenticated`) and add only what is needed.

| Table | anon | authenticated |
|---|---|---|
| `profiles` | none | read self + people who share a group; update own `display_name`, `avatar_path` only |
| `groups` | none | read groups you belong to; owner may update `name`, `cover_path`, `relationship_start_date`, `show_relationship_counter` only |
| `group_members` | none | read memberships of your groups; delete your own row (leave) |
| `invitations` | none | members read non-secret columns (`code_hash`/`token_hash` are not granted) |
| `invitation_redemptions` | none | members read |
| `invitation_attempts` | none | none |
| `group_summaries` (view) | none | read (security_invoker, so table RLS applies) |

All membership, role and invitation changes go through security-definer functions that check
`auth.uid()` themselves (see `docs/database.md`). Function `EXECUTE` is revoked from `anon` and `public`.

### Invitations
- Group-scoped; redeeming grants access to that group only (tested).
- Code and link token stored as SHA-256 hashes and shown to the creator once. Members see a 2-character hint.
- Expiry, revocation, use limits, couple capacity and duplicate redemption are enforced server-side.
- Failed lookups are rate limited (10 per 15 minutes per user) to make code guessing impractical.
- Preview reveals only the group name, type, member count and couple start date: never photos,
  member names or the group id.
- Links use the custom scheme `com.closerapp.closer://invite?t=...`. Any app could register the same
  scheme, so a link is treated as a bearer secret with expiry and limits. Verified https App Links /
  Universal Links need a domain (Phase 6).

## Photos and private storage (Phase 3)

- Bucket `photos` is **private** (tested), JPEG only, 15 MB limit.
- Storage policies: members can read objects of **active** photos in their groups; a user can
  write only the two paths reserved for their own **pending** upload; there are no update or
  delete policies, so clients can never overwrite or delete objects (tested).
- The app reads photos through signed URLs valid for 1 hour, reused for 50 minutes and cached
  on disk by photo id (not by URL).
- Re-encoding to JPEG drops EXIF metadata, including GPS location, before upload. The capture
  time is read first and stored as `taken_at`.
- Premium cannot be forged: clients have no write access to entitlements and cannot call the
  entitlement functions (tested). Retention reads only the server's entitlement.
- The cleanup Edge Function uses the service role inside Supabase; its logs contain counts only.

## Phase 1 status

- Auth uses Supabase PKCE flow; passwords go only to Supabase Auth over HTTPS.
- Password reset screen does not reveal whether an email has an account.
- Error messages are mapped to friendly text; raw server errors are not shown or logged.
- Debug-only preview mode is compiled out of release behaviour (`kDebugMode` check) and is
  impossible when a backend is configured.
- GitHub Actions: least-privilege `permissions`, third-party actions pinned to commit SHAs.
- The repository is **public**: never commit anything sensitive. Consider making it private
  (owner decision; not changed automatically).

## Planned (Phase 2+)

RLS policies, storage policies, invitation token hashing, atomic capacity checks, retention
functions, webhook verification and their tests will be documented here as they are built.
