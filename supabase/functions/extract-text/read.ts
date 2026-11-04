// "Extract text" (review 103, OCR): what the edge function does, with
// everything outside it (the caller's sign-in, storage, the PDF splitter,
// Google Cloud Vision, the database) handed in, so it is tested with fakes
// and no key. Tested with: deno test supabase/functions/extract-text/
//
// - Only for a signed-in caller who can open the file (file_for_text, asked
//   as the caller), and only a PDF or a photo of at most MAX_BYTES, said
//   before anything is downloaded (the lead's check, D7).
// - The pages counted first: at most MAX_PAGES, and a longer file is read
//   in part and kept marked partial (D3). They are reserved from the
//   caller's 50 a day before Vision is asked; if they don't fit, nothing is
//   read (D3, D5); if Vision fails, they are given back (D5).
// - Vision's document text detection gets only the pages needed, BATCH at
//   a time, each batch its own small PDF (files:annotate takes at most 5
//   pages a request); a photo goes in one images:annotate call.
// - Kept with save_file_text; a file already read gives its text back
//   without asking Vision again.

export const MAX_PAGES = 20;
export const BATCH = 5;

/** The lead's check, D7: larger files are made smaller on the phone first. */
export const MAX_BYTES = 10 * 1024 * 1024;

export type FileKind = "library" | "note";

export type FileFor = {
  bucket: string;
  path: string;
  mime: string;
  bytes: number | null;
  done: boolean;
};

export type Deps = {
  /** D25: Extract text is on (app_settings ocr_enabled). */
  enabled(): Promise<boolean>;
  /** The caller's id, from their sign-in; null when there is none. */
  caller(): Promise<string | null>;
  /** As the caller: the file, or null when they may not read it. */
  fileFor(kind: FileKind, ref: string): Promise<FileFor | null>;
  /** The text already kept, or null. */
  kept(kind: FileKind, ref: string): Promise<Kept | null>;
  /** Holds [pages] of the caller's day; false when they don't fit. */
  reserve(caller: string, pages: number): Promise<boolean>;
  /** Gives them back (Vision failed). */
  release(caller: string, pages: number): Promise<void>;
  download(bucket: string, path: string): Promise<Uint8Array>;
  /** How many pages the PDF has. */
  pageCount(pdf: Uint8Array): Promise<number>;
  /** A PDF of pages [from]..[to] (1-based) of [pdf]. */
  split(pdf: Uint8Array, from: number, to: number): Promise<Uint8Array>;
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
    partial: boolean,
  ): Promise<void>;
};

export type Kept = {
  text: string;
  lang: string | null;
  pages: number;
  partial?: boolean;
};

export type Answer = { status: number; body: Record<string, unknown> };

const json = (status: number, body: Record<string, unknown>): Answer => ({
  status,
  body,
});

export async function extract(
  input: { kind?: unknown; ref?: unknown },
  deps: Deps,
): Promise<Answer> {
  // D25: off until the Google trial starts, even with a key.
  if (!await deps.enabled()) return json(503, { error: "not_set_up" });
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
  if ((file.bytes ?? 0) > MAX_BYTES) return json(413, { error: "too_large" });

  const bytes = await deps.download(file.bucket, file.path);
  const total = pdf ? await deps.pageCount(bytes) : 1;
  const pages = Math.max(1, Math.min(total, MAX_PAGES));
  const partial = total > MAX_PAGES;
  if (!await deps.reserve(caller, pages)) {
    return json(429, { error: "daily_limit" });
  }

  const texts: string[] = [];
  let lang: string | null = null;
  try {
    if (pdf) {
      for (let from = 1; from <= pages; from += BATCH) {
        const to = Math.min(from + BATCH - 1, pages);
        const chunk = await deps.split(bytes, from, to);
        const answer = await deps.vision("files:annotate", {
          requests: [{
            inputConfig: { mimeType: "application/pdf", content: base64(chunk) },
            features: [{ type: "DOCUMENT_TEXT_DETECTION" }],
            pages: Array.from({ length: to - from + 1 }, (_, i) => i + 1),
          }],
        });
        for (const r of (answer as VisionFiles)?.responses?.[0]?.responses ?? []) {
          texts.push(r.fullTextAnnotation?.text ?? "");
          lang ??= languageOf(r);
        }
      }
    } else {
      const answer = await deps.vision("images:annotate", {
        requests: [{
          image: { content: base64(bytes) },
          features: [{ type: "DOCUMENT_TEXT_DETECTION" }],
        }],
      });
      const r = (answer as VisionImages)?.responses?.[0];
      texts.push(r?.fullTextAnnotation?.text ?? "");
      lang = r ? languageOf(r) : null;
    }
  } catch (e) {
    await deps.release(caller, pages);
    throw e;
  }
  const text = texts.map((t) => t.trim()).filter((t) => t).join("\n\n");
  await deps.save(kind, ref, caller, lang, text, pages, partial);
  return json(200, { text, lang, pages, partial });
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
