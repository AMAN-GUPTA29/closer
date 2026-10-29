# Purchases, entitlements and photo retention

**Status (Phase 3):** retention, Premium entitlements, purchase records and the storage cleanup
queue are implemented and tested on the server. The app has the upgrade screen and a
`PurchaseService` interface, but **store billing is not connected yet** (Phase 5): the upgrade
button is disabled with an explanation and no purchase is ever simulated.

## Product rules

| Plan | What it is | Photos |
|---|---|---|
| Basic | **Free** (owner decision 2026-10-20: the app itself is free) | Each group keeps its latest **10** active photos |
| Keeploom Memories | **Yearly pass per group: $5 / year, ₹449 / year in India** (owner decision 2026-10-20) | The group keeps every photo; pinning |

Prices are set in the stores and shown from the store at runtime (`StoreProduct.priceLabel`),
never hard-coded. Product id is configurable: `--dart-define=MEMORIES_PRODUCT_ID=...`
(default `keeploom_memories_year`; the Edge Functions read the same secret).

## Yearly pass (since 2026-10-20, migration `20261020000008_yearly_memories.sql`)

Store subscriptions belong to one store account, and an account can hold only one active copy
of a subscription, so an auto-renewing subscription cannot be bought once per group. The pass
is therefore sold as a **repeatable one-year product**:

- **Apple:** a *non-renewing subscription* (`keeploom_memories_year`). Apple allows buying it
  again at any time; it does not auto-renew.
- **Google Play:** a one-time *consumable* product with the same id, consumed after the grant.
- RevenueCat reports both as non-subscription purchases (`NON_RENEWING_PURCHASE`), so the
  verify/webhook pipeline below is unchanged.

Server rules (all tested in `supabase/tests/database/011_yearly_memories.test.sql`):
- Each verified purchase adds **one year** to the group's pass (`group_entitlements.expires_at`,
  `premium_period()`). Buying again before it ends extends it from the current end date.
- When the pass ends, the group stays Premium for **30 days** (`premium_grace_days()`) so anyone
  in it can renew. Nothing is deleted. After that, Basic retention applies on the next upload.
- A refund takes back the year that purchase added; if no paid time is left, the refund grace
  applies (see below).
- Entitlements granted before the migration keep `expires_at = null` (permanent).
- `group_summaries.premium_expires_at` lets the app show "Memories until …", a renew prompt in
  the last 30 days, and "ended on … · renew by …" during the grace period.

Renewal reminder push notifications (before the pass ends) are a follow-up (ISSUES E13); the
app already shows the renew prompt in the group's Details tab and on the upgrade screen.

## Billing decision (researched 2026-10-14)

- **Per-group unlock = consumable product.** Apple non-consumables can be bought only once per
  Apple ID, so they cannot unlock several groups. Each Closer Memories purchase is a consumable
  ("unlock one group"); our server records which group it unlocked, keyed by the store
  transaction id. Google Play one-time products are consumed after the grant in the same way.
- **Provider: RevenueCat** (planned for Phase 5). Consumables emit `NON_RENEWING_PURCHASE`
  webhooks with a `transaction_id`; refunds arrive as `CANCELLATION`. Recommended flow: the app
  sends the transaction id + group id to our backend, which verifies it through the RevenueCat
  REST API and calls `grant_group_entitlement`; the webhook acts as an idempotent safety net.
  Webhooks can lag by over a minute, so the app shows a "pending" state until the server confirms.
- **Restore:** stores don't restore consumables, but entitlements live on the server and
  belong to the group, so reinstalling or signing in on a new device restores access
  automatically. "Restore purchases" re-syncs any transactions the server hasn't seen.
- **Basic:** free (ISSUES D1 resolved 2026-10-20). Keeploom Memories is the only charge.

## Store integration (Phase 5)

Product: one repeatable yearly pass, `keeploom_memories_year` (override with `MEMORIES_PRODUCT_ID`), sold
through RevenueCat (`purchases_flutter`). The app's public SDK keys come from dart-defines
`REVENUECAT_ANDROID_KEY` / `REVENUECAT_IOS_KEY`. Without them the purchase buttons stay
disabled, with the label "Purchases aren't available in this build yet". Nothing is ever simulated.

**Buy flow**
1. The app identifies the RevenueCat customer with the Supabase user id and buys the product.
   Cancelled → nothing happens. Pending (e.g. Play "slow card") → "Waiting for the store".
2. The app calls the **`verify-purchase`** Edge Function with `{group_id, transaction_id}`. The
   function (signed-in caller only):
   - looks the transaction up through the RevenueCat REST API (`/v1/subscribers/{user}`
     `non_subscriptions`), so the client's word is never trusted;
   - calls `grant_group_entitlement`.
   Status codes: 200 granted / already granted · 404 not visible yet · 403 not a member ·
   409 transaction already used for another group, or refunded · 400 bad input · 401 not signed in.
3. On 404 the app retries after 2, 4 and 8 s, then shows "pending". The purchase stays recoverable.

**Webhook safety net: `revenuecat-webhook`** (deployed with `--no-verify-jwt`, authenticated by
a constant-time comparison of the `Authorization` header with `REVENUECAT_WEBHOOK_AUTH`):
- `NON_RENEWING_PURCHASE` → `record_store_purchase`. If the app never told us the group, the
  purchase is stored as **unassigned**.
- `CANCELLATION` / `REFUND` → `revoke_group_entitlement` (30-day grace, see below).
- Replays are idempotent (tested).

