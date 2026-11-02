// node --experimental-strip-types --test supabase/functions/push/message.test.ts
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import {
  buildPush, channelFor, classify, DEFAULT_CHANNEL, fcmMessage, MESSAGE_CHANNEL, NEED_YOU_CHANNEL,
  REACTIONS_CHANNEL, retryAfterSeconds, type QueueRow,
} from "./message.ts";

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
    "work_reminder", "scheduled_failed", "check_in_open", "check_in_summary",
    "post_reaction", "work_item_archived", "check_in_nudge", "need_you", "need_you_answer",
    "scheduled_expiring",
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

test("F102: a direct message, text off: who, and how many, on one notification per thread", () => {
  const data = { dm_thread_id: "d1", message_id: "m1", count: "1" };
  const one = buildPush(row("dm_message", { data }), "en", "Omar Haddad", strings);
  assert.equal(one.title, "Message from ⁨Omar Haddad⁩");
  assert.equal(one.body, "1 new message");
  assert.equal(one.tag, "d1");
  assert.equal(one.data.route, "/messages/d1");
  assert.equal(one.data.shown, undefined);
  const three = buildPush(row("dm_message", { data: { ...data, count: "3" } }), "en", "Omar Haddad", strings);
  assert.equal(`${three.title} · ${three.body}`, "Message from ⁨Omar Haddad⁩ · 3 new messages");
  assert.equal(three.tag, "d1", "the same tag: it replaces the last one");
  const ar = (n: number) => buildPush(row("dm_message", { data: { ...data, count: String(n) } }), "ar", "عمر حداد", strings);
  assert.equal(`${ar(3).title} · ${ar(3).body}`, "رسالة من ⁨عمر حداد⁩ · 3 رسائل جديدة");
  assert.deepEqual([1, 2, 3, 10, 11].map((n) => ar(n).body),
    ["رسالة جديدة", "رسالتان جديدتان", "3 رسائل جديدة", "10 رسائل جديدة", "11 رسالة جديدة"]);
  // A push queued before migration 41 has no count: one message.
  const old = buildPush(row("dm_message", { data: { dm_thread_id: "d1" } }), "en", "Omar Haddad", strings);
  assert.equal(old.body, "1 new message");
});

test("F102, review 89 M3: a direct message, text on: the name and the count as the title, the newest words as the body", () => {
  const data = { dm_thread_id: "d1", message_id: "m1", count: "1" };
  const one = buildPush(row("dm_message", { data, message_text: "Pump is late" }), "en", "Omar Haddad", strings);
  assert.equal(one.title, "⁨Omar Haddad⁩");
  assert.equal(one.body, "Pump is late");
  assert.equal(one.data.shown, "1");
  const three = buildPush(row("dm_message", { data: { ...data, count: "3" }, message_text: "Pump is late" }),
                          "en", "Omar Haddad", strings);
  assert.equal(three.title, "⁨Omar Haddad⁩ · 3 new messages");
  assert.equal(three.body, "Pump is late");
  assert.equal(three.tag, "d1");
  const ar = buildPush(row("dm_message", { data: { ...data, count: "2" }, message_text: "المضخة متأخرة" }),
                       "ar", "عمر حداد", strings);
  assert.equal(ar.title, "⁨عمر حداد⁩ · رسالتان جديدتان");
  assert.equal(ar.body, "المضخة متأخرة");
});

test("a message request never shows text", () => {
  const data = { dm_thread_id: "d1", message_id: "m1" };
  const request = buildPush(row("dm_request", { data, message_text: "Buy now" }), "en", "Sam Spam", strings);
  assert.equal(request.body, "⁨Sam Spam⁩ sent you a message request.");
  assert.equal(request.data.route, "/messages/d1");
});

