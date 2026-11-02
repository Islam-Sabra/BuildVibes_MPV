// node --experimental-strip-types --test supabase/functions/notebook-purge/plan.test.ts
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { NIGHTLY_CAP, summary, sweepSpaceFiles, type SweepStore } from "./plan.ts";

const PRIVATE = "s1/library/f1/private-plan.pdf";
const ORPHAN = "s1/old/f2/orphan-photo.jpg";

function store(over: Partial<SweepStore> = {}, log: string[] = []): SweepStore {
  return {
    purgeDeleted: async () => { log.push("purgeDeleted"); return 2; },
    claimPrivate: async () => { log.push("claimPrivate"); return [PRIVATE]; },
    claimOrphans: async () => { log.push("claimOrphans"); return [ORPHAN]; },
    remove: async (names) => { log.push(`remove ${names.join(",")}`); return true; },
    forget: async () => { log.push("forget"); },
    ...over,
  };
}

test("deleted Library files are purged first, so their objects go in the same run", async () => {
  const log: string[] = [];
  const r = await sweepSpaceFiles(store({}, log));
  assert.deepEqual(log, ["purgeDeleted", "claimPrivate", `remove ${PRIVATE}`, "claimOrphans", `remove ${ORPHAN}`, "forget"]);
  assert.deepEqual(r, { library: 2, private: 1, orphans: 1, waiting: 0 });
});

test("a failed delete is counted as waiting and stays for the next run", async () => {
  const log: string[] = [];
  const r = await sweepSpaceFiles(store({
    remove: async (names) => { log.push("remove"); return !names.includes(PRIVATE); },
    forget: async () => { log.push("forget"); },
  }, log));
  assert.deepEqual(r, { library: 2, private: 0, orphans: 1, waiting: 1 });
  // forget drops only what is gone from storage (pgTAP), so it still runs.
  assert.equal(log.at(-1), "forget");
});

test("a path the queue failed on is not tried twice in one run", async () => {
  const removed: string[] = [];
  const r = await sweepSpaceFiles(store({
    claimOrphans: async () => [PRIVATE, ORPHAN],
    remove: async (names) => { removed.push(...names); return !names.includes(PRIVATE); },
  }));
  assert.deepEqual(removed, [PRIVATE, ORPHAN]);
  assert.deepEqual(r, { library: 2, private: 0, orphans: 1, waiting: 1 });
});

test("the queue failing to read doesn't stop the sweep", async () => {
  const r = await sweepSpaceFiles(store({ claimPrivate: async () => { throw new Error(PRIVATE); } }));
  assert.equal(r.orphans, 1);
  assert.equal(r.private, 0);
});

test("the Library purge failing doesn't stop the rest", async () => {
  const r = await sweepSpaceFiles(store({ purgeDeleted: async () => { throw new Error("no"); } }));
  assert.deepEqual(r, { library: 0, private: 1, orphans: 1, waiting: 0 });
});

test("the nightly cap is one named constant, used for every claim", () => {
  assert.equal(NIGHTLY_CAP, 1000);
  const index = readFileSync(new URL("./index.ts", import.meta.url), "utf8");
  assert.equal((index.match(/p_limit: NIGHTLY_CAP/g) ?? []).length, 3);
  assert.ok(!/p_limit: \d/.test(index), "no number hard-wired");
});

test("batches of 1,000 for remove()", async () => {
  const sizes: number[] = [];
  const names = Array.from({ length: 2500 }, (_, i) => `s/o/${i}.jpg`);
  const r = await sweepSpaceFiles(store({
    claimPrivate: async () => [],
    claimOrphans: async () => names,
    remove: async (n) => { sizes.push(n.length); return true; },
  }));
  assert.deepEqual(sizes, [1000, 1000, 500]);
  assert.equal(r.orphans, 2500);
});

test("counts only: nothing the job says names a file", async () => {
  const lines: string[] = [];
  const original = console.log;
  console.log = (...a: unknown[]) => lines.push(a.join(" "));
  try {
    const r = await sweepSpaceFiles(store({
      claimPrivate: async () => { throw new Error(PRIVATE); },
      remove: async () => false,
    }));
    lines.push(summary(3, 2, 0, r));
  } finally {
    console.log = original;
  }
  const said = lines.join("\n");
  assert.ok(!said.includes("plan") && !said.includes("photo") && !said.includes("s1/"), said);
  assert.equal(summary(3, 2, 1, { library: 7, private: 4, orphans: 5, waiting: 6 }),
               "purged 3, files 2, waiting 1, library 7, private 4, orphans 5, space waiting 6");
});
