# Handoff

Where the work stopped, for whichever place picks it up next: the founder's PC, a cloud session, or the lead's chat in the Claude project. Each session rewrites this file before it stops. The full history stays in `progress.md`.

## Last update: 20 Oct 2026, evening, cloud session (branch `claude/test-tw7wuv`)

The branch now carries **everything**: `slice2-live-db`, `slice2-app`, review 63, migrations 29 and 30, and the app work below. It merges cleanly into `slice2-app`, `slice2-live-db` and `main`.

**Done here (database):**
- Review 63 (`docs/reviews/2026-10-20-63-migration29-review.md`): migration 29 approved once R1 and R2 are in.
- R1 and R2 applied to migration 29 (`20261020120000_slice2_live.sql`, still **not live**):
  - R1: the chat's `thread:<id>` channel may be joined by whoever `can_use_thread` (receive only);
  - R2: only Got it takes a new time after an edit, and Received keeps its first time.
- Migration 30 (`20261021120000_report_notes.sql`, **not live**), notes in the daily report:
  - `daily_report_notes` lists the day's notes for the "On site" suggestions;
  - a report's `item_ref` can point at a note;
  - each ref says its kind and status.
- 2,193 SQL checks in 30 files pass on the stand-in (`supabase/dev/standin/`).
- Founder's yes (20 Oct, "I will go with your recommendation") covers two steps:
  - the migration 29 push;
  - turning off public channels later, once the private-channel build is on every test phone.
  
  Migration 30: founder's yes (20 Oct, "Ok" to the recommendation). Push it right after migration 29, once the PC's checks pass.

**Done here (app, Flutter 3.44.9):**
- Private live channels, `daybook:` and `thread:` (`private: true`), and at most one page read a second per Space (R3).
- The Note (F58, K5 v13 2598:36260 and E6 v14 2598:36360):
  - first in the kind menu, with "For information, nobody needs to act";
  - posts with nothing more to set;
  - the card says "· note" and has no buttons;
  - its author can Edit and Cancel it.
- Unpin for the admin acting for a gone author, never Edit (N2).
- `my_ack_at`: an announcement edited after my Got it opens again (G1).
- F57: no Late line, and a passed due shows in the action colour for its owner and author only; once signed as done the due leaves the card.
- F56, one who-flow:
  - the who row shows from the start;
  - Post stays grey until it is filled, and a tap pulses it with "Choose who it's for";
  - pickers never post;
  - "Just for information? Post as a Note" under the owner picker;
  - a scheduled activity now needs who's coming.
- F54 on checklist points:
  - a light haptic, the check fills, and who and when slide in;
  - someone else's tick glows, then fades;
  - nothing moves with the phone's animations off.
- Later the same evening (item 2):
  - F56: an announcement and a Document for receipt show "To: Everyone ›". A single choice picks Everyone or one Team: your own Teams, or any Team for a Space admin, as the server allows.
  - F57: the Due today strip keeps open items from up to 61 days back, oldest first. An earlier day shows its day in grey ("Wed"), never "late".
- `flutter analyze` is clean, and 1,269 app tests pass.
  - 10 tests fail **here only**, and the same 10 fail on the untouched `slice2-app` in this container. Each renders a PDF (pdfx can't run on Linux): K2 file card ×4, F47 live ×4, F48 ×2. Run them on the PC.

**Not done:**
- The screens haven't been checked by eye in EN and AR at 390×844, or on a phone. Screenshots and goldens weren't re-shot. (PC)
- Waits for its slice (nothing to tick or show yet):
  - F54 on a work item's points (slice 5, opening a post);
  - F54 on Notebook to-dos (slice 8);
  - the daily report offering notes under "On site", plus F57's "never N late" in reports (slice 7, templates and daily report).
  
  The server side of the daily report (migration 30) is ready.

**Slice 2 for the founder's retest is commit `a2e330f`** (the founder's choice, 20 Oct: slice 3 is built in the cloud on the same branch, after it). Build slice 2 from that commit, not from the branch head: `git tag slice2-candidate a2e330f`, then build from the tag. Everything after it on the branch is slice 3 or its server work, in commits named "Slice 3 …" or "Migration 31 …".

