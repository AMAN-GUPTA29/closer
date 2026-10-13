# Known limitations

_Last updated: Phase 1, 2026-10-14._

## Not built yet (planned phases)

| Feature | Phase |
|---|---|
| Groups, membership, invitations, join flow, group home | 2 |
| Database migrations and RLS | 2 |
| Photo upload, private storage, retention, Premium entitlement | 3 |
| Journal, milestones, notifications feed, settings, account deletion | 4 |
| Native widgets, push notifications, purchase verification | 5 |
| Release signing, iOS hosted builds, hardening | 6 |

In the current build the Home "Create a group" / "Join with a code" buttons and several Profile
rows are visibly disabled and labelled as coming soon.

## Environment / verification gaps

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
