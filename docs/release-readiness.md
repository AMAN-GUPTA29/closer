# Release readiness (Phase 6, 2026-10-14)

**Verdict: the code is release-candidate quality, but the app is not ready for store submission.**
All features are built and tested with fakes, a local database and emulators/CI. A real release
first needs your accounts and backend (Supabase, Firebase, RevenueCat, Apple, Google Play), legal
pages and a pass on physical devices. The ordered steps are below. Details for each item are in
[ISSUES.md](../ISSUES.md).

Legend: ✅ verified · ⚠️ built, not verifiable here · 🔒 blocked on an owner account or decision

## 1. Status by area

| Area | Status | Evidence |
|---|---|---|
| Flutter app (all spec screens) | ✅ | 167 widget/unit tests, emulator walk-throughs in Phases 1–5 |
| Accessibility | ✅ (automated) | 200 % text on 18 signed-in screens + signed-out flow, tap-target/label/contrast guidelines (`test/app/accessibility_test.dart`) |
| Database, RLS, trusted functions | ✅ (local Postgres in CI) | 7 pgTAP files, 2 concurrency scripts, `db lint` |
| Edge Functions | ✅ (unit) | 32 Deno tests, type-checked |
| Android debug + release build | ✅ | CI artifacts; release APK launched on emulator (R8) |
| Android widget | ✅ emulator / ⚠️ phone | Phase 5 emulator check (C11) |
| iOS build + widget extension | ✅ compiles / ⚠️ runtime | CI unsigned build (C4, C9) |
| Hosted Supabase project | 🔒 | A1–A3, B1–B7 |
| Push notifications | ⚠️ 🔒 | A10, A13, B5, C10 |
| Store purchases | ⚠️ 🔒 | A8, A9, C12 |
| Signed Android release | ⚠️ 🔒 | `release.yml` ready, needs keystore secrets (A12) |
| Signed iOS / TestFlight | ⚠️ 🔒 | `codemagic.yaml` ready, needs A8, A11, A14 |
| Legal (privacy policy, terms) | 🔒 | D5; in-app texts are drafts |
| Secret hygiene | ✅ | gitleaks on full history in CI, nothing sensitive committed |

## 2. Reviews done in Phase 6

**Security** (details in [security.md](security.md#phase-6-review-2026-10-14)): new pgTAP 007
schema invariants; Android backups disabled; widget configure activity hardened; iOS privacy
manifests; `@claude` workflow limited to owner/collaborators; secret scanning; protected release
environment. No open high-severity findings.

**Purchases and retention:**
- The client can't grant Premium. Every grant goes through `verify-purchase`
  (RevenueCat REST) or the authenticated webhook into `grant_group_entitlement`, which is
  idempotent, member-only and one transaction per group (pgTAP 004/006, Deno).
- Retention runs on the server at upload time (newest 10 for Basic, pinned photos last). Refunds
  get a 30-day grace period, and no photos are deleted when a purchase is revoked.
- Purchases whose group is unknown are kept as "unassigned" rather than lost.
- **Risk:** Apple may question a *consumable* that unlocks a permanent feature (guideline
  3.1.1). This model is the only way to sell one unlock per group under one Apple ID. Explain it
  in the App Review notes, and keep a fallback ready (e.g. a per-group subscription) (ISSUES D8).
- **To verify in the sandbox:** RevenueCat consumes the Play product after the grant, so the same
  product can be bought again for another group (C12).

**Performance:**
- Grids and widgets use thumbnails (480 px); full images load only in the viewer.
- Lists are lazy and keyset-paginated (20 per page).
- Widget covers are now cached by thumbnail path. Before this review, every group-list change
  re-downloaded every cover (fixed, tested).
- Release build: about 25 MB per ABI APK.
- Not measured: frame timings on a real low-end phone (C14).

**Accessibility (fixed in this review):**
- At 200 % text, the group action row and the couple counter clipped, and the onboarding pages
  overflowed.
- The group header back/settings buttons were 44 dp; they are now 48 dp.
- The danger red was 4.38:1 on light surfaces; it is now #C53030, which meets WCAG AA.
- All are covered by tests now.
- Still to do by hand: a TalkBack / VoiceOver pass on a device (C15).

## 3. Launch checklist (owner, in order)

1. **Backend:**
   - create the Supabase project (A1–A3) and apply the migrations (B1);
   - deploy the 5 Edge Functions and set their secrets (B2);
   - schedule cleanup, push and reminders (B3, B5);
   - set the Auth redirect URL (A4) and review the Auth settings (B7).
2. **Legal + support:** publish a privacy policy and terms (D5) and choose a support email (D6),
   then set `PRIVACY_POLICY_URL`, `TERMS_URL` and `SUPPORT_EMAIL`.
3. **Identity:** decide the final bundle id / domain (D4) **before** creating store listings.
   It can't be changed afterwards.
4. **Push:** Firebase project (A10), APNs key (A13).
5. **Stores:**
   - Google Play and Apple Developer accounts (A8);
   - the `closer_memories_group` product in both stores plus RevenueCat (A9);
   - decide Basic pricing (D1).
6. **Signing:**
   - Android keystore into the `release` environment (A12);
   - Codemagic + App Store Connect key + identifiers with the App Group (A11, A14).
7. **Test builds:** run **Release** (Play internal testing) and Codemagic `ios-release`
   (TestFlight), then work through the device checks C1–C3, C7–C15 on a real Android phone
   and an iPhone.
8. **Store listings:**
   - screenshots;
   - Play *Data safety* and App Store *privacy labels*, matching `PrivacyInfo.xcprivacy`
     (account data, photos, user content, purchases; no tracking, no ads);
   - content rating;
   - App Review notes: a demo account, how invites work, what the consumable unlocks.
9. **Go:** staged rollout on Play, phased release on the App Store.

## 4. Store policy checklist

| Requirement | State |
|---|---|
| In-app account deletion (Apple 5.1.1(v), Play) | ✅ Profile → Delete account (typed confirmation, server-side) |
| Restore purchases button (Apple 3.1.1) | ✅ Upgrade screen + Profile → Purchased groups |
| Prices shown from the store, not hard-coded | ✅ `StoreProduct.priceLabel` |
| Sign in with Apple when offering Google sign-in (Apple 4.8) | 🔒 Both are disabled until configured (A7). Enable them together |
| Privacy manifest (iOS 17+) | ✅ app + widget, review before submission |
| Permission strings (camera, photos) | ✅ `Info.plist` |
| Push permission asked in context, not at first launch | ✅ asked after sign-in |
| Android 13+ notification permission | ✅ requested through firebase_messaging |
| Target SDK requirements | ✅ Flutter 3.47 default `targetSdk` |
| Data safety / privacy labels | 🔒 owner fills in the store consoles (step 8) |
