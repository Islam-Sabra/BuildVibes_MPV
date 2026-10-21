import { test } from "node:test";
import assert from "node:assert/strict";
import { decide, maxFails, nextLock, noLock, readLock, sameEmail, statusOf } from "./check.ts";

const now = new Date("2026-12-14T10:00:00Z");
const base = {
  email: "reviewer@example.com",
  reviewEmail: "Reviewer@Example.com ",
  reviewCode: "123456",
  lock: noLock,
  now,
  codeMatches: true,
};

test("the reviewer with the right code signs in", () => {
  assert.equal(decide(base), "ok");
  assert.equal(statusOf("ok"), 200);
});

test("off when the code secret is cleared or not 6 digits", () => {
  assert.equal(decide({ ...base, reviewCode: "" }), "off");
  assert.equal(decide({ ...base, reviewCode: "12345" }), "off");
  assert.equal(decide({ ...base, reviewCode: "12345a" }), "off");
  assert.equal(decide({ ...base, reviewEmail: "" }), "off");
});

test("anyone else gets the same answer as a wrong code", () => {
  assert.equal(decide({ ...base, email: "someone@example.com" }), "not_reviewer");
  assert.equal(statusOf("not_reviewer"), statusOf("wrong"));
  assert.equal(statusOf("off"), statusOf("wrong"));
  assert.equal(decide({ ...base, codeMatches: false }), "wrong");
});

test("five wrong codes lock it for 15 minutes; a right one clears it", () => {
  let lock = noLock;
  for (let i = 1; i < maxFails; i++) {
    lock = nextLock(lock, "wrong", now);
    assert.deepEqual(lock, { fails: i, lockedUntil: null });
  }
  lock = nextLock(lock, "wrong", now);
  assert.equal(lock.fails, 0);
  assert.equal(lock.lockedUntil, "2026-12-14T10:15:00.000Z");
  // Locked: even the right code waits.
  assert.equal(decide({ ...base, lock }), "locked");
  assert.equal(statusOf("locked"), 429);
  // After the lock.
  const later = new Date("2026-12-14T10:15:01Z");
  assert.equal(decide({ ...base, lock, now: later }), "ok");
  assert.deepEqual(nextLock(lock, "ok", later), noLock);
  // Someone else's tries never count.
  assert.deepEqual(nextLock({ fails: 2, lockedUntil: null }, "not_reviewer", now), {
    fails: 2,
    lockedUntil: null,
  });
});

test("emails compare without case or spaces", () => {
  assert.ok(sameEmail(" A@B.com", "a@b.COM "));
  assert.ok(!sameEmail("a@b.com", "a@c.com"));
});

test("a stored lock is read safely", () => {
  assert.deepEqual(readLock(undefined), noLock);
  assert.deepEqual(readLock("x"), noLock);
  assert.deepEqual(readLock({ fails: -3, lockedUntil: 5 }), noLock);
  assert.deepEqual(readLock({ fails: 2, lockedUntil: "2026-12-14T10:15:00Z" }), {
    fails: 2,
    lockedUntil: "2026-12-14T10:15:00Z",
  });
});
