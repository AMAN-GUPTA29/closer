// Edge Function: RevenueCat webhook endpoint. RevenueCat sends the
// Authorization header value configured in its dashboard; we compare it with
// REVENUECAT_WEBHOOK_AUTH. Deploy with --no-verify-jwt (RevenueCat has no
// Supabase JWT). Retries from RevenueCat are safe: every write is idempotent.
import { createClient } from "npm:@supabase/supabase-js@2.49.4";
import { handleWebhook } from "./logic.ts";

const url = Deno.env.get("SUPABASE_URL");
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const expectedAuth = Deno.env.get("REVENUECAT_WEBHOOK_AUTH");
const productId = Deno.env.get("MEMORIES_PRODUCT_ID") ??
  "keeploom_memories_year";

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }
  if (!url || !serviceKey || !expectedAuth) {
    return new Response("Not configured", { status: 503 });
  }
  const db = createClient(url, serviceKey, { auth: { persistSession: false } });
  const payload = await req.json().catch(() => null);
  try {
    const r = await handleWebhook(
      {
        record: async (a) => {
          const { error } = await db.rpc("record_store_purchase", {
            p_user_id: a.userId,
            p_store: a.store,
            p_product_id: a.productId,
            p_transaction_id: a.transactionId,
            p_purchased_at: a.purchasedAt,
          });
          if (error) throw new Error(error.message);
        },
        revoke: async (store, tx) => {
          const { error } = await db.rpc("revoke_group_entitlement", {
            p_store: store,
            p_transaction_id: tx,
          });
          if (error) throw new Error(error.message);
        },
      },
      req.headers.get("Authorization"),
      expectedAuth,
      payload,
      productId,
    );
    console.log(JSON.stringify({ event: "rc_webhook", result: r.result }));
    return Response.json({ result: r.result }, { status: r.status });
  } catch {
    // 5xx makes RevenueCat retry later.
    return new Response("Webhook failed", { status: 500 });
  }
});
