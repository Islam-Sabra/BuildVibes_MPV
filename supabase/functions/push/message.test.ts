// node --experimental-strip-types --test supabase/functions/push/message.test.ts
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { buildPush, type QueueRow } from "./message.ts";

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
