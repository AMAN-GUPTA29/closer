# CLAUDE.md — Closer

Closer is a private photo-sharing and shared-journal app for couples, friends and families
(Flutter + Supabase, native Android/iOS widgets). Tagline: *Your people. Your moments. Always close.*

## Working rules (apply to local, cloud and GitHub-Action sessions)

- **Tracker first.** `TRACKER.md` is the source of truth for progress. Tick an item only after it is
  implemented *and* verified. Use ⚠️ for implemented-but-unverifiable and 🔒 for credential-blocked items.
  Add a dated line to its change log for every meaningful update.
- **Six gated phases.** Work only inside the current phase shown in `TRACKER.md`. At the end of a phase:
  run checks, update docs + tracker, write the checkpoint report, and ask
  "Phase N is complete and tested to the extent possible. Shall I proceed to Phase N+1?" — then stop
  until the owner approves.
- **Honesty.** Never claim tests, builds, integrations, commits or deployments that did not actually happen.
- **Git.** Never force-push or rewrite `main`. Do phase work on `phase-N/<topic>` branches, open a PR into
  `main`, and let the owner merge (or merge only when the owner says so). Commit messages: imperative mood.
- **Secrets.** Never commit secrets. Only `.env.example` with placeholders. Supabase service-role keys,
  store keys, APNs/FCM credentials, signing keys live in GitHub Secrets / Supabase secrets only.
- **Security.** Never trust the client for membership, roles, capacity, photo count or Premium.
  Enforce with RLS + trusted server code (Postgres functions / Edge Functions).
- **Design.** The reference board is `Closer App UI Concept Board.png` (repo root; copy in `docs/design/`).
  Use the tokens and components in `lib/core/theme` and `lib/core/widgets`; no default-looking screens.

## Commands

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
```

Flutter is pinned to **3.47.4** (stable). Cloud sessions install it via `scripts/cloud-setup.sh`.

## Layout

See `docs/architecture.md`. Feature-first: `lib/app`, `lib/core/*`, `lib/features/<feature>/{data,domain,presentation}`.
Backend lives in `supabase/` (migrations, functions, tests).

## Remote development

See `docs/remote-development.md` (Claude mobile app cloud sessions and `@claude` on GitHub).
