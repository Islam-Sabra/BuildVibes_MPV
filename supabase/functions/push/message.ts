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
    // Daybook posts (migration 19) open their Space until the app has a
    // route for one post; the post's id is in the data (space_post_id).
    case "announcement_new":
    case "checklist_for_you":
    case "activity_invited":
    case "activity_starting":
    case "file_new_version":
      return { route: `/spaces/${d.space_id}` };
    default:
      return d.work_item_id
        ? { route: `/spaces/${d.space_id}/items/${d.work_item_id}` }
        : { route: `/spaces/${d.space_id}` };
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

  if (row.kind === "chat_message") {
    return {
      title: fill(t.chat_title),
      // The text only when the person turned it on (the queue holds it
      // only then).
      body: row.message_text ?? t.chat_hidden,
      data,
      tag: row.thread_id ?? undefined,
    };
  }
  if (row.kind === "dm_message") {
    return {
      title: fill(t.dm_title),
      // As chat: the text only when the person turned it on.
      body: row.message_text ?? t.chat_hidden,
      data,
      tag: row.data?.dm_thread_id ?? undefined,
    };
  }
  const template = t[row.kind];
  if (!template) throw new Error(`no text for ${row.kind}`);
  return { title: t.title, body: fill(template), data };
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
