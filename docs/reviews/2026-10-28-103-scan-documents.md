# Review 103: scan documents — 28 Oct 2026

**Founder (26 Oct):** add document scanning to the notebook and to Spaces. It is in the plan before the pilot (queue item 4).

**Status:** draft. Frames SC1–SC5 follow (EN and AR) for the founder's look; nothing is built before his yes.

## Why
Site paperwork reaches the phone today as crooked photos with shadows: a delivery note, an inspection request, a cube test certificate, a permit, a signed checklist, the consultant's marked-up comments.
- A scan makes them clean, straight, and in one PDF.
- **It feeds the product's promise:** a signed inspection request scanned as a work item's proof is what makes "proof from checked work" believable.

## What a scan is
- **The phone's own scanner** finds the paper's edges, straightens and cleans the page, and lets the user add pages, retake, crop and reorder. That is Google's document scanner on Android (Google Play services) and Apple's on iPhone (VisionKit). We don't build a scanner.
- **One scan is one PDF** of 1–20 pages. A JPEG thumbnail of page 1 is made for cards and lists.
- **Its name defaults to "Scan · {day} {time}"** («مسح · {day} {time}») and can be changed on the review sheet (SC3). The name is the first thing people see.
- **Size:** pages are JPEG inside the PDF at a quality that keeps text readable, at most about 2 MB a page. A scan obeys the place's existing file limit (25 MB). Past it, the review sheet says "Too large: remove some pages" and Add is off.
- **Photo privacy:** no location or device data is kept in the pages, as for photos (`photo_privacy`).
- **Huawei phones and others without Google Play services:** "Scan a document" stays, but opens **our own camera** to take pages one by one. The PDF is made on the phone with the `pdf` package already in the app. There is no edge detection, and the review sheet shows a line: "This phone has no document scanner, so pages are plain photos."
- **No reading of the text (OCR) yet.** It's parked for after the pilot, because Arabic OCR is weak on the phone.

## Where it appears ("Scan a document", «مسح مستند»)
| Place | Entry | Becomes |
|---|---|---|
| **Notebook, writing** | The 📎 card: File · **Scan a document** · Location · Date · Reminder (SC1) | A file block in the entry, like a PDF today: name, "Scanned · 3 pages", and a page 1 thumbnail (SC4) |
| **Space, writing a post** | "Add to this post": Take a photo · Photo from the gallery · **Scan a document** · File from the phone · From the Library (SC5) | The post's file, shown like a PDF, with "Scanned · N pages" |
| **Sign as done (proof)** | The proof step offers **Photo** or **Scan** as one single choice. Scan suits a signed inspection request. | The work item's proof is the PDF, and its page 1 thumbnail stands where the proof photo shows. "CHECKED" stamps it the same way. |
| **Space Library** | "Add a file" → **Scan a document** | A Library file with a version, like a PDF upload |
| **Chat and direct messages** | The attach sheet: Take a photo · Photo from your phone · **Scan a document** · PDF from your phone | A PDF card. In a Space chat it goes to the Library too, as PDFs do today. |

## The review sheet after scanning (SC3)
- **Header:** "Scanned document" and a page count: "3 pages" («3 صفحات»), using the Arabic plurals.
- **A strip of page thumbnails;** tapping one opens it full size.
  - Rescanning and reordering stay in the phone's scanner: **"Scan more pages"** reopens it with these pages.
