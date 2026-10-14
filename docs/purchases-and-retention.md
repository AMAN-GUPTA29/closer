# Purchases and retention

**Status:** planned (Phase 3 foundation, Phase 5 store integration). Nothing is purchasable yet;
the `UpgradeCard` component renders disabled with a reason when billing is unavailable.

## Product rules (from the spec)

- **Closer Basic** — pricing hypothesis $2 one-time. A Basic group keeps at most **10 active photos**.
- **Closer Memories** — pricing hypothesis +$10 one-time **per group**. Keeps every photo.
- Product IDs and prices are configuration, not code constants.
- Premium belongs to the **group**: all current and future members get it; other groups are unaffected.
- Retention is enforced **server-side** with concurrency control; a failed upload must never delete
  an existing photo; the oldest eligible photo is removed, not the newest.
- Refund/revocation does not immediately delete photos; a documented grace policy will apply.
- Before implementing purchases: verify current Apple/Google billing rules and choose RevenueCat
  or direct store billing with server-side verification.

Details (functions, tables, webhook flow, grace policy) will be written here as they are built.
