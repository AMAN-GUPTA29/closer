# Open issues — to resolve later

Everything deferred, blocked or unverified, in one place. Updated at every phase.
Claude adds new items as they come up and marks them resolved (with date and how) — items are
never silently deleted. Secrets themselves are **never** written here or in chat.

**Owner:** 👤 = you (needs your account, credentials or decision) · 🤖 = Claude · 🤝 = both
**Status:** 🔴 blocking a feature · 🟡 open · ✅ resolved

_Last updated: 2026-10-14 (after Phase 6). Release order: docs/release-readiness.md §3._

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
| A9 | RevenueCat project + store product `closer_memories_group` (consumable) | Real purchases | Create the product in Play Console + App Store Connect and in RevenueCat. Public SDK keys → build dart-defines `REVENUECAT_ANDROID_KEY` / `REVENUECAT_IOS_KEY` (GitHub repo **variables**). Secret API key + a webhook authorization value you invent → Supabase secrets `REVENUECAT_SECRET_KEY`, `REVENUECAT_WEBHOOK_AUTH` (never in chat). Webhook URL: `https://<PROJECT_REF>.supabase.co/functions/v1/revenuecat-webhook` | 🔴 purchases |
| A10 | Firebase project (FCM) | Push notifications | Add Android app `com.closerapp.closer` and iOS app. Client values → dart-defines `FIREBASE_API_KEY`, `FIREBASE_PROJECT_ID`, `FIREBASE_SENDER_ID`, `FIREBASE_ANDROID_APP_ID`, `FIREBASE_IOS_APP_ID` (repo variables; no config files are committed). A service-account JSON with the FCM role → Supabase secret `FCM_SERVICE_ACCOUNT` | 🔴 push |
| A13 | APNs auth key (.p8) uploaded to Firebase | Push on iPhone | Apple Developer → Keys → APNs; upload in Firebase → Cloud Messaging. Never commit the .p8 | 🔴 iOS push |
| A14 | iOS identifiers with App Group + Push capability | iOS widget data sharing, push | Register `com.closerapp.closer` and `com.closerapp.closer.CloserWidget`, both with App Group `group.com.closerapp.closer`; Push Notifications on the app. Used by Codemagic signing (A11) | 🟡 (Phase 6) |
| A11 | Codemagic account + App Store Connect API key | Signed iOS builds / TestFlight (`codemagic.yaml`) | Connect the repo in Codemagic; add the ASC key as integration **"Closer ASC"**; env groups `closer_signing` (`CERTIFICATE_PRIVATE_KEY`) and `closer_client` (client config + `APP_STORE_APPLE_ID`). Never in the repo | 🔴 iOS release |
| A12 | Android release keystore | Signed AAB/APK (`release.yml`) | Generate with `keytool` on your computer (docs/build-and-release.md). Put `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` in the GitHub **`release` environment** secrets. Back the key up in a password manager; enable Play App Signing | 🔴 Android release |

## B. Setup steps on the hosted backend (after A1–A3)

| # | Item | Details | Status |
|---|---|---|---|
| B1 | Apply migrations | `npx supabase@2.120.0 db push` (4 migrations so far) | 🔴 |
| B2 | Deploy Edge Functions | `npx supabase@2.120.0 functions deploy` for `cleanup-storage`, `delete-account`, `dispatch-push`, `verify-purchase`, and `revenuecat-webhook --no-verify-jwt` | 🔴 |
| B3 | Schedule cleanup every 10 min | Enable `pg_cron` + `pg_net`, then the SQL in `docs/purchases-and-retention.md` | 🔴 |
| B5 | Schedule push dispatch (every minute) + milestone reminders (daily) | SQL in `docs/notifications.md` (`pg_cron` + `pg_net`, Vault secret) | 🔴 push |
| B6 | Enable Realtime for the app tables | The migration adds them to `supabase_realtime`; check Dashboard → Database → Publications after `db push` | 🟡 |
| B7 | Review Supabase Auth settings | Dashboard → Authentication: keep email confirmation on, enable leaked-password protection, check rate limits and the minimum password length (8), set the site URL | 🟡 |
| B4 | Verify live flows once connected | Sign-up + email confirm, create/join group, upload photo, retention on the 11th photo, cleanup deletes files, milestones, notifications, avatar upload, account deletion | 🟡 🤝 |

## C. Unverified features (built and tested in code, not yet proven in the real world)

