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

## Suites (Phase 1)

| File | Covers |
|---|---|
| `test/core/core_logic_test.dart` | validators, `AppConfig`, greeting, redirect policy for every auth state, `GroupType`, display helpers |
| `test/features/auth_test.dart` | Supabase error-code mapping, unconfigured repository, `AuthController` event handling incl. password recovery and preview gating |
| `test/widgets/components_test.dart` | buttons (enabled/loading/semantics), icon button target size, empty/error/offline states, confirmation dialog, invite-code copy, upgrade card disabled state, group card semantics, milestone reduced motion, photo viewer paging/closing |
| `test/app/app_flow_test.dart` | onboarding → sign up/in, swipe, form validation, wrong password, network error, sign in → tabs → add sheet → profile → sign out, sign-up → verify email + resend cooldown, unconfigured backend + preview, legal page |

`test/helpers/fakes.dart` provides `FakeAuthRepository` and `pumpCloserApp`.

## Not yet covered (needs later phases or external resources)

| Area | Needs |
|---|---|
| Real Supabase sign-up / email confirmation / reset links | Supabase project + email delivery; physical device for deep links |
| Google / Apple OAuth | Provider credentials configured in Supabase |
| Backend RLS / retention / invitation tests (spec §13) | Phase 2–3 + local Supabase (Docker) or a test project |
| Native widgets, push | Phase 5, emulators/devices; iOS needs hosted macOS |
