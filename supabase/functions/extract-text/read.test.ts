// deno test supabase/functions/extract-text/read.test.ts
import { assertEquals } from "jsr:@std/assert@1";
import { BATCH, type Deps, extract, type FileFor, MAX_PAGES } from "./read.ts";

type Calls = { vision: { endpoint: string; body: any }[]; saved: unknown[][] };

/** Fakes: [pages] pages in the PDF, each reading "page N". */
function fakes(opts: {
  caller?: string | null;
  file?: FileFor | null;
  pages?: number;
  left?: number;
  kept?: { text: string; lang: string | null; pages: number } | null;
} = {}): { deps: Deps; calls: Calls } {
  const calls: Calls = { vision: [], saved: [] };
  const total = opts.pages ?? 3;
  const deps: Deps = {
    caller: async () => opts.caller === undefined ? "user-1" : opts.caller,
    fileFor: async () =>
      opts.file === undefined
        ? { bucket: "space-files", path: "s/library/f/a.pdf", mime: "application/pdf", done: false }
        : opts.file,
    kept: async () => opts.kept ?? null,
    pagesLeft: async () => opts.left ?? 50,
    download: async () => new TextEncoder().encode("%PDF-1.4 test"),
    vision: async (endpoint, body: any) => {
      calls.vision.push({ endpoint, body });
      const page = (n: number) => ({
        fullTextAnnotation: {
          text: n === 1 ? "إشعار تسليم\nRebar 16 mm" : `page ${n}`,
          pages: [{ property: { detectedLanguages: [{ languageCode: "ar" }] } }],
        },
      });
      if (endpoint === "images:annotate") return { responses: [page(1)] };
      const asked: number[] = body.requests[0].pages;
      return {
        responses: [{
          totalPages: total,
          responses: asked.filter((p) => p <= total).map(page),
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
  const a = await extract({ kind: "library", ref: "f" }, deps);
  assertEquals(a.status, 401);
  assertEquals(calls.vision.length, 0);
});

Deno.test("a file the caller can't open: 403, Vision never asked", async () => {
  const { deps, calls } = fakes({ file: null });
  const a = await extract({ kind: "library", ref: "f" }, deps);
  assertEquals(a.status, 403);
  assertEquals(calls.vision.length, 0);
});

Deno.test("not a PDF or a photo: 415", async () => {
  const { deps } = fakes({
    file: { bucket: "space-files", path: "x.xlsx", mime: "application/vnd.ms-excel", done: false },
  });
  assertEquals((await extract({ kind: "library", ref: "f" }, deps)).status, 415);
});

Deno.test("a 3-page PDF: one batch, every page's text in order, the language, kept", async () => {
  const { deps, calls } = fakes({ pages: 3 });
  const a = await extract({ kind: "library", ref: "f" }, deps);
  assertEquals(a.status, 200);
  assertEquals(a.body.text, "إشعار تسليم\nRebar 16 mm\n\npage 2\n\npage 3");
  assertEquals(a.body.lang, "ar");
  assertEquals(a.body.pages, 3);
  assertEquals(calls.vision.length, 1);
  assertEquals(calls.vision[0].endpoint, "files:annotate");
  assertEquals(calls.vision[0].body.requests[0].features, [{ type: "DOCUMENT_TEXT_DETECTION" }]);
  assertEquals(calls.saved, [["library", "f", "user-1", "ar", a.body.text, 3]]);
});

Deno.test("a 30-page PDF: never more than 20 pages, in batches of 5", async () => {
  const { deps, calls } = fakes({ pages: 30 });
  const a = await extract({ kind: "library", ref: "f" }, deps);
  assertEquals(a.body.pages, MAX_PAGES);
  assertEquals(calls.vision.length, MAX_PAGES / BATCH);
  assertEquals(calls.vision.at(-1)!.body.requests[0].pages, [16, 17, 18, 19, 20]);
});

Deno.test("never past the day's pages left", async () => {
  const { deps, calls } = fakes({ pages: 30, left: 7 });
  const a = await extract({ kind: "library", ref: "f" }, deps);
  assertEquals(a.body.pages, 7);
  assertEquals(calls.vision.map((c) => c.body.requests[0].pages.length), [5, 2]);
});

Deno.test("none left today: 429, Vision never asked", async () => {
  const { deps, calls } = fakes({ left: 0 });
  assertEquals((await extract({ kind: "library", ref: "f" }, deps)).status, 429);
  assertEquals(calls.vision.length, 0);
});

Deno.test("a photo: one images:annotate call, one page", async () => {
  const { deps, calls } = fakes({
    file: { bucket: "notebook-files", path: "u/n/p.jpg", mime: "image/jpeg", done: false },
  });
  const a = await extract({ kind: "note", ref: "u/n/p.jpg" }, deps);
  assertEquals(a.body.pages, 1);
  assertEquals(calls.vision.map((c) => c.endpoint), ["images:annotate"]);
});

Deno.test("already read: its text, Vision not asked again", async () => {
  const { deps, calls } = fakes({
    file: { bucket: "space-files", path: "a.pdf", mime: "application/pdf", done: true },
    kept: { text: "kept words", lang: "en", pages: 2 },
  });
  const a = await extract({ kind: "library", ref: "f" }, deps);
  assertEquals(a.body.text, "kept words");
  assertEquals(calls.vision.length, 0);
});
