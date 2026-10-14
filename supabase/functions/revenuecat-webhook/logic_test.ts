import { assertEquals } from "jsr:@std/assert@1.0.13";
import { handleWebhook, safeEqual, type WebhookDeps } from "./logic.ts";

const USER = "5f0c6d2e-1a2b-4c3d-8e9f-0a1b2c3d4e5f";
const PRODUCT = "closer_memories_group";

function deps() {
  const calls: string[] = [];
  const d: WebhookDeps = {
    record: (a) => {
      calls.push(`record:${a.userId}:${a.store}:${a.transactionId}`);
      return Promise.resolve();
    },
    revoke: (s, t) => {
      calls.push(`revoke:${s}:${t}`);
      return Promise.resolve();
    },
  };
  return { d, calls };
}

const event = (over: Record<string, unknown> = {}) => ({
  event: {
    type: "NON_RENEWING_PURCHASE",
    app_user_id: USER,
    product_id: PRODUCT,
    store: "APP_STORE",
    transaction_id: "2000000123",
    purchased_at_ms: 1_760_000_000_000,
    ...over,
  },
});

Deno.test("rejects requests without the shared secret", async () => {
  const { d, calls } = deps();
  assertEquals(
    (await handleWebhook(d, null, "s3cret", event(), PRODUCT)).status,
    401,
  );
  assertEquals(
    (await handleWebhook(d, "wrong", "s3cret", event(), PRODUCT)).status,
    401,
  );
  assertEquals(calls, []);
});

Deno.test("records new purchases as unassigned", async () => {
  const { d, calls } = deps();
  const r = await handleWebhook(d, "s3cret", "s3cret", event(), PRODUCT);
  assertEquals(r, { status: 200, result: "recorded" });
  assertEquals(calls, [`record:${USER}:app_store:2000000123`]);
});

Deno.test("refunds and cancellations revoke", async () => {
  const { d, calls } = deps();
  await handleWebhook(
    d,
    "s3cret",
    "s3cret",
    event({ type: "CANCELLATION", store: "PLAY_STORE" }),
    PRODUCT,
  );
  assertEquals(calls, ["revoke:play_store:2000000123"]);
});

Deno.test("ignores other products, stores, anonymous users and event types", async () => {
  const { d, calls } = deps();
  for (
    const e of [
      event({ product_id: "other" }),
      event({ store: "STRIPE" }),
      event({ app_user_id: "$RCAnonymousID:abc" }),
      event({ type: "TEST" }),
    ]
  ) {
    assertEquals(
      (await handleWebhook(d, "s3cret", "s3cret", e, PRODUCT)).status,
      200,
    );
  }
  assertEquals(calls, []);
});

Deno.test("malformed payloads are rejected", async () => {
  const { d } = deps();
  assertEquals(
    (await handleWebhook(d, "s3cret", "s3cret", null, PRODUCT)).status,
    400,
  );
});

Deno.test("secret comparison", () => {
  assertEquals(safeEqual("abc", "abc"), true);
  assertEquals(safeEqual("abc", "abd"), false);
  assertEquals(safeEqual("abc", "abcd"), false);
});