- **Name field** with the default name, cursor at the end.
- **"✕ Cancel"** and **"➤ Add"** as words with icons (BH5's style).
- Cancel, after one confirm "Discard this scan?", throws the pages away. Nothing was uploaded yet.

## Upload and no signal
- **Like any PDF in that place:** the outbox, "Waiting to send", "Couldn't send · Tap to fix", and retries.
- **The PDF is made on the phone first,** so a weak signal never loses pages.

## Server
- **No new table.** A scan is a PDF file in the existing places and buckets.
- **New metadata on file rows** where a "scanned" mark shows: `scanned boolean` and `page_count integer`, plus the page 1 thumbnail path.
  - This covers the notebook's `note_files`, the Library's `library_files` and the proof attachment.
  - It's one migration, with pgTAP tests that it follows each place's existing read rules (non-members can't read it).

## Tests (EN and AR)
- The scan entry appears in each place in the table, and is hidden where adding files isn't allowed (a Viewer's pass).
- With the scanner faked: 3 pages give a PDF of 3 pages, the thumbnail, the default name, a rename, Add, and Cancel with its confirm.
- Over the size limit, Add is off with the message.
- Without Google Play services, the fallback camera path builds a PDF.
- No location data is kept in the pages.
- Proof by scan: Photo/Scan as one choice, the proof shows the thumbnail, and CHECKED stamps it.

## Frames
On "PROTOTYPE · Full app v1 · EN", named "… · R103 · PROPOSAL". The EN row is at y 60400 and the AR row at y 61400.

| Frame | EN | AR |
|---|---|---|
| SC1 · The notebook's 📎 card with Scan a document | `2662:38293` | `2662:38677` |
| SC3 · After scanning: page strip, Scan more pages, Name, ✕ Cancel · + Add | `2662:38420` | `2662:38804` |
| SC4 · An entry with a scanned file block ("Scanned · 3 pages · PDF") | `2662:38569` | `2662:38953` |
| SC5 · A Space's "Add to this post" with Scan a document | `2662:39131` | (code's AR shot, mirrored by the usual rules) |
| SC6 · Sign as done: Photo \| Scan, one choice above the shutter | `2662:39295` | (code's AR shot, mirrored by the usual rules) |

- **SC2** is the phone's own scanner, so it isn't drawn.
- **The Library's "Add a file → Scan a document"** and **the chat's attach sheet** get the same row as SC5.

## Founder's changes (4 Nov)
- **Where Scan lives (founder, 12:25):** not inside the + / 📎 menu. **Scan gets its own button in the bar above the keyboard, right after the camera:** + · camera · **Scan** · mic · Send.
  - It's in the Space composer, and in the same place in the notebook's writing bar.
  - It stays in the Library's "Add a file", the chat attach sheet, and Sign as done (Photo | Scan).
  - Icon: Phosphor `scan`.
  - Frame **SC7**: EN `2744:40173`, AR `2744:40248` (the CV3 composer with the Scan button). SC1's and SC5's menu rows for Scan are dropped where the bar button exists.
- **Compression (founder, 12:25: "an effective PDF compressor and image compressor"), the lead's calls:**
  - **One photo compressor everywhere a photo enters:**
    - Work already does it (1600 px, JPEG 80, no location);
    - extend the same to Chat, DMs, Library images, the notebook and the profile, through one function;
    - a photo already under 1600 px and 500 KB is left as it is;
    - text on drawings and labels stays readable;
    - tests per place.
  - **Scans are compressed at the source:** about 200–300 KB a page, as above.
  - **Uploaded PDFs are never changed automatically.** They are records, and computer-drawn PDFs barely shrink.
  - **"Make it smaller" («صغّر الملف»):**
    - shown on the "too large" sheet next to Link folder;
    - the phone renders each page to a compressed image (pdfx, 150 dpi, JPEG ~75) and rebuilds the PDF (`pdf` package);
    - before confirming, a line says: "Text can't be selected afterwards, and fine lines get softer." («لن يمكن تحديد النص بعد ذلك، وتصبح الخطوط الدقيقة أنعم.»);
    - the original on the phone is untouched;
    - it shows the new size before adding;
    - all on the phone, with no outside service.
- **OCR, "Extract text" («استخرج النص»): waiting for the founder's decision.**
  - Phone-only OCR (ML Kit) doesn't read Arabic.
  - The lead's recommendation: a cloud reader (Google Document AI or Microsoft Read, chosen after checking current prices and data terms), called **only when someone taps the button**.
  - The text shows under the file, can be copied, and becomes searchable in Space search and notebook search.
  - Needs: the founder's yes on sending documents to a cloud reader, a privacy-policy line, and a lawyer's look.
