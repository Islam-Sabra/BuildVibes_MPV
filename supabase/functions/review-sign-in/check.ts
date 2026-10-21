// The store reviewer's sign-in (review 69 §6, D4): what to answer, without
// the network, so it can be tested. The try counter itself is in Postgres
// (migration 34, review 73 B1): review_sign_in_try() before the code is
// compared, review_sign_in_ok() after a right one.

export type Verdict = "off" | "not_reviewer" | "locked" | "wrong" | "ok";

/// What review_sign_in_try() answered.
export type Try = { allowed: boolean; retryAfter: number };

/// Seconds to wait when the counter's answer can't be read.
export const unreadableRetry = 60;

/// The same email whatever its case or spaces.
export function sameEmail(a: string, b: string): boolean {
  return a.trim().toLowerCase() === b.trim().toLowerCase();
}

/// Before any try is counted: [reviewCode] empty (or not 6 digits)
/// switches the sign-in off between reviews, and another email is never
/// counted. Null means it is the reviewer, so the try is counted next.
export function gate(input: {
  email: string;
  reviewEmail: string;
  reviewCode: string;
}): "off" | "not_reviewer" | null {
  if (!/^[0-9]{6}$/.test(input.reviewCode) || input.reviewEmail.trim() === "") {
    return "off";
  }
  if (!sameEmail(input.email, input.reviewEmail)) return "not_reviewer";
  return null;
}

/// After the try was counted: refused by the lock or the daily cap, or the
/// result of the constant-time comparison, made by the caller.
export function decide(tried: Try, codeMatches: boolean): Verdict {
  if (!tried.allowed) return "locked";
  return codeMatches ? "ok" : "wrong";
}

/// review_sign_in_try()'s answer, read safely: anything malformed is
/// refused, so a broken answer never lets a try through.
export function readTry(value: unknown): Try {
  if (typeof value !== "object" || value === null) {
    return { allowed: false, retryAfter: unreadableRetry };
  }
  const v = value as Record<string, unknown>;
  if (v.allowed === true) return { allowed: true, retryAfter: 0 };
  const retry = typeof v.retry_after === "number" && v.retry_after > 0
    ? Math.ceil(v.retry_after)
    : unreadableRetry;
  return { allowed: false, retryAfter: retry };
}

/// The answer's HTTP status. Not the reviewer, off and a wrong code look
/// the same, so the endpoint can't be probed for the address.
export function statusOf(verdict: Verdict): number {
  switch (verdict) {
    case "ok":
      return 200;
    case "locked":
      return 429;
    default:
      return 401;
  }
}
