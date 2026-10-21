// The store reviewer's sign-in (review 69 §6, D4): what to answer, without
// the network, so it can be tested.

/// Wrong codes before the sign-in locks, and for how long.
export const maxFails = 5;
export const lockMinutes = 15;

/// Kept on the reviewer account's app_metadata.review_lock.
export type Lock = { fails: number; lockedUntil: string | null };

export type Verdict = "off" | "not_reviewer" | "locked" | "wrong" | "ok";

export const noLock: Lock = { fails: 0, lockedUntil: null };

/// The same email whatever its case or spaces.
export function sameEmail(a: string, b: string): boolean {
  return a.trim().toLowerCase() === b.trim().toLowerCase();
}

/// What to answer. [reviewCode] empty (or not 6 digits) switches the
/// sign-in off between reviews. [codeMatches] is the constant-time
/// comparison, made by the caller.
export function decide(input: {
  email: string;
  reviewEmail: string;
  reviewCode: string;
  lock: Lock;
  now: Date;
  codeMatches: boolean;
}): Verdict {
  if (!/^[0-9]{6}$/.test(input.reviewCode) || input.reviewEmail.trim() === "") {
    return "off";
  }
  if (!sameEmail(input.email, input.reviewEmail)) return "not_reviewer";
  const until = input.lock.lockedUntil ? Date.parse(input.lock.lockedUntil) : NaN;
  if (!Number.isNaN(until) && until > input.now.getTime()) return "locked";
  return input.codeMatches ? "ok" : "wrong";
}

/// The lock after [verdict]: a wrong code counts, the fifth locks for 15
/// minutes, a right one clears it. Others leave it as it was.
export function nextLock(lock: Lock, verdict: Verdict, now: Date): Lock {
  if (verdict === "ok") return noLock;
  if (verdict !== "wrong") return lock;
  const fails = lock.fails + 1;
  if (fails < maxFails) return { fails, lockedUntil: null };
  return {
    fails: 0,
    lockedUntil: new Date(now.getTime() + lockMinutes * 60_000).toISOString(),
  };
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

/// The lock as stored, or none when it is missing or malformed.
export function readLock(value: unknown): Lock {
  if (typeof value !== "object" || value === null) return noLock;
  const v = value as Record<string, unknown>;
  const fails = typeof v.fails === "number" && v.fails >= 0 ? Math.floor(v.fails) : 0;
  const lockedUntil = typeof v.lockedUntil === "string" ? v.lockedUntil : null;
  return { fails, lockedUntil };
}
