import { assertEquals } from "jsr:@std/assert@1.0.13";
import { type CleanupDeps, type CleanupJob, runCleanup } from "./logic.ts";

function fakeDeps(jobs: CleanupJob[], failBuckets: string[] = []) {
  const completed: Array<{ id: number; success: boolean; error?: string }> = [];
  const removed: string[] = [];
  const deps: CleanupDeps = {
    expireStaleUploads: () => Promise.resolve(2),
    claim: (limit) => Promise.resolve(jobs.slice(0, limit)),
    remove: (bucket, paths) => {
      if (failBuckets.includes(bucket)) {
        return Promise.resolve({ error: "storage unavailable" });
      }
      removed.push(...paths);
      return Promise.resolve({});
    },
    complete: (id, success, error) => {
      completed.push({ id, success, error });
      return Promise.resolve();
    },
  };
  return { deps, completed, removed };
}

Deno.test("deletes claimed objects and completes their jobs", async () => {
  const { deps, completed, removed } = fakeDeps([
    { id: 1, bucket_id: "photos", object_path: "g/p/original.jpg" },
    { id: 2, bucket_id: "photos", object_path: "g/p/thumb.jpg" },
  ]);
  const result = await runCleanup(deps);
  assertEquals(result, { expired: 2, claimed: 2, succeeded: 2, failed: 0 });
  assertEquals(removed, ["g/p/original.jpg", "g/p/thumb.jpg"]);
  assertEquals(completed.every((c) => c.success), true);
});

Deno.test("marks jobs failed so the database retries them", async () => {
  const { deps, completed } = fakeDeps(
    [{ id: 7, bucket_id: "photos", object_path: "g/x/original.jpg" }],
    ["photos"],
  );
  const result = await runCleanup(deps);
  assertEquals(result.failed, 1);
  assertEquals(completed, [{
    id: 7,
    success: false,
    error: "storage unavailable",
  }]);
});

Deno.test("a thrown storage error is recorded, not fatal", async () => {
  const { deps, completed } = fakeDeps([
    { id: 3, bucket_id: "photos", object_path: "a" },
  ]);
  deps.remove = () => Promise.reject(new Error("network down"));
  const result = await runCleanup(deps);
  assertEquals(result.failed, 1);
  assertEquals(completed[0].error, "network down");
});

Deno.test("respects the batch limit", async () => {
  const jobs = Array.from({ length: 5 }, (_, i) => ({
    id: i,
    bucket_id: "photos",
    object_path: `p${i}`,
  }));
  const { deps } = fakeDeps(jobs);
  const result = await runCleanup(deps, 3);
  assertEquals(result.claimed, 3);
});

Deno.test("an empty queue does nothing", async () => {
  const { deps, completed } = fakeDeps([]);
  const result = await runCleanup(deps);
  assertEquals(result, { expired: 2, claimed: 0, succeeded: 0, failed: 0 });
  assertEquals(completed.length, 0);
});
