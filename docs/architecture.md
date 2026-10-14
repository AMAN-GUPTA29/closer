# Architecture

## Repository audit (Phase 1, 2026-10-14)

- `F:\closer` initially contained only `Closer App UI Concept Board.png` (no Git, no code).
- No earlier couple-widget reference image was present; only the one board exists.
- Git initialised on `main`, remote `https://github.com/AMAN-GUPTA29/closer` (public repo).
- Toolchain: Flutter 3.47.4 / Dart 3.13.3 (stable), Java 17, Android SDK 36.

## Stack

| Layer | Choice | Why |
|---|---|---|
| App | Flutter, sound null safety | One codebase for Android + iOS |
| State | Riverpod 3 (`flutter_riverpod`) | Testable providers, easy overrides |
| Routing | GoRouter 18 | Declarative redirects, deep links, `StatefulShellRoute` |
| Backend | Supabase (Auth, Postgres + RLS, private Storage, Realtime, Edge Functions) | Spec requirement; no extra backend |
| Icons | Lucide (`lucide_icons_flutter`) + a few Material rounded fills | Maintained; Phosphor 2.1 no longer compiles on Flutter 3.47 (`IconData` is final) |
| Fonts | Plus Jakarta Sans (UI) + Fraunces (display), bundled, OFL | No runtime font downloads |
| Brand marks | Simple Icons SVGs via `flutter_svg` (CC0) | Google/Apple buttons |

## Folder structure

```
lib/
  main.dart                 # bootstrap: config → Supabase.initialize (if configured) → ProviderScope
  app/app.dart              # MaterialApp.router, themes, localisation
  core/
    config/app_config.dart  # --dart-define values (client-safe only)
    errors/app_failure.dart # sealed, user-presentable failures
    models/group_type.dart  # couple / friends / family
    routing/                # routes.dart (paths + pure redirect policy), app_router.dart
    theme/                  # colours, tokens, typography, icons, ThemeData
    utils/                  # validators, greeting
    widgets/                # design-system components (see design-system.md)
  features/
    auth/{domain,data,application,presentation}
    onboarding/ home/ journal/ notifications/ profile/ legal/ shell/
    dev/component_gallery_screen.dart   # debug-only
test/
  core/ features/ widgets/ app/ helpers/
  flutter_test_config.dart  # loads real fonts for realistic layout in tests
```

Features follow `domain` (models) → `data` (repositories talking to Supabase) → `application`
(Riverpod providers/notifiers) → `presentation` (screens/widgets). Sensitive business rules live
in the database / Edge Functions, never only in Flutter.

## Auth & routing

- `AuthRepository` interface with `SupabaseAuthRepository` and `UnconfiguredAuthRepository`
  (used when no Supabase config is present → UI shows "Backend not connected").
- `AuthController` (Notifier) turns Supabase auth events into `AuthStatus`:
  `SignedOut`, `SignedIn(user)`, `PasswordRecovery(user)`, `PreviewSession` (debug-only, no backend).
- `resolveRedirect(status, path)` is a pure function (unit tested) used by GoRouter's redirect;
  the router refreshes through a `ValueNotifier` fed by the controller.
- PKCE auth flow. Callback deep link `com.closerapp.closer://auth-callback` registered in
  `AndroidManifest.xml` and `Info.plist`.

## Routes

| Path | Screen | Access |
|---|---|---|
| `/welcome` | Onboarding | public |
| `/auth/sign-up`, `/auth/sign-in`, `/auth/forgot-password`, `/auth/verify-email` | Auth | public |
| `/auth/update-password` | New password after reset link | recovery session only |
| `/legal/privacy`, `/legal/terms` | Legal summaries | always |
| `/home`, `/journal`, `/notifications`, `/profile` | Shell tabs | signed in |
| `/home/create` | Create group | signed in |
| `/home/join?t=...` or `?code=...` | Join group (preview + join) | signed in |
| `/home/groups/:id` (+ `/invite`, `/members`, `/settings`) | Group home and management | members |
| `/dev/components` | Component gallery | debug builds only |

## Groups and invitations (Phase 2)

- `GroupsBackend` (= `GroupsRepository` + `InvitationsRepository`) with three implementations:
  `SupabaseGroupsRepository` (RLS reads, RPC mutations), `InMemoryGroupsRepository` (debug Preview
  mode and widget tests; mirrors server rules) and `UnconfiguredGroupsRepository`.
- Riverpod: `myGroupsProvider`, `groupProvider(id)`, `groupMembersProvider(id)`,
  `invitationsProvider(id)`; mutations go through `GroupActions`, which invalidates what changed.
  Global `retry: null`: screens show explicit retry buttons instead of silent retries.
- Invite deep links: Flutter's built-in deep linking is disabled (`flutter_deeplinking_enabled`
  / `FlutterDeepLinkingEnabled` = false). `InviteLinkListener` (app_links) stores the secret in
  `pendingInviteProvider`; the router redirects signed-in users to Join. Auth callbacks are
  handled by supabase_flutter.
- Group screens are child routes of `/home` on the root navigator, so they cover the bottom bar
  while Home stays underneath for back navigation.

## Identifiers

- Android `applicationId` / iOS bundle id: `com.closerapp.closer` (placeholder org; change before
  store submission if you own a different domain — also update the deep-link scheme).

## Decisions log

| Date | Decision |
|---|---|
| 2026-10-14 | Lucide icons instead of Phosphor (Phosphor incompatible with Flutter 3.47). |
| 2026-10-14 | Bundle fonts instead of `google_fonts` runtime fetching (privacy, offline). |
| 2026-10-14 | Debug-only Preview mode when no backend is configured, so the UI can be reviewed on a phone before Supabase exists. Never available in release builds. |
| 2026-10-14 | Android `kotlin.incremental=false` (Windows cross-drive Kotlin cache bug). |
| 2026-10-14 | Light + dark themes from the same semantic tokens; system setting decides. |
| 2026-10-14 | Roles are `owner` and `member`. Any member may invite; only the owner manages settings, members and deletion. |
| 2026-10-14 | Owner leaving: the longest-standing member becomes owner automatically; the last member leaving deletes the group. |
| 2026-10-14 | Invitation secrets are stored hashed and shown once, instead of re-displayable codes. |
| 2026-10-14 | Cover photo upload deferred to Phase 3 (needs private storage). |
