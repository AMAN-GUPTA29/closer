# Notifications, push and realtime sync

**Status (Phase 5):** built and tested in code. The queue and functions passed pgTAP and Deno
tests in CI. No push has been delivered to a real device yet: that needs a Firebase project and,
for iOS, an APNs key (ISSUES A10, C10).

## Pipeline

```
photo / member / milestone trigger ─▶ notifications row (push_status = pending)
reminder job (daily)               ─▶ milestone_upcoming rows
dispatch-push (every minute)       ─▶ claim_push_batch → FCM HTTP v1 → complete_push
```

- `notifications` keeps the in-app list (Phase 4). Phase 5 adds `push_status`, `push_attempts`,
  `push_next_at` and `push_lease_until`, which clients can't see (column grants).
- `claim_push_batch(limit)` (service role) leases pending rows with `for update skip locked`.
  Concurrent or repeated runs never send twice. It skips users who turned off push or have no
  devices.
- `complete_push(id, outcome, invalid_tokens)` marks a row `sent`, `skipped` or `retry`, with
  backoff of 1, 2, 4 … minutes. After 6 attempts the push is marked `failed`. It also deletes tokens that FCM reports as unregistered.
- **Payloads carry names only**: "Alex shared a photo in Our Family". No captions, photo URLs or
  journal text. The data part has `type`, `group_id` and `notification_id`.
- `enqueue_milestone_reminders(date)` creates one `milestone_upcoming` notification per member
  for milestones dated tomorrow. It respects the `reminders` preference and is idempotent per day.

## Devices

- `register_device(token, platform, app_version)` / `unregister_device(token)` (signed-in users).
  A token belongs to one user. Re-registering moves it, which covers a phone changing hands.
  Users can have at most 10 devices; the oldest are dropped.
- The app registers on sign-in and on token refresh, and unregisters on sign-out.

## App

- `FirebasePushService` starts only when `FirebaseConfig.isConfigured`. Otherwise
  `NoopPushService` is used and the app works without push.
- Tapping a notification opens its group. Foreground messages refresh data.
- Android notification channel: `closer_moments` (high importance, so it pops up). The status-bar icon is the white heart `ic_stat_closer`, in brand rose.
- `AppSync` (wraps the router) refreshes groups, journal and notifications on resume, on push and
  on Supabase Realtime changes to `photos`, `milestones`, `notifications` and `group_members`.
  Realtime respects RLS, so users only receive changes for their own groups.
- Preferences (Profile → Notification preferences): `push` and `reminders`, plus the per-type
  switches from Phase 4.

## Configuration (owner)

Firebase client config is passed as dart-defines. No `google-services.json` /
`GoogleService-Info.plist` is committed:

```bash
flutter build apk --dart-define=FIREBASE_API_KEY=... --dart-define=FIREBASE_PROJECT_ID=... \
  --dart-define=FIREBASE_SENDER_ID=... --dart-define=FIREBASE_ANDROID_APP_ID=... \
  --dart-define=FIREBASE_IOS_APP_ID=...
```

Server side (never committed):

```bash
npx supabase@2.120.0 secrets set FCM_SERVICE_ACCOUNT="$(cat service-account.json)"
npx supabase@2.120.0 functions deploy dispatch-push --no-verify-jwt
```

Scheduled calls authenticate with **`closer_cron_secret`**, a random value that migration 5
generates inside the database's Vault. Nobody copies it. The functions check it with
`check_cron_secret()` and are deployed with `verify_jwt = false`, because the new `sb_secret_`
API keys are not JWTs. Run the SQL with `npx supabase@2.120.0 db query --linked -f <file>` or
paste it into the SQL editor.

```sql
select cron.schedule('closer-dispatch-push', '* * * * *', $$
  select net.http_post(
    url := 'https://<PROJECT_REF>.supabase.co/functions/v1/dispatch-push',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets
                                     where name = 'closer_cron_secret'),
      'Content-Type', 'application/json'),
    body := '{}'::jsonb
  );
$$);
-- 03:30 UTC = 09:00 IST
select cron.schedule('closer-milestone-reminders', '30 3 * * *',
  $$ select public.enqueue_milestone_reminders(); $$);
```
**Live (2026-10-15):** reminders are scheduled. Push dispatch will be scheduled once Firebase is set up.

For iOS, upload the APNs auth key (.p8) to Firebase → Project settings → Cloud Messaging.
`Runner.entitlements` declares `aps-environment` as `development`; release signing switches it to
`production` (Phase 6).
