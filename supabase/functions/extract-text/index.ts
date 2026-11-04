// Edge Function "extract-text" (review 103, OCR): "Extract text" on a
// scan or an image PDF, only when someone taps it. Reads the file with
// Google Cloud Vision (document text detection) and keeps the text with
// the file (file_texts), searchable in Space and notebook search.
//
// Signed-in callers only: their own sign-in asks file_for_text, so a file
// they can't open is never read. The service role downloads the file and
// keeps the text (save_file_text: 20 pages a file, 50 a person a day).
//
// NOT DEPLOYED. A live change for the founder's yes, after migration
// 20261128120000 is live. Secret, set in Supabase only:
// - GOOGLE_VISION_KEY: a Google Cloud project's API key restricted to the
//   Vision API. Without it the function answers 503 and the app says
//   "Couldn't read this file".

import { createClient } from "jsr:@supabase/supabase-js@2";
import { type Deps, extract, type FileKind } from "./read.ts";

const url = Deno.env.get("SUPABASE_URL")!;
const service = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response(null, { status: 405 });
  const key = Deno.env.get("GOOGLE_VISION_KEY");
  if (!key) return reply(503, { error: "not_set_up" });
  const auth = req.headers.get("Authorization") ?? "";
  // The caller's own client: what they may read, as they are.
  const asCaller = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: auth } },
  });
  let input: { kind?: unknown; ref?: unknown } = {};
  try {
    input = await req.json();
  } catch {
    return reply(400, { error: "bad_request" });
  }
  const deps: Deps = {
    caller: async () => {
      if (!auth.startsWith("Bearer ")) return null;
      const { data } = await asCaller.auth.getUser(auth.slice(7));
      return data.user?.id ?? null;
    },
    fileFor: async (kind: FileKind, ref: string) => {
      const { data, error } = await asCaller.rpc("file_for_text", {
        p_kind: kind,
        p_ref: ref,
      });
      if (error || !data?.length) return null;
      return data[0];
    },
    kept: async (kind: FileKind, ref: string) => {
      const { data } = await service.from("file_texts")
        .select("text, lang, pages")
        .eq("file_kind", kind).eq("file_ref", ref).maybeSingle();
      return data ?? null;
    },
    pagesLeft: async (caller: string) => {
      const { data, error } = await service.rpc("text_pages_left", { p_who: caller });
      if (error) throw error;
      return data as number;
    },
    download: async (bucket: string, path: string) => {
      const { data, error } = await service.storage.from(bucket).download(path);
      if (error || !data) throw error ?? new Error("no file");
      return new Uint8Array(await data.arrayBuffer());
    },
    vision: async (endpoint: string, body: unknown) => {
      const res = await fetch(
        `https://vision.googleapis.com/v1/${endpoint}?key=${encodeURIComponent(key)}`,
        {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify(body),
        },
      );
      if (!res.ok) throw new Error(`vision ${res.status}`);
      return await res.json();
    },
    save: async (kind, ref, caller, lang, text, pages) => {
      const { error } = await service.rpc("save_file_text", {
        p_kind: kind,
        p_ref: ref,
        p_who: caller,
        p_lang: lang,
        p_text: text,
        p_pages: pages,
      });
      if (error) throw error;
    },
  };
  try {
    const answer = await extract(input, deps);
    return reply(answer.status, answer.body);
  } catch (e) {
    // Counts only, never the file's words or names.
    console.error(`extract-text failed: ${(e as Error).message}`);
    return reply(502, { error: "could_not_read" });
  }
});

function reply(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}
