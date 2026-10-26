# Handoff

Where the work stopped, for whichever place picks it up next: the founder's PC, a cloud session, or the lead's chat in the Claude project. Each session rewrites this file before it stops. The full history stays in `progress.md`.

## Cloud update: 26 Oct 2026 — the lead's D1–D13 on `claude/r100-bugs` (from aa1ec48); stopped for the lead

**Standing rule (review 74):** nothing but the BuildVibes build goes on the founder's phone without his yes in chat.

- **Branch `claude/r100-bugs` is pushed** (`37462a2`). Not merged, not live, nothing installed. No database change, no migration. The redesign (Parts 0 and 3–8) is not built.
- **Each fix, test first (EN and AR); each test failed before its fix unless said:**
  - **D1:** `initState` saved a leftover edit with nothing to compare against. It now opens again in the editor, as the entry was; nothing is sent until Back. Test: `D1: an edit left open …`.
  - **D2:** `save` first waited for a held change to go out (`releaseHeld` → `_send`), and the Draft was dropped without waiting. Now the held change joins the outbox unsent, the edit is stored, and `saveOnPhone` ends there; the Draft goes after. Test: a delete held on its Undo bar and a call that hangs; the phone's outbox holds the edit.
  - **D3:** an emptied saved entry was dropped silently. It is now a held delete with "Deleted · Undo", sent when the bar closes. Two tests (it goes; Undo brings it back).
  - **D4:** a refused edit came back as a new-entry Draft beside its entry. The refusal is now said after the notebook reads again: an entry the server still has comes back as an edit in the editor, with its link; only a new entry comes back as a Draft. A second Back with no change leaves (no loop of refusals). Test: one card, the words in the editor.
  - **D5:** the room was read under the Scaffold, where the keyboard inset is 0. It is now worked out in the overlay. Test: the line menu on a line in the middle, the keyboard up.
  - **D6:** room was made for 9 rows, for the line menu only. Now the card as laid out: a card that fits neither under nor over the line stands off the screen while the page scrolls, then shows. Also found and fixed: the card didn't follow the page when it scrolled (it listened to a field's own scrolling), and the "/" card stood by the first line of its field, not the whole field. Test: the "/" card with every kind, on a line in the middle.
  - **D7:** `kToolbarHeight` is gone: `BvSize.topBar` (56), also the theme's app bar height. Nothing moves. Test (a guard; equal numbers): the bar and the room under it read the token. The frames draw the bar 48: not changed.
  - **D8:** `+` and Location called `unfocus()`. Removed. Tests: both open with the keyboard up. NBX2's old check (keyboard hidden under the grid) is turned round.
  - **D9:** `focusBlockNow` on the typed `---`, a kind from "/" or the grid on an empty line, and a toggle's line. **The cause was not reproduced:** the four tests passed before the change too (the late focus still landed before the keyboard could drop). They stay as guards.
  - **D10:** the entry's ⋯ was inside the card's `InkWell`; it now stands over the card, outside its gestures (holding it is a press, never a selection). Temporary until the redesign.
  - **D11:** a removed line's focus nodes are disposed (after the frame); Draft cards' keys and title focus are pruned on resume and Discard; the menu's comment is back on its own method; `notebookDraftFirst` removed; «تم الحفظ». Tests for the nodes and the word; the pruning is private and has no test.
  - **D12 (B6):** the root cause was bigger than the manifest. go_router 18 checks for `material_ui`'s `MaterialApp`, another class than the app's, so every screen was a `NoTransitionPage`: no predictive back and no iPhone edge swipe anywhere. Every route is now Flutter's `MaterialPage` (`_Screen` in `app_router.dart`) and moves with the theme's transitions (Android: predictive back, the Flutter default; iPhone: Cupertino with its swipe). Android: `enableOnBackInvokedCallback`. iPhone: `BvBackSwipe`: where a screen holds Back (the notebook page while writing or selecting, the pages list while selecting, walk, a Space's daybook while writing, the proof camera), a swipe from the leading edge (the right in Arabic) does what ← does; a menu's barrier closes on a swipe as on a tap. Tests (`back_swipe_test.dart`): the order menu → selection → entry (saved in place) → screen, by iPhone swipe and Android system back, and the pages list.
  - **D13:** the Draft card's ⋯ sheet is marked TEMPORARY in the code.
- **Found, not fixed (outside this branch):** a heading picked with "/" inside a toggle isn't drawn (the toggle draws only text lines; `hostBlock` has no heading).
- **Checks (cloud):**
  - `flutter analyze`: no issues;
  - `flutter test`: 2,166 pass, 1 fails (photo_privacy H1, root-only in the cloud). The run now takes about 11½ minutes (6½ before): screens have transitions;
  - screenshots: PC later. Expect changes where a shot shows a moved card (D6's anchor) or the entry's ⋯ (D10, same place).
- **Next (PC):** `flutter test test_screens` without updating; put before/after in `docs/screens/r100/before-after/` and list them. Check on the emulator: back by swipe with the screen underneath showing, the keyboard under `+` and Location, the "/" card near the keyboard. Then the lead.
- **Who has which branch:** this cloud session had `claude/r100-bugs` (done, pushed). PC: `slice2-app`.

## PC update: 26 Oct 2026, 17:00 Kuwait — review 100 bugs B1–B5 on `claude/r100-bugs` (from `slice2-app` 2371559); stopped for the lead

**Standing rule (review 74):** nothing but the BuildVibes build goes on the founder's phone without his yes in chat.

- **Branch `claude/r100-bugs` is pushed.** It is not merged, not live, and not installed. No database change. The redesign (review 100, Parts 3–8) is not built.
- **The bugs, each with its cause:**
  - **B1 — the keyboard dropped between lines.**
    - Cause: a line's field handled Enter in `onSubmitted` but had no `onEditingComplete`. Flutter's default for "next" first handed the focus to the next focusable thing, and the new line took it only a frame later (`focusBlockLater`).
    - Fix: Enter keeps the focus, and the next line (or, on Backspace, the line above) takes it at once (`focusBlockNow`).
    - Test: the focus is never outside a line's field, and the keyboard is never hidden. It fails without the fix.
  - **B2 — a saved entry showed twice after Back.**
    - Cause: Back from an edit kept the edit as the Draft, beside the saved entry.
    - Fix:
      - Back from a saved entry saves it in place when it changed, with "Saved · Undo" for 5 s; Undo puts back the entry as it was opened;
      - with no change, nothing is saved or shown;
      - an edit left open when the app closed is saved in place when the page opens again;
      - a refused entry comes back as a new-entry Draft;
      - a Draft's ⋯ has Discard, with Undo.
  - **B3 — "Write in this page" opened an old draft.**
    - Cause: there was one draft per account, and Write reopened it.
    - Fix:
      - Write always starts a new entry;
      - each unsent Draft is kept as its own card at the top of its page (`parkedDraftsProvider`, `notebook_drafts:<user>`);
      - a tap on a card goes on with that Draft;
      - New entry on the pages list does the same.
  - **B4 — the line menu went under the keyboard.**
    - Cause: the popover allowed itself over the keyboard (it used only the safe-area insets), and so did the editor's "make room" scroll.
    - Fix:
      - the area a card may stand in is the screen minus the top bar and the keyboard, with 8 of margin (`visibleTop`, `visibleBottom`);
      - a card opens under the line if it fits, else over it;
      - if it fits neither way, the line menu first scrolls the page up;
      - a card taller than the room scrolls inside it.
    - Test: the menu ends above the keyboard. It fails without the fix (772 > 544).
  - **B5 — ⋯ was slow and opened two menus.**
    - Cause: ⋯ waited for the Spaces list to load before showing anything, and nothing stopped a second one.
    - Fix:
      - the menu opens at once and its Spaces come in as they load;
      - one menu at a time (entry, page and Draft menus);
      - Back closes the page picker, the line menu or the "/" card first.
- **Tests:** `test/features/notebook/note_bugs_test.dart` (20, EN and AR). Older tests were moved to the new rules:
  - stored Drafts are continued from their card;
  - B14 now pins during the edit, then Back.
- **Shots:**
  - PG2 and PG3 are now typed on New entry; the results are identical to before.
  - 6 shots changed, as the fixes mean; before/after in `docs/screens/r100/before-after/`:
    - NBY1: the "/" card opens over the line, since the keyboard is under it;
    - NBY2: the line menu opens over the line;
    - NBW5: the Draft card has its ⋯.
- **Checks:**
  - `flutter analyze`: no issues;
  - `flutter test`: 2,120 pass;
  - `flutter test test_screens`: 426 pass.
- **Who has which branch:** PC has `claude/r100-bugs` (worktree `BuildVibes-r100`) and `slice2-app` (worktree `BuildVibes-slice1`).

## PC update: 26 Oct 2026, 14:15 Kuwait — review 99A in `slice2-app`; migration 47 live; build 640 on the founder's phone

**Standing rule (review 74):** nothing but the BuildVibes build goes on the founder's phone without his yes in chat.

- **Merge:** `claude/r99a` merged into `slice2-app` (a fast-forward to 5e025c2) and pushed. Checks on the merged branch:
  - `flutter analyze`: no issues;
  - `flutter test`: 2,100 pass;
  - `supabase db reset` + `supabase test db`: 2,863 pass in 46 files.
- **Migration 47 is live** (founder's yes, 26 Oct). The push ran from a throwaway worktree with `supabase/.temp` copied whole.
  - The dry run and the push both listed only `20261108120000_notebook_pages.sql`. The push exited 0.
  - After it applied, the CLI printed the harmless pg-delta "failed to cache migrations catalog" warning.
- **Read-only check on live:**
  - before the push: 7 notes, 1 person with notes;
  - after: 7 notes;
  - 0 notes without a page;
  - 0 people with notes who don't have exactly one "My notes";
  - 0 notes on someone else's page;
  - 1 page in all;
  - RLS is on `notebook_pages`;
  - signed out, `search_notebook` can't be called (no grant), and as a signed-in role with no user it refuses ("not allowed").
  - The last live migration is `20261108120000`.
- **Build 640** (5e025c2, versionCode 640, versionName 0.9.0) is **installed on the founder's phone** (192.168.8.24:43367, BuildVibes only). It covers reviews 94, 95, 98 and 99A.
- **Next:** the founder's test of the notebook pages on build 640; then review 99B (the entry menu's Put in a Space / Post to feed, Deleted items, the purge).
- **Who has which branch:** PC has `slice2-app` (worktree `BuildVibes-slice1`). `claude/r99a` is merged. The worktrees `BuildVibes-r99a`, `BuildVibes-r95` and `BuildVibes-hold` can be removed.

## PC update: 26 Oct 2026, 13:30 Kuwait — review 99A: the lead's check applied on `claude/r99a`; stopped for the lead

**Standing rule (review 74):** nothing but the BuildVibes build goes on the founder's phone without his yes in chat.

- **`claude/r99a` is pushed.** It is not merged, not live, and not installed anywhere.
- **Done:**
  - C1–C10.
  - The rulings: long-press selects and ⋯ opens the menu; a deleted or merged page keeps its pin; the Deleted items button is hidden until 99B; a merge's new page carries the new mark.
  - The 42 older shots, as the table says.
- **Migration 47** (still `20261108120000_notebook_pages.sql`, still not live) now has:
  - **C1:** the page that stays climbs out of the whole tree of every page that goes.
  - **C3:** merge, delete and pin are safe to send twice.
  - **C4:**
    - `save_entry` puts an entry straight into its page (`bv.note_page`).
    - If the save comes back empty, no page is made.
    - Activity is an entry written, its words or to-dos changed, or moved in; a pin or a reminder doesn't count.
    - One "My notes" per person (a unique index).
  - **C10:** tests for someone else.
  - 124 checks for migration 47.
- **App:**
  - **C2:** a merge is one call.
  - **C4:** the same activity rule on the phone.
  - **C5:** Send from New entry stays on the list, with "Saved in {page} · Open".
  - **C6:** Move to page… on a line saves both sides.
  - **C7:** a held merge or delete is kept on the phone, and goes when the app opens again.
  - **C8:** the words "page" and "entry"; unused keys removed.
  - **C9:** the path is drawn with caret icons.
- **Shots:**
  - NB1, its empty state and its menu are retired (10 goldens deleted).
  - The rest are re-pointed at an entry in "My notes".
  - PG1–PG5b are shot again. `docs/screens/r99/` was git-ignored and is now committed.
  - Before and after pictures of the 36 changed older shots are in `docs/screens/r99/before-after/`.
- **Changes beyond the top bar, the path and the line menu's Move to page… row** (for the lead):
  1. **Writing shots** (NBW1, 3, 4, NBX1–4, L1–L3, NBY1–5):
     - the entry being written is shown alone, as in PG2, so the day's other entries are no longer above it;
     - the "Today" divider is gone, so the slip sits 12 points lower.
  2. **Shots of the page** (NBW5, slice 10 NB-reminder-slip) are now PG4:
     - plain cards;
     - the kind or title, then the time and ⋯;
     - newest first;
     - pinned entries under "Pinned" instead of the band;
     - "Draft" above the draft;
     - "Write in this page" instead of the post bar;
     - "Note" now reads "Entry" (C8).
  3. **The entry's ⋯ menu** (slice 10 NB-remind-menu) has Move to page… before Delete.
- **Checks:**
  - `flutter analyze`: no issues.
  - `flutter test`: 2,100 pass.
  - `supabase test db`: 2,863 pass in 46 files.
  - `flutter test test_screens`: 426 pass, none changed.
- **Next, with the founder's yes:**
  1. Merge into `slice2-app`.
  2. `supabase db push` with migration 47 as the only file. Copy `supabase/.temp` whole and keep `| tail` off.
  3. The read-only live check from review 99.
  4. One build.
- **Who has which branch:** PC has `claude/r99a` (worktree `BuildVibes-r99a`) and `slice2-app` (worktree `BuildVibes-slice1`).

## PC update: 26 Oct 2026, 10:40 Kuwait — review 99A on `claude/r99a` (from `slice2-app` de29fa9); stopped for the lead: 42 older notebook shots change

**Standing rule (review 74):** nothing but the BuildVibes build goes on the founder's phone without his yes in chat.

- **Branch `claude/r99a` is pushed.** It is not merged, not live and not installed anywhere.
- **Server: migration 47 `20261108120000_notebook_pages.sql`, not live.**
  - `notebook_pages`, owner only (RLS read; every write goes through a function).
  - `notes.page_id` is not null. The backfill puts every note into one "My notes" page per person, in date order.
  - `save_entry` (save_note plus its page, or a new page titled from the entry and marked new). Old builds keep calling `save_note`: their new notes go into the latest page.
  - Functions: create, update (title and icon), open, pin, move pages, move notes, merge (all or nothing; emptied pages get `deleted_at`), delete (with sub-pages), `search_notebook` (Arabic letters and digits folded).
  - My calendar leaves out entries of a deleted page.
  - 86 SQL checks. They cover: the owner can do everything; another person can't read, write into, move into or out of, merge, rename, delete or search someone else's pages; the backfill keeps every note; a failed merge changes nothing.
- **App:**
  - **PG1** pages list: New entry, Search, My calendar and Deleted items (empty placeholder until 99B), pinned then latest activity, + New page.
  - **PG2/PG3** New entry: opens at once with the chip on the last page used ("New page" on a fresh notebook); the picker with search, recent and + New page.
  - **PG4** a page: path, title and icon edited in place (12 icons), sub-pages, entries newest first by day, "Write in this page" with no chip.
  - **PG5/PG5b**: select pages, then Merge, Move into…, Pin or Delete; Undo for 5 s.
  - Move to page… for one entry (⋯), several entries (long-press, then tap), and a line from the line menu (with its children).
  - Search screen.
- **Checks:**
  - `flutter analyze`: no issues.
  - `flutter test`: 2,089 pass (42 of them are new 99A tests).
  - `supabase test db`: 2,825 pass in 46 files.
  - `test_screens/pg_test.dart`: 12 shots in `docs/screens/r99/`.
- **Stopped here (as asked):**
  - `flutter test test_screens` without updating: 390 shots unchanged, and **42 older notebook shots change**. These are f106 NBW1–5, f107 NBX1–4, f108 L1–L3, nby NBY1–5, slice8 NB1 / empty / menu / Put in a Space, and slice10 Remind me, in EN and AR.
  - They show the notebook as one daybook list. 99A replaces that list with pages: the masthead, the post bar and "Only you" are gone, entries are newest first, and the line menu has one more row, "Move to page…".
  - Nothing in them is accepted or committed. Those tests still open the old way (`/notebook`, the post bar).
  - Needed from the lead: retire the NB1/NBW/NBX frames, or point them at a page and re-shoot.
- **Differences from Figma for the lead:** see the 26 Oct log entry in `progress.md`.
- **Who has which branch:** PC has `claude/r99a` (worktree `BuildVibes-r99a`) and `slice2-app` (worktree `BuildVibes-slice1`). The worktrees `BuildVibes-r95` and `BuildVibes-hold` can be removed.

## Cloud update: 25 Oct 2026 — review 96 on `claude/r96-fix` (from `claude/r95` 1599922), not merged, not live

- **F1:**
  - Space search's group is now **"Posts" / «المنشورات»** (was "Work items").
  - Each post row has its own kind's icon, the same as its kind chip (`kindIcon`): note, work item, checklist, announcement, scheduled activity, file, report.
  - Test (`space_search_test`, EN and AR): a number search ("23") finds a note and a work item, both under "Posts", each with its own icon, the number first.
- **F2: withdrawn** (review 96's addendum; the prototype wins).
  - `_kindWord` and the five header strings are back exactly as on `claude/r95`: an announcement reads "· to everyone" / «· للجميع», a scheduled activity "· scheduled" / «· مُجدول».
  - `kind_word_test` now checks those prototype words in EN and AR.
  - Only F1's string change stays: `searchWorkItems` became `searchPosts`.
- **F4:** `supabase/dev/standin/shim.sql` from `main` (with `realtime.send`).
- **Checks (cloud):**
  - `flutter analyze` clean.
  - `flutter test test` 1,949 pass after F2's undo; 1 fails, photo_privacy H1, which fails only as root in the cloud.
  - SQL stand-in: 2,739 checks in 45 files pass.
  - `test_screens/` not run here, and no `--update-goldens`.
- **For the PC:**
  1. Retake with `--update-goldens` on the PC's fonts **only R3** (`docs/screens/r95/`) and any other shot showing search results. Nothing else should change.
  2. Then the lead checks, and with the founder's yes, review 96's steps: merge `claude/r96-fix` (it carries `claude/r95`) into `slice2-app`; push migration 46 alone; the read-only check; build 613.
- **Not merged, nothing pushed to the database, nothing deployed, nothing installed.**
## Cloud update: 25 Oct 2026 — review 98, the notebook writes like Notion (`claude/r98`)

- **C1 done (lead's check, 25 Oct late):** one Arabic word per menu row in the notebook's line menu and Work's ⋮⋮ sheets: Turn into «تحويل إلى» (`pageTurnInto`, now also the sheets' title), Delete «حذف» (`pageMenuDelete`, new, on every Delete row), Move up «نقل لأعلى», Move down «نقل لأسفل». A dialog's confirm button keeps «احذف» (`pageDelete`). Removed, as unused: `notebookLineTurnInto`, `notebookLineDelete` (renamed `pageMenuDelete`), `notebookRestartNumbering`; no other string is unused. A test checks both places. Analyze clean; `flutter test test`: 2,022 pass, 1 fails (photo_privacy H1, root-only in the cloud). The lead approved the branch after C1; the PC's next steps are in the lead's check (NBY1–NBY5 and F108 L3 shots, the emulator checks, then the merge with the founder's yes after review 96's).
- **Branch `claude/r98`** (from `slice2-app` bc269ec): review 98 rules 1–8 in our own editor (`note_page_editor.dart`, the shared `page_block_editing.dart`, and Work's `daybook_page_editor.dart` where the code is shared). App only: **no database change**, nothing live, nothing installed, not merged.
- **What it does:**
  - typed shortcuts at the start of a text line (`1.` `1)` `١.`, `-` `*`, `[]` `[ ]`, `#` `##`, `>`, `"`, `---`), with a light click and the Undo bar, which gives the characters back;
  - `/` at the start of any line or after a space opens a small card next to the line (NBY1); typing filters it by the English or Arabic name and simple words ("num", "todo", «مهام»); Enter picks the first; Escape, or a space with no match, leaves the `/`; each kind shows its shortcut;
  - + adds a text line below the line and its children and opens the grid for it; an empty text line is turned instead; each tile shows its shortcut;
  - ⇥ and ⇤ on the bar each show only when they can act (NBY3, NBY4);
  - the line menu is a popover next to the line, the line tinted (NBY2), from ⋮⋮ or by holding the number, bullet or box; holding the words still selects text. Rows: Turn into ›, Move up, Move down, Indent, Outdent, Duplicate, Continue numbering / Restart at 1, Delete; rows that can't act are hidden;
  - Move up and Move down jump the whole neighbouring group, children with them; Duplicate copies the children (new ids, a toggle's lines too);
  - the Undo bar for 5 s after each menu action, a shortcut and Delete ("Moved · Undo", NBY5); Undo restores the whole note;
  - motion: the menus open in 150 ms, moves and folds slide in 180 ms and the fold arrow turns; none with Reduce motion;
  - no ⋮⋮ drag on a phone (short side under 600); a tablet keeps it.
- **Technical calls (mine):**
  - Work's page shares `/` after a space and the card (its + and "Type / to add" line keep the sheet), and loses the drag on phones: its ⋮⋮ sheet gains Move up / Move down. Shortcuts and the line popover are the notebook's only (Work's blocks are paragraphs, and its menu has other rows).
  - The bar's ⇥ ⇤ show no Undo bar (each undoes the other; NBY3 shows none). Restart at 1 stays on every numbered line ("as today").
  - The unfiltered `/` card shows 5½ rows and scrolls; grid tiles are 64 high (58 before) so the shortcut fits in Arabic.
  - Duplicate is hidden on a voice note (it is one recording). + on an empty line of another kind (an empty to-do) adds a line below, as the rule names only an empty text line.
  - The line menu uses the frames' Arabic (new keys: «تحويل إلى», «إزاحة», «ابدأ من 1», «حذف»); the older strings elsewhere are unchanged.
  - Each field keeps its place (a global key), so it keeps the keyboard when its line changes kind.
- **Checks (cloud):** `flutter analyze` clean; `flutter test test`: 2,020 pass, 1 fails (photo_privacy H1, which fails only as root in the cloud). New: `test/features/notebook/note_writing_rules_test.dart` (76, EN and AR), 5 in `note_outline_test.dart`, 4 in `daybook_page_test.dart`; 4 older tests changed to the new rules. `test_screens/` not run; no goldens updated.
- **Next (PC):** shoot NBY1–NBY5 in EN and AR at 390×844 and compare with the frames; F108's L3 shot (the ⋮⋮ menu) is now the popover, so shoot it again. On the emulator: the keyboard stays up under the `/` card and the line menu, the click on a shortcut, the slides. Then merge `claude/r98` into `slice2-app` after the lead's review.
- **Who has which branch:** this cloud session had `claude/r98` (done, pushed). Nothing else changed.

## Cloud update: 25 Oct 2026 — review 91, the interim app icon and splash (`claude/app-icon`)

- **Branch `claude/app-icon`** (from `slice2-app` 1a3cc00): the icon (`flutter_launcher_icons` 0.14.4), the native splash (`flutter_native_splash` 2.4.8) and the 350 ms fade from the splash once start-up decides. iOS label fixed to "BuildVibes". Nothing live, no migration.
- **Addendum (25 Oct):** the cube traces itself while start-up is still running after 300 ms (at most 1.2 s, then the fade; none with Reduce motion). Frames and the emulator shots in `docs/screens/app-icon/`.
- **Checks:** analyze clean, 1,817 app tests, 378 screenshots (1 new, none changed), debug APK builds. The lead checks before any merge.
- **Next (PC):** merge `claude/app-icon` into `slice2-app`; with the founder's yes, install on the emulator and his phone; check the icon (round and squircle masks), the themed icon (Settings › Wallpaper › Themed icons) and the splash on a cold start; screenshots for the lead (review 91 §6).
- **Regenerate** after a new logo: replace `assets/brand/`, then `dart run flutter_launcher_icons` and `dart run flutter_native_splash:create` (the generator rewrites `Info.plist` indentation and the launcher-icons tool changes `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS` in `project.pbxproj`; both were kept out of the commits).
## PC update: F107, the notebook writes like Notion (review 92) — on `claude/f107`, not merged, not live
**Standing rule (review 74):** nothing but the BuildVibes build goes on the founder's phone without his yes in chat.
- **Bug hunt (done first):** `docs/reviews/f106-bugs.md` on `claude/f106` (5ccfe16): 17 bugs on build 585, 4 gone with F107, 13 fix anyway (4 found in code). The emulator was left in English, airplane mode off, the 12 test notes deleted, and the test work item NST-032 in NBKCH SITE TEAM cancelled.
- **Branch `claude/f107`** (local `f107`, worktree `BuildVibes-f107`), from `claude/f106` (so it carries F106 too): a note is a page of blocks on Work's page editor (block editing now shared in `page_block_editing.dart`); the + categories grid, the additions bar (Location, Image, File, Date, Remind me, Voice), the location sheet (typed, GPS or both), the saved slip's page, older notes opened as blocks, Put in a Space with the typed place and photos (GPS only when ticked). The 13 fix-anyway bugs are fixed with tests.
- **Migration 44** `20261105120000_notebook_blocks.sql`, **not live**. It keeps the old `save_note` call working (the new arguments have defaults), so build 585 still saves after it goes live. **Live order:** migration 44 (founder's yes), then the build.
- **New package:** `geolocator` 14.1.1 (pinned); Android `ACCESS_FINE/COARSE_LOCATION` and `SCHEDULE_EXACT_ALARM` (never asked for: reminders are exact when the phone allows it, B12); iOS `NSLocationWhenInUseUsageDescription`. A debug APK builds (not installed).
- **Checks:** analyze clean; 1,830 app tests; 2,655 SQL checks in 43 files (local); Node 20; `test_screens/` 391.
- **Shots:** `docs/screens/f107/` (NBX1–NBX4, EN and AR); F106's NBW1/3/4/5 shot again on the page, NBW2 (the kind menu) gone.
- **Not checked on a device:** GPS permission and position, exact reminders (B12), the mic's spoken label (B17), PDF picking.
- **Next (PC):** review against NBX1–NBX4; merge `claude/f107` (it includes `claude/f106`) into `slice2-app`; push migration 44 with the founder's yes; build and test on the emulator and the phone.
## PC update: F106, My notebook writes in place (review 90) — on `claude/f106`, not merged
**Standing rule (review 74):** nothing but the BuildVibes build goes on the founder's phone without his yes in chat.
- **Branch `claude/f106`** (local `f106`, worktree `BuildVibes-f106`): F106 is built from `slice2-app` f2801d8. It is app only, with **no migration**, so nothing needs to go live. Checks: analyze clean, 1,815 app tests, `test_screens/` 385.
- **What it is:**
  - the notebook's sheet is replaced by a writing slip at the end of today: kind chip, the tools row, Send, by when and Remind me chips, and a Draft on leaving;
  - photos on notes (no migration);
  - the Voice note tool records a separate voice note (decision A; differs from review 90 §7 "attach").
- **Shots:** `docs/screens/f106/` (NBW1–NBW5, EN and AR). The slice 8 and slice 10 notebook shots were shot again.
- **Next (PC):** merge `claude/f106` into `slice2-app`, build, and have the founder test F106 on the phone.

## PC update: 24 Oct 2026, end of day — every F-item passed, build 579

**Standing rule (review 74):** nothing but the BuildVibes build goes on the founder's phone without his yes in chat.

**State:**
- **Live:** migrations to `20261104120000` (43), the push function v10, public channels still on. Nothing waits to go live from today.
- **`slice2-app`:** fb7927a, with `claude/f100-broadcast`, `claude/f102` and `claude/f105` merged. Checks: analyze clean, 1,781 app tests, 2,583 SQL checks in 42 files, 15 push tests, 377 screenshots.
- **Build 579** (fb7927a) is on the founder's Xiaomi and the emulator (Omar).
- **Passed today:** F100, F101, F102, F103, F47 (reopened), F104 and F105, all on the phone.

- **24 Oct 2026, end of day** (PC): every F-item from today passed on the founder's phone and the emulator:
  - F100: live direct messages through the database broadcast, migration 40;
  - F101: the banner counts hidden messages;
  - F102: one notification per conversation, counting, with sound and vibration, and mute for 8 hours / 1 week / Always;
  - F103: Space chat live, migration 43;
  - F47 reopened: the daybook live, migration 42;
  - F104: Got it faces on the author's folded line;
  - F105: Back from a Space chat goes to its Chat tab, and from a DM to Messages.
  
  `claude/f100-broadcast`, `claude/f102` and `claude/f105` are merged into `slice2-app` (fb7927a). **Live is at `20261104120000`** (migration 43); the push function is v10. **Build 579** (fb7927a) is on both phones.

**Open, for later:**
- the old 13 Oct token (`…IYgxHw`) is still accepted by Google: an old install somewhere is still signed in as Islam;
- F105: when the Space is already on top, Back from a thread opened by a quote, banner or notification returns to the tab that was showing, not always Chat (the founder can ask for always-Chat);
- the shared rejoin helper has no unit test of its own.

**Who has which branch:**
- PC: `slice2-app` (worktree `BuildVibes-slice1`); `slice2-live-db` = main (worktree `BuildVibes-db29`).
- `claude/f100`, the diagnostic, stays unmerged. `claude/f100-broadcast`, `claude/f102` and `claude/f105` are merged and done.
- The worktrees `BuildVibes-f100`, `BuildVibes-f100b`, `BuildVibes-f102`, `BuildVibes-f105` and `BuildVibes-slice10` can be removed.

## PC update: review 89 live

**Standing rule (review 74):** nothing but the BuildVibes build goes on the founder's phone without his yes in chat.

- **24 Oct 2026, 12:03 Kuwait** (PC, founder's yes, review 89's order): live from `claude/f102` da56a31, one file per push, each with a read-only check:
  1. **migration 41** (F102 + M1): `notify` and `notify_until` no longer readable by the app, `my_space_notify` for signed-in people, the quiet time gone;
  2. **the push function, v10** (M2 `buildvibes_messages` channel, M3 count in the title);
  3. **migration 42** (F47): 10 broadcast triggers on 7 tables, `daybook_live_send` dropped;
  4. **migration 43** (F103): `messages_broadcast` and `messages_deleted_broadcast`, nobody can run `handle_chat_broadcast`, no app send policy.
  
  Live is at `20261104120000`. Build 576 (da56a31) is on the founder's phone and the emulator; both have the new Messages channel. Next: the founder's tests F102, F47, F103 (review 89 §6).

**Who has which branch:** the PC has `claude/f102` (worktree `BuildVibes-f102`, build 576 on test) and `slice2-app` (f100-broadcast merged, 384ac86). Merge `claude/f102` into `slice2-app` after F102, F47 and F103 pass.

## Update: 24 Oct 2026 — F105, Back from a chat (branch `claude/f105`, from `slice2-app` ae599f4)

- **App only, no SQL, nothing installed, not merged.** Back from a Space thread goes to that Space's Chat tab, then where the person came from; Back from a direct message goes to Messages, then where they came from. Every way in: Home's Spaces row, the Chat tab, Library Share in chat, Space search, a quote's link, the message banner, a notification, Messages, a profile's Message, New message, a Space's People.
- **Checks:** analyze clean; 1,781 app tests; `test_screens/` 377, none changed.
- **Next:** the PC merges `claude/f105` into the work branch; the founder checks it on the next build.

## PC update: 24 Oct 2026 — F104, Got it faces on the author's folded pinned line (branch `claude/f102`)

- **App only, no SQL, nothing installed.** The author of a pinned announcement (or an admin acting for an author who left) sees, on the folded slim line, the faces of who tapped Got it: up to 3, then "+2", before the ›. The ordinary card and the full note show "+N" the same way. It refreshes with the live broadcast. Others see no one else's faces.
- **Checks:** analyze clean; 1,772 app tests; `test_screens/` 377; new shots in `docs/screens/f104/` (3 and 5 Got it, EN and AR).
- **Next:** one build from `claude/f102` for the founder's F47 recheck (Omar's Got it on his announcement, on Work, without opening it).

## PC update: 24 Oct 2026 — review 89: M1, M2, M3 and F103 (same branch `claude/f102`)

**Not live, nothing deployed, nothing installed.**
- **M1 (migration 41, edited in place):** a Space's level is the person's own. `notify` and `notify_until` are no longer readable from `space_members` (the grant is a column list without them); `my_space_notify(p_space)` and `my_spaces()` give your own. The app reads it from there. An older build fails on Space info once 41 is live, so the new build goes on both phones right after.
- **M2:** a "Messages" Android channel, `buildvibes_messages`, with vibration, made in MainActivity at every start; `dm_message`, `dm_request` and `chat_message` use it, the rest stay on `buildvibes`.
- **M3:** with text on, "Omar Haddad · 3 new messages" is the title and the newest words the body.
- **F103, migration 43** (`20261104120000_chat_broadcast.sql`): each chat message and delete broadcasts ids on `thread:<id>`; the app listens for it instead of Postgres changes, with BV-LIVE lines and rejoin. Test 43, 16 checks; local end-to-end 6/6.
- **Checks:** analyze clean; 1,760 app tests; 2,583 SQL checks (local); Node 15; `test_screens/` 373; a debug APK builds (not installed).
- **Live order (each with the founder's yes, from the PC, one at a time):** 41 (with M1), the push function (M2, M3), 42, 43, then one build on the phone and the emulator. Founder's tests: review 89 section 6.

## PC update: 24 Oct 2026 — F47 reopened, the daybook kept live by the database (same branch `claude/f102`)

**Not live, nothing deployed, nothing installed.**
- **Migration 42**, `20261103120000_daybook_broadcast.sql`: statement-level triggers on `space_posts`, `work_items`, `work_item_events`, `post_point_events`, `post_acks`, `post_edits` and `post_files` send `{space_id, post_id}` on the private `daybook:<space>` (event `changed`), once per post per transaction, wrapped so they never block the action. `daybook_live_send` is dropped: the app can't send. Test 42, 34 checks; test 29 adjusted.
- **App:** the phone only listens (`DaybookLive.changed` and its call sites removed); `BV-LIVE daybook:<space> <status>` and `BV-LIVE daybook:<space> broadcast post=<id>` lines; rejoin after a close, error or timeout.
- **Checks:** analyze clean; 1,759 app tests; 2,561 SQL checks (local); Node 14; `test_screens/` 373; local end-to-end 8/8.
- **Live order for this branch (each with the founder's yes, from the PC):** migration 41, then the push function deploy, then migration 42, then one build. Founder's phone checks: F102 (locked, 3 messages, one notification counting 1, 2, 3; mute 8 hours) and F47 (Omar's tick and Got it within 5 s without leaving the Space, and the other way round).

## PC update: 24 Oct 2026 — F102, message pushes as WhatsApp and mute for a time (branch `f102`, pushed as `claude/f102`)

**Not live, nothing deployed, nothing installed.**
- **Migration 41**, `20261102120000_message_pushes.sql`: every DM and Space chat message queues a push, with that person's unread count in the conversation (counted when queued); the 5-minute quiet time and F97's follow-up end (`dm_follow_up` stays valid; old queued ones still close or send). `space_members.notify_until` and `dm_members.muted_until` (null = always; a passed time is unmuted by itself). `set_space_notifications` and `mute_dm` take an optional until and touch only your own row. Test 41, 40 checks.
- **Push function:** still notification messages drawn by Android (the lead's decision); one per conversation by tag, replaced with sound each time. Text off: "Message from Omar Haddad" · "3 new messages"; text on: "Omar Haddad" · "Pump is late · 3 new messages"; Space chat: "… in a Space chat", never its name.
- **App:** "For how long?" (8 hours / 1 week / Always) for Space info Off or Needs you only and DM Mute; long-press Mute / Unmute on Home → Spaces, My Spaces and Messages; bell-slash on muted rows, unread dot kept; opening a DM or Space chat thread cancels its notification (`cancelNotification` on `buildvibes/settings`, tag + id 0). Shots in `docs/screens/f102/`.
- **Checks:** analyze clean; 1,759 app tests; 2,527 SQL checks (local); Node 14; `test_screens/` 373.
- **Live order (each with the founder's yes, from the PC):** migration 41 (needs 40, which is live), then the push function deploy, then a build from this branch.
- **Who has which branch:** `f102` (worktree `BuildVibes-f102`), from `claude/f100-broadcast` 384ac86; not merged anywhere.

## PC update: 24 Oct 2026 — F100's broadcast fallback (branch `f100-broadcast`, pushed as `claude/f100-broadcast`)

**Why:** on build 560 the private `dm:` channel joins, but no Postgres-changes callback ever arrives for a new direct message; locally it worked. So the database broadcasts instead.

- **Migration 40**, `20261101120000_dm_broadcast.sql`, **not live**: a trigger on `dm_messages` (insert, and a message deleted) calls `realtime.send` on `dm:<thread>`, private, event `dm`, with ids only (`thread_id`, `message_id`, `author_id`, `op`). A Realtime failure never blocks the message. Receiving goes through the existing `daybook_live_receive`; nobody sends on `dm:` from the app. Test 40, 27 checks.
- **App:** `DmRepository.changes()` listens with `onBroadcast('dm')`; the Postgres-changes subscription is gone. The live banner reads the message by id (`liveText`, under RLS) for its words. Join, rejoin, BV-LIVE lines, the dedupe with the push and `dm_follow_up` unchanged.
- **Checks:** analyze clean; 1,731 app tests; 2,491 SQL checks (local); Node 11; local end-to-end 7/7 (member receives; a Space member outside the thread and an outsider refused).
- **Live order (each with the founder's yes, from the PC):** migration 40 first, then a build from this branch on the phone.
- **Who has which branch:** `f100-broadcast` (worktree `BuildVibes-f100b`), from `slice2-app` 038e8e7; not merged anywhere.

## PC update: 23 Oct 2026, 11:36 — push v9, migrations 34 and 39 live, build 547

**Standing rule (review 74):** nothing but the BuildVibes build goes on the founder's phone without his yes in chat.

**Live** (founder's yes), from `slice2-app` e1b567d, one step at a time, each with a check:
1. **the push function, v9;**
2. **migration 34**, `20261030120000_review_sign_in.sql`:
   - `projects.is_demo` and `companies.is_demo` all false;
   - `review-sign-in` NOT deployed, no secrets, no demo seed: each of those still needs its own yes, before 13 Dec;
3. **migration 39**, `20261031120000_slice10_notifications.sql`: the queue accepts `dm_follow_up`.

Live is at `20261031120000`. The 3D model views take the next date after 39. Public channels are still on.

**`slice2-app`** (e1b567d):
- migration 34 and its test, taken from `claude/store-reviewer-b5` (nothing else from that branch);
- `claude/slice10` merged in;
- analyze clean, 1,712 app tests, 2,464 SQL checks (38 files), 11 push tests.

**Build 547:** installed on the emulator. **The founder's phone wasn't reachable**: install it when he sends the new wireless-debugging address.

**Who has which branch:**
- PC: `slice2-app` (worktree `BuildVibes-slice1`), `slice10` (worktree `BuildVibes-slice10`, merged), `slice2-live-db` = main.
- `claude/slice10` and `claude/store-reviewer-b5` are done; the rest of `store-reviewer-b5` (the Edge Function, the seed) waits for its own go-live yes.


## PC update: 23 Oct 2026 — review 88 S1–S5 and F99 (branch `claude/slice10`)

- **S1:** `claim_push` closes a follow-up as `superseded` when a `dm_message` push for the same person and conversation was queued at or after its `not_before`, and counts only the messages before `not_before`. Migration 39 edited in place, **not live**; test 39 has 20 checks.
- **S2:** ticks and Got it / Received / On my way that wait for a signal are kept on the phone (`daybook_marks:<user>`), sent when the app opens, when the signal is back and on the retry; never twice at once.
- **S3:** Remind me uses Phosphor's bell (`BvIcons.remind`). **S4:** «عرض الملف الشخصي» for `dmViewProfile` and `settingsViewProfile`. **S5:** OF's send-back at 11:05.
- **F99:** the DM banner's life is in `dmBannerProvider` and shown by `DmBannerHost` in MaterialApp's builder, so no rebuild of the screens can end it. 4 s, slides away; tap opens; swipe up dismisses; same message again changes nothing; a newer message of the same conversation updates the words in place and restarts the 4 s; another conversation replaces it; never over its own conversation. `PhoneClockScope` always keeps the same shape.
- **Checks:** analyze clean; `flutter test` 1,712 pass; local stand-in 2,384 SQL checks (this branch's migrations, without 34); push Node tests 11; `test_screens/` 363 pass.
- **Next:** review 88 section 6, from the PC with the founder's yes for each live step. Founder test for F99 on the Xiaomi: the banner with the app open on Home.

**Not live, nothing deployed, nothing installed.** PC has `slice10` (worktree) tracking `claude/slice10`.

, no signal and notifications (branch `claude/slice10`, from `slice2-app` 2a26898)

**Plan:** review 87 (`docs/reviews/2026-10-23-87-slice10-plan.md`), built on its own recommendations. Seven questions wait for the lead, each with a recommendation.

**For the PC:**
- Merge `claude/slice10` into `slice2-app`.
- **New packages:** `flutter_local_notifications` 22.3.2 and `timezone` 0.11. Run `flutter pub get`.
- **Android changes:** core library desugaring in `android/app/build.gradle.kts`, plus `RECEIVE_BOOT_COMPLETED` and the two scheduled-notification receivers in the manifest. Build once to check them.
- **Migration 39** (`supabase/migrations/20261031120000_slice10_notifications.sql`) and the push function's new text are **not live**. They go live together, after 38 and 34, only with the founder's yes. Until then, a direct message inside the quiet time is still not pushed (as today).
- Re-shoot `test_screens/` with the PC's fonts. The new shots are in `docs/screens/slice10/` (18 PNGs: 9 screens in English and Arabic, 12-hour).

**Migration 39 (F97):**
- A direct message inside its conversation's 5-minute quiet time queues one `dm_follow_up` push for the quiet time's end (`not_before`).
- `claim_push` sends it only if that person's newer messages are still unread, and adds how many (`count`). If they were read in time, the push is closed and nothing is sent.
- Never two per quiet time, never with the text. Muted, blocked and hidden accounts are handled as today.
- **Activity needs no change:** migration 28's `activity_rows()` already gives a daybook post's title and `space_post_id`, while the reader may see it. Review 87's draft said otherwise and is corrected.
- Tests: `supabase/tests/39_slice10_notifications.test.sql` (17). The stand-in runs every file: **2,381 pass**.

**Push function (not deployed):**
- `dm_follow_up` reads "Message from Omar Haddad" over "2 new messages", in Arabic's four counting forms (رسالة جديدة / رسالتان جديدتان / 3 رسائل جديدة / 11 رسالة جديدة).
- It opens the conversation and replaces the earlier push (same tag).
- Daybook-post pushes now open the post at its card (`/spaces/x/items/<post>`), not just the Space.
- Node tests: 11 pass.

**App:**
- **No signal (OF `2544:35135`):**
  - "No signal. Everything you post waits and sends by itself." shows under the daybook masthead after a try fails for want of a signal (outbox, marks, notebook, page editor). It goes as soon as something gets through (`signalProvider`).
  - **Send back, Give to and an update** go through the outbox. They show on the card at once (SENT BACK, the line) with "Waiting to send", are sent when the signal is back, and a refusal says why as before.
  - **Ticks and Got it / Received / On my way** stay on the card with "Waiting to send" and are sent again a little later and when the signal is back, instead of being taken back. They are kept while the app is open, not between starts.
  - **The page editor:** with no signal, Done says "No signal. Your changes stay here. Press Done again when the signal is back." and stays open. Leaving with unsaved changes asks first ("Keep editing" / "Leave"). While editing, the sheet can't be dragged away.
  - Meeting notes are unchanged (review 86 Q2).
- **F96:** after the first tries, the push token is asked for again every 30 minutes while the app is open, on every return to the app, and when the signal comes back, until it is registered. After a day without one, Settings › Notifications says "This phone isn't getting notifications yet. Restart the phone, then open BuildVibes." Home keeps F9's line.
- **Activity:** the six kinds now show, each with the post's title: a change, a cancel, an announcement, a checklist for you, a scheduled-activity invitation, and a new file version. Each opens the post at its card.
- **Remind me:**
  - In a note's menu (calendar icon), for a note, a to-do or a checklist, not a voice note. It uses the daybook's day-and-time picker; no time means 9 am; Remove takes it off; a time already gone is refused.
  - It is saved as `remind_at` (live since migration 21).
  - This phone shows "Reminder" with the note's words at that time, even with the app closed (inexact, so no exact-alarm permission is needed). A tap opens My notebook.
  - The slip shows "Reminder · today 4:00 pm" in grey.
  - Done, deleted or removed: the reminder goes. On every start the phone sets again those still to come. Another account's reminders on a shared phone are taken off.
- **F98:** a conversation's start shows the person card above the first message: face, name, role · company, and View profile (none for a deleted account), with "The start of your conversation" under it. The Space you share stays in DM2's pill. A request shows the card with its strip.

**For the lead (review 87's questions):** when OF's strip shows; what waits with no signal (page edits stay in the editor); F97's wording; Remind me's place and words; F96's day; the frames not drawn (see the slice 10 shots); the six Activity lines.

**Checks:**
- `flutter analyze`: no issues.
- `flutter test`: **1,704 pass**; 1 fails, photo_privacy H1, which fails only when run as root in the cloud.
- New tests:
  - `test/features/slice10/`: Activity kinds, F96, F98, Remind me.
  - The no-signal tests in `daybook_loop_test`, `daybook_kinds_test` and `daybook_page_test`.
  - SQL test 39 and the push function's Node tests.

**Not live, nothing deployed, nothing installed.**

**Who has which branch:**
- Cloud: `claude/slice10` (this work), from `slice2-app` 2a26898.
- PC: `slice2-app`.

## Cloud update: 23 Oct 2026 — F100, the parts that don't wait on the diagnosis (branch `claude/f100-fix`, from `slice2-app` d9b1cad)

`claude/f100` (the PC's diagnostic branch) is untouched. No migration; nothing live, deployed or installed.

- **Rejoin, not open once:**
  - The `dm:` channels open only once sign-in is complete (gate ready and a user).
  - When the sign-in token is new (refreshed, or signed in again), every channel closes and opens again. Signed out, none stays open.
  - When the app comes back to the front, they open again.
  - A channel that closes, errors or times out opens again after 2 s, then 5 s, then 15 s, then every 30 s. A join resets the waits.
  - `AuthRepository.sessionRenewed()` is new (Supabase's `tokenRefreshed` and `signedIn`).
- **One channel per thread:** the conversation screen no longer joins `dm:<thread>` itself. A second join of the same topic closes the first, which may be part of F100. The host follows the conversation on screen too, and the screen reads again through `dmChangeProvider`.
- **The live banner:**
  - A new message from the other person arriving live, in a conversation not on screen, shows the F99 banner: "Message from Omar Haddad", over the words only if the lock-screen setting shows message text (else "New message" / «رسالة جديدة»).
  - The live update and the push for the same message show one banner, matched on `message_id`, even after the first banner has gone.
- **`dm_follow_up`** is in `dmPushKinds`: it refreshes the list, with no banner.
- **Logs:** one `BV-LIVE status dm:<thread> <status>` line per channel status change, and `BV-LIVE lost dm:<thread> …` when one is opened again later.
- **Tests:** `test/features/messages/dm_live_f100_test.dart` (9).
- **Checks:** `flutter analyze` clean; `flutter test` 1,720 pass, 1 fails (photo_privacy H1, which fails only as root in the cloud).
- **Still for the diagnosis (PC):** whether the private join is refused, and whether Postgres changes reach a private channel. If not, the broadcast trigger and its migration (F100's fix) come after.

**Who has which branch:** cloud `claude/f100-fix` (this) and `claude/slice10`; PC `slice2-app` and `claude/f100`.
## Cloud update: 23 Oct 2026 — the sweep (branch `claude/sweep`, from `slice2-app` d9b1cad)

`docs/reviews/sweep-report.md` lists every hit of a scan of `lib/` against the definition of done and the product rules, with file and line. The DM files that `claude/f100-fix` changes were not touched (no hits there).

- **Fixed, in commits by kind:**
  - Sign out's arrow now mirrors in Arabic; the card highlight uses start/end.
  - The list separator ("، " / ", ") comes from the ARB in 4 places instead of being typed per language.
  - 40 ARB keys used nowhere are removed (English and Arabic still match).
- **Clean:**
  - no Material icons, raw colours, font sizes or spacing numbers;
  - no Eastern digits;
  - no country facts outside the market pack;
  - no "late" or «متأخر» shown.
- **Needs you and checklists (slice 2 note): still true, now fixed in the list.**
  - `needs_you()` already returns `checklist_for_you`, and `my_spaces()` counts it, but the app dropped those rows.
  - Now a checklist given to you is a "To tick" / «للتأشير» row in Needs you and on Home, until every point is ticked. It opens its card.
  - No migration.
- **The lead's two decisions, applied:**
  - the Team screen's heading is "Members" / «الأعضاء», with no count (the unused string is removed);
  - a Space chat thread's unread mark is a dot, as in Messages.
  - Tests updated. `docs/screens/slice3/S7-chat`, `S7N-new-chat` (re-taken) and `T1-team` (new) are in EN and AR, shot with cloud fonts: the PC re-shoots them.
- **Checks:**
  - `flutter analyze` clean.
  - `flutter test` 1,717 pass after the lead's changes too (1 cloud-only failure, photo_privacy H1).
  - Screenshot tests: all 363 pass when shot here. No image differs from `slice2-app` shot in the same place. The committed (PC) images are left as they are.
  - SQL stand-in: 2,464 pass.
- **Not live, nothing deployed, nothing installed.**

**Who has which branch:** cloud `claude/sweep` (this), `claude/f100-fix`, `claude/slice10`; PC `slice2-app` and `claude/f100`.

## Cloud update: 23 Oct 2026 — review 86 W1 (branch `claude/slice9`)

- **No "late" in the week report (F57):** no LATE stamp and no "late by N days", in English or Arabic. A work item past its due reads "Omar Haddad · was due Tue 13 Oct" / «عمر حداد · كان موعده الثلاثاء 13 أكتوبر», grey, in the action colour only when it waits on the reader (`needs_me`). The strings `weekLateBy` and `weekStampLate` are gone.
- **Not done:** review 86 also says an open item past its due that needs nothing from the reader "goes in the open list". MR1 has no such section, so those rows stay in Needs a decision, with no stamp and grey. The lead decides if they should move or go.
- **Test:** past its due reads "was due …", never "late" (EN and AR), no stamp; grey unless it waits on me.
- **Shots:** `MR1-week-report` EN and AR re-shot. The sample now has the DONE row waiting on Islam's check (the clip), and Omar's late row grey, as the redrawn frame.
- Review 86 is copied from `main`. `flutter analyze` clean; the slice 9 tests pass (22).

**Not live, nothing deployed, nothing installed.** Branches as below.

## Cloud update: 23 Oct 2026 — review 84 N1 and N2, then slice 9 (branches `claude/slice8`, then `claude/slice9` from it)

**Review 84 (on `claude/slice8`, pushed):**
- **N1:** Home's way into My notebook is Phosphor's **notebook** glyph, not list-checks (the work item's). The empty notebook and Save to my notebook use it too.
- **N2:** a card just made from a note opens new, not as "Draft", as a card made from a message (F88). Left unsent, it is the Draft when the Space opens again.
- Tests for both; `docs/screens/slice8/` re-shot (H1 and Put in a Space). Review 84 is copied from `main`.

**Slice 9 plan:** review 85 (`docs/reviews/2026-10-23-85-slice9-plan.md`), built on its own recommendations. Six questions wait for the lead, each with a recommendation. **No migration:** `create_from_message`, `week_report` and `share_week_report` (migrations 20 and 23, live) cover it.

**For the PC:** merge `claude/slice7`, `claude/slice8`, then `claude/slice9` into `slice2-app`. No new package. Re-shoot `test_screens/` with the PC's fonts. The new shots are in `docs/screens/slice9/` (22 PNGs, 11 screens in English and Arabic, 12-hour).

**Meeting notes (R3 `2540:34503`):**
- "Turn lines into work items" on holding a Space chat text message of two lines or more, for someone who may post work. S8m's "Turn into a work item" stays.
- The screen: the thread's header and the message as R3's card. The first line is the title (the meeting's own work item, a target); every other line has a tick box. List marks ("- ", "• ", "1.") and blank lines go; a long line is cut at a word; at most 30.
- Ticking a line opens the owner picker at once (you first; a Team thread's lines only for that Team). The face shows at the line's end and a tap changes it. No answer, no tick.
- **Post N work items** sends one `create_from_message` under ids chosen when the screen opened, so trying again is the same batch. No signal: the screen stays with its ticks and owners, "No signal. Try again." (question 2).
- After posting: back in the chat, "3 work items posted" with **Open** (the meeting's card in the daybook).

**The week report (MN1 `2566:35619`, MR1 `2566:35515`):**
- "Week report" in the Space menu for every member, in MN1's order: Walk, Search, Week report, Daily report, Space info.
- The week from the market pack's first day; ‹ and ›, › off on this week. One `week_report` read per week.
- Needs a decision (title, "Omar Haddad · late by 2 days" in red, "Rakesh Nair · Photo missing", "signed as done Thu 2:10 pm", the LATE / SENT BACK / DONE stamp, the paper clip when a row needs me); Checked this week (upright proof cards: the Done photo with CHECKED, the title, the day and checker); Targets ("2 of 4 checked · by Sun 18 Oct" with the green line); Coming up (calendar leaf, time and place, or a work item's due and owner) on this week only (question 4). An empty section is left out; an empty week says "Nothing to report this week." The foot line: "Made from the daybook. Everyone sees only what they may read."
- A tap on any row opens its card in the daybook.
- **Share in chat:** the Space's threads, Everyone first; `share_week_report` with the week's first day. In the chat, the message is a card "Week report · 11 – 17 October" with Open, which opens that week with the reader's own rights. The chat now reads `report_week`.

**For the lead (review 85's questions):** where meeting notes start; no outbox for them; the frames not drawn (owner picker, thread list, the chat card, the empty week; see the slice 9 shots); Coming up on this week only; every member opens the report; the stamps.

**Checks:**
- `flutter analyze`: no issues.
- `flutter test`: **1,644 pass**; 1 fails, photo_privacy H1, which fails only when run as root in the cloud.
- New tests: `test/features/spaces/meeting_report_test.dart` (2 model tests and 9 × EN and AR), and two more for review 84 in `test/features/notebook/notebook_test.dart`.

**Not live, nothing deployed, nothing installed.**

**Who has which branch:**
- Cloud: `claude/slice9` (this work), on top of `claude/slice8` (review 84 applied), on top of `claude/slice7`.
- PC: `slice2-app`, as in the review 81 update below.

## Cloud update: 23 Oct 2026 — slice 8, My notebook and My calendar (branch `claude/slice8`, from `claude/slice7` 37e1cf2)

**Plan:** review 83 (`docs/reviews/2026-10-23-83-slice8-plan.md`), drafted like reviews 76–78 and built on its own recommendations. Six questions wait for the lead, each with a recommendation. **No migration:** everything uses migration 21 (live 16 Oct).

**For the PC:** merge `claude/slice7` first, then `claude/slice8`, into `slice2-app`. No new package. Re-shoot `test_screens/` with the PC's fonts. The new shots are in `docs/screens/slice8/` (26 PNGs, 13 screens in English and Arabic, 12-hour).

**My notebook (NB1 `2557:35384`, AR `2564:549`):**
- Opens from Home's **list-checks** icon, between Search and Messages (`/notebook`). Guests don't see it.
- **Built on v13 paper, no hour spine** (question 1): each slip's first line is its kind and time ("To-do · 8:02 am").
- Header: back, My notebook, a calendar icon (My calendar, question 3), and **Only you** (a tap says what it means).
- The masthead is today; **pinned notes** sit on the brand-soft band; today's notes oldest first, then earlier days under their day dividers.
- **Kinds:** Note (words), **To-do** (a box, the words, "by today 4:00 pm" in the action colour), **Checklist** (title and points, tick in place), **Voice** (hold the mic, as in messages; it plays with the chat's player).
- **Writing:** "Note" opens a small sheet with **one choice** of Note / Checklist / To-do (rule 6), the words, the points, and When (the daybook's due picker; a day with no time is kept at the day's start). Tap a slip to edit it.
- **The menu** (long press or ⋯, `2557:35481`): Put in a Space with the Spaces I can write work in (each with its colour chip), Pin to the top / Unpin, Edit, Delete (asks first, N7).
- **No signal:** a change shows at once with "Waiting to send", is kept on the phone per account, and goes on the next change or when the notebook opens again. `save_note` is the same note by its id. A note deleted on another phone drops its waiting edit.
- **Empty:** N2's words, "Your private working area".

**Put in a Space:**
- The Space opens writing: a note → a work item (first line the title, the rest the words; a long line is cut at a word and the whole note goes in the words); a to-do → a work item with its due; a checklist → a checklist with its points. A voice note can't be put (no words).
- A card already half-written keeps its words; the note's go under them.
- Nothing posts by itself. Once the server takes the post, the app calls `mark_note_put`, and the slip says "Went into a Space". The note stays private.

**Save to my notebook** on holding a direct message and a Space chat message: a note with its words, "Saved to your notebook". It takes the notebook glyph; list-checks is Put in a Space in that menu.

**My calendar (CAL1 `2557:35587`, AR `2564:653`):**
- From the notebook's header (`/notebook/calendar`). One `my_calendar` read per week.
- The week strip starts on the market pack's day (Sunday for Kuwait); swipe for the week before or after; a dot under a day with something; the chosen day is the orange pill.
- Rows from the chosen day to the week's end, **sorted by day, all day first** (the server sends them by time with all-day last), a divider per later day.
- Each row: the Space's colour bar (`BvProjectColors.forId`, the notebook's slate for to-dos; question 4), the time or All day, the label (Due for you, Due today, Due, Done to check, Scheduled, To-do), the title, "Space · place" or My notebook, and the paper clip when it needs me.
- A tap opens the work item, checklist or activity at its card; a to-do goes back to the notebook.
- Empty week: "Nothing planned this week". No counts (rule 3).

**Not in slice 8 (review 83):** Remind me (slice 10, with notifications), photos in notes, search, shared copies, tasks for others, Repeat, Day/Week/Month views.

**For the lead (review 83's questions):**
1. Redraw NB1 and its Arabic without the hour spine.
2. Remind me waits for slice 10.
3. My calendar opens from the notebook's header.
4. Space colours by id; to-dos slate.
5. No photos in notes for now.
6. The writer sheet has no frame: check it on `NB-write-checklist` and `NB-write-todo`.

**Checks:**
- `flutter analyze`: no issues.
- `flutter test`: **1,622 pass**; 1 fails, photo_privacy H1, which fails only when run as root in the cloud.
- New tests: `test/features/notebook/notebook_test.dart` (14 × EN and AR), `test/data/note_models_test.dart` (9).

**Not live, nothing deployed, nothing installed.**

**Who has which branch:**
- Cloud: `claude/slice8` (this work), on top of `claude/slice7`.
- PC: `slice2-app`, as in the review 81 update below.

## Cloud update: 23 Oct 2026 — review 82 S1, S2 and the Arabic version picker (branch `claude/slice7`)

On top of slice 7, as asked:
- **S1, a time never wraps:**
  - every time is one line, its part of the day beside it, everywhere: the card header, history lines, a checklist point's tick, and inside sentences;
  - `timeClock12` joins them with a no-break space, in both languages;
  - `BvTime.parts` now gives one line, so the Arabic two-line slot of review 51 F15 is gone.
  - Tests that typed "10:32 am" now type the no-break space; `bv_time_test` and `one_time_format_test` say the new rule.
  - One widget test (K1's first-card fit) uses the rebar card without its history line: an Arabic one-line time is wider in the test font. The real-font fit check in `test_screens/slice2_test.dart` still passes.
- **S2, "Hand over Space admin"** in place of "Transfer ownership", on Space info and on the hand-over screen:
  - "Hand over to {name}", "Hand over to {name}?" and the button "Hand over";
  - "Hand over Space admin first" before deleting an account;
  - the Arabic was already right.
- **The Arabic version picker** read «يحل محل V3 · M-201.pdf»: the name and the version were two separate pieces. They are now one left-to-right piece, «يحل محل M-201.pdf · V3», as on the writing card.

**Screenshots:**
- `docs/screens/review82/` (10 PNGs): history lines, a checklist's ticks, Space info, the hand-over screen and the version picker, in English and Arabic, 12-hour.
- `docs/screens/slice7/` re-shot: T3 in Arabic, and SI1's row in English.
- The PC re-shoots `test_screens/` after the merge. Older folders (slice 1–6, review 72/80) change wherever an Arabic history line shows a time, and wherever "Transfer ownership" was.

**Checks:**
- `flutter analyze`: no issues.
- `flutter test`: **1,585 pass**; 1 fails, photo_privacy H1, which fails only when run as root in the cloud.

**Not live, nothing deployed, nothing installed.**

## Cloud update: 23 Oct 2026 — slice 7, templates and the daily report (branch `claude/slice7`, from `slice2-app` 2c64cd3)

Built from review 78, with the lead's notes in review 79 §1, and R2 redrawn (EN `2607:36358`, AR `2608:727`). **No migration:** everything uses migration 20's functions (live), and migration 30's `daily_report_notes` when it is there.

**For the PC:** merge `claude/slice7` into `slice2-app`, then run `flutter pub get` (new package: `pdf` 3.13.1, pure Dart, no native code). Re-shoot `test_screens/` with the PC's fonts. The new shots are in `docs/screens/slice7/` (24 PNGs, 12 screens in English and Arabic).

**Templates (review 78 §1–3, review 79 §1):**
- **More → Template** on the writing card of a work item, a checklist or an announcement. It is hidden when the Space has none of that kind, and never shown on an edit.
- **The picker** shows the built-ins first, under no heading. The Space's own follow after a hairline, under "This Space's templates", newest first. Each row has the kind's own icon and the name; a Space's own also has a grey line with its Team or "Everyone". There is no count and no date.
- **Choosing one fills the card:**
  - the title and the words;
  - a checklist's points;
  - the page, under new ids.
- **A work item's points from a template** go with a `checklist_ref` block on its page, so they show.
- **A Team's template:**
  - it is offered only where the card has an audience (an announcement, a report), and choosing it sets the audience;
  - with a Team chosen first, only that Team's and the Everyone ones are listed;
  - a work item and a checklist go to Everyone, so they are offered only the Everyone ones.
- **"From: Concrete pour check"** is a grey line at the small size, with ✕. ✕ drops the template and keeps what was written.
- **Save as template** is in a post's long-press menu for a Lead or a Space admin, on a work item, checklist, announcement or report.
  - It asks for a name of 1–60 characters, prefilled with the title.
  - At 50 it says so, and offers "Open Templates".
- **Space info › Templates** is for a Lead or a Space admin:
  - the built-ins are listed and can't be deleted;
  - Delete asks first.

**The daily report (review 78 §4–6, R2):**
- **Daily report** is in the Space menu ⋯ for a Lead or Crew who may post. It opens the writing card as kind `report`, from the built-in Daily report:
  - the title is the day ("Thursday 15 October");
  - To: Everyone or one Team;
  - **On site** is written under, and the day's notes are offered there with "Add";
  - **Done today** fills itself from `daily_report_fill`, from midnight to now, for the chosen audience; each line has its time, a small CHECKED stamp and ✕;
  - **Problems** is written under;
  - photos come through 📎, as on any post.
- **Posting** sends `create_space_post(kind: report, p_template, p_blocks)` through the outbox. The page has headings in the writer's words, the text, and an `item_ref` per line.
- **Drafts:**
  - today's own draft opens again from the menu;
  - yesterday's is put away with a line saying so;
  - a card of another kind being written opens instead;
  - the kind chip can't turn a report into another kind.
- **The card (R2 redrawn):**
  - "· daily report" in the header, the day as the title;
  - On site, Done today and Problems as small grey labels;
  - each work item as a line with its time and CHECKED; a tap opens its card;
  - a line the reader can't see isn't in `refs`, and is left out;
  - the photos fill the width;
  - Share as PDF is the pill at the end;
  - no stamp of its own and no Sign as done.
- **Share as PDF** is made on the phone with the `pdf` package:
  - the Space's name, the day, "By Sara · 5:00 pm", the headings, the lines with "Checked 10:12 by …", and up to 8 photos;
  - each photo goes through `cleanPhotoBytes` first (F60);
  - it uses Plus Jakarta Sans and Almarai, each the other's fallback; an Arabic report is right to left;
  - no logo, no company facts, no totals;
  - it is shared through the phone's share sheet.

**Calls made here (technical):**
- The report is written on the writing card, not on a screen of its own: drafts, the outbox, refusals, To, 📎 and photos are shared with every other kind.
- `SpaceFailure.limit` is used for 54000, the 50 templates.
- Typed numbers under On site stay words. The app never adds them up (review 79 Q5).

**Checks (cloud):**
- `flutter analyze`: no issues.
- `flutter test`: **1,585 pass**; 1 fails, photo_privacy H1, which fails only when run as root in the cloud.
- `flutter test test_screens/slice7_test.dart --update-goldens`: 14 pass.
- No SQL changed.

**For the lead:**
- The template screens have no frames. Check them on the slice 7 shots (T0–T4, SI1).
- R2's CHECKED stamp is the daybook's small ink stamp, slightly tilted as on every card. The frame draws it straight.

**Not live, nothing deployed, nothing installed.**

**Who has which branch:**
- Cloud: `claude/slice7` (this work).
- PC: `slice2-app`, as in the review 81 update below.

## PC update: 22 Oct 2026 — review 81 applied in `slice2-app` (also pushed to `claude/review80`)

`slice2-app` is `claude/review80` fast-forwarded in, with review 81 (`docs/reviews/2026-10-22-81-review80-check.md` on main) on top.

**Done:**
- **R1 (migration 38, edited in place, not live):** `library_files_chain_version_uidx`, a unique index on `(chain_id, version_no)`, replaces the plain index. The numbering trigger now locks the chain's id (`pg_advisory_xact_lock`), not its first file's row, so two versions added at once wait for each other even if that row is ever removed for good; the unique index refuses anything that still slips by. Nothing retries on a unique violation: `add_library_file` doesn't catch it, and `publish_model_view`'s handler only sees one if the lock fails. 2 new checks (`plan(26)`).
- **R2:** "New version of a file" from the paper clip turns the card into a **File** post (the kind chip says File); the title and words stay. A plain new PDF on a note stays the note's file. Tests: note → paper clip → File from the phone → New version of M-201 V3 → posted as kind file with `library_file_id` set, the new file V4 superseding V3 and V3 "replaced by" it (in the fakes; the fake Library now numbers versions as the trigger does). The server's NEW VERSION and `newer` are proved by migration 38's tests.
- **R4:** «يحل محل M-201.pdf · V3» on the writing card and the stamp line (`daybookReplacesOption`, `daybookStampReplaces`).
- **R3:** the rule below; the wrong sentence is gone.
- **Screenshots:** slice 2's W-file now goes through F71's single choice and the version picker; F73 has a fixed post id, so its torn edge (seeded by the id) is the same every run.

**Rules for going live (review 81 §5):**
- **Migrations 36 and 37 are live** (22 Oct, the founder's yes).
- **Migration 38 goes live before a build from this branch is installed on any phone.** The app always sends `p_install` to `register_push_token`; the live function refuses it without 38, and the phone would get no push token.
- Order, each with the founder's yes: migration 38 → deploy the `push` function → build and install.
- **Migration 34** (`claude/store-reviewer`, after B5) is renamed to a date after 38: `20261030120000_review_sign_in.sql` (its test file keeps its name). This replaces the earlier 20261028 rule. The 3D model views come after it.

**Checks on the PC:** analyze clean; **1,544 app tests**; **2,364 SQL checks in 36 files** (`db reset --local` + `test db --local`); 9 push function tests; **305 screenshots** pass with `--update-goldens` and twice without; re-shot PNGs committed.

**Not live, nothing deployed, nothing installed.**

## Cloud update: 22 Oct 2026 — review 80 applied (branch `claude/review80`, from `slice2-app` 586e017)

The founder asked to apply review 80 (`docs/reviews/2026-10-22-80-fix-batch-build473.md` on main) in its order, with each item's full text from review 50 (F70–F95). All of it is done, one commit per group, with tests.

**For the PC:** merge `claude/review80` into `slice2-app`, then re-shoot the screenshots there with `--update-goldens` (the pinned note changed, so slice 2's K1 shots differ; this branch did not touch the older folders). The new shots are in `docs/screens/review80/` (36 PNGs, 18 screens in English and Arabic, made with the cloud's fonts; `test_screens/review80_test.dart`).

**A. What the founder tests first:**
- **F81, live direct messages:**
  - `DmLiveHost` (in the app shell) follows the inbox app-wide: the Messages list, the Home dot and the tab badge;
  - it reads again on resume and on a DM push;
  - a quiet banner shows for a DM push while the app is open, unless that conversation is on screen;
  - the push function records FCM's answer for each token on the queue row and deletes UNREGISTERED and NOT_FOUND tokens (NOT_FOUND only if another phone in the same send succeeded);
  - `register_push_token(..., p_install_id)` replaces only the same install's old token.
- **F78:** New message (Messages' +) and Home's Search people, by name, role or company; the people you share a Space with first, A–Z; blocked and hidden accounts never show.
- **F92:** each checklist point on the page has its own ⋮⋮, with Turn into and Delete (Undo).
- **F94:** server only (migration 38).
- **F83, F87, F91:**
  - every kind made from a quote keeps it and shows it, the pinned announcement and the checklist's writing card included;
  - a tap on a Space-chat quote opens that message;
  - a DM quote has no link, by design: the DM isn't in the Space.
- **F73:** "Sending · 1.5 of 4.6 MB" with a thin line while a file uploads; "Waiting to send" only with no signal.
- **F79:** a person on the People tab opens a sheet:
  - View profile and Message for everyone;
  - Pass and Remove from Space for the Space admin only;
  - for yourself, View profile only.

**B. The Library and files:**
- **F70:** the empty Library keeps its margins.
- **F71:** a file from the phone is one single choice: New file, or New version of a file (search the files in use; ✕ undoes it).
- **F72:** the paper clip is the one way to add: Camera, Photos, File from the phone, From the Library.
- **F74:** the post's header says "· file"; the kind is "File".
- **F75, F76, F80:**
  - V1, V2, V3 numbering (server);
  - NEW VERSION · V2 with REPLACES V1;
  - the older post says "Replaced by V2 · today ›" and asks nobody for Received;
  - one version is in use.
- **F77:** Share in chat puts the file in the message box, ready to send with words.

**D. The page, the writing card and announcements:**
- **F89:** a table shows its column lines (2 × 2 to start, + column up to 8).
- **F90:** inside a toggle, Enter starts a new line, and Enter on the empty last line leaves it; there's no "+ Add text".
- **F93:** one history line per edit session on the card ("You edited the page"): the same person's page-only edits within 10 minutes fold into the latest. The post page still lists every edit.
  - **Not built:** a separate "Added a work item under this one" line. The server's history has no such event yet; that needs a server change, for slice 7 or the next batch.
- **F88:** a kept card always shows "Draft", a quoted one too. A card just made from a message is still new.
- **F82, an announcement pinned until a time:**
  - after the day, "+ Time" on the writing card opens the phone's 12- or 24-hour picker;
  - ✕ takes the time away, and the pin then ends with its day, as before;
  - a time that has passed is refused before sending ("Choose a later time");
  - the pinned note comes down by itself at its time, with no reload.
- **F85:**
  - the pinned note's facts line, under the title and at the main size, reads "Until Friday 16 Oct · 2:00 pm", "Until today · 2:00 pm" (in ink) or "Until today";
  - the header ends with the time it was posted;
  - the folded line ends with "until Fri".
- **F95:** a new walk's "Where" starts at the last walk's place in this Space, on this phone.
- **Small items:**
  - Search shows "You" for your own hits; the server now says which hits are yours (`search_space`'s new column `mine`);
  - the walk's owner picker has no "now".

**C. Migration 38: `20261029120000_review80_batch.sql`. Not live.**
- What it holds:
  - F75 `library_files.chain_id` and `version_no`;
  - F94 walk order;
  - F86: `ack(got_it)` from the author is refused;
  - F81 `push_tokens.install_id`, `push_queue.answers`, `finish_push` and `release_push` with answers;
  - `search_space` with `mine`.
- Its date comes after 36 and 37; migration 34 is renamed to a date after it (review 81, above).
- Tests: `supabase/tests/38_review80_batch.test.sql` (24 checks). Test 19 is now `plan(139)`.

**Checks (cloud):**
- `flutter analyze`: no issues.
- `flutter test`: **1,539 pass**; 1 fails, photo_privacy H1, which fails only when run as root in the cloud. The push function tests pass (9).
- SQL stand-in: **2,362 checks in 36 files pass**, migration 38 included.
- `flutter test test_screens/review80_test.dart --update-goldens`: 26 pass.

**Not live, nothing deployed, nothing installed.** The order on the PC, each with the founder's yes after the lead checks:
1. migration 38 (36 and 37 are already live; 34 comes later, see the review 81 section above);
2. **then** deploy the `push` function. It writes `answers` and reads `install_id`, so it must follow migration 38.

**Rule (review 81 R3):** migration 38 goes live **before** a build from this branch is installed on any phone. The app always sends `p_install` to `register_push_token`, and the live function without that parameter refuses the call, so the phone would get no push token.

**Retest order (review 80):** F81, F78, F92, F94, F83/F87, F73, F79, then B and D.

**Who has which branch:**
- Cloud: `claude/review80` (this work; nobody else on it).
- PC: as in the 23 Oct PC update below.

## PC update: 23 Oct 2026 — review 79 applied in `slice2-app`

**Done (one commit per item group):**
- **A1–A6 (Arabic):** «{rev} · الحالية»; no › or ‹ left in any ARB value (`daybookForPersonChoose` and `daybookForYouChoose` are gone, as they matched `daybookForPerson` and `daybookForYou`; `daybookToAudience` lost its `more`); the who and To rows draw the mirrored caret icon (`BvWritingProperty.caret`); the card header's time is one line at its own width (history lines and checklist ticks keep their two-line slot); Library and file names in lists and on the file pages keep their own direction (`BvNameText`); «اقبله كفريق تنفيذ»; Reply in the Space's chat is the curved arrow.
- **P1:** `walk_saved.dart` keeps the walk in progress (name, place, each photo's file, line, owner) in the app's own storage from the moment the camera first opens. Walk mode calls `retrieveLostData` (Android) and adds the photo only when the kept walk was waiting for it. Opening the Space offers Continue / Throw away (asks first). Posting or throwing away clears it.
- **P2:** the rule was already in `planPageSave`; tests now prove an empty point is dropped at Done and never sent.
- **File page:** a refused Received says so on the file page (`DaybookMarks.send(sayHere:)`), not on the Work tab.
- **C1 (migration 36, edited in place, not live):** `turn_point_into_item(..., p_title text default null)`; 4 new checks; grants for the new signature. The app makes one call with the sheet's title and keeps the item id per point until the server has it.
- **C2 (migration 37, not live):** the Team-walk test from outside the Team; `plan(33)`.

**Checks on the PC:** analyze clean; **1,481 app tests**; **2,337 SQL checks in 35 files** (`db reset --local` + `test db --local`); **279 screenshots** with and without `--update-goldens`, re-shot PNGs committed.

**Not live, nothing deployed, nothing installed.** Pushes still wait for the founder's yes: 34 (after B5), then 36, then 37.

## PC update: 22 Oct 2026 — slices 3–6 and the bug fixes in `slice2-app`, build for the founder's test

**Standing rule (review 74):** nothing but the BuildVibes build is installed on the founder's phone without his yes in chat.

**Merged:**
- `origin/slice2-app` was still at 3565b0a, so `slice2-app` fast-forwarded to `origin/claude/pre-test` (55266de), with no conflicts. That brings:
  - the trial merge (F68b, F69, slices 3–6);
  - review 78 (the slice 7 plan);
  - the slice 3–6 bug fixes.
- Screenshots re-shot on the PC (Windows fonts) for slice 3–6, f68b and the slice 1, 2 and review 72 shots they touch, and committed.

**Checks on the PC:**
- `flutter analyze`: no issues.
- `flutter test`: **1,458 pass** (photo_privacy H1 passes here; it only fails as root in the cloud).
- `flutter test test_screens/`: 279 pass, with and without `--update-goldens`.
- `supabase db reset` + `supabase test db`: **2,329 checks in 35 files pass** (migrations to 33, plus 36 and 37).

**The build:**
- A **release** APK, not a debug one. The phone's app is signed with the upload key, and a debug build (debug key) can't be installed over it without uninstalling, which would sign the founder out and clear his drafts.
- Same code, with `--dart-define-from-file=env/dev.json`; it reads "build 473" in About.
- It is on the emulator. **The phone wasn't reachable** (wireless debugging address changed): install it once the founder sends the new address.

**The founder's test:** `docs/test/2026-10-23-founder-test-slices-3-6.md`. Steps marked ⏸ wait for migrations 36 and 37.

**Not live, nothing deployed:** migrations 34–37 stay off the live project until the lead checks them and the founder says yes. Public channels on the live project are still on.

**Still open (from the cloud's bug review):**
- a walk in progress is lost if Android kills the app;
- the file page's small issues;
- the middle-version case;
- backspace on an empty point;
- report `item_ref` lines (slice 7).

**Who has which branch:**
- PC:
  - `slice2-app` (worktree `BuildVibes-slice1`, the build on test);
  - `f60-photo-reencode` (worktree `BuildVibes-phone`, merged);
  - `store-reviewer` (worktree `BuildVibes-store`, waits for the lead);
  - `slice2-live-db` = main (worktree `BuildVibes-db29`).
- The `claude/...` branches merged here (`pre-test`, `slice7-plan`, `trial-merge`, `f68b-f69`, `slice6` and before) are done; nobody is on them.

## Cloud update: 23 Oct 2026 — bug review of slices 3–6, fixes and the founder's test list (branch `claude/pre-test`, from `claude/slice7-plan`)

The founder's "ok" (23 Oct): review slices 3–6 for bugs before his phone test, fix what is real, and write the test list. Four read-only reviews ran (one per slice); every finding was checked against the code before it was fixed.

**For the PC:** merge `claude/pre-test` instead of `claude/trial-merge`. It holds the trial merge, review 78 and these fixes. Then follow the recipe in the trial-merge section below. The founder's list is `docs/test/2026-10-23-founder-test-slices-3-6.md`.

**Fixed (with tests):**
- **Walk mode (slice 6):**
  - A refused walk was turned into one work item's Draft, losing every line and owner. Now it offers Try again or Throw away (which asks first).
  - The post bar's camera tried to prove the walk itself; it never does now.
  - Signing a walk's row made a fake extra card. Now the row shows the pending state, and so does the row's own sheet, which is read again when the daybook refreshes.
  - A link to a walk's work item read its card first, instead of 50 pages.
  - A camera error locked the shutter.
  - A waiting walk showed its photos twice.
  - Cleaned-up uploads ("not allowed") are now uploaded again once.
  - **Migration 37 (not live):** cancelling a row moves the walk to Now, and the cancelled row keeps its own CANCELLED card. 3 new checks; **2,329 SQL checks pass**.
- **People, Library, search (slice 4):**
  - "Add a new version" did nothing from Search.
  - Share in chat showed for people the server refuses.
  - A long search showed a generic error.
  - Search opened an older chat message at the newest one. The thread now reads back to it.
  - People: no setState after the tab closed.
- **Chat and direct messages (slice 3):**
  - "Put in a Space" could list nothing: it read a self-disposing provider. It also ignored a Lead or Crew whose posting was turned off. It now lists only Spaces where you may post, and the list is never empty by mistake.
  - A quote on a half-written checklist was hidden. The card now turns into a work item.
  - A post whose chat message was deleted could never be sent. It comes back without the link, with the quote kept.
  - A waiting post now shows its quote.
  - An older quote's day is the phone's local day.
  - "You" now comes first in the walk's and the page's owner pickers.
- **Pages (slice 5):**
  - A Done that went part way sent points again on retry, and the server refused the duplicates every time. The editor now reads the page again first.
  - Dismissing "This page changed" threw the edit away. Now it keeps the editor open.
  - The card under the page missed new points.
  - Deleted photos and files came back. They now leave the post (`remove_files`).
  - "/" in front of existing words erased the line.
  - Turning a point into a work item used the point's words, not the words typed in the sheet.
  - A work item under another offered a work item under it (one level only).
  - Done with no change saved a page on an older post.
  - Text too long for a point or a work item could be turned into one.
  - A FocusNode leaked.

**Checks:** `flutter analyze` clean; `flutter test` **1,457 pass, 1 fails only in the cloud** (photo_privacy H1, root); SQL stand-in 2,329 pass.

**Not fixed (small, or needs a decision), for later:**
- A walk in progress lives only on the screen: if Android kills the app while the camera is open, the walk is lost. Saving it on the phone is about half a day; worth doing before the pilot.
- File page:
  - the Received pill flickers for a moment after a tap;
  - a refusal there shows on the Work tab, not on the file page;
  - Received given on an older post of the same file can't be taken back from the newest.
- When a middle version of a Library file is deleted, the app and the server can disagree on which version is in use (rare: moderation or a deleted post).
- A phone's on-screen keyboard sends no backspace key, so "backspace on an empty point" (to remove it) may not work. The handle menu's Delete does.
- A report's work-item lines (`item_ref`) aren't drawn yet (slice 7).

**Who has which branch:** this cloud session made `claude/pre-test` (done; nobody on it).

## Cloud update: 23 Oct 2026 — slice 7 plan, review 78 (branch `claude/slice7-plan`, from `claude/trial-merge`)

The founder's "ok" (23 Oct): draft the slice 7 plan (templates and the daily report), don't build it. **Review 78** is in `docs/reviews/2026-10-23-78-slice7-plan.md`. Docs only; no code changed.

- **The server is almost ready** (migration 20, live): templates, `save_template`, `space_templates` and `daily_report_fill`. Migration 30 (not live) adds the day's notes for "On site". A small migration 38 is optional.
- **The app builds:**
  - Template in the writing card;
  - Save as template;
  - Space info › Templates;
  - Daily report from the Space menu, with "Done today" filled from the day's checked work items;
  - the report card;
  - Share as PDF, made on the phone with the `pdf` package (a new dependency).
- **Founder's decisions (23 Oct, "ok"):** Lead and Crew write the daily report; more than one a day is allowed; today's report only. Recorded at the top of review 78.
- **Next for the founder:** the PC merges `claude/trial-merge` into `slice2-app` (recipe in the trial-merge section below), builds, and the founder tests slices 3–6 on the phone.
- **For the lead:**
  - redraw R2 (`2539:34498`) without the hour spine and weather before 17 Nov (review 58);
  - answer the five questions: no template frames, who writes the report, one per day, yesterday's report, the typed "On site" numbers.

**Who has which branch:** this cloud session made `claude/slice7-plan` (done; nobody on it).

## Cloud update: 23 Oct 2026 — trial merge of slices 3–6 onto `slice2-app` (branch `claude/trial-merge`)

The founder's "ok" (23 Oct): try the merge the PC will do, with the full checks, so the PC knows what to expect. **Nothing in `slice2-app` or `main` was changed.**

**What was merged, in order, onto `origin/slice2-app` (3565b0a):**
1. `origin/claude/f68b-f69` (F68b docket, F69 You first): conflicts only in `docs/handoff.md` (both sections kept).
2. `origin/claude/slice6`, which already holds `claude/slice3-rest`, `claude/slice4` and `claude/slice5`: conflicts only in files that both sides add to:
   - `lib/l10n/app_en.arb`, `app_ar.arb`: the union of both sides' keys (no key had two different values);
   - `lib/l10n/gen/*`: not merged by hand; `flutter gen-l10n` again after the ARBs;
   - `docs/handoff.md`, `docs/progress.md`, `.gitignore`: both sides of each hunk kept.
   - No Dart file conflicted.

**Checks on the merged head (7e91d32):**
- `flutter analyze`: no issues.
- `flutter test`: **1,443 pass, 1 fails only in the cloud** (photo_privacy H1, which needs a non-root user; it passes on the PC).
- SQL stand-in: **2,326 checks pass**, 0 failing files (migrations to 33, plus 36 and 37).

**Recipe for the PC:**
1. `git fetch`, then `git checkout slice2-app`.
2. Either fast-forward to the tested result, `git merge --ff-only origin/claude/trial-merge`, or redo the two merges above in the same order with the same rules.
3. After any ARB conflict: run `flutter gen-l10n`; never edit `lib/l10n/gen/` by hand.
4. Re-shoot the goldens with Windows fonts (`flutter test --update-goldens test_screens/`). The slice 3–6 and f68b PNGs here have Linux fonts.
5. `flutter analyze`, `flutter test`, push `slice2-app`.
6. Migrations 34–37 stay off the live project until the lead checks them and the founder says yes.

**Who has which branch:** this cloud session made `claude/trial-merge` (done; nobody on it). The PC owns `slice2-app` and `main`.

## Cloud update: 22 Oct 2026 — review 50 F68b and F69 (branch `claude/f68b-f69`)

**Branch:** `claude/f68b-f69`, from `origin/f60-photo-reencode` (afcbec2, the slice 2 build on the phone, which has F68), so the next test build stays slice 2 only.

**Done:**
- **F68b, the To do docket** (Figma EN `2604:36305`, AR `2604:37123`), replacing F68's line:
  - a card 16 from the edges and 8 above what follows, radius 8, a subtle border; a 48-wide brand-soft stub with the list-checks icon in the action colour, a dashed perforation (3 on, 3 off), the caret grey and mirrored;
  - line 1: "1 work item for you" / "2 work items for you" / "12 work items for you"; AR «بند عمل واحد لك», «بندا عمل لك», «{n} بنود عمل لك» (3–10), «{n} بند عمل لك» (11+);
  - line 2, grey: the oldest title, then its due ("· by today") or "· from Sun" / «· منذ الأحد», then ", and 1 more" / «، وبند آخر», ", and {n} more" / «، و{n} بنود أخرى». The title is cut with … first so the rest shows whole; only if even the rest can't fit is the whole line cut;
  - the whole docket opens the To do sheet (review 73 A1); 0 items, no docket. The count stays my own open and sent-back items due today or earlier (F65).
- **F69, the picker:** on a new work item, checklist or scheduled activity, I'm listed once, first, as "You" / «أنت» with my face, then a hairline, then everyone else. A search shows You only when my own name matches. Choosing You reads "For you ›" / «لك ›». Give to someone else on an existing item, and the To row, are unchanged.

**Checks:** `flutter analyze` clean; `flutter test`: **1,327 pass, 1 fails only in the cloud**: photo_privacy H1 makes a file read-only with `chmod 444`, and the cloud container runs as root, which can still write it. Not touched by this branch; it passes on the PC (not root); screenshots EN and AR at 390×844 in `docs/screens/f68b/` (docket with 1, 2 and 12 items, the picker), with Linux fonts.

**For the PC:**
- Re-shoot the goldens there (Windows fonts). `F61-to-do-strip` and the A1 sheet shot now show the docket, so their PNGs change.
- Build from `claude/f68b-f69` for the founder's test: F68b (1, 2 and many items, a long title, tap opens the sheet, none when nothing is due) and F69 (You first, choose You, For you on the card, then a Space admin other than you checks it once Done).
- Then merge `claude/f68b-f69` into `slice2-app` (and `f60-photo-reencode`).
- Not done here: "a Space admin other than me sees it in Needs you to check" is the server's existing rule (only who may check); nothing changed in SQL.

**Who has which branch:** this cloud session made `claude/f68b-f69` (done; nobody on it).

## Cloud update: 22 Oct 2026, night — slice 6, walk mode and work items under one (branch `claude/slice6`, from `claude/slice5`)

The founder's "ok" (22 Oct): go with review 77's recommendations and build while he tests. **Review 77** is in `docs/reviews/2026-10-22-77-slice6-plan.md`; the lead hasn't checked it yet. The build follows its three recommendations:
1. a walk's work items fold into its card (migration 37);
2. a photo's line is typed with the keyboard's own dictation;
3. photos come from the phone's camera (`image_picker`).

**Founder's decision (22 Oct, "ok"):** a tap on a card keeps opening its menu (F16).

**Server: migration 37, `20261027120000_target_cards.sql`, not live.**
- `daybook_cards` leaves out a work item whose parent is a target (`is_target`) that the reader can see. A walk is one card.
- The card's `children`:
  - says whether it is a target;
  - carries up to 30 rows (was 10), each with its ref and `needs_me`, so the owner signs from their row.
- A work item's activity raises its parent's. The trigger never waits on a parent: `cancel_space_post` locks the parent and then its work items, so it skips a locked parent.
- `daybook_card(post)`: one card for any post the caller can see, a target's work item included.
- 26 new checks. Two older checks were changed to the new card (18: the progress object has `target`; 26: the target's work item asks its owner to sign on its row).
- **2,326 SQL checks pass** on the stand-in (migrations to 33, plus 36 and 37).
- **For the lead:** an independent check. Then the push with the founder's yes, as the only file, after 34–36.

**App:**
- **Walk mode (R1).** It starts from **"Walk mode"** in the Space ⋯ menu, for people who may post work.
  - Name the walk and its place, then for each photo: its line and who does it. The last owner is kept for the next photo.
  - Thumbnails go back to a photo; a long press takes one out.
  - Finish posts through the outbox: each photo goes up into its own work item's folder, then one `create_walk`. With no signal it waits ("Waiting to send", its rows from the phone's photos).
  - ✕ asks before throwing the photos away. At most 30 photos.
- **The walk's card (R1b), drawn on v13's card:**
  - "N photos, each one a work item", the photos, and a row per work item. Each row shows its state, its stamp, what it needs of the reader ("Sign as done", "Check") and its owner's face.
  - Then "N of M checked" with the progress line. "Show all" opens the page when there are more than 10 rows.
  - A row opens that work item's own card on a sheet, with every action (sign as done, check, send back, updates).
- **Links:** a link to a walk's work item (Needs you, Activity, a push) opens the walk's card, highlighted, and that work item's card over it.
- **Fixed on the way:** the empty first page hid a waiting post of any kind but a work item (a checklist, announcement or walk posted into an empty Space with no signal).

**Different from the frames, for the lead:**
- **The way in:** R1 draws a "Photo · Walk" switch inside the camera. The app uses the phone's own camera, which can't show it, so walk mode starts from the Space menu. The plan's question 3 is what this depends on.
- **A walk isn't kept if the app is closed mid-walk** (kept on the phone only once Finish is tapped). That comes with slice 10.
- **R1b and N5 still need redrawing** without the hour spine. Until then the card follows v13's card.

**Checks:** `flutter analyze` clean; `flutter test` **1,438 pass**, 1 fails only in the cloud (photo_privacy H1 needs a non-root user). The menu says "Walk mode" / «وضع الجولة», not "Walk the site": BuildVibes is for the whole industry (the F4 words test caught it). Screenshots EN and AR at 390×844 in `docs/screens/slice6/` (committed): the walk's card, naming the walk, a photo with its line and owner.

- Merge order: … `claude/slice5`, then `claude/slice6`.
- Migrations 36 and 37 go live only after the lead's check and the founder's yes.

**Who has which branch:** this cloud session made `claude/slice6` and `claude/slice6-plan`; done, nobody on them.

## Cloud update: 22 Oct 2026, evening — slice 5, opening a post in place (branch `claude/slice5`, from `claude/slice4`)

Built in the cloud while the founder tests slices 3 and 4 (the overlap he approved; his "ok" to going ahead, 22 Oct). It follows **review 76** (`docs/reviews/2026-10-22-76-slice5-plan.md`, drafted here, **not yet checked by the lead**). If the lead changes the plan, this branch follows the lead.

**Founder's decision (22 Oct, "ok"):** Team-only Library files are not in the pilot. A Team file comes in only through that Team's chat.

**Server: migration 36, `20261026120000_turn_point_into_item.sql`, not live.**
- `turn_point_into_item(post, point, item_id, owner, base_version)`: Turn into in one step.
  - It runs `create_work_item` with `p_parent`, then saves the page with a `child_item` in the point's place, then removes the point. The page is saved first, because `edit_space_post` refuses to remove a point that the page still shows.
  - The author only, while the item is editable. A ticked point stays.
  - Idempotent by the item id; a stale page version gives 40001.
- 25 SQL checks; **2,300 pass** on the stand-in (migrations to 33, plus 36).
- **For the lead:** an independent check. Then the push, with the founder's yes, as the only file and after 34 and 35.

**App (frames N1–N4 = W1 v13, v13b, v13c, v13d):**
- **Opening a page:**
  - A card whose page holds blocks shows **"Open the page ›"** / «افتح الصفحة ›», with no count. Everyone who sees the post can open it, Viewers included.
  - The page rises over the daybook as torn paper: who and when, the title, the facts, the words, then the blocks.
  - **Blocks shown:**
    - text and headings;
    - toggles, which open in place;
    - checklist points, ticked in place by Lead and Crew;
    - tables, which scroll sideways when wider than the page;
    - photos, full screen on a tap;
    - files, which open F1;
    - the work items under this one, with their stamps and owners' faces and "1 of 2 checked".
  - Points, photos, files and work items that no block shows yet come after the blocks, so a post written before it had a page opens full.
- **Editing (the author only):** "Edit page" sits in the card's menu (after Edit) and on the page's head.
  - Words are edited in place.
  - Each block has ⋮⋮: hold it to drag, or tap it for Turn into and Delete (with Undo).
  - "/" or + opens the block menu, filtered as you type. It offers Text, Heading, Checklist, Toggle, Table, Photo (camera), File (from the Library or the phone) and Work item under this one. The work item is made at once and its owner is told.
  - Tables: + row, + column, and a long press on a cell to delete its row or column.
  - Turn into: text to a checklist point or a work item; a point to text or a work item; a ticked point stays as it is.
- **Done** saves in the server's order:
  1. the words and new points (`edit_space_post`);
  2. the blocks at the version read (`save_blocks`);
  3. the points no block shows any more, and the points' order.
  - If the page was saved on another phone, the app asks: Use mine, or Use the newer one.
  - With no signal, the edit stays open to send again.

**Different from the plan or the frames:**
- **A tap on a card still opens its menu**, as the founder asked in F16. The page opens from "Open the page ›", and the author edits from "Edit page". daybook.md says "tap a slip to open its page". The lead and the founder decide whether a tap should open the page instead.
- **"/" and Turn into open as the app's usual sheet**, not as a popover beside the line (N3 and N4). This is the same choice as slice 2's attach sheet.
- **No page outbox:** an edit made with no signal stays open on the screen. It isn't kept if the app closes; that comes with slice 10 (no signal).
- **Moving a block into or out of a toggle isn't built.** Inside a toggle, text lines can be added and edited.
- The page's history and its action stay on the card for now.

**Checks:** `flutter analyze` clean; `flutter test` **1,425 pass**, 1 fails only in the cloud (photo_privacy H1 needs a non-root user). Screenshots EN and AR at 390×844 in `docs/screens/slice5/` (committed): the card's line, N1 and its end, N2, N3, N4.

- **Merge order:** `claude/f68b-f69`, `claude/slice3-rest`, `claude/slice4`, then `claude/slice5` (each is built on the one before).
- **Migration 36** goes live only after the lead's check and the founder's yes. Slice 5 can't be tested on a phone until it is live.
- Re-shoot the goldens on Windows.

**Who has which branch:** this cloud session made `claude/slice5` and `claude/slice5-plan`; done, nobody on them.

## Cloud update: 22 Oct 2026, later — slice 4, People and Library (branch `claude/slice4`, from `claude/slice3-rest`)

Built in the cloud while the founder tests slice 3 (the overlap he approved). **No server change:** it uses migration 32 (live) and the functions already there.

**Done (review 67 with review 69 §1):**
- **P1 People** (2542:34824):
  - the request to join is a quiet bordered card: name, role · company · "wants to join", **Decline** as grey words and **Let in** as a pill;
  - then **Leads, Crew, Viewers**, each person with a pass tag in its colour on the end side (Lead orange, Crew green, Viewer grey; `BvPassChip` gains a tone), and "admin" in the role line;
  - **Teams** as chips, then **+ New team** for the Space admin only;
  - **Invite with the code K7Q 4MD** at the bottom (from `current_invite`); a tap copies the code. Someone who may not invite sees no code row.
  - The search field, "Invite people" and the Confirm sheet are gone.
- **P2 Let in** (2542:34982): the card opens in place with Lead / Crew / Viewer as one single choice, **nothing chosen first**. The pill is grey "Choose a pass" / «اختر التصريح» until a pass is chosen, then "Let in as Crew" / «اقبله كـفريق تنفيذ». It calls `confirm_join`; the person moves into their section, scrolled into view and ringed, with a short line. No jump to the pass screen.
- **LV1 Library** (2543:34980):
  - Search files;
  - each file in use: a thumbnail (paper stacked behind it when it has older versions), the name, "Rev D · 2 older versions · today", the **NEW VERSION** stamp from `library_overview.new_for_me`, and the faces of who received it (never a count);
  - no chips, no Recent;
  - **Add a file** as a quiet last row for people who may add files. It opens the Work tab's writing card as a Document for receipt with the file chooser open.
- **LV2 A file and its versions** (2543:35101):
  - a light page: the preview (a tap opens the drawing table, F1), "Received by Omar and Islam" with faces, and the **Received** pill acting on `library_file_post` (no pill and no line without a post; none for the one who added the version);
  - the versions: the one in use with an orange dot, older ones with Open;
  - **Add a new version** (Everyone files from uploads only): it goes back to the Space and opens the writing card straight at the phone's files with "Replaces Rev D" set;
  - Used in (opens the card);
  - Share in chat and Download under ⋯.
- **A new version never goes without its post** (review 69 1b): the Add file screen and F1's "Upload a new revision" are gone. Every file now enters through a file post.
- **S Search** (2543:35148):
  - Search is the first item of the Space ⋯ menu;
  - a full screen with the field, ✕ and Cancel; it searches after 2 characters and a 300 ms pause, over `search_space`;
  - groups **Work items** (with DONE / CHECKED / CANCELLED; a checklist point under its post's title), **Files** and **Chat**, each row with its date, no count; "Nothing found for “…”";
  - a row opens the card in the daybook, the file's page, or the thread at that message (scrolled to it and ringed).
  - The stamp needs the work item's status, which `search_space` doesn't return: the app reads `work_items.status` for the hits under its own rule.
- **V1:** "Read only" shows only for a Viewer; a Crew pass with posting locked shows just the pass.

**Checks:** `flutter analyze` clean; `flutter test` **1,387 pass**, 1 fails only in the cloud (photo_privacy H1 needs a non-root user). Screenshots EN and AR at 390×844 in `docs/screens/slice4/` (P1, P1 end, P2 nothing chosen, P2 Crew, LV1, LV2, S, V1 locked Crew), Linux fonts; the folder is committed.

**For the lead** (no AR frames, so check the Arabic screenshots):
- the pass tags مسؤول / فريق تنفيذ / مُطّلع; «اقبله كـ…»; «نسخة جديدة»; «استلمت».
- **Team-only Library files can no longer be added from the Library.** The old Add file screen let you pick a Team; file posts are for Everyone in this slice. A Team file still comes from a Team's chat. Should the writing card's Team choice also put a file post's file in that Team? That would be a server change in `create_space_post`/`add_library_file`.
- P1 no longer shows "asked 2 hours ago · via Omar's code" (the frame doesn't show it). Say if admins need it back.

**For the PC:** merge order `claude/f68b-f69`, then `claude/slice3-rest`, then `claude/slice4` (it is built on slice3-rest). Re-shoot the goldens on Windows. The founder tests slice 4 after slice 3 passes.

**Who has which branch:** this cloud session made `claude/slice4`; done, nobody on it.

## Cloud update: 22 Oct 2026 — slice 3's rest (branch `claude/slice3-rest`, from `slice2-app`)

**Founder's decisions (22 Oct):**
- **All ten slices are in the pilot, production-ready; nothing moves to after it.** Written in `docs/product/mvp-plan.md` on branch `claude/all-slices-plan` (from main), with the week-by-week schedule. Merge it into main.
- **Building and testing overlap:** the cloud builds the next slice while the founder tests the current one on the PC. His test still decides when a slice is done.

**Done (review 64, items 5 and 8):**
- **DM3–DM5, Put in a Space:**
  - holding a direct message with words shows "Put in a Space" / «ضعها في مساحة»;
  - the sheet quotes it ("From Omar Haddad · 10:42") and lists only the Spaces where my pass lets me post (no Viewer Spaces); none: "You're not in a Space where you can add work yet.";
  - picking one opens that Space's Work tab writing a work item, the message quoted under the text. It never posts by itself, and it isn't marked "Draft".
  - A direct message is quoted only (`p_quote`); it never leaves its thread (no `p_source_message`).
- **S8m, Turn into a work item** in Space chat:
  - on a message with words, for someone who may post work here;
  - the Work tab opens writing, quoting it ("From Rakesh Nair · 10:15"), with `p_source_message`;
  - a Team thread's message gives its Team, and the server keeps it there too.
- **The quote:** a soft panel with the orange bar at its start, on the writing card (4 lines) and on the posted card (3 lines); kept in the draft and in the outbox until sent; sent as `p_quote` / `p_source_message` with `create_work_item`, or `create_space_post` if the kind is changed. No server change: migration 18's columns and checks.

**Checks:** `flutter analyze` clean; `flutter test` **1,365 pass**, 1 fails only in the cloud (photo_privacy H1 needs a non-root user). Screenshots EN and AR at 390×844 in `docs/screens/slice3/` (DM3 hold, DM4 Put in a Space, DM5 writing with the quote, S8m hold menu, S8m posted card; also DM1, DM2, DM6), Linux fonts. `docs/screens/slice3/` is no longer ignored, so the lead can check the Arabic built without frames.

**For the lead:** the S8m frame (2480:71824) and DM5 (2561:76753) are older than v13; the quote panel follows DM5's look inside the v13 writing card. Check the Arabic (no AR frames).

- `claude/f68b-f69` (F68b, F69): build and test first, as planned; then merge into `slice2-app`. Its screenshots in `docs/screens/f68b/` were git-ignored, so they aren't on GitHub: re-shoot them on the PC, or add `!docs/screens/f68b/` to `.gitignore` on that branch.
- `claude/slice3-rest`: merge into `slice2-app` after the founder tests it (DM4–DM5 and S8m). It overlaps `claude/f68b-f69` only in `test_screens/slice2_test.dart` and the ARB files (both add keys at the end).
- Re-shoot goldens on the PC (Windows fonts).

**Next in the cloud:** slice 4 (People and Library, review 67 with review 69 §1), on its own `claude/` branch.

**Who has which branch:** this cloud session made `claude/slice3-rest`, `claude/f68b-f69` and `claude/all-slices-plan`; all done, nobody on them.

## Last update: 21 Oct 2026, evening, PC session

**Standing rule (review 74):** nothing but the BuildVibes build is installed on the founder's phone without his yes in chat. That includes test apps, helpers and other packages.

## Last update: 21 Oct 2026, PC session

**Done on the PC:**
- **Migration 33 (send-back date) is live** (D7). The dry run listed only `20261023120000_send_back_due.sql`, and the read-only check followed: the old 3-argument `send_back` calls still work. `main` has it.
- Build 394 (F64–F67) passed the founder's test, and the F68 screenshots are approved.
- **`claude/review72-app`** (4e7b639: review 72, review 73 A1, F64–F68) merged into `slice2-app`, as its handoff's recipe says.
- **`f60-photo-reencode`** (afcbec2: review 74 H1–H3, fixtures committed, F68 merged in) merged into `slice2-app`.
  - The DM screen (slice 3) needed the new picker results, and now shows "This photo can't be opened" like Space chat.
- `slice2-app` is at 3565b0a: analyze clean, 1,354 app tests, 227 screenshot checks (re-shot on the PC), 2,275 SQL checks.
- **Build 402**, from `f60-photo-reencode` (afcbec2, slice 2 only), is on the founder's phone and the emulator. The phone's logcat was cleared for the timing test.
- Terms and quick guide: the Help path is Settings → About BuildVibes and legal → Help and feedback (on `main`).
- **`claude/store-reviewer`** (da98999): review 73 B1–B4, with migration 34 `20261024120000_review_sign_in.sql` (not live), 2,336 SQL checks, 1,326 app tests and 7 Deno tests. It waits for the lead's review. Going live needs the founder's yes, before 13 Dec. 3D is migration 35.
- `model-views-3d-notes` (review 70, the 3D notes): pushed, not merged, for the lead.

**Next:**
1. **The founder's photo check on build 402:** 1 camera photo, 3 gallery photos and 1 full-size photo through Files. Are they upright, sharp and normal in colour?
   - Then read `adb logcat | findstr BV-PHOTO` for the timings, and check the stored files with no "Xiaomi", model or location.
   - If any camera or gallery photo takes more than 2 s, switch to the phone's own JPEG encoder (review 74 H3).
2. After that: the rest of slice 3 (DM4–DM5 Put in a Space, S8m Turn into a work item), then slice 4. Not before the founder says so.
3. For the lead:
   - F65's exact "owner = me" needs `owner_id` in `my_calendar` (a later migration);
   - the old fixture `test/fixtures/xiaomi_exif.jpg` stays in `claude/review72-app`'s history (no force push without the founder's yes).
4. Public channels on the live project are still on, until the founder says to turn them off.

**On the PC, not in git:**
- `BuildVibes-slice1` has a stash, "PC agent partial F54-F58, 20 Oct", superseded. Drop it once slice 2 is passed.
- The local database has migration 34 (from `store-reviewer`); `supabase db reset` on `slice2-app` puts it back to 33.

**Who has which branch:**
- PC:
  - `slice2-app` (worktree `BuildVibes-slice1`);
  - `f60-photo-reencode` (worktree `BuildVibes-phone`, the build on the phone);
  - `store-reviewer` (worktree `BuildVibes-store`);
  - `slice2-live-db` = main (worktree `BuildVibes-db29`).
- `claude/review72-app` and `claude/review72-db` are merged and done.
- Nobody is on `claude/store-reviewer` until the lead reviews it.
