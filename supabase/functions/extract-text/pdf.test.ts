// deno test --allow-read --allow-env supabase/functions/extract-text/pdf.test.ts
import { assertEquals } from "jsr:@std/assert@1";
import { PDFDocument } from "npm:pdf-lib@1.17.1";
import { pageCount, splitPdf } from "./pdf.ts";

async function pdfOf(pages: number): Promise<Uint8Array> {
  const doc = await PDFDocument.create();
  for (let i = 0; i < pages; i++) doc.addPage([200 + i, 300]);
  return await doc.save();
}

Deno.test("counts a PDF's pages", async () => {
  assertEquals(await pageCount(await pdfOf(7)), 7);
});

Deno.test("splits out pages 6 to 7, in order", async () => {
  const part = await splitPdf(await pdfOf(7), 6, 7);
  const doc = await PDFDocument.load(part);
  assertEquals(doc.getPageCount(), 2);
  assertEquals(doc.getPage(0).getWidth(), 205);
  assertEquals(doc.getPage(1).getWidth(), 206);
});
