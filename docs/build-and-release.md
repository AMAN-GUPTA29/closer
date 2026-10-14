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
No local Mac is assumed. CI (`ios-build` job, macOS runner) adds the widget extension with
`ruby ios/scripts/add_widget_extension.rb` and runs `flutter build ios --debug --no-codesign`.
Signed builds and TestFlight come in Phase 6: Codemagic (hosted macOS), App Store Connect API key,
App Group `group.com.closerapp.closer` on the app and extension (ISSUES A11, A14). Requires an
Apple Developer account.

## Android emulator tip
The local emulator is almost out of space. Install a single-ABI debug APK:
`flutter build apk --debug --split-per-abi` → `app-x86_64-debug.apk`.
