# Build and release

## Android debug APK

### Local (Windows)
```bash
flutter build apk --debug
# → build/app/outputs/flutter-apk/app-debug.apk
```
If Gradle fails with `Unable to establish loopback connection`, the JDK cannot create its socket
in a long TEMP path. Use a short temp dir for that shell (PowerShell):
```powershell
$env:TMP='C:\gtmp'; $env:TEMP='C:\gtmp'; $env:JAVA_TOOL_OPTIONS='-Djdk.net.unixdomain.tmpdir=C:\gtmp'
```

### From GitHub (works with the laptop off)
`.github/workflows/ci.yml` runs on every push to `main` / `phase-*` branches and on PRs.
Jobs:
- Flutter format, analyze and test;
- pgTAP database tests, concurrency scripts and `db lint`;
- Edge Function fmt, lint, type-check and tests;
- gitleaks secret scan over the full history;
- unsigned iOS build with the widget extension;
- release App Bundle build (catches R8 problems);
- debug APK uploaded as artifact `closer-debug-apk-<sha>` (kept 14 days).

All third-party actions are pinned to commit SHAs, and every workflow has least-privilege
`permissions`. Dependabot (`.github/dependabot.yml`) opens weekly update PRs for pub, Gradle and
Actions. CI must pass and the owner merges.

To install on your phone:
1. GitHub app/browser → repo → **Actions** → newest green **CI** run.
2. **Artifacts** → `closer-debug-apk-…` (downloads a .zip; open it in a browser if the GitHub
   mobile app can't download artifacts).
3. Unzip → tap `app-debug.apk` → allow "Install unknown apps" for that app → Install.

The CI APK connects to Supabase only if repository **variables** `SUPABASE_URL` and
`SUPABASE_ANON_KEY` are set (Settings → Secrets and variables → Actions → Variables).

## Android release (signed, for Google Play)

**One-time (owner, on your own computer, never in chat):**
```bash
keytool -genkeypair -v -keystore closer-release.jks -alias closer -keyalg RSA -keysize 4096 -validity 10000
base64 -w0 closer-release.jks > closer-release.jks.b64   # PowerShell: [Convert]::ToBase64String([IO.File]::ReadAllBytes("closer-release.jks"))
```
Keep the `.jks` and passwords in a password manager. **Losing them means you can't update the
app** (unless you use Play App Signing, which is recommended: upload this key as the *upload key*).

GitHub → Settings → Environments → create **`release`** (optionally require your approval).
Add these secrets there:
`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`,
`ANDROID_KEY_PASSWORD`. The client config goes in repository **variables** (see
`.env.example`): `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `FIREBASE_*`, `REVENUECAT_ANDROID_KEY`,
`PRIVACY_POLICY_URL`, `TERMS_URL`, `SUPPORT_EMAIL`.

**Build:** Actions → **Release** → *Run workflow*, or push a tag `v1.0.0`. The workflow:
- fails early without the keystore or `SUPABASE_URL`;
- builds `app-release.aab` and `app-release.apk` (build number = run number);
- checks that neither is signed with the debug key, then deletes the keystore from the runner;
- uploads both as the artifact `closer-release-<n>` (30 days).

Upload the `.aab` in Play Console (internal testing track first).

**Locally:** `android/key.properties` (git-ignored) with `storeFile`, `storePassword`,
`keyAlias` and `keyPassword`. Without it, `flutter build apk --release` falls back to the debug
key for local testing only. Play rejects those builds.

The release build uses R8 shrinking. A release APK was built and launched on the emulator
(2026-10-14) without crashes.

## iOS

No local Mac is assumed.
- **CI** (`ios-build`, macOS runner): `ruby ios/scripts/add_widget_extension.rb` adds the widget
  extension and the privacy manifests, then `flutter build ios --debug --no-codesign` builds it.
- **Signed / TestFlight:** `codemagic.yaml` workflow `ios-release` (on tags `v*`) does these steps:
  - adds the extension;
  - switches `aps-environment` to `production`;
  - fetches App Store signing files for the app and `…CloserWidget`;
  - builds the IPA with the client config;
  - uploads to TestFlight.

  Setup steps are in the file header (ISSUES A8, A11, A14). **Not run yet**, because it needs your
  Apple and Codemagic accounts.
- Privacy manifests: `ios/Runner/PrivacyInfo.xcprivacy` (no tracking; the data types the app
  uses) and `ios/CloserWidget/PrivacyInfo.xcprivacy`. Check them against your App Store privacy
  answers.

## Android emulator tip
The local emulator is almost out of space. Install a single-ABI debug APK:
`flutter build apk --debug --split-per-abi` → `app-x86_64-debug.apk`.
