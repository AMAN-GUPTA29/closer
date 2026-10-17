// Who may call a scheduled Edge Function. These functions are deployed with
// verify_jwt off (the new sb_secret_ keys are not JWTs) and check here instead:
// either the cron secret from Vault, or (when allowed) a signed-in user.

export type CallerChecks = {
  /** public.check_cron_secret via the service role. */
  isCronSecret: (token: string) => Promise<boolean>;
  /** Validates a user access token; only consulted when users are allowed. */
  isUser?: (token: string) => Promise<boolean>;
};

export function bearer(req: Request): string | null {
  const h = req.headers.get("Authorization") ?? "";
  const m = /^Bearer\s+(.+)$/i.exec(h.trim());
  return m ? m[1].trim() : null;
}

export async function callerAllowed(
  req: Request,
  checks: CallerChecks,
): Promise<"cron" | "user" | null> {
  const token = bearer(req);
  if (!token) return null;
  if (await checks.isCronSecret(token)) return "cron";
  if (checks.isUser && await checks.isUser(token)) return "user";
  return null;
}
