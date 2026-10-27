# Review 99: the notebook becomes pages; every note is an object; Deleted items — 26 Oct 2026

**Founder (26 Oct, 08:32–08:49):**
- "Like Notion, the notebook needs containers: pages for different uses, and a page may hold different topics."
- "Write the note directly; under it the option of a page. If none is chosen, a new page is created automatically. The user can merge many notes into one page."
- "Each note block is like a file: deleted, updated, moved from page to page, turned into another type, posted to the feed or to a Space."
- "Deleted goes to deleted items, cleaned after 30 days by default; the user can make it more or less."
- "It's huge work, but this is the added value of that part."

**Status:** rules approved by the founder (26 Oct, 09:00). Figma frames on "PROTOTYPE · Full app v1 · EN", named "… · R99 · PROPOSAL", for his look before the build:

| Frame | EN | AR |
|---|---|---|
| PG1 · Pages list | `2635:37785` | `2635:38736` |
| PG2 · Writing an entry, page chip under it | `2635:37894` | `2635:38845` |
| PG3 · Page picker from the chip | `2635:37987` | `2635:38938` |
| PG4 · A page: path, sub-pages, entries by day, "Posted to" mark | `2635:38121` | `2635:39072` |
| PG5 · Pages selected: Merge · Move into · Pin · Delete | `2635:38216` | `2635:39167` |
| PG5b · Merge sheet | `2635:38336` | `2635:39287` |
| PG6 · An entry's menu | `2635:38471` | `2635:39422` |
| PG7 · Post to feed: preview, GPS off, share check | `2635:38604` | `2635:39555` |
| PG8 · Deleted items, keep 7 · 30 · 90 days | `2635:38668` | `2635:39619` |

