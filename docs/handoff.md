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

**Who has which branch now:** nobody is working on any branch. The PC takes `slice2-live-db` and `slice2-app` tomorrow.
