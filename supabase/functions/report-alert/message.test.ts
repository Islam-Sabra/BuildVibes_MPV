// node --experimental-strip-types --test supabase/functions/report-alert/message.test.ts
import { test } from "node:test";
import assert from "node:assert/strict";
import { buildAlert } from "./message.ts";

test("the alert says what kind, why, and which report", () => {
  const m = buildAlert({
    id: "1b2c", target_kind: "post", reason: "harassment", created_at: "2026-10-13T08:00:00Z",
  });
  assert.equal(m.subject, "BuildVibes report: a post (Harassment)");
  assert.ok(m.text.includes("Report id: 1b2c"));
  assert.ok(m.text.includes("supabase/ops/moderation.sql"));
});

test("it never carries content: only these fields exist", () => {
  const m = buildAlert({
    id: "x", target_kind: "message", reason: "other", created_at: "t",
  });
  // Nothing beyond the four fields can reach the email.
  assert.ok(m.text.includes("a Space chat message"));
  assert.ok(!/body|note:/i.test(m.text));
});
