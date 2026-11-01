// deno test supabase/functions/check-in-report/
import { assert, assertEquals } from "jsr:@std/assert@1";
import strings from "./strings.json" with { type: "json" };
import { reportTable } from "./report.ts";
import { buildXlsx, columnName, crc32, safeSheetName, xmlText } from "./xlsx.ts";

const dec = new TextDecoder();

// The zip's parts, read back from its central directory, each checked
// against its CRC.
function unzip(bytes: Uint8Array): Map<string, string> {
  const v = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const end = bytes.length - 22;
  assertEquals(v.getUint32(end, true), 0x06054b50, "end of central directory");
  const count = v.getUint16(end + 10, true);
  let at = v.getUint32(end + 16, true);
  const out = new Map<string, string>();
  for (let i = 0; i < count; i++) {
    assertEquals(v.getUint32(at, true), 0x02014b50, "central header");
    const crc = v.getUint32(at + 16, true);
    const size = v.getUint32(at + 20, true);
    const nameLen = v.getUint16(at + 28, true);
    const local = v.getUint32(at + 42, true);
    const name = dec.decode(bytes.subarray(at + 46, at + 46 + nameLen));
    assertEquals(v.getUint32(local, true), 0x04034b50, "local header");
    const localName = v.getUint16(local + 26, true);
    const start = local + 30 + localName + v.getUint16(local + 28, true);
    const data = bytes.subarray(start, start + size);
    assertEquals(crc32(data), crc, `crc of ${name}`);
    out.set(name, dec.decode(data));
    at += 46 + nameLen;
  }
  return out;
}

Deno.test("crc32 matches the standard check value", () => {
  assertEquals(crc32(new TextEncoder().encode("123456789")), 0xCBF43926);
});

Deno.test("column names", () => {
  assertEquals([0, 5, 25, 26, 27].map(columnName), ["A", "F", "Z", "AA", "AB"]);
});

Deno.test("text is escaped and never a formula", () => {
  assertEquals(xmlText(`<a & "b">'`), "&lt;a &amp; &quot;b&quot;&gt;&apos;");
  assertEquals(xmlText("a\u0001b"), "ab");
  assertEquals(safeSheetName("2026/12:01"), "2026 12 01");
});

Deno.test("a workbook with its six parts and the rows as text", () => {
  const bytes = buildXlsx([["Name", "Team"], ["=SUM(A1)", "Steel & fixers"]], {
    sheetName: "2026-12-01",
  });
  const parts = unzip(bytes);
  assertEquals([...parts.keys()].sort(), [
    "[Content_Types].xml",
    "_rels/.rels",
    "xl/_rels/workbook.xml.rels",
    "xl/styles.xml",
    "xl/workbook.xml",
    "xl/worksheets/sheet1.xml",
  ]);
  const sheet = parts.get("xl/worksheets/sheet1.xml")!;
  assert(sheet.includes('<c r="A1" t="inlineStr" s="1"><is><t xml:space="preserve">Name</t></is></c>'));
  assert(sheet.includes('<c r="A2" t="inlineStr"><is><t xml:space="preserve">=SUM(A1)</t></is></c>'));
  assert(sheet.includes("Steel &amp; fixers"));
  assert(!sheet.includes("<f>"), "no formulas");
  assert(!sheet.includes("rightToLeft"));
  assert(parts.get("xl/workbook.xml")!.includes('name="2026-12-01"'));
  // The same rows give the same bytes.
  assertEquals(
    bytes,
    buildXlsx([["Name", "Team"], ["=SUM(A1)", "Steel & fixers"]], { sheetName: "2026-12-01" }),
  );
});

Deno.test("Arabic reads from the right", () => {
  const parts = unzip(buildXlsx([["الاسم"]], { sheetName: "x", rightToLeft: true }));
  const sheet = parts.get("xl/worksheets/sheet1.xml")!;
  assert(sheet.includes('rightToLeft="1"'));
  assert(sheet.includes("الاسم"));
});

Deno.test("the day's list: headings, times, late and the place", () => {
  const rows = [
    { name: "Noor Ali", team: "Steel fixers", in_time: null, out_time: null, in_late: false,
      out_late: false, place: "missed" },
    { name: "Sami Fares", team: null, in_time: "07:30", out_time: "14:20", in_late: true,
      out_late: true, place: "away" },
    { name: "Tariq Aziz", team: "Steel fixers", in_time: "07:00", out_time: null, in_late: false,
      out_late: false, place: "on_site" },
  ];
  assertEquals(reportTable(rows, "en", strings), [
    ["Name", "Team", "In", "Out", "Late", "Place"],
    ["Noor Ali", "Steel fixers", "", "", "", "Missed"],
    ["Sami Fares", "", "07:30", "14:20", "In · Out", "Not at site"],
    ["Tariq Aziz", "Steel fixers", "07:00", "", "", "On site"],
  ]);
  const ar = reportTable(rows, "ar", strings);
  assertEquals(ar[0], ["الاسم", "الفريق", "الحضور", "الخروج", "متأخر", "الموقع"]);
  assertEquals(ar[1][5], "لم يسجّل");
  assertEquals(ar[2][2], "07:30", "Western digits in Arabic too");
  // A language with no texts falls back to English.
  assertEquals(reportTable([], "fr", strings)[0][0], "Name");
});