Words (founder's audit, 26 Oct 09:06):
- Users see two words only: a **page** (a container) and an **entry** («تدوينة»), meaning what is written at one time, dated (the slip, with its blocks).
- "Line" is the code's word for one block of an entry and never appears in the app. A deleted line group reads "Part of an entry" («جزء من تدوينة»).
- Below, "note" in older wording means an entry.

## 99A: pages

### A1. The notebook opens on the pages list
- **Each row:** the page's icon and title; then the date and the first line of its latest entry ("Today · Before the pour, level 3"); then, only if there are any, its open to-dos ("3 to-dos open"), counted across the page and its sub-pages.
- **No count of entries.** It tells the user nothing (founder's audit).
- **Order:** pinned pages first, then by latest activity.
- **Above the list:** "New entry" («تدوينة جديدة», the main action); Search and Deleted items in the top bar. **Under the list:** "+ New page", which creates an empty page and opens it.
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
- **Selecting pages** (long-press one, then tap others) shows a bar: **Merge · Move into… · Pin · Delete** (PG5).
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
2. Move to page…
3. Put in a Space
4. Post to feed
5. Delete
- **Not on an entry's menu:** Merge (it's for several pages) and Turn into (lines have it in their own menu).
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
  - the preview carries a share check: "Check it has nothing your client or company wouldn't share.";
  - a public post on Home, with an optional project tag;
  - the existing feed rules apply: report and block, and no misleading numbers.
- **The original stays** in its page with a small mark, "Posted to NBKCH Site team · 08:45" (the Space's real name) or "Posted to the feed · 08:45". It isn't moved or deleted unless the user chooses.

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

## Lead's check of `claude/r99a` (26 Oct)
**Branch:** `claude/r99a` at `e4f6c25`.
**Verdict:** approved after fixes C1–C10 below. Then shoot the shots, get the founder's yes, merge, push migration 47 alone, and build.

**What I checked:**
- Migration 47 on the SQL stand-in: all 2,825 checks in 46 files pass.
- The diff, read against this review (spec) and against CLAUDE.md (standards). Two separate reviews ran in parallel.
- Every function is `security definer` with `search_path = ''`, and checks the caller.
- Pages are owner-only.
- A page can't go inside itself or inside one of its sub-pages.
- The "My notes" backfill:
  - is safe to run again;
  - isn't stopped by the hidden-account guard, because nobody is signed in during a migration.
- There are no Material icons, raw colours, sizes, `left`/`right` or country facts.

### Fixes

**C1. Merge is refused when the page that stays sits deeper inside a page that goes (bug).**
- **Example:** G is merged into I, where G → X → I. X moves under I, which would make a loop, so the parent check refuses the whole merge.
- **Fix:** before any move, the page that stays climbs out of the whole tree of every page that goes. Its parent becomes the nearest page above it that isn't in any of those trees.
- **Test:** G → X → I merged into I succeeds. X ends up under I, and I takes G's place.

**C2. Merge creates its new page in the same call.**
- The app makes the page and merges in two separate calls (`notebook_state.dart`, `'merge'`).
- Send one call with `p_new_title`. Then a failed merge leaves no empty page behind.

**C3. Safe to send twice.** When a reply is lost, the queue sends `merge_notebook_pages`, `delete_notebook_pages` and `pin_notebook_pages` again.
- **Delete:** a page of mine that is already deleted is skipped, not refused.
- **Merge:** if the page that stays is mine and every page that goes is already deleted, it returns the page that stays and does nothing more.
- **Test:** each of the three, called twice, succeeds both times with the same result.

**C4. Server: the order of pages and "My notes".**
- **New entry, with or without a new page:**
  - `save_entry` inserts the entry straight into its page. Today the `note_page_ok` trigger first puts it on another page, which stamps that page too.
  - If the save comes back empty, no page is made.
- **What counts as activity:** an entry written, its words or to-dos changed, or an entry moved in.
  - Pinning an entry or setting a reminder doesn't count. The trigger fires only on those columns.
  - The phone uses the server's `last_activity_at` and the same rule, so the order is the same before and after a reload. "Last page used" for the chip follows the same rule.
- **Only one "My notes" per person:** a unique index on `owner_id` where `named = 'my_notes'` and the page isn't deleted. The trigger reuses the existing page.

**C5. The "new" mark must be seen.**
- Today, Send from **New entry** jumps into the new page, and opening it clears the dot at once. The user never sees the mark.
- **Fix:** after Send from the pages list, stay on the list:
  - the page is at the top with its dot;
  - a toast reads "Saved in {page} · Open" («حُفظت في {page} · فتح»).
- Writing inside a page stays in that page, as now.
- **Test:** after Send with "New page", the row shows the dot, and `page_open` isn't called.

**C6. Move to page… on a line never leaves a copy.**
- Today the moved part is saved at once, but the entry it left is changed only at its Send. If the user then discards, the part is in both pages.
- **Fix:** Move to page… saves both sides together, the new entry and the entry it left as it stands at that moment. Discard after that drops only later changes.
- **Moving from a brand-new entry:** if that entry has never been sent, nothing exists to save. The part simply leaves the draft.
- **Test:** move a part, then discard. The part is in the target page only.

**C7. Merge and Delete survive a closed app.**
- A merge or delete waiting out its 5 s Undo is held only in memory, so killing the app loses it without a word.
- Keep it in the phone's outbox, marked "send after {time}", like every other waiting change. Undo removes it from the outbox.

**C8. The words "page" and "entry" only (founder's audit).** These older strings still show in the notebook. Space strings don't change.

| Now | EN | AR |
|---|---|---|
| Delete this note? | Delete this entry? | حذف هذه التدوينة؟ |
| Couldn't keep this note. It's back as a draft. | Couldn't keep this entry. It's back as a draft. | تعذّر حفظ هذه التدوينة، وعادت مسودة. |
| A note holds up to 10 files / photos | An entry holds up to 10 files / photos | تتسع التدوينة لـ 10 ملفات / صور |
| Delete this line and the {count} lines under it? | Delete this and the {count} under it? | حذف هذا مع {count} تحته؟ |
| Hide / Show the lines under it | Hide / Show what's under it | إخفاء / إظهار ما تحته |
| Empty state "Keep notes…" | the same sentence with "entries" | the same with «تدوينات» |

- Grep the notebook ARB keys for "note", "line", «ملاحظة» and «سطر», and fix any others the same way.
- **"My notes" / «ملاحظاتي» keeps its name.** It is a page's name, approved in A6.
- Remove any key that nothing reads any more.

**C9. The path separator.**
- `'$n ›'` in `notebook_page_screen.dart` (around line 1208) types a sentence in code, and the arrow doesn't flip.
- Draw the path with `BvIcons` caret icons between the names: they flip in Arabic. Or use one ARB pattern. No `›` in Dart.

**C10. Tests for someone else (definition of done).**
- Add pgTAP tests that another person can't use `pin_notebook_pages`, `move_notebook_pages` or `open_notebook_page` on my pages.
- Add a test that `search_notebook` returns none of my pages or entries to them.

### Rulings on the 9 differences
1. **The My calendar icon stays in the top bar:** accepted. It is the only way into the calendar. I'll change the frame.
2. **The hard hat instead of the crane:** accepted. The 12 icons stay as listed. I'll change the frame.
3. **Order by latest activity, and Recent lists sub-pages:** accepted, with C4's rule for what counts as activity.
4. **No ⋯ while writing:** accepted.
5. **The PG4 title at 15 bold:** accepted. The two-size rule (founder, 18 Oct) wins over a frame drawn before it. I'll change the frame.
6. **The entry menu and long-press:** the old ⋯ menu stays on PG4 entries until 99B, as built.
   - **Long-press is decided now:** long-press an entry **selects** it, as for pages (A4), and **⋯ opens its menu**.
   - In B1, read "(its ⋯)" only. The "long-press a note" in B1 is struck out.
7. **One "Into …" choice per selected page, and a merge's new page reads "Untitled":** accepted, as long as that page carries the new dot (C5).
8. **Gender-neutral Arabic** («البحث عن صفحة»، «الكتابة في هذه الصفحة»): accepted. It is better than the frame. I'll change the frames.
9. **Download my data, Restore and the purge:** accepted for 99B. Two related changes now:
   - **Don't clear `pinned`** when a page is merged away or deleted. Lists already leave deleted pages out, and B3's Restore must bring a page back as it was.
   - **The Deleted items screen:** its empty "Pages you delete or merge away will show here" reads as lost data while it stays empty. Hide the Deleted items button until 99B. The 5 s Undo stays.

### Also seen, no change now
- **Merging entries from different pages (A4).** The app can select entries inside one page only. Moving several entries to one page with Move to page… gives the same result, so A4's "or notes from different pages" is met that way.
- **Open to-dos are counted on the phone, from the latest 500 entries.** That is enough for the pilot. Move the count to the server if a page ever passes 500.
- **`my_calendar` is copied in full** to add one line. That is how `create or replace` works, and the copy is checked as identical apart from that line.
- **Search runs the page check on every row.** That is fine at pilot size.
- **Change kinds are plain strings** in `notebook_state.dart` (`'save'`, `'merge'`, …). This pattern is older than 99A; leave it.
- **The 2,000-page cap and leaving deleted pages off My calendar:** accepted, though nobody asked for them. Both are cheap safety.

### The 42 older shots
| Shots | Ruling |
|---|---|
| NB1, its empty state and its menu (the one notebook list) | **Retired.** PG1 and PG4 replace them. Delete those goldens and their frame ids in the tests. |
| NB1 "Put in a Space" | **Re-pointed** at an entry's ⋯ menu on PG4, and shot again. |
| NBW1–5, NBX1–4, L1–L3, NBY1–5, slice 10 Remind me | **Re-pointed** at an entry inside the "My notes" page, and shot again. |

For each re-pointed shot, the only changes expected are:
- the top bar and path above the entry;
- the Move to page… row in the line menu (NBY2, L3).

List anything else that changed in the report, with before and after side by side.

### Then, in this order
1. **The fixes** C1–C10, the rulings, and the shots, on `claude/r99a`. Then run `flutter analyze`, `flutter test`, the SQL checks, and `test_screens` on the PC. Report the commands and their results.
2. **Stop for the lead's look.**
3. **With the founder's yes:**
   - merge into `slice2-app`;
   - `supabase db push` with **migration 47 as the only file listed**. Copy `supabase/.temp/` whole with `cp -r`, and keep `| tail` off the push.
4. **Read-only check on live:**
   - every note has a page;
   - each person who has notes has exactly one "My notes" page;
   - every note's page belongs to the note's owner;
   - the number of notes before the push equals the number after;
   - signed out, `search_notebook` returns nothing.
5. **One build** on the founder's phone, BuildVibes only. It covers reviews 94, 95, 98 and 99A.

## Lead's second check (26 Oct, 11:00): approved
**Branch:** `claude/r99a` at `5e025c2`.

**What I checked:**
- Migration 47 on the SQL stand-in: all 2,863 checks in 46 files pass.
- The fixes:
  - C1: the merge climbs out of every tree being merged away;
  - C3: delete and merge, sent again, skip pages already gone;
  - C4: `bv.note_page` puts a new entry straight into its page (transaction-local and checked by ownership), the activity trigger fires only on the listed columns, and there is one "My notes";
  - C5: Send goes back to the list with "Saved in · Open";
  - C6: both sides are saved;
  - C9: carets.
- PG1–PG5b in EN and AR: Arabic is right to left, the chevrons and carets flip, Arabic duals are right («مهمتان مفتوحتان»), and digits are Western.

**Two notes for 99B (no change now):**
1. A merge sent again **with entries listed** clears the new mark of a page that the first call made. It has no effect in the app today, because entries aren't merged across pages.
2. The merge sheet says "The emptied page goes to Deleted items" while that screen is hidden. The page is kept on the server, and 99B shows it. Keep the sentence.

**Next, with the founder's yes:** the steps in "Then, in this order", from step 3 on.

## Lead's check of `claude/r99b-server` (27 Oct)
**Branch:** `claude/r99b-server` at `66173e1`.
**Verdict:** approved after F1. It merges into `slice2-app` but **stays off the live database** until the redesign app that uses it is built and checked. Then the migration, the Edge Function and the cron job go live together, with the founder's yes.

**What I checked:**
- **Migration 48 on the SQL stand-in:** all 2,994 checks in 47 files pass (131 new).
- **Security:**
  - every new function is `security definer` with `search_path = ''` and checks the caller;
  - `notebook_remove` and `purge_notebook` can't be called by users; only the service role runs the purge;
  - `delete_forever` takes only my items that are already in Deleted items.
- **Old builds keep working.** `save_note`, `save_entry` and `search_notebook` were dropped and made again with new parameters that have defaults, so build 659's calls by name still resolve.
- **The conflict code** `40001` ("changed on another phone") matches the code `save_blocks` already uses for pages, so the app's handling is the same.
- **Files:** the purge leaves files without a row, and the existing `orphan_note_files` claims those for the Edge Function to delete. `delete_forever` and Empty now return the paths, so the app can delete them at once.
- **The toggle heading:** it is now drawn, and its test failed before the fix.

**Rulings on the six choices:**
1. On a post or checklist, the location becomes the last line ("📍 Gate 2 · …"); on a work item it is its place: accepted.
2. A shared checklist asks who it's for: accepted. The preview asks for it, as Put in a Space does.
3. A restored line group comes back as its own entry: accepted. It's clearer than merging back, and Deleted items already calls it "Part of an entry".
4. The app copies photos and files before sharing: accepted, as today.
5. The notes table still returns deleted and archived entries: accepted. The 99B app must filter them out of every list, count and on-phone reminder, with tests.
6. Download my data lacks pages, Deleted items, archived entries and shares: **not accepted** (F1).

### F1. Download my data includes everything the notebook keeps
- `export_my_data` adds:
  - pages (title, icon, parent, pinned);
  - each entry's page;
  - Deleted items, with when each was deleted;
  - archived entries;
  - the person's keep-days choice;
  - the share records (where to, and when).
- This is in the same migration 48, which isn't live.
- **Test:** the export contains each kind, and none of anyone else's.

### Before 48 goes live (later, from the PC, with the founder's yes)
- Install Deno on the PC and `deno check supabase/functions/notebook-purge/index.ts`.
- Push migration 48 as the only file.
- Deploy `notebook-purge` with its secret, both in Supabase and in Vault, never in the repo.
- Run `supabase/ops/notebook_purge_cron.sql`.
- **Read-only check:**
  - the note count is unchanged;
  - no entry is deleted or archived yet;
  - the cron job is listed;
  - one manual call of the function with the secret returns 0.
