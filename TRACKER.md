# Closer — Build Tracker

> Your people. Your moments. Always close.

Single source of truth for build progress. Claude ticks items **only after they are implemented and verified**.
Items that are implemented but not verifiable in this environment are marked ⚠️ with the reason.

**Legend:** `[x]` done & verified · `[ ]` not started / in progress · ⚠️ implemented, verification blocked · 🔒 needs external credential/account

| Phase | Name | Status | Approved by owner |
|---|---|---|---|
| 0 | Setup & Git remote | 🟡 Owner actions pending | — |
| 1 | Audit, design system, app foundation | 🟡 In progress | — |
| 2 | Auth, database, groups, invitations | ⬜ Not started | — |
| 3 | Photos, storage, retention, Premium foundation | ⬜ Not started | — |
| 4 | Journal, milestones, core screens | ⬜ Not started | — |
| 5 | Native widgets, notifications, purchases | ⬜ Not started | — |
| 6 | CI/CD, remote dev, hardening, release | ⬜ Not started | — |

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
- [ ] CI run green on GitHub ⚠️ check after push
- [x] Unit tests (validators, config, redirect policy, error mapping, auth controller)
- [x] Widget tests (components, onboarding, auth forms, shell navigation, sign-out, unconfigured mode)
- [x] `flutter pub get` ✅ · `dart format` ✅ · `flutter analyze` ✅ (0 issues) · `flutter test` ✅ (51 passed)
- [x] Debug APK builds locally and runs on an Android 14 emulator (Pixel 8) — screens checked visually
- [ ] Commit + push, Phase 1 report, **wait for approval**

## Phase 2 — Authentication, database, groups, invitations

- [ ] Supabase project linked 🔒 (URL + anon key; service key only in secrets)
- [ ] Supabase CLI + local migrations folder
- [ ] Migration: `profiles` + auto-create trigger
- [ ] Migration: `groups` (type couple/friends/family, cover, relationship_start_date)
- [ ] Migration: `group_members` (unique membership, roles owner/admin/member)
- [ ] Atomic couple capacity (locking RPC, max 2)
- [ ] Migration: `invitations` (token hash, code, expiry, revocation, max redemptions) + `invitation_redemptions`
- [ ] RPC: create invitation · revoke invitation · preview invitation · redeem invitation (atomic)
- [ ] Leave group / transfer ownership / delete group (no orphans)
- [ ] RLS on all tables, membership-based
- [ ] Email auth wired (sign up, login, verify, reset)
- [ ] Google / Apple sign-in 🔒 (if credentials provided)
- [ ] Screens: Home/Groups, Create Group, Invite Members, Join Group (+ deep link), Group Home
- [ ] Backend tests: unauthenticated denied, non-member denied, invite scoped to group, expired/revoked fail, duplicate redemption safe, concurrent couple joins ≤ 2
- [ ] Flutter unit + widget tests for repos, forms, screens
- [ ] Docs: database.md, security.md updated
- [ ] Commit + push, Phase 2 report, **wait for approval**

## Phase 3 — Photo sharing, private storage, retention, Premium foundation

- [ ] Private storage bucket + storage RLS by group membership
- [ ] Migration: `photos` (uploader, path, caption, taken_at vs uploaded_at, status)
- [ ] Migration: `storage_cleanup_jobs` (durable retry queue)
- [ ] Gallery picker + camera capture
- [ ] Preview, caption, optional date
- [ ] Compression + thumbnail generation
- [ ] Upload progress, retry, duplicate-submit protection (idempotency key)
- [ ] Server-side Basic 10-photo retention (oldest eligible removed, concurrency-safe)
- [ ] Failed upload never deletes existing photos
- [ ] Cleanup Edge Function with retries
- [ ] Retention warning UI before loss
- [ ] Short-lived signed URLs + image caching
- [ ] Full-screen photo viewer
- [ ] Migration: `group_entitlements` + `purchase_records`
- [ ] Server-side Premium checks (client flag ignored)
- [ ] Upgrade UI ("Keep every memory from this group")
- [ ] Billing approach researched & chosen (RevenueCat vs direct) — documented
- [ ] Tests: retention ≤10, oldest removed, Premium >10, client flag bypass fails, entitlement isolated per group, concurrent uploads, cleanup retry, authorization
- [ ] Docs: purchases-and-retention.md
- [ ] Commit + push, Phase 3 report, **wait for approval**

