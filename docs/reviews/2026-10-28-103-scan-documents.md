# Review 103: scan documents — 28 Oct 2026

**Founder (26 Oct):** add document scanning to the notebook and to Spaces. It is in the plan before the pilot (queue item 4).

**Status:** approved by the founder (4 Nov 12:25–12:29) with the changes at the end: Scan next to the camera (SC7), compression, Make it smaller on every PDF, and **OCR before the pilot**.

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
- **"Make it smaller" for every PDF (founder, 12:28), replacing "only when too large":**
  - **Any PDF attached** (composer, Library, chat, notebook) shows its size on the chip with **Make it smaller** («صغّر الملف»). This is an offer, never automatic. Not shown under 1 MB, where there's nothing to gain.
  - Tapping it compresses on the phone, then shows before → after ("9.1 MB → 2.3 MB") with the warning line, and **Use smaller** · **Keep original**.
  - **Over 25 MB:** the "too large" sheet offers Make it smaller first, with Link folder beside it.
  - **Still over 25 MB after compressing:** "Still too large (31 MB). The most is 25 MB." with **Link folder** only. It can't be uploaded.
  - **Tests:**
    - the offer shows at 1 MB and up;
    - before → after;
    - Keep original;
    - over the limit → smaller → fits;
    - still too large → only Link folder.

