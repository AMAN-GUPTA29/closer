// RevenueCat webhook handling: records purchases and processes refunds.
// The webhook is a safety net next to verify-purchase: it can't know which
// group a purchase was for, so new purchases are stored as "unassigned" until
// the app applies them (verify-purchase), and refunds revoke the entitlement.

import { mapStore } from "../verify-purchase/logic.ts";

export interface WebhookDeps {
  record(args: {
    userId: string;
    store: string;
    productId: string;
    transactionId: string;
    purchasedAt: string;
  }): Promise<void>;
  revoke(store: string, transactionId: string): Promise<void>;
}

/** Constant-time string comparison for the shared webhook secret. */
export function safeEqual(a: string, b: string): boolean {
  const ea = new TextEncoder().encode(a);
  const eb = new TextEncoder().encode(b);
  let diff = ea.length ^ eb.length;
  for (let i = 0; i < Math.max(ea.length, eb.length); i++) {
    diff |= (ea[i] ?? 0) ^ (eb[i] ?? 0);
  }
  return diff === 0;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

interface RcEvent {
  type?: string;
  app_user_id?: string;
  product_id?: string;
  store?: string;
  transaction_id?: string;
  original_transaction_id?: string;
  purchased_at_ms?: number;
}

export async function handleWebhook(
  deps: WebhookDeps,
  authorization: string | null,
  expectedAuth: string,
  payload: { event?: RcEvent } | null,
  productId: string,
): Promise<{ status: number; result: string }> {
  if (!authorization || !safeEqual(authorization, expectedAuth)) {
    return { status: 401, result: "unauthorized" };
  }
  const e = payload?.event;
  if (!e?.type) return { status: 400, result: "invalid_payload" };
  if (e.product_id !== productId) {
    return { status: 200, result: "ignored_product" };
  }

  const store = mapStore(String(e.store ?? "").toLowerCase());
  const tx = e.transaction_id;
  if (!store || !tx) return { status: 200, result: "ignored_store" };

  switch (e.type) {
    case "NON_RENEWING_PURCHASE": {
      if (!e.app_user_id || !UUID.test(e.app_user_id)) {
        // Anonymous RevenueCat ids can't be tied to a Keeploom account.
        return { status: 200, result: "ignored_anonymous" };
      }
      await deps.record({
        userId: e.app_user_id,
        store,
        productId,
        transactionId: tx,
        purchasedAt: new Date(e.purchased_at_ms ?? Date.now()).toISOString(),
      });
      return { status: 200, result: "recorded" };
    }
    case "CANCELLATION":
    case "REFUND":
      await deps.revoke(store, tx);
      return { status: 200, result: "revoked" };
    default:
      return { status: 200, result: "ignored_type" };
  }
}