| # | Item | Blocked by | Status |
|---|---|---|---|
| C1 | Email confirmation / password reset deep links open the app | A1, A4, a device | 🟡 |
| C2 | Invite link `com.closerapp.closer://invite?t=…` opens the app on a phone | Physical device | 🟡 |
| C3 | Camera/gallery + compression on a **physical** Android phone | Your phone (emulator already OK) | 🟡 |
| C4 | Anything on iOS at runtime (camera permissions, links); the unsigned build compiles in CI since Phase 5 | Hosted macOS signing (Phase 6), A8 | 🟡 |
| C5 | Backend tests on the laptop | Docker Desktop did not start; tests run in GitHub Actions only | 🟡 |
| C6 | `@claude` GitHub workflow and phone cloud sessions end-to-end | A5, A6 | 🟡 |
| C7 | Account deletion against a real Supabase Auth project (Edge Function + cascades) | A1–A3, B2 | 🟡 |
| C8 | Avatar upload and signed URLs on a real project | A1–A3 | 🟡 |
| C9 | iOS widget on an iPhone: picker (AppIntent), App Group data, tap opens the group | A8, A14, device | 🟡 |
| C10 | Push delivery on Android + iOS, tap opens the group, background widget refresh, invalid-token cleanup against real FCM | A1–A3, A10, A13, B2, B5, devices | 🟡 |
| C11 | Android widget on a physical phone and other launchers (Samsung, Xiaomi pin dialog / configure step) | Your phone | 🟡 |
| C12 | Sandbox purchase end to end: buy → verify-purchase → Premium for all members; pending; cancel; refund → 30-day grace; restore on a new phone | A1–A3, A8, A9, B2 | 🟡 |
| C13 | Realtime updates between two signed-in devices | A1–A3, B6 | 🟡 |
| C14 | Performance on a low-end Android phone (scroll jank, startup, memory with large journals) | Physical device, profile build | 🟡 |
| C15 | Screen reader pass (TalkBack + VoiceOver) on the main flows | Devices | 🟡 |
| C16 | Signed release workflow + Codemagic TestFlight upload actually run | A11, A12, A14 | 🟡 |

## D. Product decisions still open (👤)

| # | Decision | Options / notes | Status |
|---|---|---|---|
| D1 | How to charge the $2 Basic price | Paid app (no code needed) vs one-time non-consumable unlock (adds a second product). Phase 5 wires only Closer Memories. Decide before release | 🟡 |
| D2 | Final prices per region | Configure in the stores; app shows store prices | 🟡 |
| D3 | Repository visibility | Repo is **public**; consider making it private | 🟡 |
| D4 | Bundle id / domain | `com.closerapp.closer` is a placeholder; a real domain is also needed for https invite links (App Links / Universal Links) | 🟡 |
| D5 | Legal documents | In-app privacy/terms are draft summaries; real policy + terms URLs needed before release (`PRIVACY_POLICY_URL`, `TERMS_URL`) | 🟡 |
| D6 | Support email | `SUPPORT_EMAIL` for Help & support | 🟡 |
| D7 | Google/Apple button branding | Monochrome marks used; check provider brand rules before enabling | 🟡 |
| D8 | Apple review risk: a consumable that unlocks a permanent per-group feature (guideline 3.1.1) | Explain in the App Review notes; fallback options are in docs/release-readiness.md §2 | 🟡 |
| D9 | Store listing content: screenshots, description, Data safety / privacy labels, content rating, demo account for review | Owner fills these in the consoles (checklist in release-readiness.md) | 🟡 |

## E. Technical follow-ups (🤖, scheduled)

| # | Item | Planned phase | Status |
|---|---|---|---|
| E1 | Byte-level upload progress (currently step-based) | Later / optional | 🟡 |
| E11 | Old remote branches `phase-1..4/*` (already merged via PR #5): delete? | Owner decision 👤 | 🟡 |
| E12 | Android emulator `Pixel_8_API_34` is almost full (~0.9 GB free); full debug APK no longer installs, so use `--split-per-abi` | Any time | 🟡 |

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
| R9 | Upcoming-milestone reminders (was E8) | 2026-10-14 | Phase 5: `enqueue_milestone_reminders` + daily job (B5) |
| R10 | Realtime refresh (was E9) | 2026-10-14 | Phase 5: `AppSync` + Supabase Realtime + refresh on resume |
| R11 | Purchase verification, webhook, restore (was E4) | 2026-10-14 | Phase 5: `verify-purchase`, `revenuecat-webhook`, unassigned purchases (live test = C12) |
| R12 | Native widgets, push (was E5) | 2026-10-14 | Phase 5 (device verification = C9–C11) |
| R13 | Stacked PRs not reaching `main` (was E7) | 2026-10-14 | Combined PR #5 merged by the owner; phase PRs now target `main` |
| R14 | Widget tap ignored Preview group ids | 2026-10-14 | Found on emulator; link parser accepts safe short ids |
| R15 | iOS CI "Multiple commands produce .appex" | 2026-10-14 | Widget target `PRODUCT_NAME` set; embed phase before Thin Binary |
| R16 | Release signing, Codemagic iOS, TestFlight config, hardening (was E6) | 2026-10-14 | Phase 6: `release.yml`, `codemagic.yaml`, security review (running them = C16) |
| R17 | Production push entitlement + widget extension for signed iOS builds (was E10) | 2026-10-14 | `codemagic.yaml` switches `aps-environment` and runs the extension script |
| R18 | Large text clipped group actions/onboarding; 44 dp header buttons; danger red below AA | 2026-10-14 | Found by the new accessibility tests; fixed |
| R19 | Widget covers re-downloaded on every group change | 2026-10-14 | Phase 6 performance review: cached by thumbnail path |
| R20 | Android backups could copy the signed-in session | 2026-10-14 | `allowBackup=false` + data-extraction rules |
