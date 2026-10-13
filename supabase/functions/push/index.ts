// Edge Function "push": sends one queued push through FCM HTTP v1.
//
// Called by a trigger on push_queue inserts (supabase/ops/push_webhook.sql)
// and every minute by cron for rows to try again (supabase/ops/push_cron.sql).
// Both send {record: {id}} and the secret, read from Vault. Not a dashboard
// webhook: it would keep the secret in plain text in the catalog (review 22).
//
// Deployed with verify_jwt = false (supabase/config.toml): the callers send
// no signed-in user, so the shared secret is the guard. Secrets, set in
// Supabase only:
// - FIREBASE_SERVICE_ACCOUNT: the Firebase service-account key (JSON),
//   pasted by the founder;
// - PUSH_WEBHOOK_SECRET: the same value as Vault's push_webhook_secret,
//   sent in the x-push-secret header.
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY come with every function.
//
// The body is trusted for one thing only, the row id. The row is claimed
// in the database (claim_push), so a repeated call sends once, and the
// push is built from the database copy.

import { createClient } from "jsr:@supabase/supabase-js@2";
import strings from "./strings.json" with { type: "json" };
import { buildPush, classify, retryAfterSeconds, type QueueRow } from "./message.ts";

type ServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
};

const db = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);
const account: ServiceAccount = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT") ?? "{}");
const enc = new TextEncoder();

// Well inside the 60-second claim window, so a slow call never overlaps a
// retry of the same row (review 22).
const timeout = () => AbortSignal.timeout(10_000);

// --- The webhook secret, compared in constant time --------------------------

async function digest(s: string): Promise<Uint8Array> {
  return new Uint8Array(await crypto.subtle.digest("SHA-256", enc.encode(s)));
}

async function sameSecret(given: string | null, expected: string): Promise<boolean> {
  const [a, b] = await Promise.all([digest(given ?? ""), digest(expected)]);
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i];
  return diff === 0;
}

// --- Google access token (cached until a minute before it expires) ---------

let cached: { token: string; until: number } | null = null;

const b64url = (bytes: Uint8Array) =>
  btoa(String.fromCharCode(...bytes)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

async function accessToken(): Promise<string> {
  if (cached && Date.now() < cached.until) return cached.token;
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(enc.encode(JSON.stringify({ alg: "RS256", typ: "JWT" })));
  const claims = b64url(enc.encode(JSON.stringify({
    iss: account.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  })));
  const pem = account.private_key.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const key = await crypto.subtle.importKey(
    "pkcs8",
    Uint8Array.from(atob(pem), (c) => c.charCodeAt(0)),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, enc.encode(`${header}.${claims}`)),
  );
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    signal: timeout(),
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${header}.${claims}.${b64url(signature)}`,
    }),
  });
  if (!res.ok) throw new Error(`google token: ${res.status}`);
  const body = await res.json();
  cached = { token: body.access_token, until: Date.now() + (body.expires_in - 60) * 1000 };
  return cached.token;
}

// --- Sending ----------------------------------------------------------------

async function send(row: QueueRow): Promise<void> {
  const [{ data: tokens, error: tokenError }, { data: actor }] = await Promise.all([
    db.from("push_tokens").select("token, platform, locale").eq("profile_id", row.profile_id),
    row.actor_id
      ? db.from("profiles").select("first_name, last_name").eq("id", row.actor_id).maybeSingle()
      : Promise.resolve({ data: null }),
  ]);
  if (tokenError) throw new Error(tokenError.message);
  const name = actor ? `${actor.first_name ?? ""} ${actor.last_name ?? ""}`.trim() : null;

  const failed: string[] = [];
  let retry = false;
  let wait: number | null = null;
  for (const t of tokens ?? []) {
    const push = buildPush(row, t.locale, name, strings);
    const res = await fetch(
      `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`,
      {
        method: "POST",
        signal: timeout(),
        headers: {
          authorization: `Bearer ${await accessToken()}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token: t.token,
            notification: { title: push.title, body: push.body },
            data: push.data,
            android: {
              priority: "high",
              notification: { channel_id: "buildvibes", ...(push.tag ? { tag: push.tag } : {}) },
            },
          },
        }),
      },
    );
    if (res.ok) continue;
    const detail = await res.text();
    switch (classify(res.status, detail)) {
      case "dead":
        await db.from("push_tokens").delete().eq("token", t.token);
        break;
      case "retry":
        retry = true;
        wait = Math.max(wait ?? 0, retryAfterSeconds(res.headers.get("retry-after")) ?? 0);
        failed.push(`${res.status}`);
        break;
      case "failed":
        failed.push(`${res.status} ${detail.slice(0, 200)}`);
    }
  }

  const error = failed.join("; ") || null;
  if (retry) {
    // Back in the queue. With several phones, one that already got it may
    // get it again: rare, and better than losing it.
    await db.rpc("release_push", {
      p_id: row.id,
      p_wait: wait ? `${wait} seconds` : null,
      p_error: error,
    });
  } else {
    await db.rpc("finish_push", { p_id: row.id, p_error: error });
  }
}

Deno.serve(async (req) => {
  const secret = Deno.env.get("PUSH_WEBHOOK_SECRET");
  if (!secret) return new Response("not set up", { status: 500 });
  if (!(await sameSecret(req.headers.get("x-push-secret"), secret))) {
    return new Response("forbidden", { status: 403 });
  }

  // Only the row id is read; the row itself comes from the database.
  const payload = await req.json().catch(() => null);
  const id = Number(payload?.record?.id);
  if (!Number.isSafeInteger(id) || id <= 0) {
    return new Response("ignored", { status: 200 });
  }

  // Claim it: nothing back means another call has it, or it is done.
  const { data: claimed, error } = await db.rpc("claim_push", { p_id: id });
  if (error) return new Response("claim failed", { status: 500 });
  const row = (claimed as QueueRow[] | null)?.[0];
  if (!row) return new Response("nothing to send", { status: 200 });

  try {
    await send(row);
  } catch (e) {
    // Network or Google trouble: back in the queue for the next retry.
    await db.rpc("release_push", { p_id: row.id, p_wait: null, p_error: String(e).slice(0, 500) });
  }
  return new Response("ok", { status: 200 });
});
