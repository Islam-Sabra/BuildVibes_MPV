// Edge Function "translate": a post in the other app language (L1–L4,
// review 23 §4).
//
// Called by the app with the person's own sign-in (verify_jwt on,
// supabase/config.toml) and {post_id, target}. The post is read with that
// token, so every read rule applies: nobody translates a post they can't
// see. A cached translation newer than the post's last edit is used;
// otherwise Google Cloud Translation (Basic, v2) is asked, at most 100 new
// translations per person a day, and the result is cached.
//
// Until the secret GOOGLE_TRANSLATE_API_KEY is set in Supabase, it answers
// with a fixed stand-in sentence ("stand_in": true), never stored or
// counted. Deploying it is a live change for the founder's yes.
//
// The post's text and the translation are never logged.

import { createClient } from "jsr:@supabase/supabase-js@2";
import { googleRequest, parseGoogle, parseRequest, standIn, type Lang } from "./translate.ts";

const url = Deno.env.get("SUPABASE_URL")!;
const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method" }, 405);
  const auth = req.headers.get("authorization");
  if (!auth) return json({ error: "sign_in" }, 401);

  const input = parseRequest(await req.json().catch(() => null));
  if (!input) return json({ error: "bad_request" }, 400);

  // As the caller: who they are, and the post only if they may read it.
  const caller = createClient(url, anonKey, { global: { headers: { Authorization: auth } } });
  const { data: who } = await caller.auth.getUser();
  if (!who?.user) return json({ error: "sign_in" }, 401);
  const { data: post, error: readError } = await caller
    .from("posts")
    .select("id, body, lang")
    .eq("id", input.postId)
    .maybeSingle();
  if (readError) return json({ error: "read" }, 500);
  if (!post || !post.body) return json({ error: "not_found" }, 404);
  const source = post.lang as Lang;
  if (source === input.target) return json({ error: "same_language" }, 400);

  const { data: cached } = await admin.rpc("cached_translation", {
    p_post: post.id,
    p_lang: input.target,
  });
  if (typeof cached === "string") return json({ body: cached, source });

  const key = Deno.env.get("GOOGLE_TRANSLATE_API_KEY");
  if (!key) return json({ body: standIn(input.target), source, stand_in: true });

  const { data: allowed, error: claimError } = await admin.rpc("claim_translation", {
    p_profile: who.user.id,
  });
  if (claimError) return json({ error: "count" }, 500);
  if (allowed !== true) return json({ error: "limit" }, 429);

  const g = googleRequest(key, post.body, source, input.target);
  let body: string | null = null;
  try {
    const res = await fetch(g.url, { ...g.init, signal: AbortSignal.timeout(10_000) });
    body = res.ok ? parseGoogle(await res.json()) : null;
    if (!res.ok) {
      await res.body?.cancel();
      console.error("translate: google status", res.status);
    }
  } catch {
    console.error("translate: google unreachable");
  }
  if (!body) return json({ error: "translate" }, 502);

  await admin.rpc("save_translation", { p_post: post.id, p_lang: input.target, p_body: body });
  return json({ body, source });
});
