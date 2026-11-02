// What a push says and where it opens. No Deno or network here, so it is
// tested with Node: node --experimental-strip-types --test supabase/functions/push/message.test.ts
//
// Never names a project, a Space or a work item (founder decision). The
// ids for the link go in the data part only.

export type QueueRow = {
  id: number;
  profile_id: string;
  kind: string;
  actor_id: string | null;
  thread_id: string | null;
  data: Record<string, string>;
  message_text: string | null;
};

export type Strings = Record<string, Record<string, string>>;

export type Push = {
  title: string;
  body: string;
  // FCM data values are strings.
  data: Record<string, string>;
  // Android: chat pushes of one thread replace each other.
  tag?: string;
};

// A name keeps its own direction inside an Arabic sentence (Unicode
// first-strong isolate), like the app's inOwnDirection.
const isolate = (s: string) => `⁨${s}⁩`;

export function routeFor(row: QueueRow): { route: string; open?: string } {
  const d = row.data ?? {};
  switch (row.kind) {
    case "chat_message":
      return { route: `/spaces/${d.space_id}/chat/${d.thread_id}` };
    // Direct messages (migration 22): the thread; a request opens it too.
    case "dm_message":
    case "dm_request":
    case "dm_follow_up":
      return { route: `/messages/${d.dm_thread_id}` };
    case "join_request":
      return { route: `/spaces/${d.space_id}`, open: "people" };
    case "join_confirmed":
      return { route: `/spaces/${d.space_id}` };
    case "role_confirmed":
      return { route: "/profile" };
    case "follow":
      return { route: `/people/${row.actor_id}` };
    case "post_reply":
      return { route: `/posts/${d.post_id}` };
    // Review 108: a scheduled post that couldn't go opens Scheduled.
    case "scheduled_failed":
      return { route: "/scheduled-posts" };
    // Review 109: a check-in opens its card.
    case "check_in_open":
    case "check_in_summary":
    // Review 113: a reaction and an archived work item open the post.
    case "post_reaction":
    case "work_item_archived":
      return { route: `/spaces/${d.space_id}/items/${d.post_id}` };
    // Review 113 (17): the Space, and the composer filled from the last
    // check-in (data.from_post_id).
    case "check_in_nudge":
      return { route: `/spaces/${d.space_id}`, open: "check_in_nudge" };
    // Review 113 NN1, NN2: the Space, with the call (data.call_id).
    case "need_you":
    case "need_you_answer":
      return { route: `/spaces/${d.space_id}`, open: "need_you" };
    // Everything else opens its card in the Space: the work item, or the
    // daybook post (migration 19's space_post_id); the Space with neither.
    default: {
      const card = d.work_item_id || d.space_post_id;
      return card
        ? { route: `/spaces/${d.space_id}/items/${card}` }
        : { route: `/spaces/${d.space_id}` };
    }
  }
}

export function buildPush(
  row: QueueRow,
  locale: string,
  actorName: string | null,
  strings: Strings,
): Push {
  const t = strings[locale] ?? strings.en;
  const name = isolate(actorName?.trim() || t.someone);
  const fill = (s: string) => s.replaceAll("{name}", name);
  const { route, open } = routeFor(row);
  const data: Record<string, string> = { kind: row.kind, route };
  if (open) data.open = open;
  for (const [k, v] of Object.entries(row.data ?? {})) data[k] = String(v);

  if (row.kind === "chat_message" || row.kind === "dm_message") {
    return messagePush(row, t, name, data);
  }
  if (row.kind === "dm_follow_up") {
    // F97 (queued before migration 41 only): the messages after the first
    // push, still unread at the quiet time's end. Never the text: it
    // stands for several. Same tag, so it replaces the first push.
    const n = Number(row.data?.count ?? "0");
    return {
      title: fill(t.dm_title),
      body: countWords(t, n),
      data,
      tag: row.data?.dm_thread_id ?? undefined,
    };
  }
  if (row.kind === "work_reminder") return reminderPush(row, t, name, data, locale);
  if (row.kind === "check_in_open") return checkInOpenPush(row, t, data, locale);
  if (row.kind === "check_in_summary") return checkInSummaryPush(row, t, data);
  if (row.kind === "post_reaction") return reactionPush(row, t, name, data);
  if (row.kind === "work_item_archived") return archivedPush(row, t, name, data);
  if (row.kind === "check_in_nudge") return nudgePush(row, t, data);
  if (row.kind === "need_you") return needYouPush(row, t, data);
  if (row.kind === "need_you_answer") return needYouAnswerPush(row, t, data);
  if (row.kind === "scheduled_failed") {
    const reason = t[`scheduled_reason_${row.data?.reason}`] ?? t.scheduled_reason_other;
    return { title: t.title, body: t.scheduled_failed.replaceAll("{reason}", reason), data };
  }
  const template = t[row.kind];
  if (!template) throw new Error(`no text for ${row.kind}`);
  return { title: t.title, body: fill(template), data };
}

