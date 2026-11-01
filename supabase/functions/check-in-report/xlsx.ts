// A one-sheet .xlsx, built in memory: no Deno or network here, so it is
// tested on its own (deno test supabase/functions/check-in-report/).
//
// Every cell is text (an inline string), so nothing a person typed can
// ever become a formula. The first row is bold (the headings). The zip
// stores its parts uncompressed: a day's list is a few kilobytes.

export const XLSX_MIME = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";

export type XlsxOptions = {
  // The sheet's tab name (Excel: at most 31 characters, none of []:*?/\).
  sheetName: string;
  // Arabic: the sheet reads from the right.
  rightToLeft?: boolean;
};

const enc = new TextEncoder();

// --- XML ----------------------------------------------------------------------

// Text as XML: the five escapes, and no control characters XML can't hold.
export function xmlText(s: string): string {
  return s
    // deno-lint-ignore no-control-regex
    .replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F￾￿]/g, "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&apos;");
}

// 0 → A, 25 → Z, 26 → AA.
export function columnName(i: number): string {
  let n = i + 1;
  let s = "";
  while (n > 0) {
    const r = (n - 1) % 26;
    s = String.fromCharCode(65 + r) + s;
    n = Math.floor((n - 1) / 26);
  }
  return s;
}

export function safeSheetName(name: string): string {
  const s = name.replace(/[\[\]:*?\/\\]/g, " ").trim().slice(0, 31);
  return s || "Sheet1";
}

const xmlHead = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n';
const mainNs = "http://schemas.openxmlformats.org/spreadsheetml/2006/main";
const relNs = "http://schemas.openxmlformats.org/officeDocument/2006/relationships";
const pkgRelNs = "http://schemas.openxmlformats.org/package/2006/relationships";

function sheetXml(rows: string[][], rightToLeft: boolean): string {
  const body = rows.map((cells, r) => {
    const style = r === 0 ? ' s="1"' : "";
    const cs = cells.map((v, c) =>
      `<c r="${columnName(c)}${r + 1}" t="inlineStr"${style}><is><t xml:space="preserve">${
        xmlText(v ?? "")
      }</t></is></c>`
    ).join("");
    return `<row r="${r + 1}">${cs}</row>`;
  }).join("");
  const width = Math.max(1, ...rows.map((r) => r.length));
  const cols = `<cols><col min="1" max="${width}" width="22" customWidth="1"/></cols>`;
  const view = `<sheetViews><sheetView workbookViewId="0"${
    rightToLeft ? ' rightToLeft="1"' : ""
  }/></sheetViews>`;
  return `${xmlHead}<worksheet xmlns="${mainNs}">${view}${cols}<sheetData>${body}</sheetData></worksheet>`;
}

function parts(rows: string[][], options: XlsxOptions): [string, string][] {
  const name = xmlText(safeSheetName(options.sheetName));
  return [
    [
      "[Content_Types].xml",
      `${xmlHead}<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">` +
      `<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>` +
      `<Default Extension="xml" ContentType="application/xml"/>` +
      `<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>` +
      `<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>` +
      `<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>` +
      `</Types>`,
    ],
    [
      "_rels/.rels",
      `${xmlHead}<Relationships xmlns="${pkgRelNs}">` +
      `<Relationship Id="rId1" Type="${relNs}/officeDocument" Target="xl/workbook.xml"/>` +
      `</Relationships>`,
    ],
    [
      "xl/workbook.xml",
      `${xmlHead}<workbook xmlns="${mainNs}" xmlns:r="${relNs}">` +
      `<sheets><sheet name="${name}" sheetId="1" r:id="rId1"/></sheets></workbook>`,
    ],
    [
      "xl/_rels/workbook.xml.rels",
      `${xmlHead}<Relationships xmlns="${pkgRelNs}">` +
      `<Relationship Id="rId1" Type="${relNs}/worksheet" Target="worksheets/sheet1.xml"/>` +
      `<Relationship Id="rId2" Type="${relNs}/styles" Target="styles.xml"/>` +
      `</Relationships>`,
    ],
    [
      "xl/styles.xml",
      `${xmlHead}<styleSheet xmlns="${mainNs}">` +
      `<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font>` +
      `<font><b/><sz val="11"/><name val="Calibri"/></font></fonts>` +
      `<fills count="2"><fill><patternFill patternType="none"/></fill>` +
      `<fill><patternFill patternType="gray125"/></fill></fills>` +
      `<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>` +
      `<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>` +
      `<cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>` +
      `<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/></cellXfs>` +
      `<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>` +
      `</styleSheet>`,
    ],
    ["xl/worksheets/sheet1.xml", sheetXml(rows, options.rightToLeft ?? false)],
  ];
}

