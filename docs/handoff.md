# Handoff

Where the work stopped, for whichever place picks it up next: the founder's PC, a cloud session, or the lead's chat in the Claude project. Each session rewrites this file before it stops. The full history stays in `progress.md`.

## Cloud update: 29 Oct 2026 — 105C part A (places, before / after) on `claude/r105c-a`; shots still to make on the PC

**Standing rule (review 74):** nothing but the BuildVibes build goes on the founder's phone without his yes in chat.

**After any Flutter upgrade, run the Daybook tests and test_screens before anything else. The Daybook paints its rows with custom render classes (review 101).**

- **Branch:** `claude/r105c-a`, this cloud session's, from `origin/slice2-app` 7714156, pushed. Nothing merged, no database push, no deploy, nothing installed, no test_screens, no goldens.
- **Kept out of C-B's ground:** the page editor and blocks untouched. In `lib/features/spaces/` two small changes, for "Search finds places": `space_search_screen.dart` (a Places group; a tap sets Work's place filter and goes back) and `space_screen.dart` (back from Search with a place, it shows Work). C-A's `daybook_writing.dart` and the card's tag and photo area are changed as the brief gives them to C-A.
- **Commits:** d02af7a places (picker, tags, filter, Search in the app); 7c148a8 before / after; c706d57 migration 53; 30ebce3 the older writing tests.
- **The Place picker (SP2):** the Place row opens `BvPlacePicker`, built like Give to's (`BvGiveToSpec`; its search is now the shared `BvPickerSearch`):
  - a search (no case and no spaces, as the server's unique name), the Space's places A to Z, the chosen one checked;
  - "Add place “…”" for who may post work (`SpaceDetail.mayPostWork`), when no place has that name; a taken name says "This Space has that place already.";
  - a Lead's long press: Rename (a field dialog, `showBvFieldDialog`) or Delete (asked first);
  - places come from `space_places` (`spacePlacesProvider`); a pick is `DaybookPostDraft.placeId`, and the post goes with it: the outbox calls `set_post_place` after `create_work_item` / `create_space_post` (`PendingItem.placeId`), and an edit's Save calls it when the place changed. A chosen place isn't sent again as `place_text`.
- **Site tags (SP1, SP7):** a post with a place shows `BvSiteTag` (sand `surfaceSiteTag`, a pin, the name) under its title (work items, notes, checklists, activities). An older post keeps its typed place as a fact line. The proof photo's place label uses the tag's name.
- **Work for one place:** a tap on a tag sets `workPlaceFilterProvider`; the chip (`BvFilterChip`, the place's name and ✕) sits under the Work · Chat switch, above the masthead. Every page is read for it (as Needs you does), and it combines with Needs you. ✕ shows everything. It clears when the Space is left.
- **Search finds places:** migration **53, `20261114120000_place_filter.sql`**: `search_space` (same signature and grants, security definer, `search_path = ''`) also returns places whose name matches (kind `place`), members only, places first so newer posts never crowd them out. Work's filter itself needs no server change (cards carry `place_id`). pgTAP `53_place_filter` (17): a Lead and Crew find a place by part of its name with its id; one letter and another Space's place find nothing; posts as before; **a non-member finds nothing and can't read, add, rename or delete a place, nor set a post's place**. **Not live.**
- **Before / after (SP7):** a work item with a cover photo and a Sign as done photo shows both side by side (`BvSlipBeforeAfter`, 150 high, 8 apart), "Before · 08:10" and "After · 10:56" on dark labels, and the proof's stamp (CHECKED) low on After. Before comes first in the reading order, so in Arabic After is at the left. With one photo the card is as before.
- **Tests (EN and AR):** `test/features/work/places_test.dart` (12 × 2), `before_after_test.dart` (4 × 2); E3, F29, SP2's Place row and F24 moved to the picker.
- **Checks (cloud):** see the numbers at the end of this section.
- **For the PC:**
  - migration 53 with the founder's yes, after the lead's check;
  - shots: every Work shot with a typed place (the fact line stays for older posts), SP2's Place picker, a tag and the filter chip, and before / after (SP7), EN and AR;
  - the merge with C-B (`claude/r105c-b`): both touch `app_en.arb` / `app_ar.arb` and maybe `daybook_tab.dart`.
- **Who has which branch:** this cloud session had `claude/r105c-a` (pushed). C-B: `claude/r105c-b`. PC: `slice2-app`.

## PC update: 29 Oct 2026, 17:20 Kuwait — reviews 106 (T4/T5) and 105B live: merged into `slice2-app`, migrations 51 and 52 live, build 800 on the founder's phone

**Standing rule (review 74):** nothing but the BuildVibes build goes on the founder's phone without his yes in chat.

**After any Flutter upgrade, run the Daybook tests and test_screens before anything else. The Daybook paints its rows with custom render classes (review 101).**

- **The founder's yes (29 Oct), after the lead accepted K1–K6 (review 106) and L1–L11 (review 105):**
  1. **`claude/r106b`** (5917c50, pushed), after `supabase db reset --local`:
     - `test_screens`, not updating: 444 pass, 10 differ. These were exactly BH2, BH4, BH5, NB-put-in-space and NS1, in EN and AR, the accepted ones.
     - **NS6 is new** (`test_screens/r106_test.dart`): an entry changed at 9:20 after its Space shares, with the dot on the Space icon. Its card shows "Older version · changed at 9:20 am" on each share, then Share again. EN and AR.
     - Goldens updated for those six shots only (one `--plain-name` run each). `docs/reviews/shots-106b/` removed.
     - Checks: `test_screens` 456 pass; `supabase test db` 3,088 in 50 files; analyze clean; `flutter test` 2,700.
  2. **Merged into `slice2-app`** with `--no-ff` (16a324f), with no conflicts, and pushed. The same checks pass again: analyze clean, 2,700, 456 and 3,088.
  3. **`r105b`:** `origin/slice2-app` merged in (ca2e357, pushed).
     - **Conflicts, both sides kept:**
       - `app_en.arb` and `app_ar.arb`: 105B's nine strings and 106 K5's `notebookOlderVersionOn`. The generated `lib/l10n/gen` was made again with `flutter gen-l10n`.
       - `handoff.md` and `progress.md`: both branches' entries.
     - The 10 accepted 105B shots (W1–W4 and C1, in EN and AR) became goldens in `docs/screens/r105b/`. `docs/reviews/shots-105b/` removed.
     - After `supabase db reset --local`: `test_screens`, not updating, 466 pass; `supabase test db` 3,185 in 51 files; analyze clean; `flutter test` 2,744.
     - **Merged into `slice2-app`** with `--no-ff` (b76fd93), with no conflicts, and pushed. The same checks pass again: analyze clean, 2,744, 466 and 3,185.
  4. **Migrations live, one per push,** from a throwaway worktree with `supabase/.temp` copied whole (`cp -r`). The full output was kept in a log.
     - At 16a324f, the dry run listed only `20261112120000_note_share_versions.sql`. The push exited 0, and `supabase migration list --linked` showed 20261112120000 live.
     - At b76fd93, the dry run listed only `20261113120000_space_work_extras.sql`. The push exited 0, and the list then ended at 20261113120000, with nothing pending.
     - Each push was followed by the known pg-delta certificate warning, which is harmless. The push worktree is removed. **No function deploys.**
  5. **Build 800** (b76fd93, release, upload key, prod env; versionCode 800, versionName 0.9.0):
     - Certificate SHA-256 9d02b7db…df9f, the same as 775.
     - On the Desktop as `BuildVibes-800.apk` (MD5 f05d10ba…a9b).
     - `android/app/google-services.json` was missing from `BuildVibes-slice1`, so the first try failed (`processReleaseGoogleServices`). It and `env/prod.json` were copied from the main repo for the build and deleted after. Both are git-ignored.
  6. **Installed on the founder's Xiaomi** over 775, at 192.168.8.33:43045 (model 22120RN86G checked first):
     - versionCode 800; first install still 17 Oct.
     - The installed `base.apk` is byte-identical to `BuildVibes-800.apk`.
     - BuildVibes is the only package of ours on it.
- **Next:**
  - the founder's test of build 800:
    - the notebook: a held entry's icons, the dot and Share again;
    - a Space's Work: my pins and "+n more", Archive with Undo and Unarchive, Share to a thread and its card in Chat, Leave and Remove refused while open work isn't handed over, and Send back to someone who has left;
  - 105C (the Place picker and filter, the table of tasks, before/after, the removal sheet);
  - the tidy lists in reviews 105 and 106.
- **Who has which branch:** PC has `slice2-app` (worktree `BuildVibes-slice1`). `claude/r106b` (worktree `BuildVibes-r106b`) and `r105b` (worktree `BuildVibes-r105b`) are merged and can be removed.

## PC update: 29 Oct 2026 — review 105B L1–L11 (the lead's check) on `r105b`; stopped for the lead

**Standing rule (review 74):** nothing but the BuildVibes build goes on the founder's phone without his yes in chat.

- **Branch:** `r105b` (worktree `BuildVibes-r105b`), pushed.
  - Nothing merged, no database push, no build, no golden updated.
  - `lib/features/notebook/` untouched.
- **The founder chose A:** Done-but-not-Checked items stay with the person who did them. Only Open items are handed over. L2 covers a later Send back.
- **Migration 52 (`20261113120000_space_work_extras.sql`), edited in place, since it isn't live.** pgTAP `52_space_work_extras` has 97 checks.
  - **L1:**
    - `leave_space` and `remove_member` refuse with **`BV001`** while the person owns Open work.
    - The handover functions raise `BV001` too when an Open item has no new owner. A wrong owner, or an item that isn't theirs and Open, is `22023`.
    - The app's Leave and Remove now call `leave_space_with_handover` and `remove_member_with_handover`, with no assignments until 105C's sheet. `BV001` reads "Give your open work to someone else first." For Remove: "Couldn't remove: their open work isn't handed over yet."
    - `09_chat_library.test.sql` now removes Rakesh through the handover.
  - **L2:** `send_back` takes `p_owner`.
    - If the owner may no longer sign the item, a new owner is required (else `22023`), and the call records a `reassigned` event.
    - If the owner may still sign it, a different `p_owner` is refused: that is Give to.
    - The app asks Give to first in that case (`PendingItem.handTo`).
  - **L3:** `set_post_place(post, place)`: the post's author, its owner or a Lead; the place must be in the post's Space; null clears it. The new checks: Crew and outsiders can't rename or delete a place, and outsiders and Viewers can't set one.
  - **L4:**
    - Both handover functions lock the Space row first.
    - A trigger on `work_items` (`work_items_owner_check`, before insert or owner change) takes the Space row `for share`, then checks again that the owner may sign it. This covers `create_work_item`, Give to and Send back.
  - **L5:** `share_post_to_thread` catches `23505` and returns the existing message. The app makes each message id once per thread chosen.
  - **L6:** `space_time_zone` reads only the project's market, else null. The app works out the Space's midnight on Post, reading the Space's details then (`spaceDayEndOf`).
  - **L7:** `space_post_json` carries `archived_at` (and `place_id`).
    - An archived item opened from Search opens by itself; before, it said "This was removed". A Lead's ⋯ has Unarchive.
    - Archive shows "Archived · Undo".
  - **L8:** `shared_post_gone(post)` is true only for a reader of a thread with that card, and only when the post was deleted.
    - The card shows OPEN too.
    - "You can't see this item" or "This post isn't in Work any more"; no signal is the usual error with Try again.
  - **L9:** at most 3 of my pins, then "+n more" opens the rest on a sheet. Unpin is in the hold bar when a held post is pinned by me.
  - **L10:** Share of several keeps going and names the ones that failed, with Try again (same ids). `daybook_month` leaves archived posts out.
  - **L11:** `test_screens/r105b_test.dart`, with W1–W4 and C1 in EN and AR. The images are in `docs/reviews/shots-105b/`, as described in its README.
- **Checks (PC):**
  - `supabase db reset --local`, then `supabase test db`: 3,155 checks in 50 files pass.
  - `flutter analyze`: no issues.
  - `flutter test`: 2,696 pass.
  - `flutter test test_screens`, not updating: 454 pass, 0 changed; 10 fail, the new shots with no golden.
- **For the lead:**
  - With L4's trigger, a Give to of an item away from someone who is leaving at that moment can deadlock: Postgres stops one of the two (`40P01`) and nothing is half-done. It is rare.
  - The concurrent case of L5 (`23505`) can't be run in pgTAP's single session; the retry case is covered.
- **The local stack** has this branch's migrations (52 in, no 51). `claude/r106b` needs `supabase db reset --local` before its SQL checks.
- **Next:**
  - the lead's check;
  - with the founder's yes: migration 52 live (after 51 if 106b goes first), the goldens, the merge and a build.
- **Who has which branch:** PC has `r105b` (worktree `BuildVibes-r105b`), `claude/r106b` (worktree `BuildVibes-r106b`, for the lead) and `slice2-app` (worktree `BuildVibes-slice1`).

## PC update: 29 Oct 2026 — review 105B on `r105b`; stopped for the lead

**Standing rule (review 74):** nothing but the BuildVibes build goes on the founder's phone without his yes in chat.

- **Branch:** `r105b` (worktree `BuildVibes-r105b`), from `slice2-app` 609622d (105A in it), pushed.
  - Nothing merged, no database push, no build.
  - `lib/features/notebook/` untouched (`claude/r106b` has it).
- **Server first, test first: migration 52, `20261113120000_space_work_extras.sql`,** with pgTAP `52_space_work_extras` (71 checks). Every function is security definer with `search_path = ''`, and every permission is checked in SQL.
  1. **Places:** `space_places` (name unique in its Space whatever its case and spaces).
     - RLS: members read; those who may post work add (`can(space, 'create_items')`); Leads rename (the name only) and delete.
     - `space_posts.place_id`, kept to the post's own Space by a trigger. Older posts keep `place_text`.
  2. **Archive:** `space_posts.archived_at` and `archived_by`.
     - `archive_space_post` and `unarchive_space_post`: a Lead of the Space, a Checked work item.
     - `daybook_cards` and `daybook_extras` leave archived posts out; `daybook_card` and `search_space` still find them.
  3. **Personal pins:** `space_post_pins` (mine only: read own, for posts I can see; written only by `pin_space_post` and `unpin_space_post`).
     - `daybook_cards` gains `pinned_by_me`; `daybook_extras` lists mine (reason `mine`).
  4. **Share to a chat thread:** `share_post_to_thread(id, post, thread)`, a message of the new kind `post` (`messages.post_id`).
     - The post and the thread are in the same Space.
     - The caller may read the post (`can_see_space_post`) and write in the thread (`can_use_thread`).
     - A Team's post goes only into that Team's thread, since its card shows the title.
     - A retry with the same id posts once.
  5. **The Space's time zone. Where the market pack keeps it:** `markets.time_zone` (IANA names, `Asia/Kuwait` and `Africa/Cairo`, from migration 13, `20261013150000_market_pack.sql`).
     - A Space has no market of its own, so `space_time_zone(space)` reads its **project's market**, else its **maker's home market** (`profiles.home_market_id`), else `UTC`, for members only.
     - The app reads it with the Space through a computed column, `time_zone(spaces)`.
  6. **Handover:** `remove_member_with_handover(space, member, assignments)` (admin) and `leave_space_with_handover(space, assignments)`, with `assignments` as `[{"item", "owner"}]`.
     - Every **open** work item the person owns needs a new owner who may own work: `may_be_post_person` (Lead or Crew, of its Team or an admin) and `member_can(…, 'mark_done')`, as `reassign_work_item` checks. Otherwise nothing changes.
     - Each handover is a `reassigned` event in the item's record.
     - **Their Done and Checked work stays** where it is: only Open items move, as with Give to. Tell me if Done items should move too.
- **The app, test first in EN and AR** (`test/features/work/work_extras_test.dart`, 16 tests):
  - **Pin (mine):** the swipe pins it, and then reads Unpin. My pinned posts show under the Space's pinned announcements as slim lines (`BvPinnedLine`, `my-pin-<id>`). A tap opens the item as from its card; a hold selects it.
  - **Archive:** a Lead's, on a Checked item. It leaves Work with "Archived".
  - **Share:** in the hold bar, a sheet of this Space's threads, only the Team's for a Team's post. The card goes there with "Shared in {thread}".
  - **In Chat:** `SharedPostBubble` shows the kind, the title, For and the status, and a tap opens the item in Work (`spaceCard`). A post the reader can't see reads "This post isn't in Work any more".
  - **A new announcement is pinned until midnight in the Space's time zone** (`spaceDayEnd`, with the `timezone` package). With none known, it's the phone's midnight.
  - `WorkLater` is on through the repository. `share` now takes the Space's id; 105A's test stub is updated to match.
- **105C, not now:** the Place picker and filter, the table of tasks, before/after, the removal sheet (the app side of handover).
- **Checks (PC):**
  - `supabase test db`: 3,129 checks in 50 files pass.
  - `flutter analyze`: no issues.
  - `flutter test`: 2,668 pass.
  - `flutter test test_screens`, not updating: 454 pass, **0 change**. `docs/reviews/shots-105b/README.md` says why, and lists the new screens that have no shot yet.
- **The local stack** was reset to this branch's migrations (`supabase db reset --local`), so migration 52 is applied there.
  - That took off `claude/r106b`'s migration 51, which isn't on this branch. That branch's worktree needs `supabase db reset --local` again before its own SQL checks.
- **Next:**
  - the lead's check;
  - with the founder's yes: migration 52 live (after 51 if 106b goes first; the two don't touch each other), the merge and a build.
- **Who has which branch:** PC has `r105b` (worktree `BuildVibes-r105b`), `claude/r106b` (worktree `BuildVibes-r106b`, for the lead) and `slice2-app` (worktree `BuildVibes-slice1`).

## Cloud update: 29 Oct 2026 — the lead's check of `claude/r106b`: K1–K6 done; shots compared

**Standing rule (review 74):** nothing but the BuildVibes build goes on the founder's phone without his yes in chat.

- **Branch:** `claude/r106b`, this cloud session's, pushed. Nothing merged, no database push, no deploy, no build, nothing installed, **no goldens updated**. Migration 51 edited in place (it isn't live).
- **K1, one truth on the server:**
  - `note_shares.content_key`, set by a before-insert trigger from the entry's key as the share is made (worked out at once, so a share made in the same transaction as an edit keeps the edited key); existing shares get their entry's key.
  - **A share is older exactly when its key isn't the entry's.** No clocks. `content_changed_at` stays only for "changed at {time}".
  - The phone's rule (`_contentChanged` and its stamps on save and Delete lines) is gone. The app reads `content_key` (`Note.contentKey`, `NoteShare.contentKey`, `NoteShare.olderThan`). After a save or Delete lines has gone, the entry is read again (`NotebookRepository.note(id)`), so the dot comes or goes with it; a share already reads the notebook again.
  - pgTAP 51: a share right after an edit isn't older; an edit after it is; editing back to the shared words isn't.