## Phase 4 — Journal, milestones, complete core screens

- [ ] Journal: newest-first, cursor pagination, stable scroll
- [ ] Captions/metadata, featured & pinned memories
- [ ] Migration: `milestones` (+ safe photo reference on delete)
- [ ] Milestone CRUD, pin/unpin, templates, themes (heart for couples, neutral/celebratory otherwise)
- [ ] Special Moment screen
- [ ] Relationship counter (documented date/timezone policy), editable start date, countdowns
- [ ] Notifications screen (read/unread, group navigation, preferences)
- [ ] Profile & settings (name, avatar, prefs, purchases, restore, help, sign out)
- [ ] Account deletion (safe, server-side)
- [ ] Group settings + members screens
- [ ] Loading / empty / error / offline states everywhere
- [ ] Design polish pass against reference image
- [ ] Tests: journal sorting, milestone calculations, screens
- [ ] Commit + push, Phase 4 report, **wait for approval**

## Phase 5 — Native widgets, notifications, purchase integration

- [ ] Android Kotlin App Widget provider + sizes
- [ ] Android per-instance configuration activity (group picker)
- [ ] Android photo cache, refresh, deep links, empty/error states
- [ ] iOS WidgetKit extension (SwiftUI) + App Groups ⚠️ (needs hosted macOS to build)
- [ ] iOS per-instance AppIntent configuration, timeline, snapshot, placeholder
- [ ] Flutter ↔ native bridge (`home_widget`)
- [ ] Widget Setup screen (previews, instructions, troubleshooting)
- [ ] Revoked membership clears widget cache
- [ ] FCM setup 🔒 + APNs 🔒
- [ ] Device token registration/rotation/invalid cleanup
- [ ] Push dispatch Edge Function (idempotent, no private content in payload)
- [ ] Foreground realtime sync
- [ ] Group-targeted widget refresh
- [ ] Purchase SDK integration + restore 🔒 (store accounts)
- [ ] Purchase webhook verification + idempotency
- [ ] Refund/revocation grace policy implemented
- [ ] Tests: widget config independence, routing, cache invalidation, device registration auth, purchase idempotency
- [ ] Physical-device verification list documented
- [ ] Commit + push, Phase 5 report, **wait for approval**

## Phase 6 — CI/CD, remote development, hardening, release readiness

- [ ] `.github/workflows/ci.yml` final (format, analyze, tests, backend checks)
- [ ] `.github/workflows/android-apk.yml` → APK artifact uploaded (verified run)
- [ ] Actions pinned to SHAs, least-privilege permissions
- [ ] Claude Code GitHub workflow (`@claude` from issues/PRs on mobile) 🔒 (ANTHROPIC_API_KEY / app install)
- [ ] `docs/remote-development.md`
- [ ] Codemagic iOS config (`codemagic.yaml`), signing, TestFlight prep 🔒
- [ ] Release signing for Android via secrets 🔒
- [ ] Full test suite run
- [ ] Security review (RLS, Storage, secrets)
- [ ] Purchase & retention review
- [ ] Performance & accessibility review
- [ ] All docs complete and in sync
- [ ] Release-readiness report

---

## Change log
- 2026-10-14 — Tracker created; design image located; toolchain verified.
- 2026-10-14 — Repo pushed; remote-development setup (cloud sessions + @claude workflow) committed; Phase 1 started.
- 2026-10-14 — Phase 1 implemented: design system, onboarding, auth, shell, docs, CI; 51 tests passing; APK verified on emulator.
