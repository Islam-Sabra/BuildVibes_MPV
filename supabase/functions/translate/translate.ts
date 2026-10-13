// The parts of the translate function that don't touch the network or the
// database, so they can be tested (translate.test.ts).

export const LANGS = ["en", "ar"] as const;
export type Lang = (typeof LANGS)[number];

export type TranslateRequest = { postId: string; target: Lang };

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** {post_id, target} from the app, or null when it isn't valid. */
export function parseRequest(body: unknown): TranslateRequest | null {
  if (typeof body !== "object" || body === null) return null;
  const { post_id, target } = body as Record<string, unknown>;
  if (typeof post_id !== "string" || !uuid.test(post_id)) return null;
  if (typeof target !== "string" || !(LANGS as readonly string[]).includes(target)) return null;
  return { postId: post_id, target: target as Lang };
}

/**
 * Used while GOOGLE_TRANSLATE_API_KEY isn't set: a fixed sentence that says
 * so, in the target language. Never stored and never counted.
 */
export function standIn(target: Lang): string {
  return target === "ar"
    ? "نص تجريبي: تبدأ الترجمة الحقيقية بعد إضافة مفتاح Google."
    : "Test text: real translation starts once the Google key is added.";
}

/**
 * Cloud Translation Basic (v2), plain text in and out. The key goes in a
 * header, never in the URL (URLs end up in logs).
 */
export function googleRequest(key: string, text: string, source: Lang, target: Lang) {
  return {
    url: "https://translation.googleapis.com/language/translate/v2",
    init: {
      method: "POST",
      headers: { "content-type": "application/json", "x-goog-api-key": key },
      body: JSON.stringify({ q: text, source, target, format: "text" }),
    },
  };
}

/** The translated text from Google's answer, or null when it has none. */
export function parseGoogle(json: unknown): string | null {
  const text = (json as { data?: { translations?: { translatedText?: unknown }[] } })
    ?.data?.translations?.[0]?.translatedText;
  return typeof text === "string" && text.trim().length > 0 ? text : null;
}
