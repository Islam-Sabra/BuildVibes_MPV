// Edge Function "account-purge": removes accounts 30 days after the person
// asked to delete them (review 23 §3, S14).
//
// Called once a night by cron (supabase/ops/account_cron.sql) with the
// secret, read from Vault. Deployed with verify_jwt = false
// (supabase/config.toml); the secret is the guard. Deploying it, its secret
// and the cron job are live changes for the founder's yes. Secret, set in
// Supabase only:
// - ACCOUNT_PURGE_SECRET: the same value as Vault's account_purge_secret.
//
// For each account due: its avatar and post photos go through the Storage
// API first (SQL can't delete stored files), then purge_account() deletes
// the user. If a file can't be deleted, the account waits for the next
// night rather than leave files nobody owns.

import { createClient } from "jsr:@supabase/supabase-js@2";
import { groupDue, type DueRow } from "./plan.ts";

const db = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);
const enc = new TextEncoder();

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
  const secret = Deno.env.get("ACCOUNT_PURGE_SECRET");
  if (!secret) return new Response("not set up", { status: 500 });
  if (!(await sameSecret(req.headers.get("x-purge-secret"), secret))) {
    return new Response("forbidden", { status: 403 });
  }

  const { data, error } = await db.rpc("accounts_due_for_purge");
  if (error) return new Response("read failed", { status: 500 });

  let purged = 0, waiting = 0;
  for (const account of groupDue((data ?? []) as DueRow[])) {
    let filesGone = true;
    for (const [bucket, names] of account.files) {
      // remove() takes up to 1,000 paths a call.
      for (let i = 0; i < names.length; i += 1000) {
        const { error: e } = await db.storage.from(bucket).remove(names.slice(i, i + 1000));
        if (e) filesGone = false;
      }
    }
    if (!filesGone) {
      waiting++;
      continue;
    }
    const { data: done, error: e } = await db.rpc("purge_account", { p_id: account.id });
    if (!e && done === true) purged++;
    else waiting++;
  }
  // Counts only: no ids or names in the logs.
  return new Response(`purged ${purged}, waiting ${waiting}`, { status: 200 });
});