// F102: a message push, sent for every message (migration 41). Android
// shows one notification per conversation: the same tag (the DM thread or
// the chat thread) replaces the last one, with sound each time. data.count
// is the person's unread messages there, counted when it was queued.
// - Text on (the queue holds the words): the name as the title (in a
//   Space chat, "Omar Haddad in a Space chat"), then " · 3 new messages"
//   when there is more than one, in the title, where a long message never
//   cuts it off (review 89 M3); the newest words as the body.
// - Text off, or no words (a photo, a voice note): "Message from Omar
//   Haddad" (in a Space chat, "... in a Space chat") over "3 new messages".
// Never a thread's or a Space's name.
function messagePush(
  row: QueueRow,
  t: Record<string, string>,
  name: string,
  data: Record<string, string>,
): Push {
  const chat = row.kind === "chat_message";
  const fill = (s: string) => s.replaceAll("{name}", name);
  const n = Math.max(1, Number(row.data?.count ?? "1") || 1);
  const words = row.message_text?.trim();
  const tag = (chat ? row.thread_id ?? row.data?.thread_id : row.data?.dm_thread_id) ?? undefined;
  if (words) {
    const who = fill(chat ? t.chat_shown_title : t.dm_shown_title);
    return {
      title: n > 1 ? `${who}${t.separator}${countWords(t, n)}` : who,
      body: words,
      // Tells the app's banner (app open) that the body holds the words
      // and the title the name (then the count).
      data: { ...data, shown: "1" },
      tag,
    };
  }
  return {
    title: fill(chat ? t.chat_hidden_title : t.dm_title),
    body: countWords(t, n),
    data,
    tag,
  };
}

// Review 108 RM2: "Reminder from Islam Sabra" over the item's words and the
// note (only when the person turned lock-screen text on; the queue then
// holds them), else "A work item needs you.", then " · due 10:00" in the
// Space's time zone, Western digits in Arabic too.
function reminderPush(
  row: QueueRow,
  t: Record<string, string>,
  name: string,
  data: Record<string, string>,
  locale: string,
): Push {
  const words = row.message_text?.trim();
  const dueAt = row.data?.due_at;
  const due = dueAt
    ? t.work_reminder_due.replaceAll("{time}", clockIn(dueAt, locale, row.data?.tz))
    : "";
  return {
    title: t.work_reminder_title.replaceAll("{name}", name),
    body: `${words || t.work_reminder_body}${due}`,
    data: words ? { ...data, shown: "1" } : data,
  };
}

