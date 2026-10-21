import { test } from "node:test";
import assert from "node:assert/strict";
import { decide, gate, readTry, sameEmail, statusOf, unreadableRetry } from "./check.ts";

const base = {
  email: "reviewer@example.com",
  reviewEmail: "Reviewer@Example.com ",
  reviewCode: "123456",
};
const allowed = { allowed: true, retryAfter: 0 };

test("the reviewer with the right code signs in", () => {
  assert.equal(gate(base), null);
  assert.equal(decide(allowed, true), "ok");
  assert.equal(statusOf("ok"), 200);
});

test("off when the code secret is cleared or not 6 digits", () => {
  assert.equal(gate({ ...base, reviewCode: "" }), "off");
  assert.equal(gate({ ...base, reviewCode: "12345" }), "off");
  assert.equal(gate({ ...base, reviewCode: "12345a" }), "off");
  assert.equal(gate({ ...base, reviewEmail: "" }), "off");
});

test("anyone else gets the same answer as a wrong code, and isn't counted", () => {
  // gate() runs before review_sign_in_try(), so another email never counts.
  assert.equal(gate({ ...base, email: "someone@example.com" }), "not_reviewer");
  assert.equal(statusOf("not_reviewer"), statusOf("wrong"));
  assert.equal(statusOf("off"), statusOf("wrong"));
  assert.equal(decide(allowed, false), "wrong");
});

test("a try the counter refuses is never compared, even with the right code", () => {
  const refused = { allowed: false, retryAfter: 900 };
  assert.equal(decide(refused, true), "locked");
  assert.equal(decide(refused, false), "locked");
  assert.equal(statusOf("locked"), 429);
});

test("the counter's answer is read as given", () => {
  assert.deepEqual(readTry({ allowed: true, retry_after: 0 }), allowed);
  assert.deepEqual(readTry({ allowed: false, retry_after: 900 }), {
    allowed: false,
    retryAfter: 900,
  });
  assert.deepEqual(readTry({ allowed: false, retry_after: 12.2 }), {
    allowed: false,
    retryAfter: 13,
  });
});

test("a malformed answer from the counter refuses the try", () => {
  const refused = { allowed: false, retryAfter: unreadableRetry };
  assert.deepEqual(readTry(null), refused);
  assert.deepEqual(readTry(undefined), refused);
  assert.deepEqual(readTry("allowed"), refused);
  assert.deepEqual(readTry({ allowed: "true" }), refused);
  assert.deepEqual(readTry({ allowed: 1, retry_after: -5 }), refused);
  assert.deepEqual(readTry([{ allowed: true }]), refused);
});

test("emails compare without case or spaces", () => {
  assert.ok(sameEmail(" A@B.com", "a@b.COM "));
  assert.ok(!sameEmail("a@b.com", "a@c.com"));
});
