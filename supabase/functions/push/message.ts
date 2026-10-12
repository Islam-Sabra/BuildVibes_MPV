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
  const template = t[row.kind];
  if (!template) throw new Error(`no text for ${row.kind}`);
  return { title: t.title, body: fill(template), data };
}