- **K2:** every field of `note_content_key` is coalesced inside `concat_ws` (test: words "[]" and an empty page are different keys); the header comment says a later migration that writes `notes` or `note_files` and then alters `notes` must `set constraints all immediate` first.
- **K3:** the selection ends only when the action is done: a cancelled time picker, a closed share card or preview, no signal or an error keep the entry held (`shareEntry(onShared:)` runs only when something went; `_remind` says whether it set one).
- **K4:** Share again ends every share card.
- **K5:** "changed at" names the day when it isn't today: "Older version · changed yesterday at 10:12 am" / a short date (`notebookOlderVersionOn`; AR «نسخة أقدم · تغيّرت {day} {time}»).
- **K6, the answer: a voice recording counts.** A recording is a `note_files` row (kind `voice`), and its path is in the key; on a page, a voice block also carries its `path` in `blocks`, which is in the key too. A new recording changes the key; the same file sent again doesn't. pgTAP 51 checks it.
- **Checks (cloud):**
  - SQL: no Supabase CLI in the cloud, so `supabase test db` ran as the stand-in (`service postgresql start; bash supabase/dev/standin/run.sh .`, the same pgTAP files on Postgres): **3,088 checks in 51 files, 0 failing** (file 51: 30).
  - `flutter analyze`: no issues.
  - `flutter test`: **2,699 pass, 1 fails**: `test/core/photo_privacy_test.dart` H1, root-only in the cloud (passes on the PC).
  - `flutter test test_screens`, **not updating**: 2 pass, 452 fail against the PC goldens. All of it is the cloud's text rendering (0.3–29%, median 3%; the base commit the same). So the pairs in **`docs/reviews/shots-106b/`** compare cloud with cloud: `609622d` (old) and this branch (new). **10 images differ (5 shots, EN and AR): BH2, BH4, BH5 and NB-put-in-space (T4, as expected) and NS1-status-card (K4's Share again).** BH3 is unchanged; no shot has an older share. The README has the table. Goldens are to be made on the PC once the lead accepts them.
- **Who has which branch:** this cloud session had `claude/r106b` (pushed). PC: `slice2-app`. Cursor has 105B (`lib/features/spaces/`, `lib/features/work/`, migration 20261113120000).

## PC update: 29 Oct 2026 — review 106 T4 and T5 on `claude/r106b`; stopped for the lead

**Standing rule (review 74):** nothing but the BuildVibes build goes on the founder's phone without his yes in chat.

- **Branch:** `claude/r106b` (worktree `BuildVibes-r106b`), from `slice2-app` 609622d, pushed.
  - Nothing merged, no database push, no deploy, nothing installed. No `test_screens` run, no goldens.
  - `lib/features/spaces/` and `lib/features/work/` untouched.
- **The version check before T5 (asked first):**
  - `note_shares` keeps no version.
  - `notes.version` moves on every `save_note`, and only there and in `delete_lines`. Pin, fold, move and arrange don't move it, and neither does the old to-do's done (`set_note_done`).
  - But the app ticks a checklist point or a page's to-do by saving the entry (`tick`, `tickBlock`), and a reminder is set the same way. So **ticks and reminders do move `version`**, and it can't tell a content change.
  - Photos and files are in `note_files`, which `set_note_files` deletes and inserts again on every save that sends them.
- **The choice (the smallest change): migration 51, `20261112120000_note_share_versions.sql`.** No share function and no `note_shares` column change. It adds:
  - `notes.content_key`: md5 of the kind, the title, an older note's words, the lines and checklist points without their `done` and `folded` marks, and the files' paths;
  - `notes.content_changed_at`: when that key last changed.
  - Two **deferred** constraint triggers, on `notes` (kind, title, body, blocks, points) and on `note_files` (insert, delete), work the key out again when the change is made for good. The change time moves only when the key did, so the delete-and-insert of the same files doesn't count.
  - Existing entries get their key and no change time, so old shares don't read as older.
  - **A share is older** when its `created_at` is before `content_changed_at`.
  - Read like the rest of a note (the owner only); nobody writes it (`notes` has no write grants).
  - pgTAP `51_note_share_versions` (21 checks): ticks, pins, folds, a move and a reminder don't count; a line, the title and a photo do; the same files sent again don't; someone else can't read or change it; even the owner can't write it.
  - **Applied to the local stack only. Not live.**
  - **Note for later migrations:** a migration that writes `notes` and then alters the table in the same transaction must `set constraints all immediate` first. Test 47, which does that to rebuild an older table, now does.
- **The app:**
  - c16019a: `Note.contentChangedAt`.
    - This phone stamps it when a save changes the content (the same rule, `_contentChanged`) and on Delete lines, so the dot shows before the server is read again.
    - Ticks, pins and reminders don't stamp it.
  - 49b700e **T4:**
    - One entry held: its status row shows all five (no reminder on a voice note). Used ones are filled, unused ones outlined (the card fill with a line ring), and "Tap to do it" («اضغط للتنفيذ») sits at its start.
    - A tap does it: Pin pins or unpins; Reminder opens the picker; Feed opens its preview; Space and Message open their step (`shareEntry(start:)`).
    - Then the selection ends.
    - Screen readers: an unused icon is its action ("Share to a Space"); a used one is its status and its action ("Shared to KCT Tower at 8:45 am. Share again").
    - The bar: one held, Move to… · Duplicate · Delete; two or more, Pin · Move to… · Duplicate · Delete, where Pin pins them all (or unpins when all are pinned). No icon rows then.
    - Selected lines keep their bar, Share included.
  - 49b700e **T5:**
    - A share kind whose last share is older than the entry has a 9 accent dot with a ring at its top end, each kind its own.
    - Its card marks each older share "Older version · changed at {time}" («نسخة أقدم · تغيّرت {time}») and ends with **Share again**, which opens the same step. The old share stays in the log.
  - ba63402: the share tests go through the held entry's icons, replacing the bar's Share. In the H2 test, with no signal a share says so and nothing goes.
  - The shot scenarios BH4, BH5 and NB-put-in-space go through the icons too. **BH4-share now draws the held entry with its icons (NS5)**, as the bar's Share card is gone for an entry.
- **Checks (PC):**
  - `flutter analyze`: no issues.
  - `flutter test`: 2,686 pass.
  - SQL: `supabase test db` on the local stack: 3,058 + 21 = 3,079 checks in 50 files pass.
    - The cloud's stand-in (`service postgresql start; bash supabase/dev/standin/run.sh .`) needs Linux; this session ran on the PC.
- **Next:**
  - the lead's check;
  - `test_screens` on the PC. Expected: every notebook shot with a held entry (BH2, BH3, BH4), BH5, NB-put-in-space, and any shot with an older share;
  - then migration 51 live, the merge and a build, with the founder's yes.
- **Who has which branch:** this session had `claude/r106b` (pushed). PC: `slice2-app`. Cursor has 105B (`lib/features/spaces/`, `lib/features/work/`, migration 20261113120000).

