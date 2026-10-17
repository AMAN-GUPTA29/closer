// Edge Function: works through the storage cleanup queue.
//
// Invoked by a scheduled job (pg_cron + pg_net, see docs/purchases-and-retention.md)
// with the Vault cron secret, and optionally by signed-in clients after an upload
// removed photos. Deployed with --no-verify-jwt; callers are checked below. The
// function itself uses the service role, which never leaves the server.
import { createClient } from "npm:@supabase/supabase-js@2.49.4";
import { callerAllowed } from "../_shared/caller.ts";
import { runCleanup } from "./logic.ts";

const url = Deno.env.get("SUPABASE_URL");
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }
  if (!url || !serviceKey) {
    return new Response("Not configured", { status: 500 });
  }
  const db = createClient(url, serviceKey, { auth: { persistSession: false } });

  const caller = await callerAllowed(req, {
    isCronSecret: async (token) => {
      const { data } = await db.rpc("check_cron_secret", { p_secret: token });
      return data === true;
    },
    isUser: async (token) => !(await db.auth.getUser(token)).error,
  });
  if (!caller) return new Response("Unauthorized", { status: 401 });

  try {
    const result = await runCleanup({
      expireStaleUploads: async () => {
        const { data, error } = await db.rpc("expire_stale_uploads");
        if (error) throw new Error(error.message);
        return (data as number) ?? 0;
      },
      claim: async (limit) => {
        const { data, error } = await db.rpc("claim_cleanup_jobs", {
          p_limit: limit,
        });
        if (error) throw new Error(error.message);
        return data ?? [];
      },
      remove: async (bucket, paths) => {
        const { error } = await db.storage.from(bucket).remove(paths);
        return { error: error?.message };
      },
      complete: async (jobId, success, message) => {
        const { error } = await db.rpc("complete_cleanup_job", {
          p_job_id: jobId,
          p_success: success,
          p_error: message ?? null,
        });
        if (error) throw new Error(error.message);
      },
    });
    // Counts only: no paths, captions or user data in logs or responses.
    console.log(JSON.stringify({ event: "cleanup", ...result }));
    return Response.json(result);
  } catch (e) {
    console.error(
      JSON.stringify({
        event: "cleanup_failed",
        message: String(e).slice(0, 200),
      }),
    );
    return new Response("Cleanup failed", { status: 500 });
  }
});
