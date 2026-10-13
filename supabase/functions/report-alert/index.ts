// Edge Function "report-alert": emails the market's moderation address
// when someone reports something (review 23 §2).
//
// Called by a trigger on reports inserts (supabase/ops/report_alert_webhook.sql)
// with {record: {id}} and the secret, read from Vault. Deployed with
// verify_jwt = false (supabase/config.toml); the secret is the guard.
// Deploying it, its secrets and the trigger are live changes for the
// founder's yes. Secrets, set in Supabase only:
// - REPORT_ALERT_SECRET: the same value as Vault's report_alert_secret;
// - RESEND_API_KEY: a Resend API key that may send from ALERT_FROM;
// - ALERT_FROM: the sender, e.g. "BuildVibes <no-reply@...>".
//
// The email holds only the report's id, kind, reason and time. It never
// quotes the content (report_alert() returns nothing else).

import { createClient } from "jsr:@supabase/supabase-js@2";
import { buildAlert, type Alert } from "./message.ts";

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
  const secret = Deno.env.get("REPORT_ALERT_SECRET");
  const key = Deno.env.get("RESEND_API_KEY");
  const from = Deno.env.get("ALERT_FROM");
  if (!secret || !key || !from) return new Response("not set up", { status: 500 });
  if (!(await sameSecret(req.headers.get("x-alert-secret"), secret))) {
    return new Response("forbidden", { status: 403 });
  }

  const payload = await req.json().catch(() => null);
  const id = String(payload?.record?.id ?? "");
  if (!/^[0-9a-f-]{36}$/.test(id)) return new Response("ignored", { status: 200 });

  const { data, error } = await db.rpc("report_alert", { p_id: id });
  if (error) return new Response("read failed", { status: 500 });
  const row = (data as (Alert & { moderation_email: string | null })[] | null)?.[0];
  // No report, or no address for its market yet: nothing to send.
  if (!row?.moderation_email) return new Response("no address", { status: 200 });

  const mail = buildAlert(row);
  try {
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      signal: AbortSignal.timeout(10_000),
      headers: { authorization: `Bearer ${key}`, "content-type": "application/json" },
      body: JSON.stringify({ from, to: [row.moderation_email], subject: mail.subject, text: mail.text }),
    });
    // The body isn't needed (review 24).
    await res.body?.cancel();
    return new Response(res.ok ? "sent" : `resend ${res.status}`, { status: res.ok ? 200 : 502 });
  } catch {
    // A timeout or a network error: nothing is lost, the report stays open
    // in supabase/ops/moderation.sql query 1.
    return new Response("not sent", { status: 200 });
  }
});
