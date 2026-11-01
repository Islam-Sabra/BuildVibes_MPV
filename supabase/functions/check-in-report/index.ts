// Edge Function "check-in-report": each evening, the day's check-in list
// as a spreadsheet in the Library, for the creator only (review 109 part 4).
//
// Called every 15 minutes by cron (supabase/ops/check_in_cron.sql) with the
// secret, read from Vault, and only when check_in_daily_report() says a
// day has ended somewhere. Deployed with verify_jwt = false
// (supabase/config.toml); the secret is the guard. Deploying it, its
// secret and the cron job are live changes for the founder's yes. Secret,
// set in Supabase only:
// - CHECK_IN_REPORT_SECRET: the same value as Vault's check_in_report_secret.
//
// 1. claim_check_in_reports() hands out the waiting days (a claim lasts 10
//    minutes, five tries in all).
// 2. check_in_report_rows() gives each day's lines: names, Teams, times in
//    the Space's time zone, late and the place result. Never a point.
// 3. The .xlsx goes to its path in space-files, then
//    finish_check_in_report() puts it in the Library's "Check-in reports"
//    folder with "only me" visibility for the creator (or the admin once
//    the creator has left).

import { createClient } from "jsr:@supabase/supabase-js@2";
import strings from "./strings.json" with { type: "json" };
import { reportTable, type ReportRow } from "./report.ts";
import { buildXlsx, XLSX_MIME } from "./xlsx.ts";

type Job = {
  post_id: string;
  day: string;
  space_id: string;
  recipient_id: string;
  file_id: string;
  file_name: string;
  storage_path: string;
  title: string;
  locale: string;
  time_zone: string;
};

const db = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);
const enc = new TextEncoder();
const bucket = "space-files";

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

async function store(job: Job): Promise<void> {
  const { data: rows, error } = await db.rpc("check_in_report_rows", {
    p_post: job.post_id,
    p_day: job.day,
  });
  if (error) throw new Error(`rows: ${error.message}`);
  const table = reportTable((rows ?? []) as ReportRow[], job.locale, strings);
  const bytes = buildXlsx(table, { sheetName: job.day, rightToLeft: job.locale === "ar" });
  const { error: up } = await db.storage.from(bucket).upload(job.storage_path, bytes, {
    contentType: XLSX_MIME,
    upsert: true,
  });
  if (up) throw new Error(`upload: ${up.message}`);
  const { error: fin } = await db.rpc("finish_check_in_report", {
    p_post: job.post_id,
    p_day: job.day,
    p_bytes: bytes.length,
    p_error: null,
  });
  if (fin) throw new Error(`finish: ${fin.message}`);
}

Deno.serve(async (req) => {
  const secret = Deno.env.get("CHECK_IN_REPORT_SECRET");
  if (!secret) return new Response("not set up", { status: 500 });
  if (!(await sameSecret(req.headers.get("x-report-secret"), secret))) {
    return new Response("forbidden", { status: 403 });
  }

  const { data: jobs, error } = await db.rpc("claim_check_in_reports", { p_limit: 20 });
  if (error) return new Response("claim failed", { status: 500 });

  let stored = 0;
  let failed = 0;
  for (const job of (jobs ?? []) as Job[]) {
    try {
      await store(job);
      stored++;
    } catch (e) {
      failed++;
      // Back to waiting for the next run (or failed after five tries).
      await db.rpc("finish_check_in_report", {
        p_post: job.post_id,
        p_day: job.day,
        p_bytes: null,
        p_error: String(e).slice(0, 500),
      });
    }
  }
  // Counts only: no names or ids in the logs.
  return new Response(`stored ${stored}, failed ${failed}`, { status: 200 });
});
