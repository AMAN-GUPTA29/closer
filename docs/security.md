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
