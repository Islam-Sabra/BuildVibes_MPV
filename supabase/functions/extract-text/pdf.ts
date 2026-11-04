// Counting and splitting a PDF for Extract text (review 103, the lead's
// check D7): Vision gets only the pages it reads, at most 5 a request.
import { PDFDocument } from "npm:pdf-lib@1.17.1";

/** How many pages [bytes] has. */
export async function pageCount(bytes: Uint8Array): Promise<number> {
  const doc = await PDFDocument.load(bytes, { ignoreEncryption: true });
  return doc.getPageCount();
}

/** A new PDF of pages [from]..[to] (1-based) of [bytes]. */
export async function splitPdf(
  bytes: Uint8Array,
  from: number,
  to: number,
): Promise<Uint8Array> {
  const source = await PDFDocument.load(bytes, { ignoreEncryption: true });
  const part = await PDFDocument.create();
  const indices = Array.from({ length: to - from + 1 }, (_, i) => from - 1 + i);
  for (const page of await part.copyPages(source, indices)) part.addPage(page);
  return await part.save();
}
