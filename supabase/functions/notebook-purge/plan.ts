// The nightly space-files step of notebook-purge (review 113). No Deno or
// network here, so it is tested with Node:
// node --experimental-strip-types --test supabase/functions/notebook-purge/plan.test.ts
//
// 1. Library files deleted 30 days ago go: their rows now, their paths into
//    the queue.
// 2. The queue goes next, with no grace period (those paths, and a deleted
//    private folder's files).
// 3. Then the sweep, the safety net: files nothing references, 7 days old.
// 4. Then forget: only what is really gone from storage is let go, so a
//    failed delete comes again next run.
// Counts only, in anything it says: never a name or a path.

// The most taken per night, for each of the three steps. Set it from the
// dry run's timing; whatever is left goes on the following nights.
export const NIGHTLY_CAP = 1000;

export type SweepStore = {
  purgeDeleted(): Promise<number>;
  claimPrivate(): Promise<string[]>;
  claimOrphans(): Promise<string[]>;
  // One batch; false when the delete failed.
  remove(names: string[]): Promise<boolean>;
  forget(): Promise<void>;
};

export type SweepResult = { library: number; private: number; orphans: number; waiting: number };

// remove() takes up to 1,000 paths a call.
const BATCH = 1000;

async function removeAll(store: SweepStore, names: string[]): Promise<number> {
  let gone = 0;
  for (let i = 0; i < names.length; i += BATCH) {
    const batch = names.slice(i, i + BATCH);
    if (await store.remove(batch)) gone += batch.length;
  }
  return gone;
}

export async function sweepSpaceFiles(store: SweepStore): Promise<SweepResult> {
  const library = await store.purgeDeleted().catch(() => 0);

  const privateNames = await store.claimPrivate().catch(() => [] as string[]);
  const privateGone = await removeAll(store, privateNames);

  const tried = new Set(privateNames);
  const orphans = (await store.claimOrphans().catch(() => [] as string[]))
    .filter((n) => !tried.has(n));
  const orphansGone = await removeAll(store, orphans);

  await store.forget().catch(() => {});
  return {
    library,
    private: privateGone,
    orphans: orphansGone,
    waiting: privateNames.length + orphans.length - privateGone - orphansGone,
  };
}

export function summary(
  purged: number,
  files: number,
  filesLeft: number,
  r: SweepResult,
): string {
  return `purged ${purged}, files ${files}, waiting ${filesLeft}, ` +
    `library ${r.library}, private ${r.private}, orphans ${r.orphans}, space waiting ${r.waiting}`;
}
