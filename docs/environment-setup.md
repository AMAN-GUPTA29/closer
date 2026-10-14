# Environment setup

## Tools

| Tool | Version used |
|---|---|
| Flutter | 3.47.4 stable (Dart 3.13.3) |
| Java | 17 (Temurin in CI; Android Studio JBR locally) |
| Android SDK | platform 36, build-tools 36 |
| Supabase CLI | needed from Phase 2 |
| Docker | optional, for local Supabase in Phase 2+ |

## App configuration

Values are passed at build time with `--dart-define` / `--dart-define-from-file=.env`.
See [`.env.example`](../.env.example).

| Key | Required | Notes |
|---|---|---|
| `SUPABASE_URL` | for sign-in | `https://<ref>.supabase.co` |
| `SUPABASE_ANON_KEY` | for sign-in | publishable/anon key (client-safe) |
| `GOOGLE_AUTH_ENABLED` / `APPLE_AUTH_ENABLED` | no | `true` only after enabling the provider in Supabase |
| `PRIVACY_POLICY_URL` / `TERMS_URL` | before release | https only; otherwise in-app draft summaries are shown |
| `SUPPORT_EMAIL` | no | enables Profile → Help & support |
| `AUTH_REDIRECT_URL` | no | default `com.closerapp.closer://auth-callback` |

Without Supabase values the app runs in "Backend not connected" mode (debug builds offer a preview).

## Supabase project (owner action)

1. Create a project at supabase.com (free tier is fine for development).
2. Project Settings → API: copy **Project URL** and **anon/publishable key** into `.env`
   (and into GitHub repo *variables* for CI APKs).
3. Authentication → URL Configuration → **Redirect URLs**: add `com.closerapp.closer://auth-callback`.
4. Authentication → Providers → Email: keep "Confirm email" on.
5. Do **not** share the service-role key in chat or commit it. Phase 2 will explain where it goes
   (Supabase CLI login / GitHub Secret) if needed.