## PC update: 29 Oct 2026 — review 105A live: merged into `slice2-app`, build 775 on the founder's phone

**Standing rule (review 74):** nothing but the BuildVibes build goes on the founder's phone without his yes in chat.

**After any Flutter upgrade, run the Daybook tests and test_screens before anything else. The Daybook paints its rows with custom render classes (review 101).**

- **The founder's yes (29 Oct), after the lead accepted J1–J4 and all 123 changed shots (review 105, "J1–J4 done"):**
  1. **Goldens updated only for the 123 accepted shots** (246 images, EN and AR).
     - Each golden is the accepted `-new` image from `docs/reviews/shots-105a/`, copied over it. `test_screens` then confirmed, without updating, that the branch draws every one of them the same.
     - `docs/reviews/shots-105a/` removed.
     - No shot renamed: the lead's last check asked for none.
  2. **Checks on `claude/r105a` (20ca1b3, pushed):**
     - `flutter test test_screens`, not updating: 454 pass.
     - `flutter analyze`: no issues.
     - `flutter test`: 2,652 pass.
     - `supabase test db`: 3,058 checks in 49 files pass.
  3. **Merged into `slice2-app`** with `--no-ff` (9c5f400, no conflicts) and pushed. The same checks on the merge: analyze clean; 2,652; 454.
     - Windows line endings in `lib/l10n/gen` again, with no content change; restored.
     - **No database push** (105A has no migration). **No function deploy.**
  4. **Build 775** (9c5f400, release, upload key, prod env; versionCode 775, versionName 0.9.0; certificate SHA-256 9d02b7db…df9f, the same as 744): on the Desktop as `BuildVibes-775.apk` (MD5 ebee9a19…).
  5. **Installed on the founder's Xiaomi** over 744, at 192.168.8.33:43045 (still connected; model 22120RN86G checked first):
     - versionCode 775; first install still 17 Oct.
     - The installed `base.apk` is byte-identical to `BuildVibes-775.apk`.
     - BuildVibes is the only package of ours on it.
