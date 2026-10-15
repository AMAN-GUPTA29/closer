import { assertEquals } from "jsr:@std/assert@1.0.13";
import { bearer, callerAllowed } from "./caller.ts";

const req = (auth?: string) =>
  new Request("https://x/functions/v1/f", {
    method: "POST",
    headers: auth ? { Authorization: auth } : {},
  });

const checks = {
  isCronSecret: (t: string) => Promise.resolve(t === "cron-s3cret"),
  isUser: (t: string) => Promise.resolve(t === "user-jwt"),
};

Deno.test("bearer parses the Authorization header", () => {
  assertEquals(bearer(req("Bearer abc")), "abc");
  assertEquals(bearer(req("bearer  abc ")), "abc");
  assertEquals(bearer(req("Basic abc")), null);
  assertEquals(bearer(req()), null);
});

Deno.test("cron secret is accepted", async () => {
  assertEquals(await callerAllowed(req("Bearer cron-s3cret"), checks), "cron");
});

Deno.test("users only where allowed", async () => {
  assertEquals(await callerAllowed(req("Bearer user-jwt"), checks), "user");
  assertEquals(
    await callerAllowed(req("Bearer user-jwt"), {
      isCronSecret: checks.isCronSecret,
    }),
    null,
  );
});

Deno.test("anything else is refused", async () => {
  assertEquals(await callerAllowed(req(), checks), null);
  assertEquals(await callerAllowed(req("Bearer nope"), checks), null);
  assertEquals(
    await callerAllowed(req("Bearer sb_publishable_x"), checks),
    null,
  );
});
