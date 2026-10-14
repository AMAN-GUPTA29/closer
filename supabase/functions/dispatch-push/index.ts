// Edge Function: delivers queued notifications as push messages via FCM.
// Scheduled every minute (pg_cron + pg_net, see docs/notifications.md).
// Secrets: FCM_SERVICE_ACCOUNT (JSON) — set with `supabase secrets set`.
import { createClient } from "npm:@supabase/supabase-js@2.49.4";
import { FcmClient, type ServiceAccount } from "./fcm.ts";
import { runDispatch } from "./logic.ts";

const url = Deno.env.get("SUPABASE_URL");
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const serviceAccountJson = Deno.env.get("FCM_SERVICE_ACCOUNT");

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }
  if (!url || !serviceKey || !serviceAccountJson) {
    return new Response("Push is not configured", { status: 503 });
  }
  const db = createClient(url, serviceKey, { auth: { persistSession: false } });
  const fcm = new FcmClient(JSON.parse(serviceAccountJson) as ServiceAccount);

  try {
    const result = await runDispatch({
      claim: async (limit) => {
        const { data, error } = await db.rpc("claim_push_batch", {
          p_limit: limit,
        });
        if (error) throw new Error(error.message);
        return data ?? [];
      },
      send: (token, message) => fcm.send(token, message),
      complete: async (id, outcome, invalidTokens) => {
        const { error } = await db.rpc("complete_push", {
          p_notification_id: id,
          p_outcome: outcome,
          p_invalid_tokens: invalidTokens,
        });
        if (error) throw new Error(error.message);
      },
    });
    // Counts only: no tokens, names or ids in logs.
    console.log(JSON.stringify({ event: "dispatch_push", ...result }));
    return Response.json(result);
  } catch (e) {
    console.error(
      JSON.stringify({
        event: "dispatch_push_failed",
        message: String(e).slice(0, 200),
      }),
    );
    return new Response("Dispatch failed", { status: 500 });
  }
});