// --- Zip (stored) ---------------------------------------------------------------

const crcTable = (() => {
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c >>> 0;
  }
  return t;
})();

export function crc32(bytes: Uint8Array): number {
  let c = 0xFFFFFFFF;
  for (let i = 0; i < bytes.length; i++) c = crcTable[(c ^ bytes[i]) & 0xFF] ^ (c >>> 8);
  return (c ^ 0xFFFFFFFF) >>> 0;
}

// The zip's time for every part: 1 Jan 1980, so the same rows give the
// same bytes.
const dosTime = 0;
const dosDate = (0 << 9) | (1 << 5) | 1;

export function zipStored(files: [string, Uint8Array][]): Uint8Array {
  const locals: Uint8Array[] = [];
  const centrals: Uint8Array[] = [];
  let offset = 0;
  for (const [name, data] of files) {
    const n = enc.encode(name);
    const crc = crc32(data);
    const local = new Uint8Array(30 + n.length);
    const lv = new DataView(local.buffer);
    lv.setUint32(0, 0x04034b50, true);
    lv.setUint16(4, 20, true); // version needed
    lv.setUint16(6, 0x0800, true); // names in UTF-8
    lv.setUint16(8, 0, true); // stored
    lv.setUint16(10, dosTime, true);
    lv.setUint16(12, dosDate, true);
    lv.setUint32(14, crc, true);
    lv.setUint32(18, data.length, true);
    lv.setUint32(22, data.length, true);
    lv.setUint16(26, n.length, true);
    lv.setUint16(28, 0, true);
    local.set(n, 30);
    locals.push(local, data);

    const central = new Uint8Array(46 + n.length);
    const cv = new DataView(central.buffer);
    cv.setUint32(0, 0x02014b50, true);
    cv.setUint16(4, 20, true); // made by
    cv.setUint16(6, 20, true); // needed
    cv.setUint16(8, 0x0800, true);
    cv.setUint16(10, 0, true);
    cv.setUint16(12, dosTime, true);
    cv.setUint16(14, dosDate, true);
    cv.setUint32(16, crc, true);
    cv.setUint32(20, data.length, true);
    cv.setUint32(24, data.length, true);
    cv.setUint16(28, n.length, true);
    cv.setUint16(30, 0, true); // extra
    cv.setUint16(32, 0, true); // comment
    cv.setUint16(34, 0, true); // disk
    cv.setUint16(36, 0, true); // internal attributes
    cv.setUint32(38, 0, true); // external attributes
    cv.setUint32(42, offset, true);
    central.set(n, 46);
    centrals.push(central);
    offset += local.length + data.length;
  }
  const centralSize = centrals.reduce((s, c) => s + c.length, 0);
  const end = new Uint8Array(22);
  const ev = new DataView(end.buffer);
  ev.setUint32(0, 0x06054b50, true);
  ev.setUint16(8, files.length, true);
  ev.setUint16(10, files.length, true);
  ev.setUint32(12, centralSize, true);
  ev.setUint32(16, offset, true);
  const all = [...locals, ...centrals, end];
  const out = new Uint8Array(all.reduce((s, a) => s + a.length, 0));
  let at = 0;
  for (const a of all) {
    out.set(a, at);
    at += a.length;
  }
  return out;
}

// The workbook: [rows][cells], the first row the headings.
export function buildXlsx(rows: string[][], options: XlsxOptions): Uint8Array {
  return zipStored(parts(rows, options).map(([name, xml]) => [name, enc.encode(xml)]));
}
