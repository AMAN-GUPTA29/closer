// Edge Function: permanently deletes the caller's own account.
//
// The caller is identified only from their access token; the request body
// must contain the typed confirmation. Uses the service role (server-side
// only) to queue private files and delete the auth user. Database cascades
// remove the profile, memberships (ownership hands over, empty groups are
// deleted), notifications and preferences. Photos the user shared stay with
// their groups without an uploader name.
import { createClient } from "npm:@supabase/supabase-js@2.49.4";
import { deleteAccount } from "./logic.ts";

const url = Deno.env.get("SUPABASE_URL");
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }
  if (!url || !serviceKey) {
    return new Response("Not configured", { status: 500 });
  }
  const admin = createClient(url, serviceKey, {
    auth: { persistSession: false },
  });
  const body = await req.json().catch(() => null);

  const result = await deleteAccount(
    {
      userIdFromToken: async (token) => {
        const { data, error } = await admin.auth.getUser(token);
        return error ? null : data.user?.id ?? null;
      },
      prepare: async (userId) => {
        const { error } = await admin.rpc("prepare_account_deletion", {
          p_user_id: userId,
        });
        if (error) throw new Error(error.message);
      },
      deleteAuthUser: async (userId) => {
        const { error } = await admin.auth.admin.deleteUser(userId);
        if (error) throw new Error(error.message);
      },
    },
    req.headers.get("Authorization"),
    body,
  );

  // No user ids or emails in logs.
  console.log(
    JSON.stringify({ event: "delete_account", status: result.status }),
  );
  return Response.json(result.body, { status: result.status });
});
