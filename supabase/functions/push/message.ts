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
// may never wake a closed app for). The tag makes each push of a
// conversation replace the last; Android sounds again on each replace
// (FCM never sets "alert once"), through the high-importance channel.
// Android channels (MainActivity): messages have their own, with vibration
// (review 89 M2); everything else stays on "buildvibes".
export const MESSAGE_CHANNEL = "buildvibes_messages";
export const DEFAULT_CHANNEL = "buildvibes";
// A follow-up queued before migration 41 is a message too.
const messageKinds = new Set(["dm_message", "dm_request", "chat_message", "dm_follow_up"]);

export function channelFor(kind: string | undefined): string {
  return kind && messageKinds.has(kind) ? MESSAGE_CHANNEL : DEFAULT_CHANNEL;
}

export function fcmMessage(token: string, push: Push): Record<string, unknown> {
  return {
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