## OCR, "Extract text": approved for before the pilot (founder, 12:29)
- **Provider (the lead's call): Google Cloud Vision, document text detection.**
  - It reads Arabic, English and most languages, including mixed pages.
  - **Price (checked 4 Nov on Google's pricing page):** the first 1,000 pages each month are free, then US$1.50 per 1,000 pages. The pilot fits in the free tier.
  - Microsoft's page shows no prices without its calculator, so it isn't chosen.
- **Only on a tap:** "Extract text" («استخرج النص») on a scan or an image PDF. Never automatic, and never for a file the person can't read.
- **Server:**
  - **An edge function `extract-text`:**
    - signed-in callers only;
    - checks `can_open_library_file`, or the note's or post's own read rule, for that file;
    - at most 20 pages a file and 50 pages a person a day;
    - reads the file from storage and sends the pages to Vision;
    - stores the text.
  - **A table `file_texts`** (file reference, language detected, text, created_at). RLS reads it exactly as the file is read. pgTAP: a non-member can't read a file's text.
  - **The API key** sits only in a function secret (`GOOGLE_VISION_KEY`), never in the app. Setting it up is a live step for the founder: a Google Cloud project with the Vision API on and a key restricted to Vision.
- **App:**
  - the text shows under the file in a collapsible "Text" section, with **Copy**;
  - the words become searchable in Space search and notebook search;
  - "Couldn't read this file" on failure;
  - tests with a faked function.
- **Privacy:**
  - the privacy policy gets a line ("When you tap Extract text, the document is sent to Google Cloud to read its text, and the text is stored with the file");
  - a lawyer looks at it with the location wording;
  - Google's data terms (no use for training) to be confirmed when the project is set up.
- **Order:** Scan, then compression, then OCR. OCR merges only after the key exists.

## The lead's check of `claude/r103` at `17c71ed1` (4 Nov)
- **What was run:**
  - The SQL stand-in: **69 files, 4,537 checks, PASS**.
  - Two independent reviews, spec and security.
  - All 28 shots viewed.
  - The lead confirmed D1 in the code.
- **Read access holds:** no caller can get another Space's file, or an Only me notebook file, read or returned. Storage is read only after `file_for_text` passes as the caller, with the bucket and path taken from the database.
- **Verdict: not ready to merge.** Fix D1–D22 test-first on `claude/r103`.

### Blockers
- **D1. A scanned proof is refused on a real phone.** `add_evidence` still has `upload_mime … not like 'image/%'` → "evidence must be a photo" (chat_library.sql:896), and a real upload carries `application/pdf`. Test 69 inserted the object with no metadata, so it passed. **Fix:** allow `application/pdf`; the test row gets `{"mimetype":"application/pdf"}`; a test that CHECKED stamps a scanned proof.
- **D2. Over 25 MB in chat, DMs and the notebook** only shows a toast. **Fix:** the same too-large sheet as the composer and Library (Make it smaller first, then Link folder; still too large → Link folder only). Tests in each place.
- **D3. Extract text never saves a part as if it were the whole file.**
  - When the file needs more pages than are left today, refuse with the daily-limit message and read nothing.
  - A file over 20 pages reads the first 20, is saved marked `partial`, and the Text section says "First 20 pages" («أول 20 صفحة»).

### Server, fix before merge
- **D4. The Google key goes in the `X-Goog-Api-Key` header,** never in the URL. Logs carry fixed error codes only, never `e.message`, never paths.
- **D5. The daily limit holds under parallel taps.**
  - A `ocr_usage` table (person, day, pages), server-only;
  - a per-person `pg_advisory_xact_lock`;
  - the pages are reserved **before** calling Vision and released if Vision fails;
  - the count no longer depends on `file_texts.created_by`.
  - pgTAP.
- **D6. Text goes with its file:** delete `file_texts` rows when a note, a note file, a Library file or an account is deleted or purged. pgTAP for each.
- **D7. Size before download:**
  - `file_for_text` returns the size, and the function answers 413 above **10 MB** without downloading;
  - the app says "Too large to read. Make it smaller first." with the Make it smaller button;
  - send Vision only the page ranges needed, not the whole PDF four times, if the API allows it, and check Vision's inline request limit while doing so.
- **D8. Missing pgTAP:** a member gets no `file_texts` row, and no `search_space` hit, for a file in someone's Only me folder or in another Team's folder.

### App, fix before merge
- **D9. Extract text on notebook PDFs too.** The notebook is the first place in the table, and the server already supports it.
- **D10. Page 1's thumbnail is uploaded** with the scan, and stored where the file row points. Cards and proofs use it instead of downloading the whole PDF.
- **D11. The size on the composer chip** («9.1 MB»), as the spec says.
- **D12. "Make it smaller" in words everywhere,** not a bare download icon (chat, composer chip, `pdf_smaller.dart`).
- **D13. When the copy isn't smaller:** "This PDF couldn't be made smaller." («لم يمكن تصغير هذا الملف.»), and only Keep original.
- **D14. Progress while compressing:** "Making it smaller… page 3 of 12" (`pdfSmallerMaking`).
- **D15. Sizes round up** in "Still too large": 25.4 MB shows as 26 MB.
- **D16. One Arabic spelling:** «ميجابايت» and «كيلوبايت» everywhere (some screens say «ميغابايت»).
- **D17. File names keep their direction in Arabic:** isolate the name (`bidi` helper) on chips and rows. The SC4 shot shows «pdf.114».
- **D18. An empty name** falls back to the default "Scan · …".
- **D19. Clean-up:**
  - the scanner's raw pages and the `scans/` copies are deleted once added (or cancelled);
  - the chat copy too, once sent;
  - thumbnails are kept only as D10.
  - Add them to B2's start-up clean-up.
- **D20. `scanPage`:** if a page can't be decoded, fail. Never fall back to the original photo with its EXIF.
- **D21. Pin `cunning_document_scanner` exactly,** as every other package is. Check the merged Android manifest for any new permission (CAMERA), and report it.
- **D22. The privacy-policy line** goes in `docs/legal/privacy-draft-en.md` and its Arabic draft: "When you tap Extract text, the document is sent to Google Cloud to read its text, and the text is stored with the file."

### Accepted
- No per-place photo tests: every picker calls the same tested function.
- The Extract text test written after the code: recorded as a process miss.
- The Library's Add a file asking "File from the phone or Scan a document" first.
- Scan more pages adds pages after the old ones.
- PNG and WebP aren't resized, which keeps drawings sharp.
- Blank thumbnails in the goldens, but an **emulator shot with real pages** of SC3, SC4 and TX2 is required before sign-off.
