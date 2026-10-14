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

## Not yet covered (needs later phases or external resources)

| Area | Needs |
|---|---|
| Real Supabase sign-up / email confirmation / reset links | Supabase project + email delivery; physical device for deep links |
| Google / Apple OAuth | Provider credentials configured in Supabase |
| Milestone references to deleted photos (spec §13 item 14) | Phase 4 |
| Store purchase verification end to end, device registration (items 15 store side, 16) | Phase 5, store sandbox accounts |
| Native image compression and camera | Physical device / emulator (plugin code is not exercised in unit tests) |
| Native widgets, push | Phase 5, emulators/devices; iOS needs hosted macOS |
