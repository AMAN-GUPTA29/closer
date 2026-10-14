# Closer

> Your people. Your moments. Always close.

Closer is a private photo-sharing app and shared journal for couples, friends and families,
built with Flutter (Android + iOS) and Supabase. The full build is split into six phases;
progress is tracked in [TRACKER.md](TRACKER.md).

**Status:** Phase 2 — groups, memberships and group-specific invitations on Supabase (with RLS
and database tests), on top of the Phase 1 design system, auth and navigation. Photos, journal,
widgets and purchases arrive in later phases (see [docs/known-limitations.md](docs/known-limitations.md)).

## Quick start

```bash
flutter pub get
cp .env.example .env          # fill in your Supabase URL + anon key (optional)
flutter run --dart-define-from-file=.env
```

Without a `.env` the app runs in **backend-not-connected** mode: sign-in is disabled and,
in debug builds only, a "Preview the app" button lets you explore the UI.

## Checks

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
```

## Get the Android APK from GitHub

Every push runs the **CI** workflow. Open the repo on GitHub → **Actions** → latest **CI** run →
**Artifacts** → `closer-debug-apk-…` → download, unzip, install `app-debug.apk` on your phone
(allow "install unknown apps" for your browser/files app). Details: [docs/build-and-release.md](docs/build-and-release.md).

## Documentation

| Doc | What it covers |
|---|---|
| [CLAUDE.md](CLAUDE.md) | Working rules for Claude sessions (local, cloud, GitHub) |
| [TRACKER.md](TRACKER.md) | Step-by-step progress tracker |
| [docs/product-requirements.md](docs/product-requirements.md) | What Closer does |
| [docs/architecture.md](docs/architecture.md) | Code structure and decisions |
| [docs/design-system.md](docs/design-system.md) | Tokens, components, reference image |
| [docs/database.md](docs/database.md) | Schema and migrations |
| [docs/security.md](docs/security.md) | RLS, storage, secrets |
| [docs/purchases-and-retention.md](docs/purchases-and-retention.md) | Basic vs Closer Memories |
| [docs/widget-implementation.md](docs/widget-implementation.md) | Native home-screen widgets |
| [docs/testing.md](docs/testing.md) | Test strategy and commands |
| [docs/environment-setup.md](docs/environment-setup.md) | Tools, Supabase, env values |
| [docs/build-and-release.md](docs/build-and-release.md) | APK, iOS, signing |
| [docs/remote-development.md](docs/remote-development.md) | Driving work from your phone |
| [docs/known-limitations.md](docs/known-limitations.md) | What is not done yet |
