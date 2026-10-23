// node --experimental-strip-types --test supabase/functions/push/message.test.ts
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { buildPush, classify, retryAfterSeconds, type QueueRow } from "./message.ts";

const strings = JSON.parse(
  readFileSync(new URL("./strings.json", import.meta.url), "utf8"),
);

const row = (kind: string, extra: Partial<QueueRow> = {}): QueueRow => ({
  id: 1,
  profile_id: "p1",
  kind,
  actor_id: "p-sara",
  thread_id: null,
  data: { space_id: "s1", work_item_id: "i1" },
  message_text: null,
  ...extra,
});

test("every kind has its text in English and Arabic", () => {
  for (const kind of [
    "item_assigned", "item_done", "item_checked", "item_sent_back",
    "item_comment", "join_request", "join_confirmed", "role_confirmed",
    "follow", "post_reply", "chat_message",
    "item_edited", "item_cancelled", "announcement_new", "checklist_for_you",
    "activity_invited", "activity_starting", "file_new_version",
    "dm_message", "dm_request", "dm_follow_up",
  ]) {
    for (const locale of ["en", "ar"]) {
      const p = buildPush(row(kind), locale, "Sara Ali", strings);
      assert.ok(p.body.length > 0 && p.title.length > 0, `${kind} ${locale}`);
      assert.ok(!p.body.includes("{name}") && !p.title.includes("{name}"));
    }
  }
});

test("the text names the person, never the work item; ids go in data", () => {
  const p = buildPush(row("item_assigned"), "en", "Sara Al-Mutairi", strings);
  assert.equal(p.body, "⁨Sara Al-Mutairi⁩ gave you a work item.");
  assert.equal(p.data.route, "/spaces/s1/items/i1");
  assert.equal(p.data.work_item_id, "i1");
});

test("a daybook post opens its card (slice 10); its id travels in the data", () => {
  for (const kind of ["announcement_new", "checklist_for_you", "activity_invited",
                      "activity_starting", "file_new_version", "item_edited", "item_cancelled"]) {
    const p = buildPush(row(kind, { data: { space_id: "s1", space_post_id: "sp1" } }),
                        "en", "Sara Ali", strings);
    assert.equal(p.data.route, "/spaces/s1/items/sp1", kind);
    assert.equal(p.data.space_post_id, "sp1");
  }
  // An edit to a work item still opens the item.
  assert.equal(buildPush(row("item_edited"), "en", "Sara Ali", strings).data.route,
               "/spaces/s1/items/i1");
  // The reminder names nobody.
  assert.equal(
    buildPush(row("activity_starting", { actor_id: null }), "en", null, strings).body,
    "A scheduled activity you are in starts in 30 minutes.");
});

test("a direct message: like chat, one tag per thread; a request never shows text", () => {
  const data = { dm_thread_id: "d1", message_id: "m1" };
  const hidden = buildPush(row("dm_message", { data }), "en", "Omar Haddad", strings);
  assert.equal(hidden.title, "Message from ⁨Omar Haddad⁩");
  assert.equal(hidden.body, "Open BuildVibes to read it.");
  assert.equal(hidden.tag, "d1");
  assert.equal(hidden.data.route, "/messages/d1");
  const shown = buildPush(row("dm_message", { data, message_text: "At the gate." }), "en", "Omar Haddad", strings);
  assert.equal(shown.body, "At the gate.");
  const request = buildPush(row("dm_request", { data, message_text: "Buy now" }), "en", "Sam Spam", strings);
  assert.equal(request.body, "⁨Sam Spam⁩ sent you a message request.");
  assert.equal(request.data.route, "/messages/d1");
});

