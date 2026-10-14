# Known limitations

The actionable list of deferred items, owner actions and credentials lives in
[`ISSUES.md`](../ISSUES.md). This page describes current behaviour limits.

_Last updated: Phase 6, 2026-10-14. Launch steps: [release-readiness.md](release-readiness.md)._

## Not built (by design, or waiting on decisions)

- Verified https invite links (App Links / Universal Links): need a domain (D4).
- Basic $2 charging: open decision (D1).
- Localisation: English only.
- Offline queueing of changes (uploads retry per step; other actions need a connection).

Release pipelines exist (`release.yml`, `codemagic.yaml`) but have **not run**, because they need
signing accounts.

Disabled and labelled until credentials exist: the Closer Memories purchase button and "Restore
purchases" (no RevenueCat keys in the build); push (no Firebase config, so the app runs without
it); Help & support until `SUPPORT_EMAIL` is set.

## Phase 5 limits

- Push, reminders and purchases are implemented and tested with fakes and a local database, but
  no message has reached a real phone and no store transaction has run (needs Firebase,
  APNs and RevenueCat/store accounts, see ISSUES).
- The iOS widget extension compiles in CI but has not run on an iPhone. Signing with the App
  Group is still needed.
- Android widget checked on an emulator only. Background refresh from a data push is unverified.
- Widgets show the newest photo as a downsampled thumbnail. OS limits decide how often widgets
  redraw (no exact interval).
- Realtime events only trigger a refetch; there is no partial merging. Offline changes are not
  queued (uploads already retry per step).
- Basic $2 pricing is still an open decision (ISSUES D1); only Closer Memories is wired.

## Environment / verification gaps

- Database code is verified only against the Supabase CLI's local Postgres in GitHub Actions; it
  has not been applied to a hosted Supabase project.
- Docker Desktop did not start on the development laptop, so backend tests ran in CI only.
- Invite links use a custom URL scheme: they open the app when installed but are not clickable web
  links in every messenger. Verified https links need a domain (Phase 6).
- Invite codes are shown only once (stored hashed). Members can create new ones at any time.
- Upload progress is reported per step (prepare, photo, preview, finish), not byte by byte.
- Images are resized so the short side is at most 2560 px (thumbnails 480 px) and re-encoded as JPEG.
- The cleanup worker must be deployed and scheduled on the hosted project (see
  `docs/purchases-and-retention.md`); until then removed photos are hidden immediately but their
  files are deleted only when the worker runs.
- Camera capture, native compression and EXIF dates were checked on an Android 14 emulator (in
  Preview mode, without a backend); not yet on a physical phone or iOS. Widget tests use a fake
  picker and processor.
- No Supabase project is configured yet → real sign-up, email confirmation and password reset
  have **not** been exercised against a live backend; they are covered by tests with a fake backend only.
- Google/Apple sign-in are wired to Supabase OAuth but disabled; untested.
- Auth deep link (`com.closerapp.closer://auth-callback`) is registered but not verified on a device.
- The debug APK builds locally; it has not been installed on a physical phone by Claude.
- iOS is built in CI only (unsigned, macOS runner); never run on a device or simulator by Claude.
- Legal pages are draft summaries, not reviewed legal documents.
- Brand marks for Google/Apple buttons are monochrome Simple Icons; check provider brand
  guidelines before enabling those buttons in production.
- The repository is public.
