# Open issues — to resolve later

Everything deferred, blocked or unverified, in one place. Updated at every phase.
Claude adds new items as they come up and marks them resolved (with date and how) — items are
never silently deleted. Secrets themselves are **never** written here or in chat.

**Owner:** 👤 = you (needs your account, credentials or decision) · 🤖 = Claude · 🤝 = both
**Status:** 🔴 blocking a feature · 🟡 open · ✅ resolved

_Last updated: 2026-10-14 (after Phase 4)._

## A. Credentials and accounts (👤 owner actions)

| # | Item | Needed for | How (safe way) | Status |
|---|---|---|---|---|
| A1 | **Supabase project URL + anon/publishable key** | Real sign-up/sign-in, groups, photos on devices | Create project at supabase.com → Settings → API. Send only URL + anon key (client-safe). Put them in `.env` locally and as GitHub repo **variables** `SUPABASE_URL`, `SUPABASE_ANON_KEY` for CI APKs | 🔴 |
| A2 | Supabase **service-role key** | Cleanup worker, purchase verification (server only) | Never share in chat or commit. It is injected automatically into Edge Functions; for the cron job store it with `vault.create_secret` in the SQL editor | 🔴 (with A1) |
| A3 | Supabase **database password / CLI login** | Applying migrations to the hosted project | Run yourself: `npx supabase@2.120.0 login`, `link --project-ref <ref>`, `db push` | 🔴 (with A1) |
| A4 | Supabase Auth redirect URL | Email confirmation / password reset links opening the app | Dashboard → Authentication → URL Configuration → add `com.closerapp.closer://auth-callback` | 🟡 |
| A5 | Claude GitHub App install | `@claude` from GitHub with laptop off | https://github.com/apps/claude → select `closer` | 🟡 |
| A6 | `CLAUDE_CODE_OAUTH_TOKEN` repo secret | `@claude` workflow | `claude setup-token` on the laptop → GitHub repo Settings → Secrets → Actions | 🟡 |
| A7 | Google / Apple sign-in credentials | Social sign-in buttons | Enable providers in Supabase Auth (Google OAuth client; Apple Services ID + key), then build with `GOOGLE_AUTH_ENABLED=true` / `APPLE_AUTH_ENABLED=true` | 🟡 |
| A8 | Apple Developer + Google Play Console accounts | Store products, sandbox purchases, iOS builds, TestFlight | Owner signs up (paid accounts) | 🟡 (needed by Phase 5/6) |
| A9 | RevenueCat project + API keys + webhook secret | Real purchases (Phase 5) | Create project, connect both stores; public SDK keys go in the app, secret key + webhook auth in Supabase secrets only | 🟡 (Phase 5) |
| A10 | Firebase project (FCM) + APNs key | Push notifications (Phase 5) | `google-services.json` / `GoogleService-Info.plist` and the APNs `.p8` stay out of git (already in `.gitignore`); server credentials in Supabase secrets | 🟡 (Phase 5) |
| A11 | Codemagic account + App Store Connect API key | Hosted iOS builds (Phase 6) | Stored in Codemagic, never in the repo | 🟡 (Phase 6) |
| A12 | Android release keystore | Signed release APK/AAB (Phase 6) | Generate locally, store base64 + passwords as GitHub Secrets | 🟡 (Phase 6) |

## B. Setup steps on the hosted backend (after A1–A3)

| # | Item | Details | Status |
|---|---|---|---|
| B1 | Apply migrations | `npx supabase@2.120.0 db push` (3 migrations so far) | 🔴 |
| B2 | Deploy Edge Functions | `npx supabase@2.120.0 functions deploy cleanup-storage` and `... deploy delete-account` | 🔴 |
| B3 | Schedule cleanup every 10 min | Enable `pg_cron` + `pg_net`, then the SQL in `docs/purchases-and-retention.md` | 🔴 |
| B4 | Verify live flows once connected | Sign-up + email confirm, create/join group, upload photo, retention on the 11th photo, cleanup deletes files, milestones, notifications, avatar upload, account deletion | 🟡 🤝 |