// Review 109 CI2: when check-in (or check-out) opens. The post's title
// over "Space · by 7:15" (the on-time limit, in the Space's zone), as the
// approved frame shows: here the title and the Space are what the person
// acts on. Android gets it as data and draws it itself, with Check in and
// Open, on its "check_in" channel; iOS as a time-sensitive alert with the
// CHECK_IN_IN or CHECK_IN_OUT category (fcmMessage).
function checkInOpenPush(
  row: QueueRow,
  t: Record<string, string>,
  data: Record<string, string>,
  locale: string,
): Push {
  const d = row.data ?? {};
  const plain = d.mark === "out" ? t.check_in_open_out : t.check_in_open_in;
  let title = t.title;
  let body = plain;
  // The lock-screen rule (migration 14): the queue carries the title and
  // the Space only when the person turned lock-screen text on. Off, only
  // "Time to check in"; the ids stay in the data, so the actions work.
  if (d.title?.trim()) {
    const until = d.until ? clockIn(d.until, locale, d.tz) : "";
    const space = d.space_name?.trim() ? isolate(d.space_name.trim()) : "";
    const by = until ? t.check_in_by.replaceAll("{time}", until) : "";
    title = isolate(d.title.trim());
    body = [space, by].filter((x) => x).join(t.separator) || plain;
  }
  // One tag per post and kind: the app's own notification (same tag, id 0)
  // replaces this one with its buttons, from these words.
  const tag = `checkin:${d.post_id}:${d.mark === "out" ? "out" : "in"}`;
  return { title, body, tag, data: { ...data, push_title: title, push_body: body, tag } };
}

// Review 109 CI5: one summary to the creator when check-in closes, only
// when there is something to see: "Morning, Block B" over "2 late · 1 not
// at site · 1 missed".
function checkInSummaryPush(
  row: QueueRow,
  t: Record<string, string>,
  data: Record<string, string>,
): Push {
  const d = row.data ?? {};
  const tag = `checkin:${d.post_id}:summary`;
  // Lock-screen text off: the queue holds no title and no counts.
  if (!d.title?.trim()) return { title: t.title, body: t.check_in_summary, tag, data };
  const parts = (["late", "away", "missed"] as const)
    .map((k) => [k, Number(d[k] ?? "0") || 0] as const)
    .filter(([, n]) => n > 0)
    .map(([k, n]) => t[`check_in_${k}`].replaceAll("{count}", String(n)));
  return {
    title: isolate(d.title.trim()),
    body: parts.join(t.separator) || t.check_in_summary,
    tag,
    data,
  };
}

// Review 113 RX1: "Rakesh Nair reacted to your post.", one per post: the
// tag makes a later one (after the 10 minutes) replace it. Lock-screen text
// on: the post's title over "Space · ...". The reaction's own kind travels
// as data.reaction (data.kind stays the push's kind, for the app).
function reactionPush(
  row: QueueRow,
  t: Record<string, string>,
  name: string,
  data: Record<string, string>,
): Push {
  const d = row.data ?? {};
  const out = { ...data, kind: row.kind };
  if (d.kind) out.reaction = String(d.kind);
  const sentence = t.post_reaction.replaceAll("{name}", name);
  const tag = `reaction:${d.post_id}`;
  if (!d.title?.trim()) return { title: t.title, body: sentence, data: out, tag };
  const space = d.space_name?.trim() ? isolate(d.space_name.trim()) : "";
  return {
    title: isolate(d.title.trim()),
    body: [space, sentence].filter((x) => x).join(t.separator),
    data: out,
    tag,
  };
}

// Review 113: an open work item was archived: "Gus Lead archived a work
// item of yours: no longer needed." Text on: its title over "Archived by
// Gus Lead: no longer needed."
function archivedPush(
  row: QueueRow,
  t: Record<string, string>,
  name: string,
  data: Record<string, string>,
): Push {
  const title = row.data?.title?.trim();
  if (!title) return { title: t.title, body: t.work_item_archived.replaceAll("{name}", name), data };
  return {
    title: isolate(title),
    body: t.work_item_archived_shown.replaceAll("{name}", name),
    data,
  };
}

// Review 113 (17): "No check-in posted for today. Post one?" to the Lead;
// the Space's name as the title with lock-screen text on.
function nudgePush(row: QueueRow, t: Record<string, string>, data: Record<string, string>): Push {
  const d = row.data ?? {};
  const space = d.space_name?.trim();
  return {
    title: space ? isolate(space) : t.title,
    body: t.check_in_nudge,
    data,
    tag: `checkin_nudge:${d.space_id}`,
  };
}

