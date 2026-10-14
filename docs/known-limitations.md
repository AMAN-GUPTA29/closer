# Known limitations

_Last updated: Phase 2, 2026-10-14._

## Not built yet (planned phases)

| Feature | Phase |
|---|---|
| Photo upload, private storage, retention, Premium entitlement | 3 |
| Journal, milestones, notifications feed, settings, account deletion | 4 |
| Native widgets, push notifications, purchase verification | 5 |
| Release signing, iOS hosted builds, hardening | 6 |

Disabled and labelled in the current build: Group home "Share"/"Add" (photos, Phase 3), cover
photos, the Closer Memories upgrade button, several Profile rows.

## Environment / verification gaps

- Database code is verified only against the Supabase CLI's local Postgres in GitHub Actions; it
  has not been applied to a hosted Supabase project.
- Docker Desktop did not start on the development laptop, so backend tests ran in CI only.
- Invite links use a custom URL scheme: they open the app when installed but are not clickable web
  links in every messenger. Verified https links need a domain (Phase 6).
- Invite codes are shown only once (stored hashed). Members can create new ones at any time.
- No Supabase project is configured yet → real sign-up, email confirmation and password reset
  have **not** been exercised against a live backend; they are covered by tests with a fake backend only.
- Google/Apple sign-in are wired to Supabase OAuth but disabled; untested.
- Auth deep link (`com.closerapp.closer://auth-callback`) is registered but not verified on a device.
- The debug APK builds locally; it has not been installed on a physical phone by Claude.
- iOS has not been built (no macOS available).
- Legal pages are draft summaries, not reviewed legal documents.
- Brand marks for Google/Apple buttons are monochrome Simple Icons; check provider brand
  guidelines before enabling those buttons in production.
- The repository is public.
