// "Extract text" (review 103, OCR): what the edge function does, with
// everything outside it (the caller's sign-in, storage, Google Cloud
// Vision, the database) handed in, so it is tested with fakes and no key.
// Tested with: deno test supabase/functions/extract-text/read.test.ts
//
// - Only for a signed-in caller who can open the file (file_for_text, asked
//   as the caller), and only a PDF or a photo.
// - At most MAX_PAGES pages a file, and never past what the caller has left
//   of 50 pages a day (text_pages_left).
// - Vision's document text detection: a PDF in batches of 5 pages
//   (files:annotate), a photo in one go (images:annotate). The text of
//   each page, in order, with the first language Vision names.
// - Kept with save_file_text; a file already read gives its text back
//   without asking Vision again.

export const MAX_PAGES = 20;
export const BATCH = 5;

export type FileKind = "library" | "note";

export type FileFor = {
  bucket: string;
  path: string;
  mime: string;
  done: boolean;
};

export type Deps = {
  /** The caller's id, from their sign-in; null when there is none. */
  caller(): Promise<string | null>;
  /** As the caller: the file, or null when they may not read it. */
  fileFor(kind: FileKind, ref: string): Promise<FileFor | null>;
  /** The text already kept, or null. */
  kept(kind: FileKind, ref: string): Promise<Kept | null>;
  pagesLeft(caller: string): Promise<number>;
  download(bucket: string, path: string): Promise<Uint8Array>;
  /** One Vision call: its endpoint ("files:annotate" or "images:annotate")
   *  and request body; the parsed JSON answer. */
  vision(endpoint: string, body: unknown): Promise<unknown>;
  save(
    kind: FileKind,
    ref: string,
    caller: string,
    lang: string | null,
    text: string,
    pages: number,
  ): Promise<void>;
};

export type Kept = { text: string; lang: string | null; pages: number };

export type Answer = { status: number; body: Record<string, unknown> };

const json = (status: number, body: Record<string, unknown>): Answer => ({
  status,
  body,
});

export async function extract(
  input: { kind?: unknown; ref?: unknown },
  deps: Deps,
): Promise<Answer> {
  const caller = await deps.caller();
  if (!caller) return json(401, { error: "sign_in" });
  const kind = input.kind;
  const ref = input.ref;
  if ((kind !== "library" && kind !== "note") || typeof ref !== "string" || !ref) {
    return json(400, { error: "bad_request" });
  }
  const file = await deps.fileFor(kind, ref);
  if (!file) return json(403, { error: "not_allowed" });
  if (file.done) {
    const kept = await deps.kept(kind, ref);
    if (kept) return json(200, { ...kept });
  }
  const pdf = file.mime === "application/pdf";
  if (!pdf && !file.mime.startsWith("image/")) {
    return json(415, { error: "not_a_document" });
  }
  const left = await deps.pagesLeft(caller);
  if (left <= 0) return json(429, { error: "daily_limit" });
  const most = Math.min(MAX_PAGES, left);

  const bytes = await deps.download(file.bucket, file.path);
  const content = base64(bytes);
  const texts: string[] = [];
  let lang: string | null = null;
  if (pdf) {
    for (let from = 1; from <= most; from += BATCH) {
      const pages = [];
      for (let p = from; p < from + BATCH && p <= most; p++) pages.push(p);
      const answer = await deps.vision("files:annotate", {
        requests: [{
          inputConfig: { mimeType: "application/pdf", content },
          features: [{ type: "DOCUMENT_TEXT_DETECTION" }],
          pages,
        }],
      });
      const batch = (answer as VisionFiles)?.responses?.[0];
      const each = batch?.responses ?? [];
      for (const r of each) {
        texts.push(r.fullTextAnnotation?.text ?? "");
        lang ??= languageOf(r);
      }
      const total = batch?.totalPages ?? 0;
      if (each.length < pages.length || from + BATCH > total) break;
    }
  } else {
    const answer = await deps.vision("images:annotate", {
      requests: [{
        image: { content },
        features: [{ type: "DOCUMENT_TEXT_DETECTION" }],
      }],
    });
    const r = (answer as VisionImages)?.responses?.[0];
    texts.push(r?.fullTextAnnotation?.text ?? "");
    lang = r ? languageOf(r) : null;
  }
  const text = texts.map((t) => t.trim()).filter((t) => t).join("\n\n");
  const pages = Math.max(texts.length, 1);
  await deps.save(kind, ref, caller, lang, text, pages);
  return json(200, { text, lang, pages });
}

type VisionPage = {
  fullTextAnnotation?: {
    text?: string;
    pages?: { property?: { detectedLanguages?: { languageCode?: string }[] } }[];
  };
};
type VisionFiles = {
  responses?: { responses?: VisionPage[]; totalPages?: number }[];
};
type VisionImages = { responses?: VisionPage[] };

function languageOf(r: VisionPage): string | null {
  return r.fullTextAnnotation?.pages?.[0]?.property?.detectedLanguages?.[0]
    ?.languageCode ?? null;
}

function base64(bytes: Uint8Array): string {
  let s = "";
  const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) {
    s += String.fromCharCode(...bytes.subarray(i, i + chunk));
  }
  return btoa(s);
}