test("F97: one follow-up for the messages after the first push, never the text", () => {
  const data = { dm_thread_id: "d1", since: "2026-10-23T07:00:00Z", count: "2" };
  const en = buildPush(row("dm_follow_up", { data }), "en", "Omar Haddad", strings);
  assert.equal(en.title, "Message from ⁨Omar Haddad⁩");
  assert.equal(en.body, "2 new messages");
  assert.equal(en.tag, "d1", "it replaces the first push");
  assert.equal(en.data.route, "/messages/d1");
  const words = (n: number, locale: string) =>
    buildPush(row("dm_follow_up", { data: { ...data, count: String(n) } }), locale, "Omar Haddad", strings).body;
  assert.equal(words(1, "en"), "1 new message");
  assert.equal(words(7, "en"), "7 new messages");
  assert.equal(words(1, "ar"), "رسالة جديدة");
  assert.equal(words(2, "ar"), "رسالتان جديدتان");
  assert.equal(words(3, "ar"), "3 رسائل جديدة");
  assert.equal(words(10, "ar"), "10 رسائل جديدة");
  assert.equal(words(11, "ar"), "11 رسالة جديدة");
});

test("a space with no card opens the Space", () => {
  assert.equal(buildPush(row("join_confirmed", { data: { space_id: "s1" } }), "en", "Sara", strings).data.route,
               "/spaces/s1");
});

test("Arabic text with the name kept in its own direction", () => {
  const p = buildPush(row("join_request"), "ar", "Rakesh Nair", strings);
  assert.equal(p.body, "طلب انضمام من ⁨Rakesh Nair⁩ إلى مساحة تديرها.");
  assert.equal(p.data.open, "people");
});

test("chat: the text only when kept for the lock screen; one tag per thread", () => {
  const data = { space_id: "s1", thread_id: "t1", message_id: "m1" };
  const hidden = buildPush(row("chat_message", { thread_id: "t1", data }), "en", "Omar Haddad", strings);
  assert.equal(hidden.title, "New message from ⁨Omar Haddad⁩");
  assert.equal(hidden.body, "Open BuildVibes to read it.");
  assert.equal(hidden.tag, "t1");
  assert.equal(hidden.data.route, "/spaces/s1/chat/t1");
  const shown = buildPush(
    row("chat_message", { thread_id: "t1", data, message_text: "Concrete at 7." }),
    "en", "Omar Haddad", strings,
  );
  assert.equal(shown.body, "Concrete at 7.");
});

test("no name: Someone", () => {
  const p = buildPush(row("follow", { data: {} }), "en", null, strings);
  assert.equal(p.body, "⁨Someone⁩ started following you.");
  assert.equal(p.data.route, "/people/p-sara");
});

test("only an error that names the token deletes it", () => {
  assert.equal(classify(404, '{"error":{"status":"NOT_FOUND","details":[{"errorCode":"UNREGISTERED"}]}}'), "dead");
  assert.equal(classify(400, '{"error":{"status":"INVALID_ARGUMENT","message":"The registration token is not a valid FCM registration token"}}'), "dead");
  // Another project's key, or a wrong project or URL: every phone stays.
  assert.equal(classify(403, '{"error":{"details":[{"errorCode":"SENDER_ID_MISMATCH"}]}}'), "failed");
  assert.equal(classify(404, "Not Found"), "failed");
  // FCM's own NOT_FOUND for one token: gone, deleted only when another
  // phone in the same send got it (index.ts).
  assert.equal(classify(404, '{"error":{"code":404,"status":"NOT_FOUND","message":"Requested entity was not found."}}'), "gone");
  assert.equal(classify(400, '{"error":{"status":"INVALID_ARGUMENT","message":"Invalid JSON payload"}}'), "failed");
});

test("429 and 5xx are tried again, after Retry-After", () => {
  assert.equal(classify(429, '{"error":{"status":"RESOURCE_EXHAUSTED"}}'), "retry");
  assert.equal(classify(503, "Service Unavailable"), "retry");
  assert.equal(retryAfterSeconds("30"), 30);
  assert.equal(retryAfterSeconds(null), null);
  assert.equal(retryAfterSeconds("soon"), null);
  assert.equal(retryAfterSeconds("99999"), 3600);
});