- **Next:**
  - the founder's test of build 775: a Space's Work in the notebook's one language, Needs you, People, Space info, Walk as the last kind chip, "Write in this Space";
  - 105B (places, archive, personal pins, share to a chat thread, the Space's time zone, handover on removal; one migration);
  - the tidy lists in reviews 105 and 106.
- **Who has which branch:** PC has `slice2-app` (worktree `BuildVibes-slice1`), `claude/r105a` (worktree `BuildVibes-r105a`, merged) and `r106` (merged).

## PC update: 29 Oct 2026 — review 105 J1–J4 (the lead's check of the 105A shots) on `claude/r105a`; stopped for the lead

**Standing rule (review 74):** nothing but the BuildVibes build goes on the founder's phone without his yes in chat.

- **Branch:** `claude/r105a` (worktree `BuildVibes-r105a`), pushed. Nothing merged, no goldens updated, no database push, no build.
- **Commits, test first, EN and AR:**
  - 1911316 **J1:** the Space's back is always there (SP1).
    - With something under the Space it pops, as before.
    - With nothing under it (a link, a notification) it goes to Home's Spaces.
    - Test: `space_layout_test` J1 (opened with `go`, back shows, goes to Home on Spaces).
  - 6137c4b **J2 (systematic-debugging): the cause was the shot's fake data, not the app.**
    - The evidence: the opened item's `postPageProvider` was in error, from a `ProviderException`. `pageRepositoryProvider` builds the real Supabase repository, and the shots never start Supabase. The daybook and slice2 shot files build their own overrides and had no page repository; `pumpApp` gives one, so the app tests were fine.
    - Fix: `FakePageRepository` in those two files' overrides. Y1, X1 and C6 now show the opened item: title, For line, and Edit page and ⋯ where they apply.
    - No app change: there's none to test.
  - 0245d33 **J3:**
    - A Space opened on its People pushes them after the Space's first frame, scheduled from its first build (not `initState`), and only through a router that is there (`GoRouter.maybeOf`).
    - The SP1 shot draws the People screen itself, since People is its own screen over the Space now.
    - X2 needed nothing more: its "No element" was J2's error page, which has no For line. `openedPick` already uses the For line.
  - 76b6a20 **J4:** Work's post bar reads "Write in this Space" («اكتب في هذه المساحة», new key `daybookWriteInSpace`).
    - An opened item's bar keeps `daybookAddUpdate` ("Add update", «إضافة تحديث»).
    - Test: `space_layout_test` J4.
  - d33a13f **Deleted:**
    - the F61-to-do-strip and A1-to-do-sheet goldens (review72), with their scenarios in `slice2_test`;
    - the MN1-space-menu goldens in slice1, slice7 and slice9. No scenario had drawn them since Part 1.
    - slice9's test is renamed "MR1 the week report".
  - b64993e **Shots:** `docs/reviews/shots-105a/` replaced, with its README.
- **Checks (PC):**
  - `flutter analyze`: no issues.
  - `flutter test`: 2,652 pass.
  - `supabase test db`: 3,058 checks in 49 files pass.
  - `flutter test test_screens`, not updating: 230 pass, 224 fail.
    - Every failure is a changed picture: 123 shots, 246 images. No scenario errors now.
- **Corrections to my list at 132d84e** (also in the README):
  - It missed four changed shots: D-F24-update-sheet-keyboard, K1-announcement-checklist, T2-checklist-from-template and T3-menu-save-as-template. My pattern missed a line break; it was 248 images, not 240.
  - "MN1 passes unchanged" was wrong: nothing drew those files.
  - F71-replaces-picked is in two folders (review80, review82). Its two new images are now taken from each file's own run.
- **Next:** the lead's check of the shots. Then, with the founder's yes: goldens (with the renames), the merge into `slice2-app` and a build.
- **Who has which branch:** PC has `claude/r105a` (worktree `BuildVibes-r105a`), `slice2-app` (worktree `BuildVibes-slice1`) and `r106` (merged).

## PC update: 29 Oct 2026 — `slice2-app` merged into `claude/r105a`; 105A's shots for the lead

**Standing rule (review 74):** nothing but the BuildVibes build goes on the founder's phone without his yes in chat.

- **Branch:** `claude/r105a` (worktree `BuildVibes-r105a`), at 86eff0e, with `origin/slice2-app` (11e99eb + 27bca2e: reviews 104 and 106) merged in. Pushed.
  - Not merged into `slice2-app`; no goldens updated; no database push; no build.
- **Commits:**
  - a1b5900 the merge;
  - 6934376 `docs/reviews/shots-105a/`;
  - this handoff.
- **Conflicts, and how each was resolved:**
  - `lib/features/notebook/notebook_page_parts.dart`:
    - 105A moved `SelectionAction` and `SelectionBar` to `lib/shared/widgets/bv_selection_bar.dart` (H8), with a re-export here; `slice2-app` added `confirmNotebookDelete` (review 104 N6) beside them.
    - Kept: the move (not the old copy) and `confirmNotebookDelete`.
    - `slice2-app` hadn't changed the bar's code since the base (3f14b70), so the shared copy loses nothing.
    - The notebook keeps its review 106 bar. Against `slice2-app`, the merged notebook differs only by the bar's move.
  - `lib/l10n/app_en.arb`, `app_ar.arb`: both sides had added keys in the same place.
    - Merged key by key against the base. Kept: 105A's 39 new keys and `slice2-app`'s 44.
    - Removed, as one side removed them and the other left them alone: `notebookShareKindPost`, `notebookShareKindWork` and `notebookShareKindChecklist` (review 104 N9); `notebookFilterReminders` and `notebookSortLabel` (review 106); `daybookHoldToProve` (105 H1).
    - No key was changed differently on the two sides.
  - `lib/l10n/gen/*.dart` (3 files): regenerated with `flutter gen-l10n` from the merged ARB files.
  - `docs/handoff.md`: both sides' new sections kept (105A's, then `slice2-app`'s), above the common history.
  - Everything else merged cleanly, including `daybook_writing.dart` (review 104's Team and For rows), `bv_popover_menu.dart`, `app_router.dart` and `app_routes.dart`.
- **Checks (PC, on the merge):**
  - `flutter analyze`: no issues.
  - `flutter test`: 2,648 pass (photo_privacy H1 included).
  - `supabase test db`: 3,058 checks in 49 files pass.
  - `flutter test test_screens`, not updating: 230 pass, 228 fail.
    - **120 shots changed (240 images)**, all Space screens: Work, People, Space info, the walk, Library and Chat with the new header, the To do strip, and the shots renamed in content (Y1-swipe-update, E2-more-menu, E6/F50/F63 kind menu, E6-kind-chip).
    - All are expected under 105A. Old and new pairs and the full list are in `docs/reviews/shots-105a/`.
- **For the lead:**
  - **Unchanged though expected:** F95-walk-place (review80); MN1-space-menu (slice1, slice7, slice9: deletable, still drawn); R1-walk-start and R1-walk-photo (slice6).
  - **Two scenarios fail on `claude/r105a` itself** (checked at 86eff0e, before the merge):
    - `daybook_test` **X2 give it to someone else**: "Bad state: No element" at `openedPick(l10n.daybookGiveTo)`. No image, so X2-give-to is not in the list.
    - `around_test` **SP1 the Space: People**: "No GoRouter found in context", from `SpaceScreen.initState`'s `context.push` to People in a scenario without a router. Its image is drawn and listed.
    - Both are for 105A's side to fix.
  - **Can be deleted** (the lead): the To do strip shots (review72 F61-to-do-strip, A1-to-do-sheet) and MN1.
- **Next:** the lead's check of the shots; the two scenarios fixed; then goldens, the merge into `slice2-app` and a build, with the founder's yes.
- **Who has which branch:** PC has `claude/r105a` (worktree `BuildVibes-r105a`, merged with `slice2-app`, pushed), `slice2-app` (worktree `BuildVibes-slice1`) and `r106` (merged).

## Cloud update: 29 Oct 2026 (later) — the lead's check of `claude/r105a`: H1–H9 done (H3 as the lead ruled)

**Standing rule (review 74):** nothing but the BuildVibes build goes on the founder's phone without his yes in chat.

**After any Flutter upgrade, run the Daybook tests and test_screens before anything else. The Daybook paints its rows with custom render classes (review 101).**

- **Branch:** `claude/r105a`, this cloud session's, pushed. Nothing merged, nothing live, no deploy, nothing installed, **no migration**.
- **Commits:** 63e118b H1, H4, H5; 1f3586f H2, H6, H8; 22a200b H7; 5e9a1f9 H9; 91baa1c H3.
- **H1:** the post bar's camera has no hold (`onProve` gone from `BvPostBar`); its screen-reader label is "Camera" (`daybookCameraLabel`; `daybookHoldToProve` removed). Sign as done starts only from the work item.
- **H2:** a pinned announcement: **tap opens** it as an item, **hold selects** it (it joins the selection bar; Delete for its author). Folding is its own 24 chevron at the start of its head (`BvPinnedFold`, key `pinned-fold`; ⌄ open, › folded, mirrored in Arabic), as review 106 T2; the line's trailing › is gone.
- **H3 (the lead's ruling, no camera plugin before the pilot; 91baa1c):** the post bar's camera opens the phone's camera **straight away** for a photo post (no sheet). **Walk is the writing card's last kind chip** ("Walk" / «جولة», the camera icon, key `kind-chip-walk`, value `kindChipWalk`), shown only when `SpaceDetail.mayPostWork`; it starts walk mode as before (an empty card is put down first, one with words stays a Draft). The two-tile sheet (`daybook_camera.dart`), `BvCameraModesSpec`, `BvIcons.walk` and the `cameraPhoto` string are gone; `cameraWalk` became `daybookKindWalk`. The F95 walk shot (`review80_test.dart`) now starts from the chip.
- **H4:** Delete is hidden (not greyed) when a held post can't be deleted (a Checked one).
- **H5:** Delete of several tries every post; the ones that fail with no signal are named after ("Couldn't delete … Try again.", `daybookDeleteFailed`); ones the server keeps say so as before.
- **H6:** the registered company uses `BvType.emphasisSm`; the proof card's View uses `textAction`; the 105A spec numbers are on the BvSpace / BvSize / BvRadius scales (Needs you padding 12 and icon 20, writing rows padding and gap 12, kind chips round, proof seal 40 and icon 24, People tag padding 2, header dot inset 8) — small changes in those shots.
- **H7:** `SpaceDetail.mayPostWork` (Lead or Crew with the right to create items) is the one check for the camera's Walk and Space info's daily report.
- **H8:** Work's own ARB keys: `workPin`, `workArchive`, `workReminder`, `workChangeReminder`, `workShare`, `workDuplicate`, `workRemindPast`, `workReminderLine`, `workSelected`, `workCloseSelection`. `SelectionBar` moved to `lib/shared/widgets/bv_selection_bar.dart`; `notebook_page_parts.dart` only re-exports it now (the one line changed in `lib/features/notebook/`, as H8 asks).
- **H9:** the 15 shot drivers use the new gestures (new helper `test_screens/work_gestures.dart`); analyze clean, **not run** (test_screens is the PC's). Shots that now show something else under the old name: `Y1-swipe-update` (the opened item's Add update), `E2-more-menu` (the writing card's +), `E6`/`F50`/`F63` kind-menu shots and `E6-kind-chip` (the chips row). The drivers for Library and People now draw those screens directly (`shoot` has no router).
- **Checks (cloud):** `flutter analyze` (whole project, test_screens included): no issues. `flutter test` (after H9 and H3): 2,503 pass, 1 fails — `test/core/photo_privacy_test.dart` H1, root-only in the cloud (passes on the PC). SQL stand-in: ok=3038, files failing 0. No test_screens run, no goldens updated, no migration.
- **For the PC, when the shots are checked:** every Work shot changes on purpose (as before, plus H2's chevron and H6's spacing); People's (SP8); the To do strip's and MN1's PNGs can go.
- **Who has which branch:** this cloud session had `claude/r105a` (pushed). PC: `slice2-app`. `claude/r104` is with the lead.

## Cloud update: 29 Oct 2026 — review 105A done on `claude/r105a` (from `slice2-app` 3f14b70); shots still to check on the PC

**Standing rule (review 74):** nothing but the BuildVibes build goes on the founder's phone without his yes in chat.

**After any Flutter upgrade, run the Daybook tests and test_screens before anything else. The Daybook paints its rows with custom render classes (review 101).**

- **Branch:** `claude/r105a`, this cloud session's, pushed. Nothing merged, nothing live, no deploy, nothing installed, **no migration**. `lib/features/notebook/` untouched (claude/r104 has it; Work imports its `SelectionBar` and `reminderWhen` only).
- **The lead's rulings (29 Oct) followed:** Q1–Q5, search in People, and Walk moved into the camera as Photo · Walk (6ee4224; Space info keeps Week report and Daily report in its Work group).
- **Commits:** adab5e2 and 39fa823 Part 1; 6ee4224 the rulings; a1407be Part 8; 65d6b64 Parts 2, 3 and 6; a743037 Part 7.
- **Part 2, the gestures (SP5, SP6, ruling Q3):**
  - **Tap opens** the item (its page). The old hold menu's actions are there: tap the **title** (or words) to edit in place, the **For line** to give it to someone else, **"Add an update"** at the bottom, **Send back** as a button for whoever checks it, and **⋯** for Unpin · Save as template · Cancel (Cancel work item still held). A pinned announcement opens the same way on a hold (a tap still folds and unfolds it).
  - **Hold selects:** "1 selected" with ✕ in the Space header (SP6: brand-soft paper, an orange edge); a tap adds or takes off; the bottom bar is **Duplicate** (one card: a new card at Now with the same kind, words, owner and place, no due or pin) · **Delete** (asked first; only my own, never a Checked or cancelled one; `delete_space_post`, which refuses once someone else has added: that one stays and says to cancel it). No Move. Back or ✕ ends it; Viewers don't select.
  - **Swipe toward the end: Reminder**, a phone notification for me only (the notebook's picker; `space_reminders` on the phone, per account; its tap opens the card on Work through `RoutedReminders` in `core/push/reminders.dart`, never My notebook).
  - **Behind the off flag** (`workLaterProvider`, null until 105B): **Pin** (swipe), **Share** (hold bar), **Archive** (swipe toward the start, Lead + Checked only, a round button: `BvSwipeCard.startFullSwipe: false` keeps it round).
  - Sign as done, Check and Send back are never on a swipe or a hold; the old Update swipe is gone.
- **Part 3, the writing card (SP2):** the kinds as one choice that scrolls sideways (Note · Work item · Checklist · Announcement · Scheduled; Work item first); title, then details ("Add details."); **For · Place · Due · Team rows** that open their pickers (For: Give to's picker, one person for a work item; Place: free text until 105B; Team: "Whole Space" until one is chosen), only the rows a kind uses (Note: Team only); the bar **+ · camera · attach, then Send**, no mic (Q4). + holds what the rows don't: a template, an announcement's pin. **A work item now goes with its Team** (`create_work_item` already takes `p_team`; app only). A file post starts from the Library's Add a file; a daily report from Space info.
- **Part 6:** **"3 need you · 2 due today ›"** at the top of Work, in the To do strip's place (the strip and its sheet are removed): mine waiting on the page and in what's due; a tap shows only those (older pages are read until all are there), again everything; hidden when nothing waits. **An announcement starts pinned until today ends, at the phone's midnight** (Q5); + changes or removes it. Got it as now.
- **Part 7 (card only):** when my item is Checked, once, for 4 s: "Added to your proof of work · Checked by {name} · {time} · View"; View goes to my proof of work on the Profile tab (pushing it over a Space clashes in go_router, so it is a `go`). Owner's phone only; shown once (kept per account); not for a check over a day old.
- **Part 8 (SP8):** one "In this Space" list (Leads first): name; title · company (registered company in ink, medium; typed one plain grey, `SpacePerson.companyRegistered` from the embed already fetched); the pass and the person's Teams as chips. Join requests on top under "Needs you · Join request" with **Decline · Confirm**; Confirm asks for the pass as before. **Search** in People's header (name, role or company).
- **Things I chose that the review didn't spell out (for the lead):**
  - the hold on a pinned announcement opens it (its tap was already fold/unfold);
  - Duplicate drops the due and the pin; Delete of several posts deletes each the server allows and says how many stayed;
  - the work-item hint is "Add details." without "+ for bullet points, a table or a table of tasks": the writing card's + doesn't offer those until 105C (SP4); the rest of the hint goes in with them;
  - the Needs you count is what waits on me on the page (to sign, to check, to give to, sent back) plus my due items; "due today" counts those due today;
  - the admin's "Space admin" now shows as a tag beside the pass in People (SP8 shows no admin line).
- **Checks (cloud):** `flutter analyze` (whole project, test_screens included): no issues. `flutter test`: 2,488 pass, 1 fails — `test/core/photo_privacy_test.dart` H1, which fails only because the cloud runs as root (a read-only file is still writable for root); it passes on the PC. SQL stand-in: ok=3038, files failing 0. No test_screens run, no goldens updated, no migration.
- **For the PC, when the shots are checked:**
  - every Work shot changes on purpose (the Needs you line for the To do strip, the writing card with chips, rows and the new bar, a selected card), and People's (SP8);
  - these shot drivers still use the old hold menu, kind menu, ⋯ More, the To do strip or the Update swipe and need moving to the new gestures before shooting: `test_screens/slice2_test.dart`, `slice3_test.dart`, `slice5_test.dart`, `slice7_test.dart`, `slice8_test.dart`, `slice9_test.dart`, `slice10_test.dart`, `daybook_test.dart`, `review80_test.dart`, `review82_test.dart`, `around_test.dart`, `slice4_test.dart` (People), `bh_test.dart`, `pg_test.dart` and `f102_test.dart` (holds: check each is not a notebook hold);
  - the To do strip's PNGs (and its sheet's) can go;
  - the MN1 Space-menu PNGs can go (Part 1).
- **Who has which branch:** this cloud session had `claude/r105a` (105A done, pushed). PC: `slice2-app`. `claude/r104` is with the lead.

## PC update: 29 Oct 2026 — review 106 live: merged into `slice2-app`, migration 50 live, build 744 on the founder's phone

**Standing rule (review 74):** nothing but the BuildVibes build goes on the founder's phone without his yes in chat.

**After any Flutter upgrade, run the Daybook tests and test_screens before anything else. The Daybook paints its rows with custom render classes (review 101).**

- **The founder's yes (29 Oct), after the lead accepted r106's shots (review 106, "G1–G5 done"):**
  1. **Goldens updated only for the accepted shots**, EN and AR:
     - the 11 changed: BH2, BH3, BH4, BH5, BH9, N5-page-filter, N5-sort-chip, PG4, NB-reminder-slip, NB-remind-menu, NB-put-in-space;
     - the 4 new: `docs/screens/r106/` NS1–NS4.
     - That is 30 images, each byte-identical to its accepted image.
     - `docs/screens/r106/` falls under the ignore rule for `docs/screens/*`, so it was added with `git add -f`, as the other golden folders were.
     - `docs/reviews/shots-106/` removed.
  2. **Checks on `r106` (e6a71c1, pushed):**
     - `flutter test test_screens`, not updating: 462 pass.
     - `flutter analyze`: no issues.
     - `flutter test`: 2,535 pass.
     - `supabase test db`: 3,058 checks in 49 files pass.
  3. **Merged into `slice2-app`** with `--no-ff` (11e99eb, no conflicts) and pushed. The same checks on the merge: analyze clean; 2,535; 462.
     - The run left Windows line endings in `lib/l10n/gen`, with no content change. Restored before the push.
  4. **Migration 50 live** (`20261111120000_note_collapsed.sql`), from a throwaway worktree at 11e99eb with `supabase/.temp` copied whole.
     - The dry run listed only that file. The push exited 0 ("Applying migration 20261111120000_note_collapsed.sql…", "Finished supabase db push"). The known pg-delta certificate warning followed: harmless.
     - `supabase migration list --linked` ends at 20261111120000, local and remote alike, and a second dry run says "Remote database is up to date".
     - The push worktree is removed. **No function deploys.**
  5. **Build 744** (11e99eb, release, upload key, prod env; versionCode 744, versionName 0.9.0; certificate SHA-256 9d02b7db…df9f, the same as 729): on the Desktop as `BuildVibes-744.apk` (MD5 b2cf3694…).
  6. **Installed on the founder's Xiaomi** at 192.168.8.33:43045 (model 22120RN86G checked first), over 729:
     - versionCode 744; first install still 17 Oct.
     - The installed `base.apk` is byte-identical to `BuildVibes-744.apk`.
     - BuildVibes is the only package of ours on it.
     - The first install command printed nothing and left 729 in place; the second gave "Success".
- **Next:**
  - the founder's test of build 744: the status row, folding, Collapse all · Expand all, the Filter · Sort switch, STATUS;
  - the tidy list in review 106: `_setFilter` in two screens, `statusHits`, `entryHead`/`foldHidden` in a screen file, the 'collapse' / 'expand' strings.
- **Who has which branch:** PC has `slice2-app` (worktree `BuildVibes-slice1`) and `r106` (worktree `BuildVibes-r106`, merged). `claude/r105a` is a cloud session's.

## PC update: 29 Oct 2026 — review 106 G1–G5 (the lead's check of `r106`) done on `r106`; stopped for the lead

**Standing rule (review 74):** nothing but the BuildVibes build goes on the founder's phone without his yes in chat.

- **Branch:** `r106` (worktree `BuildVibes-r106`), pushed. Nothing merged, no database push, no build. `lib/features/spaces/` untouched.
- **Commits, test first, EN and AR:**
  - a3b2375 **G4:** migration 50 (the file itself; it isn't live) adds `owner_id = v_me` to its `update`.
    - pgTAP 50 now has 20 checks: the version doesn't move; a deleted entry is refused (42501); an empty list and a null `p_on` each give 22023.
    - The local stack's function was re-created from the edited file.
  - feb42d3 **G1–G3, G5:**
    - **G1:** an archived entry keeps the short card (the first 3 lines, each on one line, "…"), with no fold control.
    - **G2:** in a page, an untitled entry's head is fold · time, and its words stay in the body at normal weight, for every kind; the kind words don't come back.
      - Folded, the head shows its first line in the body's style, cut to one line. That line isn't counted in "{n} lines hidden".
    - **G3:** the fold control shows only when folding would hide something.
      - An entry kept folded that hides nothing shows open, with no empty row.
      - Collapse all leaves such entries alone.
    - **G5:** the Status groups follow `EntrySort.status`'s one order. The page builds `byStatus` from the sorted entries; the second copy of the order is gone.
    - The `EntrySort` method is still called `sorted`; the lead's note calls it `order`.
  - 31a52e5 **Shots:** `docs/reviews/shots-106/` replaced, with the README updated. Only the six NB images changed (G2, G3).
- **Tests changed on purpose:** `entry_fold_test`'s "first line as the title" test is replaced by the G2 tests; `notebook_test` PG4 now expects no kind word on the to-do's head (G2).
- **Checks (PC):**
  - `supabase test db`: 3,058 checks in 49 files pass.
  - `flutter analyze`: no issues.
  - `flutter test`: 2,535 pass.
  - `flutter test test_screens`, not updating: 434 pass and 28 fail.
    - 20 are the same 11 changed shots as before (22 images).
    - 8 are the new NS1–NS4 shots, with no golden yet.
    - Against `fbe1691`, only the six NB images are new.
- **Next:** the lead's check of the fixes. Then, with the founder's yes: migration 50 live, merge, and one build.
- **Who has which branch:** PC has `r106` (worktree `BuildVibes-r106`) and `slice2-app` (worktree `BuildVibes-slice1`). `claude/r105a` is a cloud session's.

## PC update: 29 Oct 2026 — review 106 (T1, T2, T3) on `r106`; stopped for the lead

**Standing rule (review 74):** nothing but the BuildVibes build goes on the founder's phone without his yes in chat.

**After any Flutter upgrade, run the Daybook tests and test_screens before anything else. The Daybook paints its rows with custom render classes (review 101).**

- **Branch:** `r106` (worktree `BuildVibes-r106`), from `slice2-app` 0cab77a (review 104 in it), pushed. Nothing merged, no database push, no build, nothing installed. `lib/features/spaces/` untouched (`claude/r105a` has it).
- **Commits, test first, in this order:**
  - 62ac997 **T2 server: migration 50** (`20261111120000_note_collapsed.sql`): `notes.collapsed boolean not null default false`, and `set_notes_collapsed(p_ids, p_on)`.
    - The function is owner only, like every write to `notes`: the table's own policy only lets the owner read. Writes go through owner-checked functions, as in migration 49.
    - pgTAP `50_note_collapsed` (15 checks): the owner folds and opens; someone else can't read Omar's entry or fold it; signed out is refused.
    - **Applied to the local stack only. Not live.**
  - e76e631 **T1:** the status row.
    - Where: at the entry's bottom end, one round icon per kind (pinned · reminder · feed · Space · message), all of them, no "+N".
    - Size: each a 32 target, a 16 icon on the sunk colour, 6 apart.
    - The card: a tap opens it under the icon, listing every share of that kind ("Kuwait City Tower · 8:45 am"); the icon shows selected while it is open. The reminder's card keeps Change.
    - The top line is title and time only. Screen-reader labels as review 104.
    - The new words for T1–T3 are in both ARB files. `notebookStatusMore`, `notebookStatusMoreLabel`, `notebookFilterReminders` and (in T3) `notebookSortLabel` are gone.
  - f351ca3 **T2:**
    - Inside a page every entry shows in full: no 3-line cut, lines wrap.
    - The head is the fold chevron (24, 44 tap area) · title · time. An untitled entry's head is its first line; a to-do or a voice note keeps its kind word.
    - Folded: the head, then "{n} lines hidden" and the status icons, still tappable. The chevron or the folded head opens it; tapping an open entry's text still edits it.
    - The page's ⋯ gains Collapse all · Expand all, for this page only.
    - Kept through the notebook's queue (`NoteChange.collapse`).
    - A search or Filter hit opens its entry unfolded, on this phone only (nothing written).
    - My notebook's Filter results keep their short cards.
  - 505303f **T3:**
    - The ☰ card has a switch with its word at the top: "Filter" / "Sort". It is the new `BvSwitch.inRow`, 44 × 26, with its row as the tap, and it opens in the mode used last (`notebook_filter_mode`).
    - Filter mode: SHOW (To-dos open · Photos · Files · Voice notes · Archived) · STATUS (Pinned · Reminder · Shared to the feed · Shared to a Space · Sent in a message) · IN.
    - One choice in each section; SHOW and STATUS combine; the chosen one tapped again clears it; each choice on is its own chip with ✕.
    - STATUS is read on the phone from the entries and shares it keeps: no server change. On its own it lists the phone's entries; with SHOW it narrows the server's hits. Search keeps STATUS (`status` in its route).
    - Sort inside a page: Newest · Oldest · Name A–Z · Type · **Status**, grouped Reminder · Shared to the feed · Shared to a Space · Sent in a message · No status, with pinned on top as in every sort. Type and Status have their hints (NS4).
    - The pages list keeps its four sorts.
  - 89f47dd **Shot scenarios:**
    - `test_screens/r106_test.dart` adds NS1–NS4 (EN, AR).
    - The N5 shots open the card in Sort mode, since SORT is behind the switch now.
    - A line card's note wraps to two lines (NS4's hints).
  - 525625d **The shots for the lead:** `docs/reviews/shots-106/` (old and new, plus its README).
- **Tests changed on purpose** (the rule they checked is replaced by review 106):
  - `status_icons_test` rewritten for T1, so the two "+N" tests are gone.
  - `remind_me_test`: the barrier is tapped at its corner, since the card now opens lower.
  - `note_page_test`: the saved slip shows every line.
  - `notebook_test` PG4: scrolls 200 before comparing the to-do; the cards are taller.
  - `redesign_share_limits_test` J1: holds the head of the 3,000-character entry, which now runs past the screen.
  - `redesign_filter_test`: no Reminders in SHOW; the in-page test uses Photos.
  - `sort_test` and `arrange_test`: the switch goes to Sort first.
- **Checks (PC):**
  - `flutter analyze`: no issues.
  - `flutter test`: 2,525 pass (photo_privacy H1 included).
  - `supabase test db`: 3,053 checks in 49 files pass.
  - `flutter test test_screens`, not updating: 434 pass and 28 fail.
    - 20 of the failures are changed shots: 11 shots, 22 images ("Remind me" takes two): BH2, BH3, BH4, BH5, BH9, NB-reminder-slip, NB-remind-menu, NB-put-in-space, PG4, N5-page-filter, N5-sort-chip.
    - The other 8 are the new shots (NS1–NS4, EN and AR), with no golden yet.
    - Old and new copies are in `docs/reviews/shots-106/`, and its README says which shots review 106 names. PG4, N5-sort-chip, BH9 and N5-page-filter are not named: they change from T2 and T3.
- **For the lead (also in the README):**
  - `BvSwitch`'s off colour is kept against NS3's lighter one.
  - An untitled long one-line note becomes a three-line bold head.
  - The 44 fold area makes the gap under the head about 6 px larger than NS2's.
- **Local stack:** migration 50 is applied.
- **Next:** the lead's check of `r106` and its shots. Migration 50 goes live only with the founder's yes, then merge and one build.
- **Who has which branch:** PC has `r106` (worktree `BuildVibes-r106`), `slice2-app` (worktree `BuildVibes-slice1`) and `claude/r104` (merged). `claude/r105a` is a cloud session's.

## PC update: 29 Oct 2026 — review 104 live on build 729 (merged into `slice2-app`, on the founder's phone)

**Standing rule (review 74):** nothing but the BuildVibes build goes on the founder's phone without his yes in chat.

**After any Flutter upgrade, run the Daybook tests and test_screens before anything else. The Daybook paints its rows with custom render classes (review 101).**

- **The founder's yes (29 Oct), after the lead's check of the shots (review 104, "Shots (29 Oct, 30c271c)"):**
  1. **S1 on `claude/r104`, test first:** Share → Space reads "A note, work item or checklist" / «ملاحظة أو بند عمل أو قائمة تحقق» (`notebookShareSpaceNote`, both ARB files). BH4's share test failed on the new words first, then passed.
  2. `docs/reviews/shots-104/` removed (it was for the lead's check only).
  3. **Goldens updated only for the accepted shots**, EN and AR: r100 BH2-entry-selected, BH3-swipe, BH4-share, BH5-message-preview, BH9-filter; r102 N2-time-wheel, N5-page-filter, N11-time-clock (new); slice10 NB-remind-menu, NB-reminder-slip; slice8 NB-put-in-space. 22 files, nothing else.
  4. **Checks on `claude/r104` (4b9ff2b, pushed):** `flutter analyze` no issues; `flutter test` 2,487 pass (photo_privacy H1 included); `flutter test test_screens`, not updating: 454 pass.
  5. **Merged into `slice2-app`** with `--no-ff` (8e8c423, no conflicts) and pushed. The same checks on the merge: analyze clean; 2,487; 454.
- **No database push, no deploy:** review 104 has no migration and no server change.
- **Build 729** (8e8c423, release, upload key, prod env, versionCode 729, versionName 0.9.0; certificate SHA-256 9d02b7db…df9f, the same as 712): on the Desktop as `BuildVibes-729.apk` (MD5 b97d5b53…).
- **Installed on the founder's Xiaomi** (29 Oct, 08:04, at 192.168.8.33:43045, the address he sent; model 22120RN86G checked first) over 712: versionCode 729, first install still 17 Oct, the installed `base.apk` byte-identical to `BuildVibes-729.apk`. BuildVibes is the only package of ours on it.
- **Next:** the founder's test of build 729; review 105 when the lead hands it over.
- **Who has which branch:** PC has `slice2-app` (worktree `BuildVibes-slice1`), `claude/r104` (worktree `BuildVibes-r104`, merged) and `claude/r101-l1` (worktree `BuildVibes-l1`, for the lead).

## Cloud update: 29 Oct 2026 — the lead's check of `claude/r104`: F1–F3 done; stopped for the lead

**Standing rule (review 74):** nothing but the BuildVibes build goes on the founder's phone without his yes in chat.

- **Branch:** `claude/r104` (this cloud session), from 226919b, pushed. Nothing merged, nothing live, no deploy, nothing installed, no migration.
- **Commits:**
  - 7b19fd3 **F1**: a saved entry left empty after editing now asks "Delete this empty entry?" («حذف هذه التدوينة الفارغة؟»), with the days kept and Cancel · Delete. Cancel brings the editor back with the empty entry, and whatever asked (Back, Done, opening another entry, New entry) does not go on; Back on New entry leaves the screen only after Delete. Delete goes on as before ("Deleted · Undo", to Deleted items when the bar closes). The app going behind asks nothing and keeps the edit on the phone (D1 opens it again). D3 and H5 tap Delete in the confirm now.
  - 1b65bac **F2**: the dial's numbers are read "7 o'clock" / «الساعة 7» and "35 minutes" / «35 دقيقة» («5 دقائق»), from the ARB; tested with the semantics finder (tapping an hour and a minute by their words).
  - 2a76d2a **F3**: the "+N" badge has its own key `notebookStatusMore` ("+3"); the screen reader's "3 more" moved to `notebookStatusMoreLabel`. A share whose Space or person has no name is left out of the icons.
- **Checks (cloud):**
  - `flutter analyze`: no issues.
  - `flutter test`: 2,486 pass, 1 fails: photo_privacy H1, root-only in the cloud (as before).
  - SQL stand-in: migrations apply; 3,038 checks in 48 files pass.
  - Screenshots: PC later; no `test_screens`, no `--update-goldens`. F1–F3 change no shot (F2 is semantics only; F3 shows the same "+3").
- **The PC still has to:** the steps in the section below (test_screens without updating; the shots review 104 changes on purpose, plus the new N11-time-clock; the lead's check; merge with the founder's yes; one build). No database push.
- **Who has which branch:** this cloud session had `claude/r104` (F1–F3 done, pushed). PC: `slice2-app`.

## Cloud update: 28 Oct 2026 — review 104 (N6–N12) on `claude/r104` (from `slice2-app` 3f14b70); stopped for the lead

**Standing rule (review 74):** nothing but the BuildVibes build goes on the founder's phone without his yes in chat.

**After any Flutter upgrade, run the Daybook tests and test_screens before anything else. The Daybook paints its rows with custom render classes (review 101).**

- **Branch:** `claude/r104`, this cloud session's, pushed. Nothing merged, nothing live, no deploy, nothing installed. **No migration and no server change**: Share → Space already took the kind, Team, owner and people.
- **Commits, in the order done:**
  - 8c55e14 **N8** (bug, first): the cause was the card's summary drawing a table as one line of its first row only (`rows.take(1)`). It now draws the whole table (`PageTableView`, as Work's page), sideways scroll when wider, columns mirrored in Arabic. The data and the editor already kept every row; tests prove the card, a wide table, the editor reopened, the full make-and-Send flow and the JSON round trip.
  - e85cdfe **N6**: one confirm before every delete: entries, pages (page menu and pages list), selected lines, a Draft's Discard (swipe and top bar). The body reads the person's 7/30/90 days from the server; with no answer in 2 s it says "It goes to Deleted items." without a number; a Draft and lines never saved say "It isn't kept in Deleted items." (they never go there). Cancel · Delete, Delete in red. The Undo bar after Delete is unchanged; Archive asks nothing.
  - 98d7c50 **N7**: pages list + Oldest created; inside a page + Name A–Z and Type (groups To-dos · Checklists · Photos · Files · Voice notes · Text, the first kind found, newest first in each; an empty group has no label). Day headers and hold-and-move only in the two date sorts (elsewhere a hold selects). Pinned on top in every sort. Two Phosphor icons added (calendar-blank, shapes), checked against the bundled font.
  - 473e15e **N9 + N10**: the kinds read the Space's own words and icons (`kindName`/`kindIcon`); "Post" and its three strings gone. Team and For are rows: Team opens a one-choice sheet of the Space's Teams; For opens `BvGiveToPicker` (me first as You, the chosen Team's people, then the rest A–Z; no Viewers). A work item takes exactly one (a pick closes it); a checklist several until Done ("You + 2"). Tested with 120 members.
  - 873bfe3 **N11**: `showBvTimePicker` (`lib/shared/widgets/bv_time_picker.dart`) is the one picker in all six places. Clock face by default (our own dial: Material's can't grey passed times), the mode switch where typed input was, the wheels as the second mode; AM/PM above in both; nothing typed; passed times greyed in both; the last mode kept on the phone (`time_picker_mode`). `showBvTimeWheel` and its dialog are gone; `BvTimeWheel` is the wheel mode.
  - 4b893af **N12**: status icons beside the time (pinned, reminder accent/grey, feed, Space, person), 14 grey, 4 apart, max 3 then "+N"; a tap opens a compact card (the reminder's with Change); screen-reader labels; the text marks under the entry are gone. Found on the way: the reminder's day dialog overflowed 31 px in Arabic with Remove showing; Remove now takes the free room and wraps.
- **Tests changed on purpose** (the old rule they checked was replaced by this review): every test that deleted without a question now taps Delete in the confirm (N6; one title read "Delete: no question"); review 102 N5's sort tests now expect four choices each (N7); H11's Team/For chips are now rows (N10); the wheel tests open the picker on its wheels, and `note_page_test`'s reminder expects the clock (N11); the reminder line and share-mark tests now read the icons and their card (N12).
- **Checks (cloud):**
  - `flutter analyze`: no issues.
  - `flutter test`: 2,473 pass, 1 fails: photo_privacy H1, which fails only when run as root (the cloud), as on every cloud branch; the PC runs it as a user.
  - SQL stand-in (`bash supabase/dev/standin/run.sh .`): all migrations apply; 3,038 checks in 48 files pass.
  - Screenshots: PC later. `test_screens` not run, no `--update-goldens`.
- **The PC still has to:**
  1. run `flutter test test_screens` without updating. Expected to change on purpose: BH3 and PG4 (icons replace the marks); BH4 and BH5 (Note · Work item · Checklist, and the Team and For rows); `r102` N2-time-wheel (the mode switch is now in the dialog's bottom row); the BH9 sort parts (four choices). New, no golden yet: `r102` N11-time-clock (EN, AR). List any other changed shot with before/after; don't accept it;
  2. check the shots against Figma with the lead, then accept only those;
  3. with the founder's yes, merge `claude/r104` into `slice2-app` and run every check;
  4. one build on his phone, plus a Desktop copy. No database push is needed.
- **Who has which branch:** this cloud session had `claude/r104` (done, pushed). PC: `slice2-app` (worktree `BuildVibes-slice1`).

## PC update: 28 Oct 2026 — review 102 live: merged into `slice2-app`, migration 49 live, build 712 on the founder's phone

**Standing rule (review 74):** nothing but the BuildVibes build goes on the founder's phone without his yes in chat.

**After any Flutter upgrade, run the Daybook tests and test_screens before anything else. The Daybook paints its rows with custom render classes (review 101).**

- **The founder's yes (28 Oct), after the lead's check (16:10) and the cloud's P1 (80d9be7):**
  1. **The six N4 label shots accepted** on `claude/r102-notebook` (cd4aaf6): BH2-entry-selected, BH4-share and BH12-line-selected, EN and AR. Each differs only in one label-sized box in the selection bar.
  2. **Checks on the branch:**
     - `flutter analyze`: no issues.
     - `flutter test`: 2,391 pass, photo_privacy H1 included.
     - `supabase test db`: 3,038 checks in 48 files pass.
     - `flutter test test_screens`, not updating: 452 pass. P1 changed no shot.
  3. **Merged into `slice2-app`** (7a24f55, no conflicts) and pushed. The same checks on the merge: analyze clean; 2,391; 3,038; 452.
  4. **Migration 49 live** (`20261110120000_note_day_position.sql`). It was the only file in the dry run and in the push, from a throwaway worktree at 7a24f55 with `supabase/.temp` copied whole.
     - The push exited 0, and the remote migration list now ends at 20261110120000.
     - After it, the known pg-delta certificate warning: harmless.
     - Read-only check:
       - notes 11 and notebook pages 5, before and after;
       - `day_position` set on 0 notes;
       - `arrange_day` is `security definer` with `search_path=""`, and anon can't execute it;
       - signed out, the REST call refuses (401, 42501).
     - The push worktree is removed.
  5. **Build 712** (7a24f55, release, upload key, prod env): on the Desktop as `BuildVibes-712.apk`. Installed on the founder's Xiaomi 22120RN86G over 701 (versionCode 712); BuildVibes is the only package of ours on it.
- **No deploy.** No edge function changed.
- **Next:** the founder's test of build 712 (the time wheels, Move to…, SORT, hold and move); review 102's N6 and later, if he adds them.
- **Who has which branch:** PC has `slice2-app` (worktree `BuildVibes-slice1`), and `claude/r102-notebook` (worktree `BuildVibes-r102`, merged); the review 100 and 101 branches are merged too.

## Cloud update: 28 Oct 2026 — review 102 P1 on `claude/r102-notebook` (from 728bece); stopped

**Standing rule (review 74):** nothing but the BuildVibes build goes on the founder's phone without his yes in chat.

- **Done (the lead's check, 28 Oct 16:10, only P1):** on a one-line entry the swipe buttons overflowed by 2 px. A round button with its word needs 48 + 4 + 16 = 68 in English; the one-line card is 66 (in Arabic the line is 18 and the card 72, so it fitted). The button and its word are now made smaller only on a card shorter than they are (`BvSwipeCard`, a `FittedBox` that only scales down); every taller card is laid out as before.
- **Test first:** `review 102 P1: on a one-line entry the round buttons and their words fit inside the card, both ways` (`redesign_swipe_test.dart`). English failed before the fix ("A RenderFlex overflowed by 2.0 pixels"); Arabic passed before and after (a guard).
- **Checks (cloud):** `flutter analyze`: no issues. `flutter test`: 2,390 pass, 1 fails (photo_privacy H1, root-only in the cloud). Screenshots: PC later. No shot accepted, nothing merged, no database push, no deploy, nothing installed.
- **The PC still has to:**
  1. accept the six shots changed by N4's label (BH2, BH4, BH12, EN and AR), as the lead approved;
  2. run `flutter test test_screens` without updating; only a one-line card's swipe state may change (P1);
  3. with the founder's yes, merge `claude/r102-notebook` into `slice2-app` and run every check;
  4. `supabase db push` with migration 49 as the only file listed, then the read-only check (note count unchanged, `day_position` null everywhere, `arrange_day` refuses signed out);
  5. one build on his phone, plus a Desktop copy.
- **Who has which branch:** this cloud session had `claude/r102-notebook` (P1 done, pushed). PC: worktree `BuildVibes-r102`.

## PC update: 28 Oct 2026 — review 102 (N1–N5) on `claude/r102-notebook`; for the lead

**Standing rule (review 74):** nothing but the BuildVibes build goes on the founder's phone without his yes in chat.

**After any Flutter upgrade, run the Daybook tests and test_screens before anything else. The Daybook paints its rows with custom render classes (review 101).**

- **Branch:** `claude/r102-notebook` (worktree `BuildVibes-r102`), from `slice2-app` 19da7f6, pushed. Nothing merged, nothing live, no deploy, nothing installed.
- **Commits, in the review's order:**
  - 57cb02a N1 + N2: `BvTimeWheel`, every time picker; "in the morning" gone.
  - d0de023 N4: "Move to…".
  - b9b26c9 N5: SORT.
  - 05cfe56 N3 server: migration 49.
  - f3cdde8 N3 app: hold and move.
- **N1 + N2:**
  - `lib/shared/widgets/bv_time_wheel.dart`: the hour (1–12) and the minutes in 5-minute steps, as snapping wheels.
    - The chosen row sits between two lines in the main text size; the rows around it fade; each step gives a light haptic.
    - AM / PM is one single choice above («ص / م»). Nothing is typed, and there's no clock face.
    - Arabic: Western digits, the time read as 9:05.
    - Each wheel is an adjustable control for screen readers.
  - Used by all six time pickers: due, Remind me, pin until, activity start and end. A guard test fails on any `showTimePicker` left in `lib/`.
  - Remind me: "In the morning" is removed from both ARB files and the code, so its Cancel now cancels.
    - A time already passed today is greyed and can't be chosen.
    - New times start at the next 5-minute mark an hour on.
  - Changed test: `note_page_test` B5 asserted the "In the morning" button, which N1 removes. It now asserts the wheels and a plain Cancel.
- **N4:** the selection bar's Move (entries and lines) and the page picker's title read "Move to…" / «نقل إلى…», with the same icon. The pages list's "Move into…" is unchanged.
- **N5:** SORT is the Filter card's third part.
  - Pages list: Latest activity · Name A–Z · Newest created, with pinned pages on top.
  - Inside a page: Newest first · Oldest first.
  - Kept on the phone: once for the pages list (`notebook_sort_pages`), and for each page on its own (`notebook_sort_page:<id>`).
  - A sort that isn't the default shows as a chip, and its ✕ resets it.
  - Name A–Z keeps each alphabet together, the app language's first.
  - Five Phosphor icons added (clock-counter-clockwise, text-aa, calendar-plus, sort-descending and sort-ascending), checked against the bundled font.
  - `BvMenuItem.checked`: a menu row can carry its own check.
- **N3:**
  - **Migration 49** (`20261110120000_note_day_position.sql`): `notes.day_position`, plus `arrange_day(p_ids)`.
    - Owner only; not across pages or days; each entry once.
    - pgTAP `49_note_day_position` (19 checks), including that someone else's entry can't be arranged and that someone else can't move Omar's.
    - **Applied to the local stack only.** Not live.
  - **The app:**
    - Hold and let go selects, as before.
    - Hold and move: the card lifts into the overlay and follows the finger, clamped to its day. The others slide aside in 180 ms, a line shows where it lands, and the page scrolls itself at an edge.
    - Let go: "Moved · Undo", and the order is saved through the notebook's queue.
    - Not while entries are selected. Pinned and archived entries don't move. A sideways drag is still a swipe, and a drag without a hold a scroll.
    - Screen readers get Move up and Move down. Reduce motion: no lift, no slide, but the move works.
    - Each day keeps its hand order in both sorts; entries added later come in by time.
  - **A limit for the lead:** a day with more entries than fit on the screen plus its margin can't be arranged by dragging, because its off-screen rows aren't built. Move up and Move down still work there.
- **Checks on the branch:**
  - `flutter analyze`: no issues.
  - `flutter test`: 2,389 pass.
  - `supabase test db`: 3,038 checks in 48 files pass.
  - `flutter test test_screens`, not updating: 446 pass and 6 fail.
    - The 6 are **not accepted**: BH2-entry-selected, BH4-share and BH12-line-selected, EN and AR.
    - Each changes only the selection bar's label, "Move" → "Move to…" (N4), about 850 px. Before/after crop: `BH2_bar_before_after.png` in this session's scratchpad; the six diffs are kept there too.
  - New shots:
    - `docs/screens/r102/N2-time-wheel`, `N5-page-filter` and `N5-sort-chip` (EN, AR);
    - BH9-filter (EN, AR) remade with SORT, as the review asks.
- **Found, not fixed (already on slice2-app 19da7f6):** a one-line entry's swipe actions overflow by 2 px (RenderFlex). The N3 swipe test uses the sample page's taller entry.
- **Local stack:** migration 49 is applied. For the SQL checks, the busy seed and its test phone were removed; reload with `supabase/dev/seed_busy_space.sql`.
- **Next:** the lead's check of review 102. For the six N4 shots: update them if the label is right. Migration 49 goes live only with the founder's yes.
- **Who has which branch:** PC has `claude/r102-notebook` (worktree `BuildVibes-r102`), `slice2-app` (worktree `BuildVibes-slice1`), and `claude/r101-lists`, `claude/r101-search-wait` and `claude/r100-redesign` (all merged).

## PC update: 28 Oct 2026 — review 101 merged into `slice2-app`; build 701 on the founder's phone

**Standing rule (review 74):** nothing but the BuildVibes build goes on the founder's phone without his yes in chat.

**After any Flutter upgrade, run the Daybook tests and test_screens before anything else. The Daybook paints its rows with custom render classes (review 101).**

- **The founder's yes (28 Oct), the lead's second check (K1–K3), then:**
  - **K1** (bf414b3): a tap on a card's paper clip never goes to the card above, and on its own card goes to that card. The middle of each of three stacked cards hits that card. EN and AR.
    - Measured: the clip reaches out of its card over the 12 px gap and the card above's shadow. It stops 4 px short of that card's slip.
    - A tap on the tip lands in the gap, as on the old page; tap areas are unchanged.
  - **K2** (bf414b3): a guard test fails if the Daybook stops using `_RenderNowViewport`, `_RenderPageGroup` or `_RenderSliverListTopDown`. It failed on the old Daybook and passes now. The upgrade line is in `CLAUDE.md` and above.
  - **K3** (23ef4a5, `integration_test/busy_space_perf_test.dart`, local only). Setup:
    - `flutter drive --profile` on the Pixel 8 emulator (x86_64, Impeller on OpenGLES), against the local stack with `seed_busy_space.sql`.
    - Not on the founder's phone: a profile build is signed with the debug key, so it can't install over his release app without uninstalling it and wiping his data.
    - Two runs each. Opening = from opening the Space to its first card. Fling = up through all 500 posts, to the oldest.
    - **slice2-app 510b834:** open 789 / 743 ms. Fling: 2,689 / 2,740 frames; build over budget 516 / 502; raster over budget 286 / 276. Average build 9.4 / 8.9 ms (90th 19.5 / 18.9, worst 208 / 89). Average raster 10.9 / 10.7 ms.
    - **claude/r101-lists:** open 677 / 185 ms. Fling: 3,900 / 3,867 frames; build over budget 0 / 0; raster over budget 1,903 / 1,901. Average build 0.75 / 0.82 ms (90th 1.3 / 1.4, worst 9.3 / 12.9). Average raster 16.0 / 16.0 ms.
    - Build work fell to almost nothing. Raster time per frame rose to about the frame budget on this emulator.
    - With the per-row repaint boundaries put back, raster was the same (2,017 over budget), so those aren't the cause.
    - Emulator raster runs on this PC's GPU through OpenGLES translation: a phone reading is still to come.
- **Merged into `slice2-app`:** `claude/r101-search-wait` (89d90af), then `claude/r101-lists` (25bc211; handoff and progress resolved by hand). Pushed.
  - On the merge: `flutter analyze` no issues; `flutter test` 2,332 pass; `flutter test test_screens` 446 pass, not updating.
- **Build 701** (25bc211, release, signed with the upload key, prod env): on the Desktop as `BuildVibes-701.apk`, and installed on the founder's Xiaomi 22120RN86G over 686 (versionCode 701). BuildVibes is the only package of ours on it.
- **No database push, no deploy.** There's no database change in review 101.
- **On the local stack only:** the busy seed is loaded, and its lead (`busy.lead@example.com`) has the local test phone 96550000002 for K3's sign-in.
- **Next:** the lead's check of build 701; a phone reading of K3 when a phone without the release app is at hand.
- **Who has which branch:** PC has `slice2-app` (worktree `BuildVibes-slice1`), `claude/r101-lists` and `claude/r101-search-wait` (worktrees `BuildVibes-r101`, `BuildVibes-r101b`; both merged), and `claude/r100-redesign` (worktree `BuildVibes-r100r`, merged).

## PC update: 28 Oct 2026 — review 101 Part A done on `claude/r101-lists` (option 1); for the lead

**Standing rule (review 74):** nothing but the BuildVibes build goes on the founder's phone without his yes in chat.

- **Branch:** `claude/r101-lists` (worktree `BuildVibes-r101`), from `slice2-app` 510b834, pushed. Nothing merged, nothing live, nothing installed.
- **Commits:** 3cb8160 (Daybook), 683120b (notebook page), b877c13 (the seed), and this handoff.
- **Checks on the branch:** `flutter analyze` no issues; `flutter test` 2,324 pass; `flutter test test_screens` 446 pass, **not updating, no shot changed**.

**The Daybook (lead's option 1, the clip kept by painting order):**
- A `CustomScrollView` with a centre sliver at Now (anchor 1): older days grow up from it. No `reverse: true` list. The clip is not moved or redrawn.
- A centre alone doesn't keep the order: Flutter paints a list's rows in index order, and growing up from Now index 0 is the newest. So the rows' list and the page (rows, then the writing card) paint top to bottom, as the page always did, and hit-test the other way. Layout is Flutter's own (`RenderSliverList`, `RenderSliverMainAxisGroup`).
- Three more things were needed for the shots to stay the same:
  1. Rows have no repaint boundary of their own (`addRepaintBoundaries: false`). With one, 18 Arabic shots changed by tiny amounts (most by one colour level in a few pixels).
  2. Flutter's reveal (`ensureVisible`, a field kept above the keyboard) leaves out the anchor, so with Now at the foot it landed a screen off. The Daybook's viewport puts the anchor back, and on this page an alignment of 0 is the foot, as it was.
  3. The masthead's day is read once the page is laid out where it scrolled (D-F20 named Today instead of Wednesday).
- The new 500-post test: failed first (30 cards built on opening; all 500 after a jump to post 450), passes now.

**The 47 tests, now passing.** Each goes to the card it checks (`scrollToRow`) or reads the whole page from its top to Now in screen order (`readPage`, `pageKeys`). Both are in `test/helpers/daybook_rows.dart`. No assertion was removed. Each test, with what it asserts before → after:
- `daybook_test.dart`:
  1. One card per work item: sleeves below rebar by `getTopLeft` (rebar off screen) → sleeves after rebar in the page's screen order, rebar on the page; "2 slips" counted in the tree → counted down the page.
  2. History, latest three; Show earlier: tap straight after `ensureVisible` → `pumpAndSettle` between them (slivers move at layout); the rebar scrolled on screen before its lines are read. Same assertions.
  3. Past the first 50: as 2, twice. Same assertions.
  4. One trace on Wednesday: 1 trace and the dividers [Wednesday, Today] read in the tree → read down the page, in screen order.
  5. A trace on each earlier day: times [Mon 9:00, Tue 15:00] and 3 dividers in tree order → in screen order; scrolled to Monday's trace before the tap.
  6. Made on an earlier day, no trace: 0 traces and 2 dividers in the tree → down the page.
  7. needs_me: each card read where it was → each scrolled on screen first. Post-none is asserted on the page before "no clip, no action", so that check isn't empty. Added: `_card('post-none')` finds one.
  8. Slice 2, announcement and report: 1, 1, 0 texts and 3 slips in the tree → down the page.
  9. Scrolling back loads older pages: "Item 0" found off screen → scrolled to the top where it is, then found.
- `daybook_fresh_test.dart`:
  10. F11, reading older days: one 500 px drag, then the first older item in the tree (it was off screen) → 500 px drags until an older item is on screen. Then the same checks: its place doesn't move, New shows, and New takes you to Now.
  11. A new event moves a card to Now: an item measured only if built; its trace on its old day found off screen → one, down the page.
  12–15. F17 (no signal then back; sent but not read back; reopened ×2): "one card", the label or none, in the tree → down the whole page.
- 16. `daybook_kinds_test.dart`, K1 ticking moves the checklist to Now: below rebar by `getTopLeft` → after rebar in screen order.
- 17. `daybook_live_test.dart`, my own post at Now at once: each card scrolled on screen before it is read; after rebar in screen order.
- `daybook_loop_test.dart`:
  18. `_longPress` (X1 and the other long-press tests) scrolls the card on screen first.
  19. F16, a Viewer's short press: scrolls to the rebar first.
- `daybook_part_d_test.dart`:
  20. F23/F59, the masthead: 2 dividers in the tree → down the page; each divider's visibility read where it is built.
  21. F59, nothing yet today: yesterday's divider was visible at Now, read off screen. Now the page is moved up to just short of leaving Now; the masthead still says Today (added assertion), and the divider, built there, is visible.
- `daybook_writing_test.dart`:
  22. E3, Post sends create_work_item: the posted card and no label, in the tree → down the page.
  23. No signal, the slip waits: the title and the label, in the tree → down the page.
- 24. `post_refs_test.dart`, number then kind: `scrollUntilVisible(card, 200)`, whose direction came from the old upward list → `scrollToRow`.
- Shot tests: none changed.

**The notebook page:**
- `ListView.builder`: a row at a time, each with its key, so a row keeps its swipe and selection as rows come and go above it.
- Opened at an entry (Filter, search), the page scrolls until the entry is built, then puts it near the top as before.
- The new 300-entry test (`test/features/notebook/notebook_long_page_test.dart`, EN and AR): all 4 checks failed first, and pass now.
  - Note for the lead: the old `ListView(children:)` already built its elements lazily, so "only what shows is built" held before. The eager part was making all 300 entry widgets on every build, so the test also asserts a builder delegate.
  - The jump to entry 250 did fail before: the entry was never built, so the page never reached it.
- No existing notebook test needed a change.

**The seed:** `supabase/dev/seed_busy_space.sql`, **local only**.
- One Space of 500 posts of every kind over 30 days, with sign-offs, checks and photo placeholders.
- One notebook of 5 pages with 60 entries each.
- Run on the local stack inside a rolled-back transaction: 500 posts, 300 entries, and nothing left behind.

- **Next:** the lead's check of Part A, with the test list above. Part B (`claude/r101-search-wait`, d116b5e) is approved and waits for the next build's merge.
- **Who has which branch:** PC has `claude/r101-lists` (worktree `BuildVibes-r101`), `claude/r101-search-wait` (worktree `BuildVibes-r101b`), `slice2-app` (worktree `BuildVibes-slice1`) and `claude/r100-redesign` (worktree `BuildVibes-r100r`, merged).

## PC update: 28 Oct 2026 — review 100 live (migration 48, notebook-purge, build 686 on the phone)

**Standing rule (review 74):** nothing but the BuildVibes build goes on the founder's phone without his yes in chat.

- **Live (founder's yes, 28 Oct), the lead's second check, steps 1-8 done:**
  1. `claude/r100-redesign` merged into `slice2-app` (15b7932, pushed). Checks on the merge: analyze clean; 2,316 app tests; 3,019 SQL checks; test_screens 446, not updating.
  2. Before: 10 notes, 4 notebook pages.
  3. Migration 48 pushed, the only file (dry run and push). The pg-delta certificate warning followed, as for migration 46; `migration list` shows 48 on both sides.
  4. Read-only check passed: counts the same; no note deleted or archived; 24 new functions, all `security definer` with `search_path=""`; signed out, `search_notebook` and `my_deleted_items` refuse.
  5. Deno 2.9.8 installed; `deno check supabase/functions/notebook-purge/index.ts` clean.
  6. `NOTEBOOK_PURGE_SECRET` in the function secrets and Vault (`notebook_purge_secret`); they match. Not in the repo or a chat.
  7. `notebook-purge` deployed (v1, verify_jwt off). Cron job `notebook-purge`, 03:15 UTC, active.
  8. By hand: "purged 0, files 1, waiting 0". The one file was a stored notebook file no entry used (a day old at least); notes, pages and `note_files` rows are unchanged.
- **Step 9 done:** build 686 (15b7932, release, upload key) is **installed on the founder's Xiaomi** (22120RN86G, 192.168.8.33:33547, versionCode 686 over 659, BuildVibes only), and on the Desktop as `BuildVibes-686.apk` for testers.
- **Worktrees:** -db29 removed (line endings only); the throwaway push worktree removed. Left: main, -r100r, -slice1.
- **Who has which branch:** PC has `slice2-app` (worktree `BuildVibes-slice1`) and `claude/r100-redesign` (worktree `BuildVibes-r100r`, merged).

## PC update: 28 Oct 2026 — review 100 J1–J4 done on `claude/r100-redesign`; stopped for the lead

**Standing rule (review 74):** nothing but the BuildVibes build goes on the founder's phone without his yes in chat.

- **Branch:** `claude/r100-redesign` (worktree `BuildVibes-r100r`), pushed. **Not merged, no database push, no deploy, nothing installed.** No new migration: J1–J3 are edits inside migration 48, which isn't live.
- **Done (commit 0ef35a2), each test seen failing first:**
  1. J1: `share_note_to_person` cuts at 3,000. The preview says "Too long for a message: share it to a Space, or shorten it." and Send is off.
  2. J2: to-dos are written as `[ ]` and `[x]` in a Space post, a feed post and a message (server `note_words`, and the app's `shareText`, which the preview's length check uses). A checklist is still real points. A received message shows no ☐, ☑ or ≡.
  3. J3: `export_my_data`'s notebook pages carry `named`.
  4. J4: Restore is `BvButtonStyle.quiet` (grey words, the ↺ arrow, no box), which mirrors in Arabic. The frame (`2635:38668`) draws a small grey pill; J4's "no box" is followed.
- **Found and repaired (commit ed30a3c):** the shots commit 7cdb212 stored 56 PNGs with their `\r` bytes stripped (a line-ending fix run over binary files), so test_screens failed with "Invalid image data". They were shot again on the same code: the 44 older ones match their copies in `docs/screens/r100/before-after/` pixel for pixel; the 12 r100 ones (BH2–BH5, BH7, BH9 and PG8) had no other copy, and PG8 now shows J4. All 640 committed PNGs now start with the right header.
- **Checks:** analyze clean; 2,316 app tests; 3,019 SQL checks in 47 files; test_screens 446 pass, not updating.
- **Housekeeping (as review 100's second check wrote it):** -f100, -f100b, -f102, -f105, -phone: `git checkout -- lib/l10n/gen`, then `git worktree remove`. -f102 and -phone stopped on Windows' path length after git had unregistered them, so their folders went with the same long-path `rmdir` as -f107 and -icon (both gone). Local branch `r100-lf` deleted. -db29 kept: its diff is line endings only (CRLF in the working copy; empty with `--ignore-cr-at-eol`). The local branches f100, f100-broadcast, f102, f105, f60-photo-reencode are kept, and nothing on GitHub was deleted. `BuildVibes-apk` isn't a worktree, so it wasn't touched.
- **Next:** the lead's check. Then, with the founder's yes, the live steps.
- **Who has which branch:** PC has `claude/r100-redesign` (worktree `BuildVibes-r100r`), `slice2-app` (worktree `BuildVibes-slice1`) and `slice2-live-db` (worktree `BuildVibes-db29`).

## PC update: 28 Oct 2026 — review 100 H1–H22 done on `claude/r100-redesign`; stopped for the lead

**Standing rule (review 74):** nothing but the BuildVibes build goes on the founder's phone without his yes in chat.

- **Branch:** `claude/r100-redesign` (worktree `BuildVibes-r100r`), pushed. **Not merged, no database push, no deploy, nothing installed.** No new migration; the Copy mark is dropped (ruling 6).
- **Done:** H1–H8 (bugs, each with a failing test first, EN and AR), H9–H21, and H22 (the shots). The commits: e5adaa0 (Share: H1, H2, H11, H13, H14, H20), 99f06fe (H3–H8), da497d3 (H9, H10, H12, H15–H19, H21), 7cdb212 (the shots).
- **Checks:** analyze clean; 2,309 app tests; 3,012 SQL checks in 47 files; test_screens 446 pass after the re-shoot, the same on a second run.
- **H22, the older shots:** before/after for each changed one in `docs/screens/r100/before-after/` (`<folder>_<shot>_before.png` / `_after.png`). Beyond the bar, rows and cards:
  1. every new entry's top bar now has Discard (Part 0);
  2. the location line reads "on the map", and the NBX4 panel's words have no GPS (H12);
X
  4. slice 10's two shots start a little lower on the page (the page's title row now shows above the list);
  5. slice 8's shot is now Share → Space's preview (re-pointed).
  Retired: NBW3, NBW4, NBW5 (tests and goldens).
- **Found on the way (fixed, test first):** the Share preview drew a to-do as ☐, which the app's fonts lack (it showed as "≡"); it now draws the app's box, as BH5 does. The server still sends ☐ / ☑ in the shared text; the receiving app draws them in the same fonts, so the lead may want the server text checked.
- **Also for the lead:**
  1. Restore in Deleted items is the BV secondary button (bordered), larger than PG8's small grey pill (H19).
  2. `share_note_to_person` cuts the text at 4,000 characters, while `dm_post` refuses past 3,000: a long entry sent to a person is refused (said in the preview, H1). Server-side; no migration made.
  3. H17's Arabic words were changed before their test first ran, so that test never failed first.
- **Housekeeping (founder, 28 Oct):** worktrees removed (clean, on GitHub): BuildVibes-build, -f106, -f108, -hold, -r100, -r95, -r99a, -r99b, -rejoin, -slice10, -store. Kept with uncommitted changes: -db29 (a review doc), -f100, -f100b, -f102, -f105, -phone (generated l10n files). `BuildVibes-f107` and `BuildVibes-icon` are unregistered but their folders are left on disk (Windows' path length stopped the delete). No branch deleted, on GitHub or locally.
- **Next:** the lead's check. Then, with the founder's yes, the live steps in "Build of the redesign (27 Oct)".
- **Who has which branch:** PC has `claude/r100-redesign` (worktree `BuildVibes-r100r`) and `slice2-app` (worktree `BuildVibes-slice1`). The local branch `r100-lf` can be deleted.

## PC update: 28 Oct 2026 — review 100's redesign built on `claude/r100-redesign`; stopped for the lead

**Standing rule (review 74):** nothing but the BuildVibes build goes on the founder's phone without his yes in chat.

- **Branch:** `claude/r100-redesign` (worktree `BuildVibes-r100r`), from `slice2-app` 1283413, pushed. **Not merged, no database push, no deploy, nothing installed.** It uses migration 48's functions, which aren't live: the build only works against a database with 48.
- **Built, in the review's order** (one commit per step, tests first, EN and AR): Part 0 and the selection bars (BH2, BH12); swipe and Archive (BH3); the compact card, the bar and `+` (BH6–BH8, BH10), Discard and Done; the pages rows and round New entry (BH1), Filter and search (BH9, BH11); Share with previews (BH4, BH5); Deleted items (PG8).
- **Checks:** analyze clean; 2,265 app tests; 3,012 SQL checks (local reset); 26 new shots `docs/screens/r100/` (BH1–BH12, PG8; EN, AR).
- **Older shots (not updated, for the lead):** 48 notebook shots differ. 40 are pixel changes from the new bar, rows and cards (NBW1, NBX1–NBX3, L1–L3, NBY1–NBY5, PG1–PG5b). 8 can't run because their scripts drive what the redesign removed: NBW3, NBW4, NBW5, NBX4 (the old bar's Date/Remind/Location), slice 10's Remind me (the entry ⋯), slice 8's Put in a Space.
- **Differences from the frames and choices made (for the lead):**
  1. BH5: the To row has no avatar or ▾, and there's no "From Islam's notebook · 10:40 am" line: the message the server sends has neither.
  2. BH7: the reminder's value reads "tomorrow 7:00 am" and is cut ("tomorrow 7…"); the frame has "Fri 7:00".
  3. BH7, BH9: the 📎 and Filter cards draw grey icon tiles (the review 98 card); those frames draw plain icons. BH9's card ends under the Filter button, not at the screen margin, and has no scrim.
  4. BH10: a numbered line keeps Continue numbering / Restart at 1 in ⋮⋮ (Part 0's table lists only five rows; nothing else gives Restart).
  5. BH12: Share shows only for lines of a saved entry whose lines are all on the server (the share functions work on a saved entry); the frame shows it on a new entry.
  6. Duplicate's "Copy" mark is kept on the phone only (no column for it; no migration made).
  7. Callout is left out of `+` and `/` (Part 5's groups don't list it); it stays in Turn into.
  8. Space share: no Team picker; a work item or checklist is for me. No project tag on Feed.
  9. Deleted items opens from a quiet row at the pages list's end (BH1 has no fourth top-bar icon).
  10. The location panel (NBX4) still says GPS in its own rows; every other place reads "on the map".
  11. Restore uses the counter-clockwise arrow; the notebook's Arabic groups read «النصوص · القوائم · الإدراج» («نص» was also the Text row).
- **Next:** the lead's check of `claude/r100-redesign`. Then, with the founder's yes: merge into `slice2-app`; migration 48 alone, the read-only check, `deno check` and the `notebook-purge` function with its secret, the cron job; then one build.
- **Who has which branch:** PC has `claude/r100-redesign` (worktree `BuildVibes-r100r`) and `slice2-app` (worktree `BuildVibes-slice1`). A local branch `r100-lf` (the same commits rewritten in LF, kept only because a force-push was refused) can be deleted.

## PC update: 27 Oct 2026 — review 99B server merged into `slice2-app`; migration 48 NOT live; F1 done

**Standing rule (review 74):** nothing but the BuildVibes build goes on the founder's phone without his yes in chat.

- **Branches:** `claude/r99b-server` is merged into `slice2-app`. Both branches are pushed. Neither is deployed to the live database, and nothing is installed on the founder's phone.
- **F1 (Download my data) done in migration 48:**
  - Updated `export_my_data(p_request uuid)` in `supabase/migrations/20261109120000_notebook_deleted_share.sql` to include:
    - `notebook_pages`: user's notebook pages (`id`, `title`, `icon`, `color`, `parent_id`, `position`, `created_at`, `updated_at`);
    - `notes`: carrying each entry's `page_id`, `deleted_at`, and `archived_at` alongside existing entry fields;
    - `note_shares`: note share records (`note_id`, `destination`, `target_id`, `created_at`);
    - `profile_private`: `notebook_keep_days` choice (7, 30, or 90 days; default 30).
  - pgTAP tests in `supabase/tests/48_notebook_deleted_share.test.sql` extended from 131 to 149 tests (testing payload structure, pages, entries with `page_id`/`deleted_at`/`archived_at`, `note_shares`, and retention keep-days).
- **Migration 48, `20261109120000_notebook_deleted_share.sql` (NOT LIVE):**
  - **Deleted items (99B B3):** `notes.deleted_at`, `delete_entries`, `delete_note_lines`, `my_deleted_items`, `restore_items`, `delete_forever`, `empty_deleted_items`.
  - **Keep for 7 / 30 / 90 days:** `profile_private.notebook_keep_days` (default 30), set by `set_notebook_keep_days`.
  - **Daily purge:** `purge_notebook()`, service role only. Edge Function `supabase/functions/notebook-purge` NOT deployed; cron in `supabase/ops/notebook_purge_cron.sql` NOT run.
  - **Archive:** `notes.archived_at`, `archive_note`, `unarchive_note`.
  - **Share:** `note_share_text`, `share_note_to_space`, `share_note_to_feed`, `share_note_to_person`, tracking in `note_shares`.
  - **Filter:** `search_notebook(p_q, p_kind, p_page)`.
  - **Base version:** `notes.version` concurrency check (40001 "changed on another phone").
  - **App fix:** heading picked with "/" inside a toggle is drawn (`test/features/notebook/toggle_heading_test.dart`, EN and AR).
- **Checks on both branches (`claude/r99b-server` and merged `slice2-app`):**
  - `supabase test db`: 3,012 pass in 47 files (all 149 tests in `48_notebook_deleted_share.test.sql` pass).
  - `flutter analyze`: no issues.
  - `flutter test`: 2,170 pass.
- **Who has which branch:** PC has `slice2-app` (worktree `BuildVibes-slice1`) and `claude/r99b-server` (worktree `BuildVibes-r99b`). Both pushed to `origin`.

## PC update: 27 Oct 2026 — review 100 bugs merged into `slice2-app`; build 659 on the founder's phone

**Standing rule (review 74):** nothing but the BuildVibes build goes on the founder's phone without his yes in chat.

- **The lead's third check is applied on `claude/r100-bugs`:**
  - **The text cursor:** F78-new-message (EN, AR) and NBX2-categories (EN, AR) now draw it steadily (`steadyCursor()` in `test_screens/shot.dart`, which sets `EditableText.debugDeterministicCursor`). Their shots came out identical on two runs and are accepted.
  - **NBY1-slash-num (AR) and PG4-page (AR)** are accepted as they are.
  - **Not done as written:** the setting is scoped to those two tests. In `test_screens`' test config it would change **58 shots**, because every shot with a focused field would draw its cursor. That is for the lead to decide.
- **Merge:** `claude/r100-bugs` merged into `slice2-app` (a fast-forward to 68af86d) and pushed. Checks on the merged branch:
  - `flutter analyze`: no issues;
  - `flutter test`: 2,168 pass;
  - `flutter test test_screens` (not updating): 426 pass.
  - No database change.
- **Build 659** (68af86d, versionCode 659, versionName 0.9.0) is built.
  - **A copy is on the PC's Desktop:** `C:\Users\PathFinder\Desktop\BuildVibes-659-test.apk`. Same file (hash checked); not uploaded or emailed.
  - **Installed on the founder's phone** (27 Oct, 09:22): the phone was paired again (wireless debugging with a pairing code) and connected at 192.168.8.24:35403. Model 22120RN86G; versionCode 659, versionName 0.9.0; BuildVibes only.
- **Who has which branch:** PC has `slice2-app` (worktree `BuildVibes-slice1`). `claude/r100-bugs` is merged; the worktree `BuildVibes-r100` can be removed.

## PC update: 27 Oct 2026 — review 100 E1 on `claude/r100-bugs`; shots run, 6 change, none accepted; stopped for the lead

**Standing rule (review 74):** nothing but the BuildVibes build goes on the founder's phone without his yes in chat.

- **Branch `claude/r100-bugs` is pushed.** It is not merged and not live; nothing is installed and nothing changes in the database.
- **E1:**
  - `bv_theme.dart` now sets `pageTransitionsTheme`: Android `PredictiveBackPageTransitionsBuilder`, iOS `CupertinoPageTransitionsBuilder`. A test checks the theme carries both.
  - **Note for the lead:** the test passed before the change too. These two builders are already Flutter 3.44.2's defaults, so Android's predictive preview should already show. Naming them guards against a future default.
  - If the phone still doesn't show the screen underneath, the next suspect is the phone itself: on Android 14, predictive back animations sit behind a developer option.
- **Checks:**
  - `flutter analyze`: no issues;
  - `flutter test`: 2,168 pass;
  - `flutter test test_screens`, not updating: 420 pass and 6 change.
- **The six changed shots:**
  - F78-new-message (en, ar) and NBX2-categories (en, ar): the text cursor is caught visible;
  - NBY1-slash-num (ar): the "/" card sits about a pixel off (D5/D6);
  - PG4-page (ar): each entry's ⋯ sits about a pixel off (D10).
  - The same six change at `b79fc38`, before E1.
  - None is accepted. Before/after pictures and one line each are in `docs/screens/r100/before-after/E1-run*.png` and `E1-run.md`.
- **Next, with the founder's yes:**
  1. Accept the shots (or the lead's call).
  2. Merge into `slice2-app`.
  3. One release build on his phone.
- **Who has which branch:** PC has `claude/r100-bugs` (worktree `BuildVibes-r100`) and `slice2-app` (worktree `BuildVibes-slice1`).

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