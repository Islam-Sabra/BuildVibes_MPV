# Review 99: the notebook becomes pages; every note is an object; Deleted items — 26 Oct 2026

**Founder (26 Oct, 08:32–08:49):**
- "Like Notion, the notebook needs containers: pages for different uses, and a page may hold different topics."
- "Write the note directly; under it the option of a page. If none is chosen, a new page is created automatically. The user can merge many notes into one page."
- "Each note block is like a file: deleted, updated, moved from page to page, turned into another type, posted to the feed or to a Space."
- "Deleted goes to deleted items, cleaned after 30 days by default; the user can make it more or less."
- "It's huge work, but this is the added value of that part."

**Status:** the rules, for the founder's approval. Figma frames follow his yes, then the build. It comes in **two parts**, each built, checked and merged on its own:
- **99A:** pages, the page chip, auto-pages, move, merge, search, pin, sub-pages.
- **99B:** note actions to the outside (Post to feed, Put in a Space from a line), and Deleted items with its retention choice.

Words: a **page** is a container; a **note** is one written entry (the slip, with its blocks); a **line** is one block inside a note.

## 99A: pages

### A1. The notebook opens on the pages list
- **Each row:** the page's icon, title, the date of the latest note and a count of its notes. The count describes the user's own content; it isn't a quality signal, so it's allowed.
- **Order:** pinned pages first, then by latest activity.
- **Above the list:** "Write a note" (the main action), and Search.
- **Icons** come from a fixed set of about 12 Phosphor line icons: folder, hard hat, building, phone, list, calendar, camera, warning, star, wrench, ruler, notebook. No emoji, and no upload.
- Pages are **personal**. Nobody else can read them (row-level security, as for notes today).

### A2. Writing never waits for a page
- **"Write a note"** opens a new note at once (the F106/F107 slip). The keyboard is up on the title.
- **The page chip under the note** shows "Page: Site A – Tower ▾". It starts on the **last page used**, and on a fresh account it shows "New page".
- **Tapping the chip** opens a short list: recent pages first, then search, then "+ New page".
- **On Send:**
  - with a page chosen, the note goes into that page;
  - with "New page", a page is created, **titled from the note's first line** and marked **new** (a dot), until the user opens it, renames it or merges it.
- **Writing inside a page** puts the note in that page, with no chip question.

### A3. Inside a page
- **The title and icon** can be edited in place.
- **The page's notes** show newest first, grouped by day ("Thursday 15 October"). A page can serve as a daily log for its site without any setting.
- **Sub-pages:** a page can hold pages, as deep as needed. They show as rows at the top of the page ("Pour day ›") and get a path at the top ("Site A › Level 3").
- **Pin** a page to the top of its list.

### A4. Move and merge
- **Move to page…** works on a note, or on several selected notes (long-press one, then tap others). The picker is the same as the page chip's.
- **Merge into one page:**
  - select pages, or notes from different pages;
  - choose the page that stays, or "New page";
  - every note moves there in date order, the emptied pages go to Deleted items, and Undo is available for 5 s.
- **A line** can be moved to another page from the line menu (review 98) with **Move to page…**. It becomes a new note there, with its children.

### A5. Search in the notebook
- One field over every page: page titles, note titles and the text of lines.
- **Western digits and Arabic** work as in Space search.
- **Results** show the page and the date, and tapping one opens the note in its page.

### A6. Existing notes
- Every existing note is moved into one page named **"My notes" / «ملاحظاتي»**, in its date order, so nothing is lost and the user can split them later.
- Drafts stay drafts.

## 99B: notes to the outside, and Deleted items

### B1. A note's menu (long-press a note, or its ⋯)
1. Edit
2. Turn into
3. Move to page…
4. Merge into a page…
5. Put in a Space
6. Post to feed
7. Delete
- **Rows that can't act are hidden**, for example Put in a Space for someone in no Space.
- **The line menu (review 98) gains** Move to page…, Put in a Space and Post to feed, for one line with its children.

### B2. Going out is always previewed
- **Put in a Space** and **Post to feed** first show a **preview** of exactly what others will see, with Post and Cancel. Nothing goes out in one tap.
- **The GPS position never goes**, unless the user ticks "Include my GPS position" on that preview (as today).
- **Put in a Space:**
  - the user chooses the Space, its kind (post, work item, checklist) and the Team, as today;
  - the rules of the Space and the pass apply on the server;
  - **Work stays in Spaces:** a work item is created only in a Space.
- **Post to feed:**
  - a public post on Home, with an optional project tag;
  - the existing feed rules apply: report and block, and no misleading numbers.
- **The original stays** in its page with a small mark, "Posted to Site A · 08:45" or "Posted to the feed · 08:45". It isn't moved or deleted unless the user chooses.

### B3. Deleted items
- **Deleting** a note, a line group, a page (with everything inside) or a merge's emptied pages shows **Undo for 5 s**, then moves them to **My notebook → Deleted items**. They aren't drafts.
- **Each item** shows what it is, the page it came from and when it was deleted.
- **Restore** puts it back in its page. If that page is gone, it goes to a new page with the old title. **Delete forever** removes it, after one confirm.
- **Empty now** removes everything, after one confirm.
- **One choice inside the Deleted items screen** (rule 6: one single-choice control; rule 7: no Settings entry):
  - "Keep deleted items for: 7 days · 30 days · 90 days";
  - 30 is the default.
- **On the server,** a daily job removes items past their time, along with their files (voice, photos, files) from Storage.
- **Nothing in Deleted items** shows in search, on the pages list or on My calendar, and its reminders don't ring.

## Server (one migration per part; not live until the lead checks it and the founder says yes)
- **99A:**
  - `notebook_pages`: owner, parent page, title, icon key, pinned, `is_new`, `created_at`, `last_activity_at`, `deleted_at`;
  - `notes.page_id`, not null after the backfill into "My notes";
  - RLS: owner only;
  - functions for move, merge (all or nothing) and search;
  - tests that another person can't read, move into or merge someone else's pages.
- **99B:**
  - `deleted_at` on notes, and the retention choice on the profile (7, 30 or 90);
  - the daily purge (pg_cron or a scheduled function, decided at build), with Storage clean-up;
  - post-to-feed and put-in-a-Space from a note or a line, reusing today's functions, with the preview's choices sent along and GPS dropped unless ticked;
  - tests for the purge, Restore, a page deleted with its children, and someone else's items.

## Tests and screenshots
Each rule above gets a test, in EN and AR. Screenshots at 390×844, EN and AR:
- PG1: pages list;
- PG2: writing with the page chip;
- PG3: the chip's picker;
- PG4: a page with day groups and sub-pages;
- PG5: merge;
- PG6: the note menu;
- PG7: the Post-to-feed preview;
- PG8: Deleted items with the 7/30/90 choice.

## Not in this review
- Sharing a page with other people. Sharing is by Put in a Space or Post to feed.
- Dates inside the line, and dragging on phones: the next review.
- Databases and colours: later, as review 98's table says.