**Next, on the PC (in order):**
1. `git fetch`. Merge `origin/claude/test-tw7wuv` into `slice2-live-db` and into `slice2-app`.
2. Run `supabase test db`; 2,193 should pass. Then check against the local Realtime server:
   - a private `daybook:` and `thread:` join works for a member and is refused for an outsider;
   - with public access off, a chat message still arrives live.
3. Push migration 29 to the live database. `supabase db push` must list only `20261020120000_slice2_live.sql`. Do the read-only check after, then merge `slice2-live-db` into `main`.
4. On `slice2-app`:
   - `flutter analyze`, then `flutter test`; the 10 PDF tests should pass on Windows;
   - check the Note, the kind menu, the who row, the due colours and the tick feel in EN and AR;
   - re-shoot the screenshots, make a build, and give it to the founder to test.
5. The "Not done" list above.
6. Migration 30 (founder's yes given): after migration 29 is live and `supabase test db` passes, push it. `supabase db push` must list only `20261021120000_report_notes.sql`, and the read-only check follows.
7. Turn off public channels on the live project, only after the step 4 build is on every test phone.

**Also done in the cloud (evening, after the handoff above):**
- A Figma check of today's new screens, with two fixes, and screen tests for K5, F56 and F57 (`test_screens/slice2_test.dart`):
  - the Note shows its words before its photos (K5 v13);
  - the kind menu is wide enough for its small lines (E6 v14).
  
  The committed PNGs were **not** re-shot here: Linux fonts differ slightly, so the PC re-shoots them (`flutter test test_screens --update-goldens`).
- The slice 3 plan: `docs/reviews/2026-10-20-64-slice3-plan.md`. It has no code, and the build starts only after the founder's slice 2 retest passes. It needs a small migration 31 (a private `dm:` channel).

**Night of 20 Oct, cloud (after the slice 2 commit `a2e330f`; founder's choice B):**
- Review 65: an independent review of migration 30, with no high or medium finding. Its three low findings are fixed in migration 30, which is still not live.
- Migration 31 (`20261021180000_dm_live.sql`, **not live**): a private `dm:<thread>` live channel, receive only, for the thread's two people while neither blocks the other. 12 checks; all 2,208 SQL checks pass on the stand-in.
- Slice 3, first part, in commits named "Slice 3 …", checked against DM1, DM2 and DM6 in EN and AR:
  - Messages on Home, beside Search, with a dot (never a number);
  - DM1, the list: the request on top, Today and Earlier, unread cards, previews, search, and + to find someone;
  - DM2, a conversation:
    - the person and what they do, and "Both in <Space>";
    - day chips, text, photos and PDFs, Reply, and live updates on `dm:`;
    - DM3, holding a message: Reply, Copy, and Report or Delete;
    - ⋯: Mute, Report the person, Block;
  - DM6, a request: "Not in your Spaces · Decline · Block", and photos behind Tap to show;
  - Message on a person's profile (R5 v3), and a new conversation whose first message makes the thread (`start_dm`, with the spam guard's pause and warning).
- Analyze is clean and 1,293 app tests pass, apart from the same 10 PDF tests.
- **Later the same night:**
  - Review 66: migration 31 approved, with no high or medium finding. Two checks were added (presence refused, receiving after Decline), and all 2,210 SQL checks pass.
  - Voice notes in direct messages: hold the mic, slide away to cancel, and play in the bubble.
  - S7-N, New chat in a Space:
    - "New group in this Space" (a new Team) for the Space admin only;
    - "Message one person": the Space's people, then Messages.
    
    **For the lead:** the S7-N frame says "Leads and the admin can do this", but `create_team` lets only the Space admin make a Team. The app follows the server and says "The Space admin can do this". If Leads should make Teams, that's a server change.
  - 1,299 app tests pass, apart from the same 10 PDF tests.
  - Later: the test app swaps in a PDF-free preview (`filePreviewProvider`), so those 10 now pass on any machine. **All 1,309 app tests pass.** The Arabic of every new string was checked against the glossary, with four fixes.
  - **Review 67, the slice 4 plan** (People and Library, no code): six EN frames, no Arabic ones. The Viewer's daybook is already built; People, the Library, a file's page and Search are redrawn or new. Server: a small migration 32 (who received a Library file, NEW VERSION for me, search shows only the version in use). Two calls for the lead: nothing chosen first when letting someone in, and no Add file button in the Library (files come through a file post).
  - **Migration 32** (not live): `library_overview`, `library_file_receipts`, `library_file_post`, and `search_space` showing only the version in use. Review 68 approved it after two fixes (a deleted middle version, an index). All 2,251 SQL checks pass. **Founder's yes** (20 Oct, late night): push it after 31 is live, as the only file (`20261022120000_library_receipts.sql`), after `supabase test db` passes, with the read-only check after.
- **Still to build in slice 3, after the slice 2 retest (both use the daybook's writing card):**
  - DM4–DM5, Put in a Space;
  - S8m, Turn into a work item in Space chat.
- **Migration 31: founder's yes** (20 Oct, night), on these conditions, in order:
  1. after migrations 29 and 30 are live;
  2. `supabase test db` passes;
  3. the local Realtime server lets a member join the private `dm:` channel and refuses an outsider;
  4. then `supabase db push`, listing only `20261021180000_dm_live.sql`, with the read-only check after;
  5. and before any slice 3 build goes on a phone.
- **For the PC:**
  - **Migrations:** push 29 → 30 → 31 → 32 from the branch **head**, one file per push (all four have the founder's yes). The head has the review 65 fixes to migration 30, and migration 31 is new.
  - **Slice 2 retest:** build the app from `a2e330f`.

**Business items (21 Oct, founder's "ok" to the recommendations):**
- Drafts of the Terms and Privacy policy for a lawyer in Kuwait: `docs/legal/` (English; Arabic after the lawyer). Blanks for the founder: company name and address, support email, minimum age (recommended 18). Questions for the lawyer marked **[Lawyer]**: data hosted in India (Mumbai), who owns a Space's records, work kept as "Former member".
- Pilot targets, proposed: `docs/product/pilot-targets.md` (80% joined in week 1; 80% active working days; 3 Crew sign off with a photo by week 2; 3 show proof by week 4). The founder approves the numbers.
- `supabase/ops/pilot_targets.sql`: the founder's read-only report for the pilot Space (tested on the stand-in). `pilot_measures.sql` stays for every Space.
- The founder's to-dos: the site's permission for photos (pilot agreement), the Apple and Google developer accounts (in November), and who answers reports (founder, 24 hours, as the Terms say).
- **Photos lose their location before upload (done, 21 Oct):** `lib/core/photo_privacy.dart` empties the EXIF GPS block of a JPEG (orientation and time stay) and drops XMP; PNG and WebP lose EXIF and XMP. It is run on every picker: camera, gallery, Files, profile photo. The Files picker no longer offers HEIC (its location can't be removed on the phone). Checked with a real image reader: GPS gone, the photo opens. **On the PC:** take one photo with location on, post it, download it from Storage and check that it has no GPS.
- Store listing draft, English and Arabic, with the data-safety answers: `docs/store/listing-draft.md`. The quick guide for the pilot team, English and Arabic: `docs/pilot/quick-guide.md`. Both for the lead to check against the app's words.

**Who has which branch now:** nobody is working on any branch. The PC takes `slice2-live-db` and `slice2-app` tomorrow.