**Unassigned purchases / restore:** Profile → Purchased groups lists "Unused Closer Memories
purchase". The user picks a group and the app sends it through `verify-purchase` again, so the
same server checks apply. "Restore purchases" asks the store to re-sync, so missed transactions
reach the webhook. Entitlements already live on the server, so a reinstall or a new phone keeps
Premium without any restore.

**Owner setup** (ISSUES A9, B2): create the product in both stores and RevenueCat, then:
```bash
npx supabase@2.120.0 secrets set REVENUECAT_SECRET_KEY=... REVENUECAT_WEBHOOK_AUTH=...
npx supabase@2.120.0 functions deploy verify-purchase
npx supabase@2.120.0 functions deploy revenuecat-webhook --no-verify-jwt
```
RevenueCat → Integrations → Webhooks: URL `https://<PROJECT_REF>.supabase.co/functions/v1/revenuecat-webhook`,
with the same authorization value.
- Verify against the current App Review Guidelines (3.1.1) before submission; App Review notes
  should explain that each consumable unlocks one group permanently.

Sources: RevenueCat event types (https://www.revenuecat.com/docs/integrations/webhooks/event-types-and-fields),
RevenueCat community answer on consumables
(https://community.revenuecat.com/sdks-51/clarification-on-webhooks-and-error-handling-for-in-app-purchases-non-subscription-7073),
Apple developer forums on consumables (https://developer.apple.com/forums/thread/838101).

## Server-side entitlement (authoritative)

- `group_entitlements` (one row per group) + `purchase_records` (unique `(store, transaction_id)`).
- `grant_group_entitlement(group, user, store, product, transaction)` — **service role only**.
  The purchaser must be a member. Idempotent: the same transaction returns `already_granted`;
  a transaction cannot unlock a second group.
- `is_group_premium(group)` = active pass (or ended less than 30 days ago), or revoked but
  still inside the refund grace period.
  All retention decisions read this; there is no client-writable Premium flag (tested).
- Premium belongs to the group: every member, including people who join later, gets it; other
  groups are unaffected (tested).

### Refunds and revocation (grace policy)

`revoke_group_entitlement(store, transaction)` (service role, idempotent):
1. Marks the purchase `refunded` and the entitlement `revoked` with `grace_until = now + 30 days`.
2. **No photos are deleted at revocation.** During the 30 days the group behaves as Premium.
3. After the grace period the group is Basic again: the next upload trims it to the newest 10
   photos (oldest removed first, pinned photos last). Members are warned in the app before
   sharing into a full Basic group.

## Basic retention (server-side)

Implemented in `finalize_photo` → `apply_retention`:

1. The new photo's original and thumbnail must already exist in storage (`upload_incomplete`
   otherwise) — a failed or abandoned upload never removes anything (tested).
2. The group row is locked (`for update`) so concurrent uploads are serialised (tested with
   3 parallel uploads into a full group: exactly 10 remain, the 3 oldest removed).
3. The photo becomes `active`; then, if the group is not Premium, the oldest eligible active
   photos above 10 are marked `removed` (`removed_reason = 'retention'`). Order: unpinned before
   pinned, then oldest `uploaded_at`, then id.
4. Their storage objects are queued in `storage_cleanup_jobs`; the response lists the removed
   ids so the app can report it ("The oldest photo was removed to keep 10").

Removed photos disappear from queries and their objects stop being readable immediately (RLS),
before the files are physically deleted. Permanently deleted photos are not recoverable, and the
app says so.

## Storage cleanup (keeping PostgreSQL and Storage consistent)

| Situation | What happens |
|---|---|
| Photo removed by retention / deleted by a user | Row marked `removed`; both objects queued |
| Upload abandoned (pending > 24 h) | `expire_stale_uploads()` marks it removed and queues objects |
| Group deleted (owner, last member leaving, account deletion) | `groups_before_delete_cleanup` trigger queues every photo's objects before rows cascade |

`storage_cleanup_jobs` is a durable queue with a unique `(bucket, path)`:
- `claim_cleanup_jobs(limit)` leases due jobs with `FOR UPDATE SKIP LOCKED` (5-minute lease; a
  crashed worker's jobs are reclaimed).
- `complete_cleanup_job(id, ok, error)` → `done`, or back to `queued` with exponential backoff
  (1, 2, 4… minutes, max 6 h). After 10 failed attempts the job is `dead` and kept for inspection.
- Deleting an already-missing object counts as success, so retries are safe.
- Worker: Edge Function `supabase/functions/cleanup-storage` (service role from the Supabase
  runtime; logs counts only). The app also pings it after an upload removed photos.

### Scheduling the worker (owner action on the hosted project)

```bash
npx supabase@2.120.0 functions deploy cleanup-storage --no-verify-jwt
```
Scheduled calls authenticate with **`closer_cron_secret`**, a random value that migration 5
generates inside the database's Vault. Nobody copies it. The functions check it with
`check_cron_secret()` and are deployed with `verify_jwt = false`, because the new `sb_secret_`
API keys are not JWTs. Run the SQL with `npx supabase@2.120.0 db query --linked -f <file>` or
paste it into the SQL editor.
```sql
create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;
select cron.schedule('closer-storage-cleanup', '*/10 * * * *', $$
  select net.http_post(
    url := 'https://<PROJECT_REF>.supabase.co/functions/v1/cleanup-storage',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets
                                     where name = 'closer_cron_secret'),
      'Content-Type', 'application/json'),
    body := '{}'::jsonb
  );
$$);
```
**Live (2026-10-15):** scheduled on project `yvompyeqlhjzhrogodqp`. A test call returned 200.
