# Closer — Build Tracker

> Your people. Your moments. Always close.

Single source of truth for build progress. Claude ticks items **only after they are implemented and verified**.
Items that are implemented but not verifiable in this environment are marked ⚠️ with the reason.
Deferred items, credentials and owner actions are collected in [ISSUES.md](ISSUES.md).

**Legend:** `[x]` done & verified · `[ ]` not started / in progress · ⚠️ implemented, verification blocked · 🔒 needs external credential/account

| Phase | Name | Status | Approved by owner |
|---|---|---|---|
| 0 | Setup & Git remote | 🟡 Owner actions pending | — |
| 1 | Audit, design system, app foundation | ✅ Done (PR #1) | ✅ 2026-10-14 |
| 2 | Auth, database, groups, invitations | ✅ Done (PR #2) | ✅ 2026-10-14 |
| 3 | Photos, storage, retention, Premium foundation | ✅ Done (PR #3) | ✅ 2026-10-14 |
| 4 | Journal, milestones, core screens | ✅ Done (PR #5) | ✅ 2026-10-14 |
| 5 | Native widgets, notifications, purchases | ✅ Done (PR #6) | ✅ 2026-10-14 |
| 6 | CI/CD, remote dev, hardening, release | ✅ Done (PR #7) | ✅ 2026-10-15 (merged) |

_Last updated: 2026-10-14_

---

## Phase 0 — Setup & Git remote

- [x] Inspect project folder (`F:\closer`) — contains only the design reference image; not yet a Git repo
- [x] Locate design reference: `Closer App UI Concept Board.png` (project root, 1536×1024, 14 screens incl. widgets)
- [x] Confirm toolchain: Flutter 3.47.4 / Dart 3.13.3, Java 17.0.10, Git, GitHub CLI (logged in)
- [x] Create this tracker
- [x] Receive empty GitHub repo URL: https://github.com/AMAN-GUPTA29/closer (⚠️ repo is **public**)
- [x] `git init`, set `main` branch, add remote, first commit (tracker + design image), push
- [x] Document mobile command workflow → `docs/remote-development.md`
- [x] Cloud-session bootstrap: `.claude/settings.json` SessionStart hook + `scripts/cloud-setup.sh` (installs Flutter 3.47.4)
- [x] `@claude` GitHub workflow `.github/workflows/claude.yml` (SHA-pinned)
- [x] `CLAUDE.md` with working rules for local + cloud sessions
- [ ] 🔒 Owner: install Claude GitHub App on the repo
- [ ] 🔒 Owner: add `CLAUDE_CODE_OAUTH_TOKEN` repo secret (`claude setup-token`)
- [ ] Verify a cloud session from the phone runs `flutter test` ⚠️ needs owner to start one
- [ ] Verify `@claude` workflow end-to-end ⚠️ needs secret

## Phase 1 — Repository audit, design system, app foundation

**Audit & docs**
- [x] Repo + Git audit recorded in `docs/architecture.md`
- [x] Copy design image to `docs/design/closer-ui-concept-board.png` (original preserved in root, byte-identical)
- [x] `CLAUDE.md`
- [x] `README.md`
- [x] Docs: product-requirements, architecture, design-system, database, security, testing, build-and-release, remote-development, widget-implementation, purchases-and-retention, environment-setup, known-limitations
- [x] `.env.example` (placeholders only) + `.gitignore` covering secrets

**Flutter foundation**
- [x] `flutter create` (Android + iOS), id `com.closerapp.closer` documented
- [x] Feature-based folder structure (`lib/app`, `lib/core/*`, `lib/features/*`)
- [x] Dependencies: Riverpod 3, GoRouter 18, supabase_flutter, intl, Lucide icons, flutter_svg, url_launcher (fonts bundled instead of google_fonts)
- [x] Centralized env config (`--dart-define`) with graceful "Backend not connected" mode
- [x] GoRouter with pure, unit-tested auth redirect policy + deep-link-ready routes
- [x] Riverpod providers foundation (`AuthController`, repositories)
- [x] Auth callback deep link registered (Android intent filter, iOS URL scheme) ⚠️ not verified on a device

**Design system**
- [x] Tokens: colours, typography (Plus Jakarta Sans + Fraunces), spacing, radii, elevation, motion
- [x] Light + dark themes from the same semantic tokens
- [x] Reduced-motion support (`CloserMotion.of`)
- [x] Components: CloserButton, CloserIconButton, GroupCard, MemoryCard, MilestoneCard, MemberAvatar/AvatarStack, PhotoViewer, InviteCodeCard, UpgradeCard, WidgetPreviewCard, LoadingState, EmptyState, ErrorState(+offline), OfflineBanner, ConfirmationDialog, CloserTextField, CloserPhoto, SunsetArt, CloserLogo
- [x] Debug-only component gallery (Profile → Component gallery)
- [x] `docs/design-system.md` written from the reference image

**Screens**
- [x] Onboarding (painted sunset hero, tagline, 3 swipeable pages, Get Started, Sign in)
- [x] Auth UI: sign up, sign in, verify email (+ resend cooldown), forgot password, set new password, legal summaries
- [x] Google/Apple buttons wired to Supabase OAuth, shown disabled until configured
- [x] Main navigation shell (Home, Journal, Add sheet, Notifications, Profile) with honest empty states
- [x] Profile with sign-out confirmation; later-phase rows marked "Soon"
- [ ] 🔒 Real sign-up / sign-in against Supabase — needs Supabase project URL + anon key

**CI & tests**
- [x] GitHub Actions `ci.yml`: format, analyze, test, debug APK artifact (SHA-pinned actions)
- [x] CI run green on GitHub (5/5 checks on PR #1)
- [x] Unit tests (validators, config, redirect policy, error mapping, auth controller)
- [x] Widget tests (components, onboarding, auth forms, shell navigation, sign-out, unconfigured mode)
- [x] `flutter pub get` ✅ · `dart format` ✅ · `flutter analyze` ✅ (0 issues) · `flutter test` ✅ (51 passed)
- [x] Debug APK builds locally and runs on an Android 14 emulator (Pixel 8) — screens checked visually
- [x] Commit + push, Phase 1 report, approved 2026-10-14

## Phase 2 — Authentication, database, groups, invitations

**Backend**
- [ ] 🔒 Supabase hosted project linked (URL + anon key; service key only in secrets) — owner action
- [x] Supabase CLI project (`supabase/config.toml`, email confirmation on, app redirect URL)
- [x] Migration: `profiles` + auto-create trigger
- [x] Migration: `groups` (couple/friends/family, relationship_start_date, counter toggle)
- [x] Migration: `group_members` (unique membership, roles owner/member, one owner)
- [x] Atomic couple capacity (row-locking trigger, max 2) — concurrency test: 5 parallel joins, 1 succeeds
- [x] Migration: `invitations` (hashed code + token, hint, expiry, revocation, max uses) + `invitation_redemptions` + rate-limit attempts
- [x] Functions: create_group, create/revoke/preview/redeem invitation, leave, transfer ownership, remove member, delete group
- [x] No orphaned/ownerless groups (trigger covers leave, removal, account deletion)
- [x] RLS on all tables + column-level grants; `group_summaries` view (security_invoker)
- [x] pgTAP: 105 assertions passing in CI (unauth, non-member, invite scope, expired/revoked, duplicate redemption, capacity, lifecycle)
- [x] CI "Database tests" job: db start, pgTAP, concurrency script, db lint
- [ ] ⚠️ Migrations applied to a hosted project — needs Supabase credentials
- [ ] ⚠️ Local backend tests — Docker Desktop did not start on the laptop; verified in CI only

**App**
- [x] Email auth wired (Phase 1) ⚠️ not yet exercised against a live project
- [ ] 🔒 Google / Apple sign-in — needs provider credentials
- [x] Groups repositories (Supabase / in-memory preview / unconfigured), Riverpod providers, error mapping
- [x] Home: group list with counters/activity, pull to refresh, loading/error/offline/empty states
- [x] Create Group: type cards, name, couple start date, validation
- [x] Invite Members: expiry + use-limit choices, code + link, share sheet, copy, invitation list, revoke
- [x] Join Group: code entry, paste invite message, preview, all failure states, rate-limit message
- [x] Invite deep link `com.closerapp.closer://invite?t=...` (kept through sign-in) ⚠️ not tested on a device
- [x] Group Home: hero, couple counter, avatars, actions, Journal/Milestones/Details tabs, upgrade card (disabled)
- [x] Members (make owner, remove) and Group settings (rename, start date, counter, leave, delete)
- [x] Preview mode uses in-memory sample groups (debug builds only)
- [x] Flutter tests: 80 passing (29 new: logic + full group/invite flows)
- [x] `dart format` ✅ · `flutter analyze` ✅ · debug APK ✅ · checked on Android 14 emulator
- [x] Docs: database.md, security.md, testing.md, architecture.md, known-limitations.md updated
- [x] Commit + push, Phase 2 report, approved 2026-10-14

## Phase 3 — Photo sharing, private storage, retention, Premium foundation

**Backend**
- [x] Private `photos` bucket (JPEG, 15 MB) + storage policies (read active photos of your groups; write only your pending upload paths; no update/delete)
- [x] Migration: `photos` (uploader, paths, caption, taken_at vs uploaded_at, status, pin)
- [x] Upload protocol: request (idempotent) → store objects → finalize (verifies objects, group lock)
- [x] Server-side Basic 10-photo retention, oldest eligible removed, concurrency-safe (3 parallel uploads test)
- [x] Failed/abandoned upload never deletes photos; stale pending uploads expire
- [x] Migration: `storage_cleanup_jobs` durable queue (leases, backoff, dead-letter) + group-deletion trigger
- [x] Edge Function `cleanup-storage` + Deno tests (5)
- [ ] 🔒 Deploy + schedule cleanup worker on hosted project — owner action (docs/purchases-and-retention.md)
- [x] Migration: `group_entitlements` + `purchase_records`; grant/revoke functions (service role, idempotent)
- [x] Server-side Premium checks; client flag cannot bypass; isolated per group; inherited by new members
- [x] Refund grace policy (30 days, no deletion at revocation)
- [x] pgTAP 004 + concurrency script in CI

**App**
- [x] Gallery picker + camera (image_picker) — camera path verified on Android 14 emulator
- [x] Validation (type by content, 30 MB), EXIF capture date, JPEG compression + thumbnail, metadata stripped — compression + EXIF date verified on emulator
- [x] Add Memory screen: preview, caption, date, step progress, Retry, duplicate protection, retention warning
- [x] Signed URLs + disk image cache keyed by photo id
- [x] Journal photo grid with keyset pagination; full-screen viewer with delete / pin
- [x] Group covers from newest photo; Home cards show covers and Premium crown
- [x] Add tab: choose a group
- [x] Upgrade screen ("Keep every memory from this group"), purchase disabled with reason, restore entry point
- [x] Billing approach researched & documented (consumable per group via RevenueCat, server verification)
- [x] `PurchaseService` foundation (no fake purchases)
- [x] Flutter tests: 98 passing (18 new)
- [x] Docs: purchases-and-retention, database, security, testing, architecture, known-limitations
- [x] CI green: 168 pgTAP assertions, both concurrency scripts, Deno tests, Flutter, APK
- [x] Commit + push, Phase 3 report, approved 2026-10-14

## Phase 4 — Journal, milestones, and complete core screens

**Backend**
- [x] Migration: `milestones` (types, themes, cover, pin) + RLS (members create as themselves; creator/owner edit)
- [x] `journal_entries` RPC: photos + past milestones, newest first, keyset pagination, RLS-respecting
- [x] Chosen group covers (`set_group_cover`) and cover thumbnails for milestones
- [x] Removed photos cleared from milestone/group covers (spec §13.14) — tested for deletion and retention
- [x] Notifications (triggers on photo/member/milestone, preferences, mark read, cleared on leave) — no captions
- [x] Private `avatars` bucket + `set_avatar`
- [x] Account deletion: `prepare_account_deletion` + Edge Function `delete-account` (+5 Deno tests)
- [x] pgTAP 005 — CI: 220 assertions total, all passing
- [ ] 🔒 Deploy `delete-account` on the hosted project (ISSUES B2)

**App**
- [x] Journal tab (all groups) + group journal: day headers, captions, uploader, pinned strip, infinite scroll, viewer
- [x] Milestones tab: couple counter + countdowns (next 100s, anniversary), upcoming, past
- [x] Special Moment screen: templates per group type, title, date, description, cover from group photos, theme, pin; edit/delete
- [x] "Mark as special moment" after sharing a photo
- [x] Notifications screen (Today/Yesterday/Earlier, unread, mark all read, open group) + preferences; Home badge
- [x] Profile: edit name + avatar, purchased groups, restore entry point, help, legal, sign out
- [x] Account deletion screen with typed confirmation
- [x] Group settings: choose cover photo; members screen (Phase 2)
- [x] Offline banner (connectivity) + loading/empty/error states on all new screens
- [x] Design check on emulator (fixed share-button overlap)
- [x] Flutter tests: 121 passing (23 new)
- [x] Docs + ISSUES.md updated
- [x] Commit + push, Phase 4 report, approved 2026-10-14 (merged to `main` via PR #5)

## Phase 5 — Native widgets, notifications, purchase integration

**Widgets**
- [x] Android Kotlin App Widget provider (2×2, resizable) with signed-out / unconfigured / unavailable / group states
- [x] Android per-instance configuration activity (group picker, reconfigurable, also opens from an unconfigured widget)
- [x] Android downsampled photo cache, app-driven refresh, deep link to the group — checked on emulator
- [x] iOS WidgetKit extension (SwiftUI) + App Group; CI adds the target and compiles unsigned ⚠️ not run on an iPhone (ISSUES C9)
- [x] iOS per-instance AppIntent configuration, timeline, snapshot, placeholder ⚠️ (C9)
- [x] Flutter ↔ native bridge (`home_widget` + MethodChannel for refresh/pin)
- [x] Widget Setup screen (previews, "Add a widget" pin request, manual steps, troubleshooting)
- [x] Revoked membership / sign-out clears widget data (tested)
- [x] Group-targeted widget refresh (tested)

**Push & sync**
- [ ] 🔒 FCM project + APNs key (ISSUES A10, A13) — app runs without push until configured
- [x] Device token registration / rotation / move between accounts / invalid cleanup (pgTAP)
- [x] `dispatch-push` Edge Function: leased queue, idempotent, backoff, names-only payload (pgTAP + Deno) ⚠️ no real delivery yet (C10)
- [x] Milestone reminders (daily job) + push/reminder preferences
- [x] Foreground realtime sync (Supabase Realtime) + refresh on resume; tapped push opens group
- [x] Background widget refresh from data push ⚠️ unverified (C10)

**Purchases**
- [x] RevenueCat SDK integration + restore; disabled and labelled without keys 🔒 (A9)
- [x] `verify-purchase` (server-side REST verification) + `revenuecat-webhook` (auth, idempotent) — Deno + pgTAP
- [x] Unassigned purchases can be applied to a group from Profile
- [x] Refund/revocation → 30-day grace (Phase 3 policy, now wired to webhook)
- [ ] 🔒 Sandbox purchase end to end (C12)

**Quality**
- [x] Tests: widget data independence, routing/links, cache invalidation, device registration auth, purchase idempotency — 141 Flutter, 263 pgTAP, 32 Deno
- [x] Emulator check of the Android widget (found + fixed Preview link bug)
- [x] Physical-device verification list documented (ISSUES C9–C13)
- [x] Docs: widget-implementation, notifications (new), purchases-and-retention, database, security, architecture, testing, known-limitations, README
- [x] Commit + push, PR #6 into `main`, CI green (incl. iOS unsigned build), Phase 5 report
- [x] Owner approved 2026-10-14 ("proceed phase 6")

## Phase 6 — CI/CD, remote development, hardening, release readiness

**CI/CD**
- [x] `ci.yml` final: format, analyze, tests, pgTAP + concurrency + db lint, Deno, gitleaks, iOS unsigned build, release (R8) build, debug APK artifact
- [x] APK artifact uploaded on every run (verified since Phase 1)
- [x] Actions pinned to SHAs, least-privilege permissions; Dependabot for pub/Gradle/Actions
- [x] `release.yml`: signed AAB + APK from `release` environment secrets, debug-key guard ⚠️ 🔒 not run (A12, C16)
- [x] `codemagic.yaml`: signed iOS + widget, production push, TestFlight ⚠️ 🔒 not run (A8, A11, A14, C16)
- [x] Android release signing via `key.properties` / env; release APK built and launched on emulator

**Remote development**
- [x] Claude Code GitHub workflow restricted to owner/collaborators 🔒 needs app install + token (A5, A6)
- [x] `docs/remote-development.md` up to date

**Reviews**
- [x] Full test suite: 167 Flutter, 8 pgTAP files, 32 Deno, 2 concurrency scripts (CI)
- [x] Security review → pgTAP 007, backups off, widget activity guard, privacy manifests, docs/security.md
- [x] Purchase & retention review (no client grants, idempotency, grace; App Review risk D8)
- [x] Performance review (cover cache fix) & accessibility review (26 new tests, 3 fixes)
- [x] All docs in sync; `docs/release-readiness.md` (report + launch checklist)
- [x] Commit + push, PR #7, final report; owner merged 2026-10-15

---

## Change log
- 2026-10-14 — Tracker created; design image located; toolchain verified.
- 2026-10-14 — Repo pushed; remote-development setup (cloud sessions + @claude workflow) committed; Phase 1 started.
- 2026-10-14 — Phase 1 implemented: design system, onboarding, auth, shell, docs, CI; 51 tests passing; APK verified on emulator.
- 2026-10-14 — Phase 2 implemented: Supabase schema + RLS + trusted functions, groups and invitations UI; 105 pgTAP + concurrency + 80 Flutter tests passing.
- 2026-10-14 — Phase 3 implemented: photos, private storage, retention, entitlements, cleanup queue, upload UI; 98 Flutter tests.
- 2026-10-14 — Added ISSUES.md (open issues register) at the owner's request.
- 2026-10-14 — Phase 4 implemented: journal, milestones, notifications, profile, account deletion; 220 pgTAP + 10 Deno + 121 Flutter tests.
- 2026-10-14 — Phase 4 approved and merged (PR #5). Phase 5 implemented: Android + iOS widgets, push queue + FCM dispatch, reminders, realtime, RevenueCat purchases with server verification; 263 pgTAP + 32 Deno + 141 Flutter tests; Android widget checked on emulator.
- 2026-10-14 — Phase 5 approved. Phase 6: release + secret-scan + R8 CI, Codemagic, signing, security/purchase/performance/accessibility reviews, release-readiness report; 167 Flutter tests.
- 2026-10-15 — Launch: Supabase project live (5 migrations, 5 Edge Functions, cleanup + reminder schedules, realtime); cron auth via Vault secret (migration 5, pgTAP 008).
- 2026-10-18 — Keeploom redesign: brand tokens (light + dark), Appearance setting, vector logo + icons/splash/notification icon, floating dock, onboarding/Home/share-sheet polish, all visible text and native labels renamed; 192 Flutter tests.
- 2026-10-20 — Keeploom redesign: Home, Journal, Share a memory (single screen, several photos and groups at once), Notifications and Profile now match the showcase in light and dark. Appearance, Sign out and Delete account moved to Profile → ⚙ Settings. 197 Flutter tests.
- 2026-10-20 — Remaining screens checked in light + dark against the redesigned ones: shared SectionCard (Notification preferences, Members, group Details, Profile), readable initials in avatar stacks, brand avatar on Edit profile. 197 Flutter tests.
- 2026-10-20 — UI locked by the owner. New CI job runs a 7-step end-to-end journey (sign-up → email confirm → groups/invites → photos/retention → journal/milestones/notifications → ownership/leave/delete → account deletion) through the app's real Supabase repositories against a throwaway local Supabase stack; all jobs green (run 39335497398). On-device check against the hosted backend still pending (emulator full).