// Review 113 NN2: "Omar Haddad needs you now" over "NBKCH Site: Gate 2,
// concrete truck waiting". Lock-screen text off (the queue then has no
// name, reason, place or Space): only "Someone needs you now", never a
// name, even the actor's. As check-in (option C), one tag per call, and
// the words in the data for the app's own notification with On my way and
// Can't now.
function needYouPush(row: QueueRow, t: Record<string, string>, data: Record<string, string>): Push {
  const d = row.data ?? {};
  const from = d.from_name?.trim();
  let title = t.title;
  let body = t.need_you_hidden;
  if (from) {
    title = t.need_you_title.replaceAll("{name}", isolate(from));
    const what = [d.place, d.reason]
      .map((x) => x?.trim())
      .filter((x): x is string => !!x)
      .map(isolate)
      .join(t.need_you_comma);
    const space = d.space_name?.trim() ? isolate(d.space_name.trim()) : "";
    body = [space, what].filter((x) => x).join(t.need_you_colon) || t.need_you_hidden;
  }
  const tag = `needyou:${d.call_id}`;
  return { title, body, tag, data: { ...data, push_title: title, push_body: body, tag } };
}

// Review 113 NN2: the answer, to the caller: "Tariq Aziz: On my way" (the
// name only with lock-screen text on, from the queue), else "Answer to
// your call: On my way".
function needYouAnswerPush(
  row: QueueRow,
  t: Record<string, string>,
  data: Record<string, string>,
): Push {
  const d = row.data ?? {};
  const answer = d.answer === "cant" ? "cant" : "coming";
  const who = d.name?.trim();
  const body = who
    ? t[`need_you_answer_${answer}`].replaceAll("{name}", isolate(who))
    : t[`need_you_answer_hidden_${answer}`];
  return { title: t.title, body, data, tag: `needyou_answer:${d.call_id}` };
}

// "10:00" at [iso] in [zone] (UTC without one).
// Review 108 V6: a zone Intl can't read is UTC, never a dropped push.
function clockIn(iso: string, locale: string, zone?: string): string {
  const format = (timeZone: string) =>
    new Intl.DateTimeFormat(locale === "ar" ? "ar-u-nu-latn" : "en-GB", {
      hour: "2-digit",
      minute: "2-digit",
      hourCycle: "h23",
      timeZone,
    }).format(new Date(iso));
  try {
    return format(zone || "UTC");
  } catch {
    return format("UTC");
  }
}

// "3 new messages" / «3 رسائل جديدة», as F97 and F101.
export function countWords(t: Record<string, string>, n: number): string {
  return (t[followUpKey(n)] ?? t.dm_follow_up_many).replaceAll("{count}", String(n));
}

// What goes to FCM for one phone. A notification message drawn by Android
// itself (the lead's decision, 24 Oct: no data-only messages, which MIUI
// may never wake a closed app for). Check-in keeps to it (review 109,
// option C): it is a notification with data, never data-only. The tag makes each push of a
// conversation replace the last; Android sounds again on each replace
// (FCM never sets "alert once"), through the high-importance channel.
// Android channels (MainActivity): messages have their own, with vibration
// (review 89 M2); everything else stays on "buildvibes".
export const MESSAGE_CHANNEL = "buildvibes_messages";
export const DEFAULT_CHANNEL = "buildvibes";
// A follow-up queued before migration 41 is a message too.
const messageKinds = new Set(["dm_message", "dm_request", "chat_message", "dm_follow_up"]);

// Review 109: check-in's own Android channel (the app makes it, with sound
// and high importance), and the iOS categories that carry Check in and
// Check out.
export const CHECK_IN_CHANNEL = "check_in";
// Review 113: Need you now's own strong channel (the app makes it, with
// sound and high importance, as check_in).
export const NEED_YOU_CHANNEL = "need_you";
// Review 113 RX1 (the lead, 2 Nov): reactions' own low-importance channel,
// no sound and no pop-up (the app makes it).
export const REACTIONS_CHANNEL = "reactions";

export function channelFor(kind: string | undefined): string {
  if (kind === "check_in_open") return CHECK_IN_CHANNEL;
  if (kind === "need_you") return NEED_YOU_CHANNEL;
  if (kind === "post_reaction") return REACTIONS_CHANNEL;
  return kind && messageKinds.has(kind) ? MESSAGE_CHANNEL : DEFAULT_CHANNEL;
}

