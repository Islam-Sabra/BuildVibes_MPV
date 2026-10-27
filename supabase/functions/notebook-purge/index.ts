// Edge Function "notebook-purge": the notebook's Deleted items go for good
// once past each person's 7, 30 or 90 days (review 99B B3), with their files.
//
// Called once a night by cron (supabase/ops/notebook_purge_cron.sql) with
// the secret, read from Vault. Deployed with verify_jwt = false
// (supabase/config.toml); the secret is the guard. Deploying it, its secret
// and the cron job are live changes for the founder's yes. Secret, set in
// Supabase only:
// - NOTEBOOK_PURGE_SECRET: the same value as Vault's notebook_purge_secret.
//
// 1. purge_notebook() deletes what is due; its files are then orphans.
// 2. orphan_note_files() claims notebook files no entry uses any more (a
//    day old at least), and they go through the Storage API (SQL can't
//    delete stored files).
// 3. forget_cleanup_claims() lets go of the claims whose files are gone; a
//    file that couldn't be deleted waits for the next night.

import { createClient } from "jsr:@supabase/supabase-js@2";

const db = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);
const enc = new TextEncoder();
const bucket = "notebook-files";

async function sameSecret(given: string | null, expected: string): Promise<boolean> {
  const [a, b] = await Promise.all([
    crypto.subtle.digest("SHA-256", enc.encode(given ?? "")),
    crypto.subtle.digest("SHA-256", enc.encode(expected)),
  ]);
  const x = new Uint8Array(a), y = new Uint8Array(b);
  let diff = 0;
  for (let i = 0; i < x.length; i++) diff |= x[i] ^ y[i];
  return diff === 0;
}

Deno.serve(async (req) => {
  const secret = Deno.env.get("NOTEBOOK_PURGE_SECRET");
  if (!secret) return new Response("not set up", { status: 500 });
  if (!(await sameSecret(req.headers.get("x-purge-secret"), secret))) {
    return new Response("forbidden", { status: 403 });
  }

  const { data: purged, error } = await db.rpc("purge_notebook");
  if (error) return new Response("purge failed", { status: 500 });

  const { data: orphans, error: e } = await db.rpc("orphan_note_files", {
    p_age: "1 day",
  });
  if (e) return new Response("files not read", { status: 500 });
  const names = ((orphans ?? []) as { name: string }[]).map((o) => o.name);
  let filesLeft = 0;
  // remove() takes up to 1,000 paths a call.
  for (let i = 0; i < names.length; i += 1000) {
    const { error: r } = await db.storage.from(bucket).remove(names.slice(i, i + 1000));
    if (r) filesLeft += Math.min(1000, names.length - i);
  }
  await db.rpc("forget_cleanup_claims");
  // Counts only: no ids or names in the logs.
  return new Response(
    `purged ${purged ?? 0}, files ${names.length - filesLeft}, waiting ${filesLeft}`,
    { status: 200 },
  );
});
