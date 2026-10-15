// Push dispatch logic, independent of Supabase/FCM so it can be unit tested.

export interface PushJob {
  notification_id: number;
  user_id: string;
  kind: string;
  group_id: string;
  group_name: string;
  actor_name: string | null;
  milestone_title: string | null;
  push_enabled: boolean;
  tokens: string[];
}

export interface PushMessage {
  title: string;
  body: string;
  /** Ids only. The app fetches content itself after authenticating. */
  data: Record<string, string>;
}

export type SendResult = "ok" | "invalid" | "retry";

export interface DispatchDeps {
  claim(limit: number): Promise<PushJob[]>;
  send(token: string, message: PushMessage): Promise<SendResult>;
  complete(
    notificationId: number,
    outcome: "sent" | "skipped" | "retry" | "failed",
    invalidTokens: string[],
  ): Promise<void>;
}

/**
 * Builds the visible text. Never includes captions, photo content or
 * descriptions — only who did what in which group.
 */
export function buildMessage(job: PushJob): PushMessage {
  const who = job.actor_name ?? "Someone";
  const group = job.group_name;
  const [title, body] = (() => {
    switch (job.kind) {
      case "photo_added":
        return [group, `${who} shared a new photo`];
      case "member_joined":
        return [group, `${who} joined the group`];
      case "milestone_added":
        return [group, `${who} added a special moment`];
      case "milestone_upcoming":
        return [
          group,
          job.milestone_title
            ? `Tomorrow: ${job.milestone_title}`
            : "A special moment is tomorrow",
        ];
      default:
        return [group, "New activity"];
    }
  })();
  return {
    title,
    body,
    data: {
      type: job.kind,
      group_id: job.group_id,
      notification_id: String(job.notification_id),
    },
  };
}

export interface DispatchResult {
  claimed: number;
  sent: number;
  skipped: number;
  retried: number;
  invalidTokens: number;
}

/**
 * Sends one batch. A notification counts as sent when at least one device
 * accepted it; tokens the provider rejects as invalid are retired; if every
 * device failed transiently the notification is retried with backoff.
 */
export async function runDispatch(
  deps: DispatchDeps,
  limit = 100,
): Promise<DispatchResult> {
  const jobs = await deps.claim(limit);
  const result: DispatchResult = {
    claimed: jobs.length,
    sent: 0,
    skipped: 0,
    retried: 0,
    invalidTokens: 0,
  };
  for (const job of jobs) {
    if (!job.push_enabled || job.tokens.length === 0) {
      await deps.complete(job.notification_id, "skipped", []);
      result.skipped++;
      continue;
    }
    const message = buildMessage(job);
    const invalid: string[] = [];
    let delivered = false;
    let transient = false;
    for (const token of job.tokens) {
      let r: SendResult;
      try {
        r = await deps.send(token, message);
      } catch {
        r = "retry";
      }
      if (r === "ok") delivered = true;
      else if (r === "invalid") invalid.push(token);
      else transient = true;
    }
    result.invalidTokens += invalid.length;
    if (delivered) {
      await deps.complete(job.notification_id, "sent", invalid);
      result.sent++;
    } else if (transient) {
      await deps.complete(job.notification_id, "retry", invalid);
      result.retried++;
    } else {
      // Every token was invalid: nothing left to deliver to.
      await deps.complete(job.notification_id, "skipped", invalid);
      result.skipped++;
    }
  }
  return result;
}
