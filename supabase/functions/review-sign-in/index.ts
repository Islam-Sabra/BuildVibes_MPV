// Edge Function "review-sign-in": the App Store and Google Play reviewers'
// way in (review 69 §6, founder's D4). Sign-in is by email code, and a
// reviewer can't read our inbox, so ONE reviewer account signs in with a
// fixed code. Nobody else gets a password or a fixed code.
//
// Deployed with verify_jwt = false (supabase/config.toml): the caller isn't
// signed in yet. Deploying it and setting its secrets are live changes for
// the founder's yes. Secrets, set in Supabase only (never in the app or the
// repo):
// - REVIEW_EMAIL: the reviewer account's email;
// - REVIEW_USER_ID: that account's id (it must have that email);
// - REVIEW_CODE: 6 digits. Clear it between reviews to switch this off.
//
// POST {"email", "code"} → 200 {"access_token", "refresh_token"} for the
// reviewer; 401 for a wrong code, for anyone else and when it is off (the
// same answer, so the address can't be probed); 429 for 15 minutes after
// five wrong codes. The session is a normal one, issued through the admin
// API (a magic link verified on the server).

import { createClient } from "jsr:@supabase/supabase-js@2";
import { decide, nextLock, readLock, sameEmail, statusOf } from "./check.ts";

const url = Deno.env.get("SUPABASE_URL")!;
const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
  auth: { persistSession: false, autoRefreshToken: false },
});
const enc = new TextEncoder();

async function sameSecret(given: string, expected: string): Promise<boolean> {
  const [a, b] = await Promise.all([
    crypto.subtle.digest("SHA-256", enc.encode(given)),
    crypto.subtle.digest("SHA-256", enc.encode(expected)),
  ]);
  const x = new Uint8Array(a), y = new Uint8Array(b);
  let diff = 0;
  for (let i = 0; i < x.length; i++) diff |= x[i] ^ y[i];
  return diff === 0;
}

function answer(status: number, body: Record<string, unknown> = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return answer(405);
  let email = "", code = "";
  try {
    const body = await req.json();
    email = typeof body.email === "string" ? body.email : "";
    code = typeof body.code === "string" ? body.code : "";
  } catch {
    return answer(400);
  }
  const reviewEmail = Deno.env.get("REVIEW_EMAIL") ?? "";
  const reviewCode = Deno.env.get("REVIEW_CODE") ?? "";
  const reviewUserId = Deno.env.get("REVIEW_USER_ID") ?? "";
  const now = new Date();

  // Only the reviewer's tries read or count the lock.
  const first = decide({
    email, reviewEmail, reviewCode, lock: readLock(null), now, codeMatches: false,
  });
  if (first === "off" || first === "not_reviewer" || reviewUserId === "") {
    console.log(`review sign-in: ${first === "off" ? "off" : "refused"}`);
    return answer(401, { error: "wrong_code" });
  }

  const { data: found, error: readError } = await admin.auth.admin.getUserById(reviewUserId);
  const user = found?.user;
  if (readError || !user || !sameEmail(user.email ?? "", reviewEmail)) {
    console.log("review sign-in: account not set up");
    return answer(401, { error: "wrong_code" });
  }
  const lock = readLock(user.app_metadata?.review_lock);
  const verdict = decide({
    email, reviewEmail, reviewCode, lock, now,
    codeMatches: await sameSecret(code.trim(), reviewCode),
  });
  const after = nextLock(lock, verdict, now);
  if (JSON.stringify(after) !== JSON.stringify(lock)) {
    await admin.auth.admin.updateUserById(reviewUserId, {
      app_metadata: { ...user.app_metadata, review_lock: after },
    });
  }
  // Counts only: no email and no code in the logs.
  console.log(`review sign-in: ${verdict}`);
  if (verdict !== "ok") {
    return answer(statusOf(verdict), {
      error: verdict === "locked" ? "too_many" : "wrong_code",
    });
  }

  // A normal session: a magic link for the account, verified here.
  const { data: link, error: linkError } = await admin.auth.admin.generateLink({
    type: "magiclink",
    email: user.email!,
  });
  const tokenHash = link?.properties?.hashed_token;
  if (linkError || !tokenHash) return answer(500);
  const anon = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: signedIn, error: verifyError } = await anon.auth.verifyOtp({
    type: "magiclink",
    token_hash: tokenHash,
  });
  const session = signedIn?.session;
  if (verifyError || !session) return answer(500);
  return answer(200, {
    access_token: session.access_token,
    refresh_token: session.refresh_token,
  });
});
