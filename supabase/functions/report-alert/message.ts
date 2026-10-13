// The moderation alert email. No Deno or network here, so it is tested with
// Node: node --experimental-strip-types --test supabase/functions/report-alert/message.test.ts
//
// It never quotes the reported content or names anyone: only the report's
// id, what kind of thing it is, the reason, the time, and how to decide.

export type Alert = {
  id: string;
  target_kind: string;
  reason: string;
  created_at: string;
};

const kinds: Record<string, string> = {
  post: "a post",
  reply: "a reply",
  message: "a Space chat message",
  profile: "a person",
};

const reasons: Record<string, string> = {
  spam: "Spam",
  scam_or_misleading: "Scam or misleading",
  inappropriate_content: "Inappropriate content",
  harassment: "Harassment",
  unsafe_construction_advice: "Unsafe construction advice",
  other: "Something else (see the note in the report)",
};

const OPS = "supabase/ops/moderation.sql";

export function buildAlert(a: Alert): { subject: string; text: string } {
  const kind = kinds[a.target_kind] ?? a.target_kind;
  const reason = reasons[a.reason] ?? a.reason;
  return {
    subject: `BuildVibes report: ${kind} (${reason})`,
    text: [
      `Someone reported ${kind}.`,
      ``,
      `Reason: ${reason}`,
      `Report id: ${a.id}`,
      `Sent: ${a.created_at}`,
      ``,
      `To look at it and decide (remove or dismiss), use ${OPS}.`,
      `Please reply within 24 hours.`,
    ].join("\n"),
  };
}
