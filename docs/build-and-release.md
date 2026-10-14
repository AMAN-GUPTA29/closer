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
`.github/workflows/ci.yml` runs on every push to `main` / `phase-*` branches and on PRs:
format → analyze → test → build debug APK → upload artifact `closer-debug-apk-<sha>` (kept 14 days).

To install on your phone:
1. GitHub app/browser → repo → **Actions** → newest green **CI** run.
2. **Artifacts** → `closer-debug-apk-…` (downloads a .zip; open it in a browser if the GitHub
   mobile app can't download artifacts).
3. Unzip → tap `app-debug.apk` → allow "Install unknown apps" for that app → Install.

The CI APK connects to Supabase only if repository **variables** `SUPABASE_URL` and
`SUPABASE_ANON_KEY` are set (Settings → Secrets and variables → Actions → Variables).

## Android release (Phase 6)
Release signing via keystore stored in GitHub Secrets, never committed. Not set up yet.

## iOS (Phase 5–6)
No local Mac is assumed. Plan: Codemagic (hosted macOS) with App Store Connect API key,
App Group + widget extension entitlements, TestFlight upload. Requires an Apple Developer
account. Not set up yet.
