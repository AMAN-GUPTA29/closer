# Purchases, entitlements and photo retention

**Status (Phase 3):** retention, Premium entitlements, purchase records and the storage cleanup
queue are implemented and tested on the server. The app has the upgrade screen and a
`PurchaseService` interface, but **store billing is not connected yet** (Phase 5): the upgrade
button is disabled with an explanation and no purchase is ever simulated.

## Product rules

| Plan | What it is | Photos |
|---|---|---|
| Closer Basic | Pricing hypothesis: $2 one-time | Each group keeps its latest **10** active photos |
| Closer Memories | Pricing hypothesis: +$10 one-time **per group** | The group keeps every photo; pinning |

Prices are shown from the store at runtime (`StoreProduct.priceLabel`), never hard-coded.
Product id is configurable: `--dart-define=MEMORIES_PRODUCT_ID=...` (default `closer_memories_group`).

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
- **Basic $2:** to be decided in Phase 5 between a paid app and a one-time non-consumable.
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
- `is_group_premium(group)` = active entitlement, or revoked but still inside the grace period.
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
npx supabase@2.120.0 functions deploy cleanup-storage
```
Then, in the SQL editor (stores the key in Vault, not in a migration):
```sql
select vault.create_secret('<SERVICE_ROLE_KEY>', 'cleanup_service_key');
select cron.schedule('closer-storage-cleanup', '*/10 * * * *', $$
  select net.http_post(
    url := 'https://<PROJECT_REF>.supabase.co/functions/v1/cleanup-storage',
    headers := jsonb_build_object('Authorization', 'Bearer ' ||
      (select decrypted_secret from vault.decrypted_secrets where name = 'cleanup_service_key'))
  );
$$);
```
(Requires the `pg_cron` and `pg_net` extensions enabled in the dashboard.)
