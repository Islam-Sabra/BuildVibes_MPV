# Handoff

Where the work stopped, for whichever place picks it up next: the founder's PC, a cloud session, or the lead's chat in the Claude project. Each session rewrites this file before it stops. The full history stays in `progress.md`.

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
- `flutter test`: the full run is being counted; see the next commit.

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
