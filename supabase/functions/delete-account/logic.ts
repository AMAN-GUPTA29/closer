// Pure account-deletion flow, independent of Supabase for unit testing.

export interface DeleteAccountDeps {
  /** Resolves the signed-in user from the caller's access token. */
  userIdFromToken(token: string): Promise<string | null>;
  /** Queues the user's private files (avatar) for deletion. */
  prepare(userId: string): Promise<void>;
  /** Deletes the auth user; database cascades handle the rest. */
  deleteAuthUser(userId: string): Promise<void>;
}

export type DeleteAccountResult =
  | { status: 200; body: { deleted: true } }
  | { status: 400 | 401 | 500; body: { error: string } };

/** The confirmation phrase the app sends after the user typed it. */
export const confirmationPhrase = "DELETE";

export async function deleteAccount(
  deps: DeleteAccountDeps,
  authorization: string | null,
  body: unknown,
): Promise<DeleteAccountResult> {
  const token = authorization?.match(/^Bearer\s+(.+)$/i)?.[1];
  if (!token) return { status: 401, body: { error: "not_authenticated" } };

  const confirm = (body as { confirm?: unknown } | null)?.confirm;
  if (confirm !== confirmationPhrase) {
    return { status: 400, body: { error: "confirmation_required" } };
  }

  const userId = await deps.userIdFromToken(token);
  if (!userId) return { status: 401, body: { error: "not_authenticated" } };

  try {
    await deps.prepare(userId);
    await deps.deleteAuthUser(userId);
    return { status: 200, body: { deleted: true } };
  } catch {
    return { status: 500, body: { error: "deletion_failed" } };
  }
}
