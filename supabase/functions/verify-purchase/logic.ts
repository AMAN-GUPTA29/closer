// Verifies a Closer Memories purchase with RevenueCat and grants it to a group.

export type Store = "app_store" | "play_store";

export interface NonSubscriptionTransaction {
  id: string;
  store_transaction_id: string;
  purchase_date: string;
  store: string;
}

export interface VerifyDeps {
  /** Signed-in user id from the caller's JWT, or null. */
  userIdFromToken(token: string): Promise<string | null>;
  /** RevenueCat: the user's non-subscription purchases for a product. */
  transactions(
    appUserId: string,
    productId: string,
  ): Promise<NonSubscriptionTransaction[]>;
  /** Calls grant_group_entitlement; throws Error('closer:<key>') on refusal. */
  grant(args: {
    groupId: string;
    userId: string;
    store: Store;
    productId: string;
    transactionId: string;
    purchasedAt: string;
  }): Promise<"granted" | "already_granted">;
}

export interface VerifyRequest {
  group_id?: unknown;
  transaction_id?: unknown;
  product_id?: unknown;
}

export type VerifyResult = { status: number; body: Record<string, string> };

/** Maps RevenueCat store names to ours. */
export function mapStore(store: string): Store | null {
  switch (store) {
    case "app_store":
    case "mac_app_store":
      return "app_store";
    case "play_store":
      return "play_store";
    default:
      return null;
  }
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export async function verifyPurchase(
  deps: VerifyDeps,
  authorization: string | null,
  req: VerifyRequest | null,
  allowedProductId: string,
): Promise<VerifyResult> {
  const token = authorization?.match(/^Bearer\s+(.+)$/i)?.[1];
  if (!token) return { status: 401, body: { error: "not_authenticated" } };

  const groupId = req?.group_id;
  const transactionId = req?.transaction_id;
  const productId = req?.product_id;
  if (
    typeof groupId !== "string" || !UUID.test(groupId) ||
    typeof transactionId !== "string" || transactionId.length === 0 ||
    transactionId.length > 200 || productId !== allowedProductId
  ) {
    return { status: 400, body: { error: "invalid_request" } };
  }

  const userId = await deps.userIdFromToken(token);
  if (!userId) return { status: 401, body: { error: "not_authenticated" } };

  // The store, not the client, is the source of truth.
  const txs = await deps.transactions(userId, productId);
  const tx = txs.find((t) =>
    t.store_transaction_id === transactionId || t.id === transactionId
  );
  if (!tx) {
    // Not visible to RevenueCat yet (or not this user's): the app retries.
    return { status: 404, body: { error: "purchase_not_found" } };
  }
  const store = mapStore(tx.store);
  if (!store) return { status: 400, body: { error: "unsupported_store" } };

  try {
    const status = await deps.grant({
      groupId,
      userId,
      store,
      productId,
      transactionId: tx.store_transaction_id,
      purchasedAt: tx.purchase_date,
    });
    return { status: 200, body: { status } };
  } catch (e) {
    const key = String(e instanceof Error ? e.message : e).match(
      /closer:([a-z_]+)/,
    )?.[1];
    switch (key) {
      case "not_a_member":
        return { status: 403, body: { error: key } };
      case "transaction_already_used":
      case "purchase_refunded":
        return { status: 409, body: { error: key } };
      default:
        return { status: 500, body: { error: "grant_failed" } };
    }
  }
}
