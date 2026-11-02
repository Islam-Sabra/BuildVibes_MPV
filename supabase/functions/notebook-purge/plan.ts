// The nightly space-files step of notebook-purge (review 113). No Deno or
// network here, so it is tested with Node:
// node --experimental-strip-types --test supabase/functions/notebook-purge/plan.test.ts
//
// 1. A deleted private folder's files go first, with no grace period.
// 2. Then the sweep, the safety net: files nothing references, 7 days old.
// 3. Then forget: only what is really gone from storage is let go, so a
//    failed delete comes again next run.
// Counts only, in anything it says: never a name or a path.

export type SweepStore = {
  claimPrivate(): Promise<string[]>;
  claimOrphans(): Promise<string[]>;
  // One batch; false when the delete failed.
  remove(names: string[]): Promise<boolean>;
  forget(): Promise<void>;
};

export type SweepResult = { private: number; orphans: number; waiting: number };

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
  const privateNames = await store.claimPrivate().catch(() => [] as string[]);
  const privateGone = await removeAll(store, privateNames);

  const tried = new Set(privateNames);
  const orphans = (await store.claimOrphans().catch(() => [] as string[]))
    .filter((n) => !tried.has(n));
  const orphansGone = await removeAll(store, orphans);

  await store.forget().catch(() => {});
  return {
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
    `private ${r.private}, orphans ${r.orphans}, space waiting ${r.waiting}`;
}
