import { test } from "node:test";
import assert from "node:assert/strict";
import { googleRequest, parseGoogle, parseRequest, standIn } from "./translate.ts";

const id = "00000000-0000-0000-0000-000000000017";

test("accepts a post id and en or ar", () => {
  assert.deepEqual(parseRequest({ post_id: id, target: "ar" }), { postId: id, target: "ar" });
  assert.deepEqual(parseRequest({ post_id: id, target: "en" }), { postId: id, target: "en" });
});

test("refuses anything else", () => {
  assert.equal(parseRequest({ post_id: id, target: "fr" }), null);
  assert.equal(parseRequest({ post_id: "1; drop table", target: "ar" }), null);
  assert.equal(parseRequest({ target: "ar" }), null);
  assert.equal(parseRequest(null), null);
  assert.equal(parseRequest("x"), null);
});

test("the stand-in says it is a test, in the target language", () => {
  assert.match(standIn("en"), /^Test text/);
  assert.match(standIn("ar"), /^نص تجريبي/);
});

test("Google gets plain text, the source and the target", () => {
  const r = googleRequest("k&y", "Slab poured.", "en", "ar");
  assert.equal(r.url, "https://translation.googleapis.com/language/translate/v2");
  assert.equal(r.init.headers["x-goog-api-key"], "k&y");
  assert.deepEqual(JSON.parse(r.init.body), { q: "Slab poured.", source: "en", target: "ar", format: "text" });
});

test("reads Google's answer", () => {
  assert.equal(parseGoogle({ data: { translations: [{ translatedText: "تم صب البلاطة." }] } }), "تم صب البلاطة.");
  assert.equal(parseGoogle({ data: { translations: [{ translatedText: " " }] } }), null);
  assert.equal(parseGoogle({ error: { code: 403 } }), null);
  assert.equal(parseGoogle(null), null);
});
