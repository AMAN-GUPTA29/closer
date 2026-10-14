# Testing

## Commands

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test                 # all unit + widget tests
flutter test test/app        # end-to-end-style app flow tests with a fake auth backend
flutter build apk --debug
```

`test/flutter_test_config.dart` loads the bundled fonts so layout tests use real text metrics
(this caught several overflow bugs that only appear with wider text).

## Backend suites (Phase 2), run in CI ("Database tests" job)

| File | Covers (spec section 13 numbers) |
|---|---|
| `supabase/tests/database/001_groups_rls.test.sql` | profile trigger; create_group validation; owner vs non-member access; column privileges; no direct inserts; anon denied everywhere (1, 2); RLS enabled on all tables |
| `supabase/tests/database/002_invitations.test.sql` | hashing, hints, default expiry; preview grants nothing; redemption scoped to its group (3); expired and revoked fail (4); duplicate redemption safe (5); use limits; rate limiting; couple capacity incl. trusted inserts; revoke permissions |
| `supabase/tests/database/003_membership_lifecycle.test.sql` | transfer, remove, leave, delete; ownership hand-over; empty groups deleted; account deletion leaves no orphaned or ownerless groups |
| `supabase/tests/concurrency/couple_capacity.sh` | 5 parallel connections redeem 5 invitations to one couple group: exactly 1 joins, 2 members (6) |

Latest CI result: 105 pgTAP assertions passed; concurrency script: 1 joined, 4 full, members = 2.

| `supabase/tests/database/004_photos_retention.test.sql` | private bucket; idempotent upload requests; storage write/read policies; finalize requires stored objects; failed upload deletes nothing (12); 11th upload removes the oldest (7, 8); Premium keeps more than 10 (9); client Premium forgery blocked (10); Premium isolated per group and inherited by new members (11); purchase idempotency (15); refund grace period; delete permissions; stale uploads; group deletion queues objects; cleanup queue claim/backoff/lease/dead (13) |
| `supabase/tests/database/005_journal_milestones_notifications.test.sql` | notification fan-out, self-exclusion, preferences, recipients-only reads, mark read; milestone RLS, forged creator, cover validation, creator/owner edits; journal mixing, ordering, future exclusion, keyset pages; chosen covers; deleted/retained photos cleared from milestone and group covers (14); avatars write/read policies; leaving clears notifications; account deletion keeps shared content |
| `supabase/functions/delete-account/logic_test.ts` | Deno: own-account deletion order, bearer token required, typed confirmation, invalid tokens, no leaked errors |
| `supabase/tests/concurrency/basic_retention.sh` | 3 uploads finalize in parallel into a full Basic group: exactly 10 active, the 3 oldest removed |
| `supabase/functions/cleanup-storage/logic_test.ts` | Deno: deletes and completes jobs, failures recorded for retry, thrown errors not fatal, batch limit, empty queue |

Locally these need Docker; see `docs/database.md`. Edge Function tests: `cd supabase/functions && npx deno@2 test cleanup-storage/`.

## Suites (Phase 1)

| File | Covers |
|---|---|
| `test/core/core_logic_test.dart` | validators, `AppConfig`, greeting, redirect policy for every auth state, `GroupType`, display helpers |
| `test/features/auth_test.dart` | Supabase error-code mapping, unconfigured repository, `AuthController` event handling incl. password recovery and preview gating |
| `test/widgets/components_test.dart` | buttons (enabled/loading/semantics), icon button target size, empty/error/offline states, confirmation dialog, invite-code copy, upgrade card disabled state, group card semantics, milestone reduced motion, photo viewer paging/closing |
| `test/app/app_flow_test.dart` | onboarding → sign up/in, swipe, form validation, wrong password, network error, sign in → tabs → add sheet → profile → sign out, sign-up → verify email + resend cooldown, unconfigured backend + preview, legal page |

`test/helpers/fakes.dart` provides `FakeAuthRepository` and `pumpCloserApp`.

## Flutter suites added in Phase 2

| File | Covers |
|---|---|
| `test/features/groups_invitations_logic_test.dart` | model parsing, date policy (start date = day 1, leap years), labels, invite code normalising/formatting/link parsing, status messages, backend error mapping (no leaked details), pending-invite redirect, in-memory backend rules |
| `test/app/groups_flow_test.dart` | create couple group, invite code, group home, Home list; revoke with confirmation; join by code with preview and counter; invalid/full/expired explanations; pasted invite message; invite link while signed out opens Join after sign-in; owner removes member, renames, leaves (ownership passes); non-owner read-only settings |

Total Flutter tests: 80.

## Flutter suites added in Phase 3

| File | Covers |
|---|---|
| `test/features/photos_logic_test.dart` | file-type detection, size/type validation, EXIF dates, photo parsing, retention helpers, upload protocol order, retry without duplicates, Basic vs Premium retention, keyset pagination, pin requires Premium |
| `test/app/photos_flow_test.dart` | share with caption → journal; full-group warning then oldest removed; failed upload → Retry → one photo; unsupported file; viewer + delete with confirmation; upgrade screen never fakes a purchase; Premium status; Add tab group picker |

Total Flutter tests: 98.

## Flutter suites added in Phase 4

| File | Covers |
|---|---|
| `test/features/journal_logic_test.dart` | milestone parsing/highlights, drafts, templates (hearts only for couples), journal entry parsing and time-zone-safe day grouping, couple countdowns (round numbers, anniversaries, 29 Feb, future start), notification parsing/messages, preferences, in-memory rules (cover cleared on photo delete, same-group covers, journal mixing, edit permissions) |
| `test/app/journal_flow_test.dart` | counter + countdown; create → pin → edit → delete a moment; "mark as special moment" pre-selects the cover; all-groups journal; notification badge, open + mark read, preferences; edit profile; typed account deletion → signed out; owner chooses cover; offline banner |

Total Flutter tests: 121. Latest CI: 220 pgTAP assertions, 10 Deno tests, both concurrency scripts.

## Suites added in Phase 5

| File | Covers |
|---|---|
| `supabase/tests/database/006_push_reminders_purchases.test.sql` | device registration (own tokens only, validation, no direct writes, token moves between accounts, sign-out, 10-device cap); push queue (names but no content, leasing, backoff, invalid token retirement, expired leases, no double send, clients can't claim or see bookkeeping); reminders (day before, once, preference respected); purchases (unassigned recording, webhook replay, unknown users, apply once, one group per purchase, every member gets Premium, refunds, clients can't record) |
| `supabase/functions/dispatch-push/logic_test.ts` | message text (names only), sent/skipped/retry outcomes, invalid token retirement, FCM response classification, JWT assertion |
| `supabase/functions/verify-purchase/logic_test.ts` | RevenueCat lookup, status mapping (200/404/403/409/400/401) |
| `supabase/functions/revenuecat-webhook/logic_test.ts` | auth (constant-time), purchase → record, cancellation/refund → revoke, ignored events |
| `test/features/phase5_logic_test.dart` | widget snapshots/index/covers, revoked groups removed, failing cover download, sign-out wipe, group-targeted refresh; group links (UUID + Preview ids, junk rejected); push payload parsing; RevenueCat flow (verified, cancelled, pending, retries, refused, unassigned, unavailable) |
| `test/app/phase5_flow_test.dart` | sign-in starts push + realtime and fills widgets; tapped push opens group; realtime refresh; sign-out clears widgets; Widget Setup preview + add; applying an unused purchase |

**Manual (emulator, Android 14, Preview mode):** add widget from the app, launcher pin dialog,
group picker, widget shows "My Love · 182 days", and tapping it opens the group. This check found
that Preview group ids were rejected by the link parser (fixed).

**CI:** `ios-build` (macOS) adds the widget extension and compiles the app unsigned.

Totals: 141 Flutter tests, 263 pgTAP assertions, 32 Deno tests, both concurrency scripts.

## Suites added in Phase 6

| File | Covers |
|---|---|
| `test/app/accessibility_test.dart` | 18 signed-in screens + onboarding/welcome/sign-in/sign-up/reset at 200 % text with no overflow; Android/iOS tap-target and labelled-tap-target guidelines on Home, Profile, group home, preferences; WCAG text contrast on Home, Profile, preferences |
| `test/features/phase5_logic_test.dart` (+1) | unchanged widget covers are not downloaded again |
| `supabase/tests/database/007_security_review.test.sql` | schema-wide: RLS on every table, no anon table grants or function execution, server-only functions closed to signed-in users, `search_path` on definer functions, no public buckets, bucket limits, invoker views |

**CI jobs added:** gitleaks secret scan (full history), release App Bundle build (R8).
**Manual:** release APK (R8) installed and launched on the Android 14 emulator, no crashes.

Totals: 167 Flutter tests, 8 pgTAP files, 32 Deno tests, both concurrency scripts.

## Not yet covered (needs later phases or external resources)

| Area | Needs |
|---|---|
| Real Supabase sign-up / email confirmation / reset links | Supabase project + email delivery; physical device for deep links |
| Google / Apple OAuth | Provider credentials configured in Supabase |
| Native image compression and camera | Physical device / emulator (plugin code is not exercised in unit tests) |
| Push delivery to a real device, background widget refresh | Firebase project + APNs key, physical devices |
| iOS widget on an iPhone, App Group sharing at runtime | Apple Developer account + signing, device |
| Real store purchases (sandbox) end to end | Store accounts, RevenueCat project, hosted backend |
| Signed release builds, TestFlight upload | Keystore secrets, Apple/Codemagic accounts |
| Screen readers, low-end device performance | Physical devices (ISSUES C14, C15) |