export function fcmMessage(token: string, push: Push): Record<string, unknown> {
  const message = {
    token,
    notification: { title: push.title, body: push.body },
    data: push.data,
    android: {
      priority: "high",
      notification: {
        channel_id: channelFor(push.data.kind),
        ...(push.tag ? { tag: push.tag } : {}),
        // Phones before Android 8; from 8 on the channel decides.
        default_sound: true,
        default_vibrate_timings: true,
      },
    },
  };
  if (push.data.kind === "post_reaction") {
    // Review 113 RX1: quiet. Normal priority, low on the shade, no sound or
    // vibration, on the reactions channel (low importance from Android 8);
    // iOS passive: in the list, never lighting the screen.
    return {
      ...message,
      android: {
        priority: "normal",
        notification: {
          channel_id: REACTIONS_CHANNEL,
          ...(push.tag ? { tag: push.tag } : {}),
          notification_priority: "PRIORITY_LOW",
        },
      },
      apns: {
        headers: { "apns-priority": "5", "apns-push-type": "alert" },
        payload: {
          aps: {
            alert: { title: push.title, body: push.body },
            "interruption-level": "passive",
          },
        },
      },
    };
  }
  if (push.data.kind === "need_you") {
    // Review 113 NN2, option C as check-in: the notification on the
    // need_you channel, tagged "needyou:<call>" (data.tag the same), which
    // the app replaces with its own (same tag, id 0) carrying On my way and
    // Can't now. iOS: time-sensitive, with the NEED_YOU category.
    return {
      ...message,
      apns: {
        headers: { "apns-priority": "10", "apns-push-type": "alert" },
        payload: {
          aps: {
            alert: { title: push.title, body: push.body },
            sound: "default",
            category: "NEED_YOU",
            "interruption-level": "time-sensitive",
          },
        },
      },
    };
  }
  if (push.data.kind === "check_in_open") {
    // Review 109, option C. Android: the notification above, on the
    // check_in channel, tagged "checkin:<post>:<in|out>" (data.tag holds the
    // same), so it shows even when MIUI never wakes the app; the app then
    // posts its own with that tag and id 0, replacing it with the Check in
    // and Open buttons: never two. iOS: an alert APNs shows,
    // time-sensitive, with the category whose actions the app registered.
    return {
      ...message,
      apns: {
        headers: { "apns-priority": "10", "apns-push-type": "alert" },
        payload: {
          aps: {
            alert: { title: push.title, body: push.body },
            sound: "default",
            category: push.data.mark === "out" ? "CHECK_IN_OUT" : "CHECK_IN_IN",
            "interruption-level": "time-sensitive",
          },
        },
      },
    };
  }
  return message;
}

// Arabic counts its nouns in four forms (one, two, 3–10, 11 and more);
// English uses the first and the last.
export function followUpKey(n: number): string {
  if (n === 1) return "dm_follow_up_one";
  if (n === 2) return "dm_follow_up_two";
  if (n >= 3 && n <= 10) return "dm_follow_up_few";
  return "dm_follow_up_many";
}

// What an FCM error means (reviews 21 and 22). Only an error that names
// the token deletes it. A plain 404 (a wrong project) and SENDER_ID_MISMATCH
// (another project's key) are failures: they must never wipe phones.
//
// "gone" (F81): FCM's own NOT_FOUND for one token, with no error code. The
// token is deleted only when another phone in the same send got the push,
// which proves the project and key are right.
export type Outcome = "dead" | "gone" | "retry" | "failed";

export function classify(status: number, body: string): Outcome {
  if (
    body.includes("UNREGISTERED") ||
    (body.includes("INVALID_ARGUMENT") && /registration token/i.test(body))
  ) {
    return "dead";
  }
  if (status === 429 || status >= 500) return "retry";
  if (status === 404 && /"status"\s*:\s*"NOT_FOUND"/.test(body)) return "gone";
  return "failed";
}

// Retry-After in seconds (FCM sends seconds); null when missing or odd.
export function retryAfterSeconds(header: string | null): number | null {
  if (!header) return null;
  const n = Number(header);
  return Number.isFinite(n) && n >= 0 ? Math.min(n, 3600) : null;
}
