// deno test --allow-read --allow-env supabase/functions/extract-text/read.test.ts
import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import {
  BATCH,
  type Deps,
  extract,
  type FileFor,
  MAX_BYTES,
  MAX_PAGES,
} from "./read.ts";

type Calls = {
  vision: { endpoint: string; body: any }[];
  saved: unknown[][];
  reserved: number[];
  released: number[];
  downloaded: number;
  split: [number, number][];
};

/** Fakes: a PDF of [pages] pages, each reading "page N". */
function fakes(opts: {
  caller?: string | null;
  file?: FileFor | null;
  pages?: number;
  left?: number;
  kept?: { text: string; lang: string | null; pages: number } | null;
  visionFails?: boolean;
} = {}): { deps: Deps; calls: Calls } {
  const calls: Calls = {
    vision: [],
    saved: [],
    reserved: [],
    released: [],
    downloaded: 0,
    split: [],
  };
  const total = opts.pages ?? 3;
  let left = opts.left ?? 50;
  const deps: Deps = {
    caller: async () => opts.caller === undefined ? "user-1" : opts.caller,
    fileFor: async () =>
      opts.file === undefined
        ? {
          bucket: "space-files",
          path: "s/library/f/a.pdf",
          mime: "application/pdf",
          bytes: 400_000,
          done: false,
        }
        : opts.file,
    kept: async () => opts.kept ?? null,
    reserve: async (_who, pages) => {
      if (pages > left) return false;
      left -= pages;
      calls.reserved.push(pages);
      return true;
    },
    release: async (_who, pages) => {
      left += pages;
      calls.released.push(pages);
    },
    download: async () => {
      calls.downloaded++;
      return new TextEncoder().encode("%PDF-1.4 test");
    },
    pageCount: async () => total,
    split: async (_bytes, from, to) => {
      calls.split.push([from, to]);
      return new TextEncoder().encode(`%PDF pages ${from}-${to}`);
    },
    vision: async (endpoint, body: any) => {
      calls.vision.push({ endpoint, body });
      if (opts.visionFails) throw new Error("vision 500");
      const page = (n: number) => ({
        fullTextAnnotation: {
          text: n === 1 ? "إشعار تسليم\nRebar 16 mm" : `page ${n}`,
          pages: [{ property: { detectedLanguages: [{ languageCode: "ar" }] } }],
        },
      });
      if (endpoint === "images:annotate") return { responses: [page(1)] };
      // The chunk's own pages, 1..k, stand for its range.
      const chunk = calls.split.at(-1)!;
      const asked: number[] = body.requests[0].pages;
      return {
        responses: [{
          totalPages: asked.length,
          responses: asked.map((p) => page(chunk[0] + p - 1)),
        }],
      };
    },
    save: async (...args) => {
      calls.saved.push(args);
    },
  };
  return { deps, calls };
}

Deno.test("signed out: 401, Vision never asked", async () => {
  const { deps, calls } = fakes({ caller: null });
  assertEquals((await extract({ kind: "library", ref: "f" }, deps)).status, 401);
  assertEquals(calls.vision.length, 0);
});

Deno.test("a file the caller can't open: 403, never downloaded", async () => {
  const { deps, calls } = fakes({ file: null });
  assertEquals((await extract({ kind: "library", ref: "f" }, deps)).status, 403);
  assertEquals(calls.downloaded, 0);
});

Deno.test("not a PDF or a photo: 415", async () => {
  const { deps } = fakes({
    file: { bucket: "space-files", path: "x.xlsx", mime: "application/vnd.ms-excel", bytes: 9, done: false },
  });
  assertEquals((await extract({ kind: "library", ref: "f" }, deps)).status, 415);
});

Deno.test("D7: over 10 MB: 413 without downloading it", async () => {
  const { deps, calls } = fakes({
    file: { bucket: "space-files", path: "a.pdf", mime: "application/pdf", bytes: MAX_BYTES + 1, done: false },
  });
  const a = await extract({ kind: "library", ref: "f" }, deps);
  assertEquals(a.status, 413);
  assertEquals(a.body.error, "too_large");
  assertEquals(calls.downloaded, 0);
});

Deno.test("a 3-page PDF: the pages reserved, read in order, kept whole", async () => {
  const { deps, calls } = fakes({ pages: 3 });
  const a = await extract({ kind: "library", ref: "f" }, deps);
  assertEquals(a.status, 200);
  assertEquals(a.body.text, "إشعار تسليم\nRebar 16 mm\n\npage 2\n\npage 3");
  assertEquals(a.body.lang, "ar");
  assertEquals(a.body.pages, 3);
  assertEquals(a.body.partial, false);
  assertEquals(calls.reserved, [3]);
  assertEquals(calls.saved, [["library", "f", "user-1", "ar", a.body.text, 3, false]]);
});

Deno.test("D7: only the pages needed go to Vision, 5 at a time", async () => {
  const { deps, calls } = fakes({ pages: 12 });
  await extract({ kind: "library", ref: "f" }, deps);
  assertEquals(calls.split, [[1, 5], [6, 10], [11, 12]]);
  assertEquals(calls.vision.map((c) => c.body.requests[0].pages), [
    [1, 2, 3, 4, 5],
    [1, 2, 3, 4, 5],
    [1, 2],
  ]);
});

Deno.test("D3: a 30-page PDF: the first 20, kept marked partial", async () => {
  const { deps, calls } = fakes({ pages: 30 });
  const a = await extract({ kind: "library", ref: "f" }, deps);
  assertEquals(a.body.pages, MAX_PAGES);
  assertEquals(a.body.partial, true);
  assertEquals(calls.reserved, [MAX_PAGES]);
  assertEquals(calls.vision.length, MAX_PAGES / BATCH);
  assertEquals(calls.saved[0][6], true);
});

Deno.test("D3: more pages than left today: refused, nothing read", async () => {
  const { deps, calls } = fakes({ pages: 12, left: 7 });
  const a = await extract({ kind: "library", ref: "f" }, deps);
  assertEquals(a.status, 429);
  assertEquals(a.body.error, "daily_limit");
  assertEquals(calls.vision.length, 0);
  assertEquals(calls.saved.length, 0);
});

Deno.test("D5: Vision fails: the pages are given back, nothing kept", async () => {
  const { deps, calls } = fakes({ pages: 4, visionFails: true });
  await assertRejects(() => extract({ kind: "library", ref: "f" }, deps));
  assertEquals(calls.reserved, [4]);
  assertEquals(calls.released, [4]);
  assertEquals(calls.saved.length, 0);
});

Deno.test("a photo: one images:annotate call, one page", async () => {
  const { deps, calls } = fakes({
    file: { bucket: "notebook-files", path: "u/n/p.jpg", mime: "image/jpeg", bytes: 90_000, done: false },
  });
  const a = await extract({ kind: "note", ref: "u/n/p.jpg" }, deps);
  assertEquals(a.body.pages, 1);
  assertEquals(calls.vision.map((c) => c.endpoint), ["images:annotate"]);
  assertEquals(calls.reserved, [1]);
});

Deno.test("already read: its text, Vision not asked again", async () => {
  const { deps, calls } = fakes({
    file: { bucket: "space-files", path: "a.pdf", mime: "application/pdf", bytes: 9, done: true },
    kept: { text: "kept words", lang: "en", pages: 2 },
  });
  const a = await extract({ kind: "library", ref: "f" }, deps);
  assertEquals(a.body.text, "kept words");
  assertEquals(calls.vision.length, 0);
  assertEquals(calls.reserved.length, 0);
});
