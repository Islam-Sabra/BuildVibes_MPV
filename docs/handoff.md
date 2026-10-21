# Handoff

Where the work stopped, for whichever place picks it up next: the founder's PC, a cloud session, or the lead's chat in the Claude project. Each session rewrites this file before it stops. The full history stays in `progress.md`.

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

**For the PC:**
- `claude/f68b-f69` (F68b, F69): build and test first, as planned; then merge into `slice2-app`. Its screenshots in `docs/screens/f68b/` were git-ignored, so they aren't on GitHub: re-shoot them on the PC, or add `!docs/screens/f68b/` to `.gitignore` on that branch.
- `claude/slice3-rest`: merge into `slice2-app` after the founder tests it (DM4–DM5 and S8m). It overlaps `claude/f68b-f69` only in `test_screens/slice2_test.dart` and the ARB files (both add keys at the end).
- Re-shoot goldens on the PC (Windows fonts).

**Next in the cloud:** slice 4 (People and Library, review 67 with review 69 §1), on its own `claude/` branch.

**Who has which branch:** this cloud session made `claude/slice3-rest`, `claude/f68b-f69` and `claude/all-slices-plan`; all done, nobody on them.

## Last update: 21 Oct 2026, evening, PC session

**Standing rule (review 74):** nothing but the BuildVibes build is installed on the founder's phone without his yes in chat. That includes test apps, helpers and other packages.

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
