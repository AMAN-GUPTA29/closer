// Pure cleanup logic, independent of Supabase so it can be unit tested.

export interface CleanupJob {
  id: number;
  bucket_id: string;
  object_path: string;
}

export interface CleanupDeps {
  /** Expires abandoned uploads (queues their objects). */
  expireStaleUploads(): Promise<number>;
  /** Leases due jobs. */
  claim(limit: number): Promise<CleanupJob[]>;
  /** Deletes objects; resolves with an error message on failure. */
  remove(bucket: string, paths: string[]): Promise<{ error?: string }>;
  /** Records the outcome of a job. */
  complete(jobId: number, success: boolean, error?: string): Promise<void>;
}

export interface CleanupResult {
  expired: number;
  claimed: number;
  succeeded: number;
  failed: number;
}

/**
 * Processes one batch of the storage cleanup queue.
 *
 * Deleting an object that no longer exists is treated as success, so jobs are
 * safe to retry. A failed batch marks each of its jobs failed; the database
 * schedules retries with backoff.
 */
export async function runCleanup(
  deps: CleanupDeps,
  limit = 50,
): Promise<CleanupResult> {
  const expired = await deps.expireStaleUploads();
  const jobs = await deps.claim(limit);
  const byBucket = new Map<string, CleanupJob[]>();
  for (const job of jobs) {
    const list = byBucket.get(job.bucket_id) ?? [];
    list.push(job);
    byBucket.set(job.bucket_id, list);
  }

  let succeeded = 0;
  let failed = 0;
  for (const [bucket, list] of byBucket) {
    let error: string | undefined;
    try {
      ({ error } = await deps.remove(bucket, list.map((j) => j.object_path)));
    } catch (e) {
      error = e instanceof Error ? e.message : String(e);
    }
    for (const job of list) {
      if (error) {
        failed++;
        await deps.complete(job.id, false, error.slice(0, 500));
      } else {
        succeeded++;
        await deps.complete(job.id, true);
      }
    }
  }
  return { expired, claimed: jobs.length, succeeded, failed };
}
