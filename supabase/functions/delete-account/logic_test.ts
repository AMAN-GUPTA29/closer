import { assertEquals } from "jsr:@std/assert@1.0.13";
import { deleteAccount, type DeleteAccountDeps } from "./logic.ts";

function fakeDeps(user: string | null = "u1") {
  const calls: string[] = [];
  const deps: DeleteAccountDeps = {
    userIdFromToken: (token) => {
      calls.push(`token:${token}`);
      return Promise.resolve(user);
    },
    prepare: (id) => {
      calls.push(`prepare:${id}`);
      return Promise.resolve();
    },
    deleteAuthUser: (id) => {
      calls.push(`delete:${id}`);
      return Promise.resolve();
    },
  };
  return { deps, calls };
}

Deno.test("deletes the caller's own account after confirmation", async () => {
  const { deps, calls } = fakeDeps("u1");
  const res = await deleteAccount(deps, "Bearer abc", { confirm: "DELETE" });
  assertEquals(res.status, 200);
  assertEquals(calls, ["token:abc", "prepare:u1", "delete:u1"]);
});

Deno.test("requires a bearer token", async () => {
  const { deps, calls } = fakeDeps();
  const res = await deleteAccount(deps, null, { confirm: "DELETE" });
  assertEquals(res.status, 401);
  assertEquals(calls, []);
});

Deno.test("requires the typed confirmation", async () => {
  const { deps, calls } = fakeDeps();
  const res = await deleteAccount(deps, "Bearer abc", { confirm: "delete" });
  assertEquals(res.status, 400);
  assertEquals(calls, []);
});

Deno.test("rejects invalid tokens without deleting anything", async () => {
  const { deps, calls } = fakeDeps(null);
  const res = await deleteAccount(deps, "Bearer bad", { confirm: "DELETE" });
  assertEquals(res.status, 401);
  assertEquals(calls, ["token:bad"]);
});

Deno.test("reports failures without leaking details", async () => {
  const { deps } = fakeDeps("u1");
  deps.deleteAuthUser = () => Promise.reject(new Error("db password=secret"));
  const res = await deleteAccount(deps, "Bearer abc", { confirm: "DELETE" });
  assertEquals(res, { status: 500, body: { error: "deletion_failed" } });
});
