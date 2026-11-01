import { test } from "node:test";
import assert from "node:assert/strict";
import { groupDue } from "./plan.ts";

test("groups files per account and bucket", () => {
  const out = groupDue([
    { profile_id: "a", bucket: "avatars", name: "a/me.jpg" },
    { profile_id: "a", bucket: "post-media", name: "a/p1/1.jpg" },
    { profile_id: "a", bucket: "post-media", name: "a/p1/2.jpg" },
    { profile_id: "b", bucket: "post-media", name: "b/p2/1.jpg" },
  ]);
  assert.equal(out.length, 2);
  assert.deepEqual(out[0].files.get("avatars"), ["a/me.jpg"]);
  assert.deepEqual(out[0].files.get("post-media"), ["a/p1/1.jpg", "a/p1/2.jpg"]);
  assert.deepEqual([...out[1].files.keys()], ["post-media"]);
});

test("an account with no files is still purged", () => {
  const out = groupDue([{ profile_id: "c", bucket: null, name: null }]);
  assert.equal(out.length, 1);
  assert.equal(out[0].id, "c");
  assert.equal(out[0].files.size, 0);
});

test("nothing due, nothing to do", () => {
  assert.deepEqual(groupDue([]), []);
});

test("review 109: an account's only-me check-in reports in space-files are removed with its other files", () => {
  const [a] = groupDue([
    { profile_id: "p1", bucket: "avatars", name: "p1/me.jpg" },
    { profile_id: "p1", bucket: "space-files", name: "s1/library/f1/check-in-2026-12-01.xlsx" },
    { profile_id: "p1", bucket: "space-files", name: "s1/library/f2/check-in-2026-12-02.xlsx" },
  ]);
  assert.deepEqual(a.files.get("space-files"), [
    "s1/library/f1/check-in-2026-12-01.xlsx",
    "s1/library/f2/check-in-2026-12-02.xlsx",
  ]);
  assert.deepEqual(a.files.get("avatars"), ["p1/me.jpg"]);
});
