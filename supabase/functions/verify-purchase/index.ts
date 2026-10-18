// Edge Function: the app calls this after a store purchase. It confirms the
// transaction with RevenueCat's REST API (server-side secret) and grants
// Keeploom Memories to the chosen group. Also used to apply "unassigned"
// purchases (restore).
// Secrets: REVENUECAT_SECRET_KEY, MEMORIES_PRODUCT_ID (optional).
import { createClient } from "npm:@supabase/supabase-js@2.49.4";
import { type NonSubscriptionTransaction, verifyPurchase } from "./logic.ts";

const url = Deno.env.get("SUPABASE_URL");
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const rcKey = Deno.env.get("REVENUECAT_SECRET_KEY");
const productId = Deno.env.get("MEMORIES_PRODUCT_ID") ??
  "closer_memories_group";

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }
  if (!url || !serviceKey || !rcKey) {
    return Response.json({ error: "purchases_not_configured" }, {
      status: 503,
    });
  }
  const admin = createClient(url, serviceKey, {
    auth: { persistSession: false },
  });
  const body = await req.json().catch(() => null);

  const result = await verifyPurchase(
    {
      userIdFromToken: async (token) => {
        const { data, error } = await admin.auth.getUser(token);
        return error ? null : data.user?.id ?? null;
      },
      transactions: async (appUserId, product) => {
        const res = await fetch(
          `https://api.revenuecat.com/v1/subscribers/${
            encodeURIComponent(appUserId)
          }`,
          { headers: { Authorization: `Bearer ${rcKey}` } },
        );
        if (!res.ok) throw new Error(`revenuecat ${res.status}`);
        const json = await res.json() as {
          subscriber?: {
            non_subscriptions?: Record<string, NonSubscriptionTransaction[]>;
          };
        };
        return json.subscriber?.non_subscriptions?.[product] ?? [];
      },
      grant: async (a) => {
        const { data, error } = await admin.rpc("grant_group_entitlement", {
          p_group_id: a.groupId,
          p_user_id: a.userId,
          p_store: a.store,
          p_product_id: a.productId,
          p_transaction_id: a.transactionId,
          p_purchased_at: a.purchasedAt,
        });
        if (error) throw new Error(error.message);
        return (data as { status: "granted" | "already_granted" }).status;
      },
    },
    req.headers.get("Authorization"),
    body,
    productId,
  ).catch(() => ({ status: 502, body: { error: "verification_unavailable" } }));

  console.log(
    JSON.stringify({ event: "verify_purchase", status: result.status }),
  );
  return Response.json(result.body, { status: result.status });
});
