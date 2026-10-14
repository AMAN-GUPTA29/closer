import { assertEquals } from "jsr:@std/assert@1.0.13";
import { mapStore, type VerifyDeps, verifyPurchase } from "./logic.ts";

const GROUP = "5f0c6d2e-1a2b-4c3d-8e9f-0a1b2c3d4e5f";
const PRODUCT = "closer_memories_group";

function deps(over: Partial<VerifyDeps> = {}) {
  const grants: unknown[] = [];
  const d: VerifyDeps = {
    userIdFromToken: () => Promise.resolve("user-1"),
    transactions: () =>
      Promise.resolve([{
        id: "rc-1",
        store_transaction_id: "2000000123",
        purchase_date: "2026-10-14T10:00:00Z",
        store: "app_store",
      }]),
    grant: (a) => {
      grants.push(a);
      return Promise.resolve("granted");
    },
    ...over,
  };
  return { d, grants };
}

const req = (over: Record<string, unknown> = {}) => ({
  group_id: GROUP,
  transaction_id: "2000000123",
  product_id: PRODUCT,
  ...over,
});

Deno.test("verifies with the store record and grants the group", async () => {
  const { d, grants } = deps();
  const r = await verifyPurchase(d, "Bearer t", req(), PRODUCT);
  assertEquals(r, { status: 200, body: { status: "granted" } });
  assertEquals(grants, [{
    groupId: GROUP,
    userId: "user-1",
    store: "app_store",
    productId: PRODUCT,
    transactionId: "2000000123",
    purchasedAt: "2026-10-14T10:00:00Z",
  }]);
});

Deno.test("a transaction the store doesn't know is not granted", async () => {
  const { d, grants } = deps();
  const r = await verifyPurchase(
    d,
    "Bearer t",
    req({ transaction_id: "forged" }),
    PRODUCT,
  );
  assertEquals(r.status, 404);
  assertEquals(grants, []);
});

Deno.test("requires a signed-in caller", async () => {
  const { d } = deps({ userIdFromToken: () => Promise.resolve(null) });
  assertEquals(
    (await verifyPurchase(d, "Bearer bad", req(), PRODUCT)).status,
    401,
  );
  assertEquals((await verifyPurchase(d, null, req(), PRODUCT)).status, 401);
});

Deno.test("rejects malformed requests and other products", async () => {
  const { d, grants } = deps();
  assertEquals(
    (await verifyPurchase(d, "Bearer t", req({ group_id: "nope" }), PRODUCT))
      .status,
    400,
  );
  assertEquals(
    (await verifyPurchase(d, "Bearer t", req({ product_id: "other" }), PRODUCT))
      .status,
    400,
  );
  assertEquals(
    (await verifyPurchase(d, "Bearer t", null, PRODUCT)).status,
    400,
  );
  assertEquals(grants, []);
});

Deno.test("database refusals map to clear statuses", async () => {
  for (
    const [msg, status] of [
      ["closer:not_a_member", 403],
      ["closer:transaction_already_used", 409],
      ["closer:purchase_refunded", 409],
      ["boom", 500],
    ] as const
  ) {
    const { d } = deps({ grant: () => Promise.reject(new Error(msg)) });
    assertEquals(
      (await verifyPurchase(d, "Bearer t", req(), PRODUCT)).status,
      status,
    );
  }
});

Deno.test("repeat verification is idempotent", async () => {
  const { d } = deps({ grant: () => Promise.resolve("already_granted") });
  const r = await verifyPurchase(d, "Bearer t", req(), PRODUCT);
  assertEquals(r.body.status, "already_granted");
});

Deno.test("store names", () => {
  assertEquals(mapStore("app_store"), "app_store");
  assertEquals(mapStore("play_store"), "play_store");
  assertEquals(mapStore("stripe"), null);
});
