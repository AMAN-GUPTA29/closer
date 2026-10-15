import { assert, assertEquals } from "jsr:@std/assert@1.0.13";
import {
  buildMessage,
  type DispatchDeps,
  type PushJob,
  runDispatch,
  type SendResult,
} from "./logic.ts";
import {
  classifyFcmResponse,
  pemToPkcs8,
  type ServiceAccount,
  signAssertion,
} from "./fcm.ts";

const job = (over: Partial<PushJob> = {}): PushJob => ({
  notification_id: 1,
  user_id: "u1",
  kind: "photo_added",
  group_id: "g1",
  group_name: "My Love",
  actor_name: "Emma",
  milestone_title: null,
  push_enabled: true,
  tokens: ["t1"],
  ...over,
});

function deps(jobs: PushJob[], results: Record<string, SendResult>) {
  const completed: Array<[number, string, string[]]> = [];
  const sent: string[] = [];
  const d: DispatchDeps = {
    claim: () => Promise.resolve(jobs),
    send: (token) => {
      sent.push(token);
      return Promise.resolve(results[token] ?? "ok");
    },
    complete: (id, outcome, invalid) => {
      completed.push([id, outcome, invalid]);
      return Promise.resolve();
    },
  };
  return { d, completed, sent };
}

Deno.test("messages name people and groups but never captions", () => {
  const m = buildMessage(job());
  assertEquals(m.title, "My Love");
  assertEquals(m.body, "Emma shared a new photo");
  assertEquals(m.data, {
    type: "photo_added",
    group_id: "g1",
    notification_id: "1",
  });
  assertEquals(
    buildMessage(
      job({ kind: "milestone_upcoming", milestone_title: "Anniversary" }),
    ).body,
    "Tomorrow: Anniversary",
  );
  assertEquals(
    buildMessage(job({ actor_name: null })).body,
    "Someone shared a new photo",
  );
});

Deno.test("sends to every device and records success", async () => {
  const { d, completed, sent } = deps([job({ tokens: ["a", "b"] })], {});
  const r = await runDispatch(d);
  assertEquals(sent, ["a", "b"]);
  assertEquals(completed, [[1, "sent", []]]);
  assertEquals(r.sent, 1);
});

Deno.test("retires invalid tokens and still counts a delivery", async () => {
  const { d, completed } = deps([job({ tokens: ["dead", "live"] })], {
    dead: "invalid",
  });
  const r = await runDispatch(d);
  assertEquals(completed, [[1, "sent", ["dead"]]]);
  assertEquals(r.invalidTokens, 1);
});

Deno.test("transient failures are retried", async () => {
  const { d, completed } = deps([job({ tokens: ["a"] })], { a: "retry" });
  await runDispatch(d);
  assertEquals(completed, [[1, "retry", []]]);
});

Deno.test("thrown send errors are treated as transient", async () => {
  const { d, completed } = deps([job()], {});
  d.send = () => Promise.reject(new Error("socket hang up"));
  await runDispatch(d);
  assertEquals(completed[0][1], "retry");
});

Deno.test("users without devices or with push off are skipped", async () => {
  const { d, completed, sent } = deps(
    [
      job({ notification_id: 1, tokens: [] }),
      job({ notification_id: 2, push_enabled: false }),
    ],
    {},
  );
  const r = await runDispatch(d);
  assertEquals(sent, []);
  assertEquals(completed.map((c) => c[1]), ["skipped", "skipped"]);
  assertEquals(r.skipped, 2);
});

Deno.test("all-invalid tokens end as skipped, not retried forever", async () => {
  const { d, completed } = deps([job({ tokens: ["x"] })], { x: "invalid" });
  await runDispatch(d);
  assertEquals(completed, [[1, "skipped", ["x"]]]);
});

Deno.test("FCM responses are classified", () => {
  assertEquals(classifyFcmResponse(200, "{}"), "ok");
  assertEquals(
    classifyFcmResponse(
      404,
      '{"status":"NOT_FOUND","details":[{"errorCode":"UNREGISTERED"}]}',
    ),
    "invalid",
  );
  assertEquals(
    classifyFcmResponse(400, '{"status":"INVALID_ARGUMENT"}'),
    "invalid",
  );
  assertEquals(classifyFcmResponse(429, "{}"), "retry");
  assertEquals(classifyFcmResponse(503, "{}"), "retry");
});

Deno.test("the service-account assertion is a valid RS256 JWT", async () => {
  const pair = await crypto.subtle.generateKey(
    {
      name: "RSASSA-PKCS1-v1_5",
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: "SHA-256",
    },
    true,
    ["sign", "verify"],
  );
  const pkcs8 = new Uint8Array(
    await crypto.subtle.exportKey("pkcs8", pair.privateKey),
  );
  let bin = "";
  for (const b of pkcs8) bin += String.fromCharCode(b);
  const pem = `-----BEGIN PRIVATE KEY-----\n${
    btoa(bin)
  }\n-----END PRIVATE KEY-----\n`;
  assertEquals(pemToPkcs8(pem), pkcs8);

  const sa: ServiceAccount = {
    project_id: "p",
    client_email: "push@p.iam.gserviceaccount.com",
    private_key: pem,
  };
  const jwt = await signAssertion(sa, 1_700_000_000);
  const [h, c, s] = jwt.split(".");
  const fromB64url = (x: string) =>
    Uint8Array.from(
      atob(
        x.replace(/-/g, "+").replace(/_/g, "/") +
          "===".slice((x.length + 3) % 4),
      ),
      (ch) => ch.charCodeAt(0),
    );
  const claims = JSON.parse(new TextDecoder().decode(fromB64url(c)));
  assertEquals(
    claims.scope,
    "https://www.googleapis.com/auth/firebase.messaging",
  );
  assertEquals(claims.exp - claims.iat, 3600);
  const ok = await crypto.subtle.verify(
    "RSASSA-PKCS1-v1_5",
    pair.publicKey,
    fromB64url(s),
    new TextEncoder().encode(`${h}.${c}`),
  );
  assert(ok, "signature verifies with the public key");
});