test("F97: a follow-up queued before migration 41 still reads right, never the text", () => {
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

test("F102: Space chat names the person, never the thread or the Space; one tag per thread", () => {
  const data = { space_id: "s1", thread_id: "t1", message_id: "m1", count: "3" };
  const hidden = buildPush(row("chat_message", { thread_id: "t1", data }), "en", "Omar Haddad", strings);
  assert.equal(`${hidden.title} · ${hidden.body}`,
    "Message from ⁨Omar Haddad⁩ in a Space chat · 3 new messages");
  assert.equal(hidden.tag, "t1");
  assert.equal(hidden.data.route, "/spaces/s1/chat/t1");
  const ar = buildPush(row("chat_message", { thread_id: "t1", data }), "ar", "عمر حداد", strings);
  assert.equal(`${ar.title} · ${ar.body}`, "رسالة من ⁨عمر حداد⁩ في محادثة مساحة · 3 رسائل جديدة");
  const shown = buildPush(
    row("chat_message", { thread_id: "t1", data: { ...data, count: "1" }, message_text: "Concrete at 7." }),
    "en", "Omar Haddad", strings,
  );
  assert.equal(shown.title, "⁨Omar Haddad⁩ in a Space chat");
  assert.equal(shown.body, "Concrete at 7.");
  const two = buildPush(
    row("chat_message", { thread_id: "t1", data: { ...data, count: "2" }, message_text: "Concrete at 7." }),
    "en", "Omar Haddad", strings,
  );
  assert.equal(two.title, "⁨Omar Haddad⁩ in a Space chat · 2 new messages");
  assert.equal(two.body, "Concrete at 7.");
});

test("F102: FCM gets a notification Android draws, tagged per conversation, with sound", () => {
  const push = buildPush(row("dm_message", { data: { dm_thread_id: "d1", count: "2" } }), "en", "Omar Haddad", strings);
  const m = fcmMessage("tok", push) as {
    token: string;
    notification: { title: string; body: string };
    data: Record<string, string>;
    android: { priority: string; notification: Record<string, unknown> };
  };
  assert.equal(m.token, "tok");
  assert.deepEqual(m.notification, { title: "Message from ⁨Omar Haddad⁩", body: "2 new messages" });
  assert.equal(m.android.priority, "high");
  assert.equal(m.android.notification.channel_id, "buildvibes_messages");
  assert.equal(m.android.notification.tag, "d1");
  assert.equal(m.android.notification.default_sound, true);
  assert.equal(m.android.notification.default_vibrate_timings, true);
  assert.equal(m.data.count, "2");
  // Other kinds: no tag, each stands alone.
  const item = fcmMessage("tok", buildPush(row("item_assigned"), "en", "Sara", strings)) as {
    android: { notification: Record<string, unknown> };
  };
  assert.equal(item.android.notification.tag, undefined);
  assert.equal(item.android.notification.channel_id, "buildvibes");
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

test("review 89 M2: messages go on their own channel, with vibration; the rest stay on buildvibes", () => {
  assert.equal(MESSAGE_CHANNEL, "buildvibes_messages");
  assert.equal(DEFAULT_CHANNEL, "buildvibes");
  for (const kind of ["dm_message", "dm_request", "chat_message", "dm_follow_up"]) {
    assert.equal(channelFor(kind), MESSAGE_CHANNEL, kind);
  }
  for (const kind of ["item_assigned", "announcement_new", "join_request", "follow", undefined]) {
    assert.equal(channelFor(kind), DEFAULT_CHANNEL, String(kind));
  }
  // The app makes that channel, with vibration on (MainActivity).
  const activity = readFileSync(new URL(
    "../../../android/app/src/main/kotlin/com/buildvibes/buildvibes/MainActivity.kt", import.meta.url), "utf8");
  assert.ok(activity.includes(`"${MESSAGE_CHANNEL}"`) && activity.includes("enableVibration(true)"));
  assert.ok(activity.includes(`"${DEFAULT_CHANNEL}"`));
});

// Review 108 (migration 57).
const reminder = (extra: Partial<QueueRow> = {}): QueueRow =>
  row("work_reminder", {
    actor_id: "p-islam",
    data: { space_id: "s1", space_post_id: "sp1", due_at: "2026-11-01T07:00:00Z", tz: "Asia/Kuwait" },
    ...extra,
  });

test("review 108 RM2: a reminder from someone opens the item; the time of the due in the Space's zone", () => {
  const p = buildPush(reminder(), "en", "Islam Sabra", strings);
  assert.equal(p.title, "Reminder from ⁨Islam Sabra⁩");
  // Without lock-screen text: no title, no note.
  assert.equal(p.body, "A work item needs you. · due 10:00");
  assert.equal(p.data.route, "/spaces/s1/items/sp1");
  const ar = buildPush(reminder(), "ar", "إسلام صبرة", strings);
  assert.equal(ar.title, "تذكير من ⁨إسلام صبرة⁩");
  assert.equal(ar.body, "بند عمل بانتظارك. · الموعد 10:00");
});

test("review 108 RM2: the item's words and the note only when the person chose lock-screen text", () => {
  const p = buildPush(
    reminder({ message_text: "Formwork check, level 3 · Check the formwork before the pour" }),
    "en", "Islam Sabra", strings,
  );
  assert.equal(p.body, "Formwork check, level 3 · Check the formwork before the pour · due 10:00");
  assert.equal(p.data.shown, "1");
  const none = buildPush(reminder({ data: { space_id: "s1", space_post_id: "sp1" } }), "en", "Islam Sabra", strings);
  assert.equal(none.body, "A work item needs you.");
});

test("review 108 V6: a time zone the phone can't read falls back to UTC; the push still goes", () => {
  const p = buildPush(
    reminder({ data: { space_id: "s1", space_post_id: "sp1", due_at: "2026-11-01T07:00:00Z", tz: "Not/AZone" } }),
    "en", "Islam Sabra", strings,
  );
  assert.equal(p.body, "A work item needs you. · due 07:00");
});

test("review 108 PL: a scheduled post that couldn't go says why and opens Scheduled", () => {
  const p = buildPush(
    row("scheduled_failed", { actor_id: null, data: { scheduled_id: "x1", reason: "not_allowed" } }),
    "en", null, strings,
  );
  assert.equal(p.body, "Couldn't post: you can't post there any more.");
  assert.equal(p.data.route, "/scheduled-posts");
  const ar = buildPush(
    row("scheduled_failed", { actor_id: null, data: { scheduled_id: "x1", reason: "other" } }),
    "ar", null, strings,
  );
  assert.equal(ar.body, "تعذّر النشر: افتح المجدولة لتحاول مجددًا.");
});

const checkIn = (mark: string): QueueRow =>
  row("check_in_open", {
    actor_id: null,
    data: {
      post_id: "p1", space_id: "s1", mark, title: "Morning, Block B", space_name: "Tower 3",
      until: mark === "in" ? "2026-12-01T04:15:00+00:00" : "2026-12-01T11:15:00+00:00",
      tz: "Asia/Kuwait",
    },
  });

// Lock-screen text off (migration 14's rule): the queue has no title, no
// Space and no counts; only the ids and the window.
const checkInPlain = (mark: string): QueueRow =>
  row("check_in_open", {
    actor_id: null,
    data: { post_id: "p1", space_id: "s1", mark, until: "2026-12-01T04:15:00+00:00", tz: "Asia/Kuwait" },
  });

test("review 109 CI2: check-in opens: the title over the Space and the on-time limit, in the Space's zone", () => {
  const p = buildPush(checkIn("in"), "en", null, strings);
  assert.equal(p.title, "⁨Morning, Block B⁩");
  assert.equal(p.body, "⁨Tower 3⁩ · by 07:15");
  assert.equal(p.data.route, "/spaces/s1/items/p1");
  assert.equal(p.data.mark, "in");
  assert.equal(p.data.push_title, p.title);
  assert.equal(p.data.push_body, p.body);
  const ar = buildPush(checkIn("out"), "ar", null, strings);
  assert.equal(ar.body, "⁨Tower 3⁩ · حتى 14:15", "Western digits in Arabic");
});

type CheckInFcm = {
  notification: { title: string; body: string };
  data: Record<string, string>;
  android: {
    priority: string;
    notification: { channel_id: string; tag: string; default_sound: boolean };
  };
  apns: {
    headers: Record<string, string>;
    payload: { aps: Record<string, unknown> & { alert: { title: string; body: string } } };
  };
};

test("review 109 (option C): Android gets a notification on the check_in channel, tagged per post and kind, with the data part", () => {
  for (const [label, push, title, body] of [
    ["text on", buildPush(checkIn("in"), "en", null, strings), "⁨Morning, Block B⁩", "⁨Tower 3⁩ · by 07:15"],
    ["text off", buildPush(checkInPlain("in"), "en", null, strings), "BuildVibes", "Time to check in"],
  ] as const) {
    const m = fcmMessage("tok", push) as CheckInFcm;
    assert.deepEqual(m.notification, { title, body }, `${label}: a notification Android draws`);
    assert.equal(m.android.priority, "high", label);
    assert.equal(m.android.notification.channel_id, "check_in", label);
    assert.equal(m.android.notification.default_sound, true, label);
    assert.equal(m.android.notification.tag, "checkin:p1:in", `${label}: one tag per post and kind`);
    assert.equal(m.data.tag, "checkin:p1:in", `${label}: the same tag in the data`);
    assert.equal(m.data.post_id, "p1", label);
    assert.equal(m.data.mark, "in", label);
    assert.equal(m.data.until, "2026-12-01T04:15:00+00:00", label);
    assert.equal(m.data.push_title, title, label);
    assert.equal(m.data.push_body, body, label);
    assert.ok(Object.values(m.data).every((v) => typeof v === "string"), "FCM data values are strings");
  }
  const on = fcmMessage("tok", buildPush(checkIn("in"), "en", null, strings)) as CheckInFcm;
  assert.equal(on.data.title, "Morning, Block B");
  assert.equal(on.data.space_name, "Tower 3");
  const off = fcmMessage("tok", buildPush(checkInPlain("in"), "en", null, strings)) as CheckInFcm;
  assert.equal(off.data.title, undefined, "text off: no title in the data");
  assert.equal(off.data.space_name, undefined, "nor the Space");
  assert.ok(!JSON.stringify(off).includes("Tower"), "anywhere");
  const out = fcmMessage("tok", buildPush(checkIn("out"), "en", null, strings)) as CheckInFcm;
  assert.equal(out.android.notification.tag, "checkin:p1:out");
  assert.equal(out.data.tag, "checkin:p1:out");
});

test("review 109 CI2: iOS a time-sensitive alert with its category", () => {
  const m = fcmMessage("tok", buildPush(checkIn("in"), "en", null, strings)) as CheckInFcm;
  assert.equal(m.data.kind, "check_in_open");
  assert.ok(Object.values(m.data).every((v) => typeof v === "string"), "FCM data values are strings");
  assert.equal(m.apns.headers["apns-priority"], "10");
  assert.equal(m.apns.payload.aps.category, "CHECK_IN_IN");
  assert.equal(m.apns.payload.aps["interruption-level"], "time-sensitive");
  assert.equal(m.apns.payload.aps.alert.title, "⁨Morning, Block B⁩");
  const out = fcmMessage("tok", buildPush(checkIn("out"), "en", null, strings)) as {
    apns: { payload: { aps: { category: string } } };
  };
  assert.equal(out.apns.payload.aps.category, "CHECK_IN_OUT");
});

test("review 109 CI5: the creator's summary is a normal notification with what there is to see", () => {
  const summary = row("check_in_summary", {
    actor_id: null,
    data: { post_id: "p1", space_id: "s1", title: "Morning, Block B", late: "2", away: "1", missed: "0" },
  });
  const p = buildPush(summary, "en", null, strings);
  assert.equal(p.title, "⁨Morning, Block B⁩");
  assert.equal(p.body, "2 late · 1 not at site");
  assert.equal(p.data.route, "/spaces/s1/items/p1");
  assert.equal(buildPush(summary, "ar", null, strings).body, "متأخر 2 · خارج الموقع 1");
  const m = fcmMessage("tok", p) as {
    notification: { title: string; body: string };
    android: { notification: { channel_id: string } };
    apns?: unknown;
  };
  assert.equal(m.notification.body, "2 late · 1 not at site");
  assert.equal(m.android.notification.channel_id, DEFAULT_CHANNEL);
  assert.equal(m.apns, undefined);
});

test("review 109, lock-screen text off: only Time to check in / out, in the person's language, actions kept", () => {
  const p = buildPush(checkInPlain("in"), "en", null, strings);
  assert.equal(p.title, "BuildVibes");
  assert.equal(p.body, "Time to check in");
  assert.ok(!p.body.includes("07:15"), "not even the time");
  assert.equal(p.data.push_title, "BuildVibes");
  assert.equal(p.data.push_body, "Time to check in");
  assert.equal(p.data.post_id, "p1", "the ids stay, so Check in works");
  assert.equal(p.data.mark, "in");
  assert.equal(p.data.route, "/spaces/s1/items/p1");
  assert.equal(buildPush(checkInPlain("out"), "en", null, strings).body, "Time to check out");
  assert.equal(buildPush(checkInPlain("in"), "ar", null, strings).body, "حان وقت تسجيل الحضور");
  assert.equal(buildPush(checkInPlain("out"), "ar", null, strings).body, "حان وقت تسجيل الخروج");
  const m = fcmMessage("tok", p) as {
    android: { notification: { channel_id: string } };
    apns: { payload: { aps: { category: string; alert: { title: string; body: string } } } };
  };
  assert.equal(m.apns.payload.aps.category, "CHECK_IN_IN", "the actions stay on iOS");
  assert.equal(m.apns.payload.aps.alert.body, "Time to check in");
  assert.equal(m.android.notification.channel_id, "check_in");
  assert.ok(!JSON.stringify(m).includes("Morning"), "no title anywhere in what FCM gets");
});

test("review 109, lock-screen text off: the summary says only that it is ready", () => {
  const summary = row("check_in_summary", { actor_id: null, data: { post_id: "p1", space_id: "s1" } });
  const p = buildPush(summary, "en", null, strings);
  assert.equal(p.title, "BuildVibes");
  assert.equal(p.body, "Check-in summary ready");
  assert.equal(p.data.route, "/spaces/s1/items/p1");
  assert.equal(buildPush(summary, "ar", null, strings).body, "ملخص الحضور جاهز");
});

// Review 113 (migration 60).
type AnyFcm = {
  notification: { title: string; body: string };
  data: Record<string, string>;
  android: { priority: string; notification: Record<string, unknown> };
  apns?: {
    headers: Record<string, string>;
    payload: { aps: Record<string, unknown> & { alert?: { title: string; body: string } } };
  };
};

test("review 113 RX1: a reaction is one quiet push to the author, opening the post", () => {
  const off = row("post_reaction", {
    actor_id: "p-rakesh",
    data: { post_id: "p1", space_id: "s1", kind: "like" },
  });
  const p = buildPush(off, "en", "Rakesh Nair", strings);
  assert.equal(p.title, "BuildVibes");
  assert.equal(p.body, "⁨Rakesh Nair⁩ reacted to your post.");
  assert.equal(p.data.route, "/spaces/s1/items/p1");
  assert.equal(p.data.kind, "post_reaction", "the push's own kind, not the reaction's");
  assert.equal(p.data.reaction, "like", "the reaction travels as reaction");
  assert.equal(p.tag, "reaction:p1", "a later one replaces it");
  assert.equal(buildPush(off, "ar", "راكيش", strings).body, "تفاعل من ⁨راكيش⁩ على منشورك.");
  const m = fcmMessage("tok", p) as AnyFcm;
  assert.equal(m.android.priority, "normal", "low priority");
  assert.equal(m.android.notification.channel_id, REACTIONS_CHANNEL, "its own low-importance channel");
  assert.equal(REACTIONS_CHANNEL, "reactions");
  assert.equal(channelFor("post_reaction"), "reactions");
  assert.equal(m.android.notification.notification_priority, "PRIORITY_LOW");
  assert.equal(m.android.notification.default_sound, undefined, "no sound");
  assert.equal(m.android.notification.default_vibrate_timings, undefined, "no vibration");
  assert.equal(m.android.notification.tag, "reaction:p1");
  assert.equal(m.apns?.headers["apns-priority"], "5");
  assert.equal(m.apns?.payload.aps["interruption-level"], "passive");
  assert.equal(m.apns?.payload.aps.sound, undefined, "no sound on iOS either");
  assert.ok(!JSON.stringify(m).includes("Tower"), "text off: no Space");
  const on = buildPush(row("post_reaction", {
    actor_id: "p-rakesh",
    data: { post_id: "p1", space_id: "s1", kind: "heart", title: "Concrete pour", space_name: "Tower 113" },
  }), "en", "Rakesh Nair", strings);
  assert.equal(on.title, "⁨Concrete pour⁩");
  assert.equal(on.body, "⁨Tower 113⁩ · ⁨Rakesh Nair⁩ reacted to your post.");
});

test("review 113: archiving an open work item tells its owner: no longer needed", () => {
  const off = row("work_item_archived", { actor_id: "p-gus", data: { post_id: "p1", space_id: "s1" } });
  const p = buildPush(off, "en", "Gus Lead", strings);
  assert.equal(p.title, "BuildVibes");
  assert.equal(p.body, "⁨Gus Lead⁩ archived a work item of yours: no longer needed.");
  assert.equal(p.data.route, "/spaces/s1/items/p1");
  assert.equal(buildPush(off, "ar", "غس", strings).body, "أرشفة من ⁨غس⁩ لبند عمل لك: لم يعد مطلوبًا.");
  const on = buildPush(row("work_item_archived", {
    actor_id: "p-gus", data: { post_id: "p1", space_id: "s1", title: "Door closers" },
  }), "en", "Gus Lead", strings);
  assert.equal(on.title, "⁨Door closers⁩");
  assert.equal(on.body, "Archived by ⁨Gus Lead⁩: no longer needed.");
  assert.equal(fcmMessage("tok", on).apns, undefined, "an ordinary notification");
});

test("review 113 (17): the check-in nudge opens the Space's composer from the last check-in", () => {
  const off = row("check_in_nudge", { actor_id: null, data: { space_id: "s1", from_post_id: "c1" } });
  const p = buildPush(off, "en", null, strings);
  assert.equal(p.title, "BuildVibes");
  assert.equal(p.body, "No check-in posted for today. Post one?");
  assert.equal(p.data.route, "/spaces/s1");
  assert.equal(p.data.open, "check_in_nudge");
  assert.equal(p.data.from_post_id, "c1");
  assert.equal(p.tag, "checkin_nudge:s1");
  assert.equal(buildPush(off, "ar", null, strings).body, "لم يُنشر تسجيل حضور لليوم. هل تنشر واحدًا؟");
  const on = buildPush(row("check_in_nudge", {
    actor_id: null, data: { space_id: "s1", from_post_id: "c1", space_name: "Tower 113" },
  }), "en", null, strings);
  assert.equal(on.title, "⁨Tower 113⁩");
  assert.equal(on.body, "No check-in posted for today. Post one?");
});

const needYou = (data: Record<string, string>, actor: string | null = "p-omar"): QueueRow =>
  row("need_you", { actor_id: actor, data: { call_id: "n1", space_id: "s1", ...data } });

test("review 113 NN2: Need you now names who, the Space, the place and the reason (text on)", () => {
  const p = buildPush(needYou({
    from_name: "Omar Haddad", space_name: "NBKCH Site", place: "Gate 2", reason: "concrete truck waiting",
  }), "en", "Omar Haddad", strings);
  assert.equal(p.title, "⁨Omar Haddad⁩ needs you now");
  assert.equal(p.body, "⁨NBKCH Site⁩: ⁨Gate 2⁩, ⁨concrete truck waiting⁩");
  assert.equal(p.data.route, "/spaces/s1");
  assert.equal(p.data.open, "need_you");
  assert.equal(p.data.call_id, "n1");
  assert.equal(p.tag, "needyou:n1");
  assert.equal(p.data.tag, "needyou:n1");
  assert.equal(p.data.push_title, p.title);
  assert.equal(p.data.push_body, p.body);
  const ar = buildPush(needYou({ from_name: "عمر", space_name: "NBKCH Site", reason: "الخلاطة تنتظر" }),
                       "ar", null, strings);
  assert.equal(ar.title, "⁨عمر⁩ يحتاجك الآن");
  assert.equal(ar.body, "⁨NBKCH Site⁩: ⁨الخلاطة تنتظر⁩");
  const bare = buildPush(needYou({ from_name: "Omar Haddad", space_name: "NBKCH Site" }), "en", null, strings);
  assert.equal(bare.body, "⁨NBKCH Site⁩", "no reason or place: the Space");
});

test("review 113 NN2, lock-screen text off: Someone needs you now, nothing else", () => {
  const p = buildPush(needYou({}, null), "en", "Omar Haddad", strings);
  assert.equal(p.title, "BuildVibes");
  assert.equal(p.body, "Someone needs you now");
  assert.equal(buildPush(needYou({}, null), "ar", null, strings).body, "شخص يحتاجك الآن");
  assert.equal(p.data.call_id, "n1", "the ids stay, so the buttons work");
  assert.ok(!JSON.stringify(fcmMessage("tok", p)).includes("Omar"), "no name anywhere, even with an actor");
});

test("review 113 NN2 (option C): the strong channel, tagged per call; iOS time-sensitive with its category", () => {
  for (const push of [
    buildPush(needYou({ from_name: "Omar Haddad", space_name: "NBKCH Site" }), "en", null, strings),
    buildPush(needYou({}, null), "en", null, strings),
  ]) {
    const m = fcmMessage("tok", push) as AnyFcm;
    assert.deepEqual(m.notification, { title: push.title, body: push.body }, "a notification Android draws");
    assert.equal(m.android.priority, "high");
    assert.equal(m.android.notification.channel_id, NEED_YOU_CHANNEL);
    assert.equal(m.android.notification.tag, "needyou:n1");
    assert.equal(m.android.notification.default_sound, true);
    assert.equal(m.data.tag, "needyou:n1");
    assert.ok(Object.values(m.data).every((v) => typeof v === "string"), "FCM data values are strings");
    assert.equal(m.apns?.headers["apns-priority"], "10");
    assert.equal(m.apns?.payload.aps.category, "NEED_YOU");
    assert.equal(m.apns?.payload.aps["interruption-level"], "time-sensitive");
    assert.equal(m.apns?.payload.aps.sound, "default");
  }
  assert.equal(NEED_YOU_CHANNEL, "need_you");
  assert.equal(channelFor("need_you"), "need_you");
});

test("review 113 NN2: the answer goes back to the caller; the name only with text on", () => {
  const on = (answer: string) => row("need_you_answer", {
    actor_id: "p-tariq", data: { call_id: "n1", answer, space_id: "s1", name: "Tariq Aziz" },
  });
  const off = (answer: string) => row("need_you_answer", {
    actor_id: null, data: { call_id: "n1", answer, space_id: "s1" },
  });
  assert.equal(buildPush(on("coming"), "en", "Tariq Aziz", strings).body, "⁨Tariq Aziz⁩: On my way");
  assert.equal(buildPush(on("cant"), "en", "Tariq Aziz", strings).body, "⁨Tariq Aziz⁩: Can't now");
  assert.equal(buildPush(off("coming"), "en", "Tariq Aziz", strings).body, "Answer to your call: On my way");
  assert.equal(buildPush(off("cant"), "en", null, strings).body, "Answer to your call: Can't now");
  assert.equal(buildPush(on("coming"), "ar", "طارق", strings).body, "⁨Tariq Aziz⁩: في الطريق");
  assert.equal(buildPush(off("cant"), "ar", null, strings).body, "ردّ على طلبك: لا أستطيع الآن");
  const p = buildPush(on("coming"), "en", null, strings);
  assert.equal(p.data.route, "/spaces/s1");
  assert.equal(p.data.open, "need_you");
  assert.equal(p.tag, "needyou_answer:n1");
  const m = fcmMessage("tok", p) as AnyFcm;
  assert.equal(m.android.notification.channel_id, DEFAULT_CHANNEL);
  assert.equal(m.apns, undefined);
});

test("the lead, 2 Nov: a failed Post later is cancelled tomorrow; it opens Scheduled", () => {
  const off = row("scheduled_expiring", { actor_id: null, data: { scheduled_id: "x1" } });
  const p = buildPush(off, "en", null, strings);
  assert.equal(p.title, "BuildVibes");
  assert.equal(p.body, "Your scheduled post will be cancelled tomorrow");
  assert.equal(p.data.route, "/scheduled-posts");
  assert.equal(buildPush(off, "ar", null, strings).body, "سيُلغى منشورك المجدول غدًا");
  const on = buildPush(row("scheduled_expiring", {
    actor_id: null, data: { scheduled_id: "x1", title: "Pour notice" },
  }), "en", null, strings);
  assert.equal(on.title, "⁨Pour notice⁩");
  assert.equal(on.body, "Your scheduled post will be cancelled tomorrow");
});
