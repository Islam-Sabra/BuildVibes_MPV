// Edge Function "push": sends one queued push through FCM HTTP v1.
//
// Called by a database webhook on push_queue inserts (not added yet: a live
// change that waits for the founder's yes). Secrets, set in Supabase only:
// - FCM_SERVICE_ACCOUNT: the Firebase service-account key (JSON), pasted by
//   the founder;
// - PUSH_WEBHOOK_SECRET: sent by the webhook in the x-push-secret header.
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY come with every function.

import { createClient } from "jsr:@supabase/supabase-js@2";
import strings from "./strings.json" with { type: "json" };
import { buildPush, type QueueRow } from "./message.ts";

type ServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
};

const db = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);
const account: ServiceAccount = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT") ?? "{}");

// --- Google access token (cached until a minute before it expires) ---------

let cached: { token: string; until: number } | null = null;

const b64url = (bytes: Uint8Array) =>
  btoa(String.fromCharCode(...bytes)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
const enc = new TextEncoder();

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

// FCM says the token no longer works: the phone uninstalled or signed out.
const deadToken = (status: number, detail: string) =>
  status === 404 || detail.includes("UNREGISTERED") ||
  (status === 400 && detail.includes("registration token"));

Deno.serve(async (req) => {
  if (req.headers.get("x-push-secret") !== Deno.env.get("PUSH_WEBHOOK_SECRET")) {
    return new Response("forbidden", { status: 403 });
  }
  const payload = await req.json();
  const row = payload?.record as QueueRow | undefined;
  if (!row || payload.table !== "push_queue" || payload.type !== "INSERT") {
    return new Response("ignored", { status: 200 });
  }

  const [{ data: tokens }, { data: actor }] = await Promise.all([
    db.from("push_tokens").select("token, platform, locale").eq("profile_id", row.profile_id),
    row.actor_id
      ? db.from("profiles").select("first_name, last_name").eq("id", row.actor_id).maybeSingle()
      : Promise.resolve({ data: null }),
  ]);
  const name = actor ? `${actor.first_name ?? ""} ${actor.last_name ?? ""}`.trim() : null;

  const errors: string[] = [];
  for (const t of tokens ?? []) {
    const push = buildPush(row, t.locale, name, strings);
    const res = await fetch(
      `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`,
      {
        method: "POST",
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
    if (!res.ok) {
      const detail = await res.text();
      if (deadToken(res.status, detail)) {
        await db.from("push_tokens").delete().eq("token", t.token);
      } else {
        errors.push(`${res.status} ${detail.slice(0, 200)}`);
      }
    }
  }

  await db.from("push_queue")
    .update({ sent_at: new Date().toISOString(), error: errors.join("; ").slice(0, 500) || null })
    .eq("id", row.id);
  return new Response("ok", { status: 200 });
});