## C. Unverified features (built and tested in code, not yet proven in the real world)

| # | Item | Blocked by | Status |
|---|---|---|---|
| C1 | Email confirmation / password reset deep links open the app | A1, A4, a device | 🟡 |
| C2 | Invite link `com.closerapp.closer://invite?t=…` opens the app on a phone | Physical device | 🟡 |
| C3 | Camera/gallery + compression on a **physical** Android phone | Your phone (emulator already OK) | 🟡 |
| C4 | Anything on iOS (build, camera permissions, links) | Hosted macOS (Phase 6), A8 | 🟡 |
| C5 | Backend tests on the laptop | Docker Desktop did not start; tests run in GitHub Actions only | 🟡 |
| C6 | `@claude` GitHub workflow and phone cloud sessions end-to-end | A5, A6 | 🟡 |
| C7 | Account deletion against a real Supabase Auth project (Edge Function + cascades) | A1–A3, B2 | 🟡 |
| C8 | Avatar upload and signed URLs on a real project | A1–A3 | 🟡 |

## D. Product decisions still open (👤)

| # | Decision | Options / notes | Status |
|---|---|---|---|
| D1 | How to charge the $2 Basic price | Paid app vs one-time non-consumable unlock (decide before Phase 5) | 🟡 |
| D2 | Final prices per region | Configure in the stores; app shows store prices | 🟡 |
| D3 | Repository visibility | Repo is **public**; consider making it private | 🟡 |
| D4 | Bundle id / domain | `com.closerapp.closer` is a placeholder; a real domain is also needed for https invite links (App Links / Universal Links) | 🟡 |
| D5 | Legal documents | In-app privacy/terms are draft summaries; real policy + terms URLs needed before release (`PRIVACY_POLICY_URL`, `TERMS_URL`) | 🟡 |
| D6 | Support email | `SUPPORT_EMAIL` for Help & support | 🟡 |
| D7 | Google/Apple button branding | Monochrome marks used; check provider brand rules before enabling | 🟡 |

## E. Technical follow-ups (🤖, scheduled)

| # | Item | Planned phase | Status |
|---|---|---|---|
| E1 | Byte-level upload progress (currently step-based) | Later / optional | 🟡 |
| E8 | Upcoming-milestone reminders (scheduled job + push) | Phase 5 | 🟡 |
| E9 | Realtime refresh of journals/notifications (now: refresh on open / pull to refresh) | Phase 5 | 🟡 |
| E4 | Store purchase verification + RevenueCat webhook + restore | Phase 5 | 🟡 |
| E5 | Native widgets, push notifications, realtime refresh | Phase 5 | 🟡 |
| E6 | Release signing, Codemagic iOS, TestFlight, hardening | Phase 6 | 🟡 |
| E7 | Merge stacked PRs #1 → #2 → #3 → #4 into `main` (owner merges) | Any time 👤 | 🟡 |

## Resolved

| # | Item | Resolved | How |
|---|---|---|---|
| R1 | GitHub repository created and connected | 2026-10-14 | `AMAN-GUPTA29/closer` |
| R2 | Windows Gradle "loopback connection" build failure | 2026-10-14 | Short TEMP dir; documented in `docs/build-and-release.md` |
| R3 | Kotlin incremental cache failure across drives | 2026-10-14 | `kotlin.incremental=false` |
| R4 | `phosphor_flutter` incompatible with Flutter 3.47 | 2026-10-14 | Switched to Lucide icons |
| R5 | Remote Control for this desktop session | 2026-10-14 | Turned on; session reachable from the Claude app while the laptop is awake |
| R6 | Choose a specific group cover photo (was E2) | 2026-10-14 | Phase 4: `set_group_cover` + Group settings |
| R7 | Deleted photos must not break milestone references, spec §13.14 (was E3) | 2026-10-14 | Phase 4 trigger + pgTAP and Flutter tests |
| R8 | Floating "+" button overlapped "Create a special moment" | 2026-10-14 | Found on emulator; button now only on the Journal tab |
