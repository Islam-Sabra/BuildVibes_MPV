# Handoff

Where the work stopped, for whichever place picks it up next: the founder's PC, a cloud session, or the lead's chat in the Claude project. Each session rewrites this file before it stops. The full history stays in `progress.md`.

## Cloud update: 21 Oct 2026, evening — review 72, app part (branch `claude/review72-app`)

**Branch:** `claude/review72-app`, made from `origin/slice2-retest` (so the next test build is slice 2 only), with migration 33's two commits cherry-picked from `claude/review72-db` (`f801dbd`, `41e8079` here; `ef90d0c`, `aea1799` there). `claude/review72-db` was not merged: it carries slice 3.

**Done (review 72 / review 50):**
- **F59:** at Now the masthead reads "**Today** · Thursday 15 October" (AR «**اليوم** · الخميس 15 أكتوبر»), also while writing and when an older card fills the screen. Today's divider is always there above the writing area, with "Nothing yet today" / «لا شيء بعد اليوم» when the day is empty. Every earlier day keeps its divider at Now. Only when scrolled back does the masthead follow the day at the top (F23); then the "Today ↓" chip shows (the New chip wins when new things came in) and takes you back.
- **F61:** the strip is "To do:" / «مطلوب منك:». It is now built from its parts, so an earlier day ("Sun") is always grey and the label and titles stay in the action colour (before, the grey depended on finding the day's word in the text).
- **F62:**
  - no due on a Done card (already so since F57, kept);
  - the author's Needs you row: "Omar Haddad · Done 10:21 · waiting for your check" / «منجز 10:21 · بانتظار تحققك», never red;
  - the send-back sheet has "New date": Today · Tomorrow · Pick a date · No new date (اليوم · غدًا · اختر تاريخًا · بلا موعد جديد), chips, nothing chosen first, and Send back stays off until one is chosen. Pick a date uses the writing card's day and time picker and then shows the day;
  - it calls `send_back(…, p_due_set: true, p_due, p_due_at)`, both null for No new date;
  - the card shows the server's new due (or none); the history line ends "· new date Sat 17 Oct" / "· no new date" from `new_due`.
- **F63:** the kind menu has no description lines (E6 v14).
- **F60:** photos also lose Make, Model, Artist, CameraOwnerName / OwnerName, BodySerialNumber, LensSerialNumber and the maker notes. Orientation and the time taken stay. Checked on a real JPEG with an image reader.
- Test app: the PDF-free file preview (from `claude/test-tw7wuv`), so the PDF tests pass here too.

**Checks:**
- `flutter analyze`: no issues. `flutter test`: **1,296, all pass**.
- SQL stand-in on this branch: **2,217 checks, all pass**. Fewer than review 72's 2,275 because this branch has no migrations 31 and 32 (slice 3 and slice 4 server work) and has migration 30 without review 65's later checks. On `slice2-app` it is 2,275.
- Screenshots for the lead, EN and AR at 390×844, in `docs/screens/review72/` (Linux fonts; the PC re-shoots goldens): F59 masthead at Now with yesterday's cards, F61 To do strip, F62 send-back sheet with the date, F62 a sent-back card with its new date, F63 kind menu.

**For the lead to decide:**
- The "+ more ›" at the end of an overflowing To do strip (F61) doesn't exist; the strip stops at two lines with "…". Not built in this round.
- "No new date" adds "· no new date" to the history line (the review only words the date case).

**Order for the PC:**
1. Migration 33 must be **live before** this build goes on a phone: the new sheet calls `send_back` with `p_due_set`. Push it (founder's yes) as the only file, `20261023120000_send_back_due.sql`, after `supabase test db` on `slice2-app` with `claude/review72-db` merged.
2. Build from `claude/review72-app` for the founder's test (steps 3–7 of build 375 first, then F59, F61, F62, F63, and F60 with a real phone photo).
3. After the founder's test, merge `claude/review72-app` into `slice2-app` (and the PC's `slice2-retest` worktree). Re-shoot the goldens there.

**Trial merge into `slice2-app` (cloud, local only, not pushed):** `git merge origin/claude/review72-app` on `origin/slice2-app` (e5e8589) stops on six files. Settled like this, it passes **1,326 app tests, `flutter analyze` clean, and 2,275 SQL checks**:
- `lib/core/photo_privacy.dart`, `test/core/photo_privacy_test.dart`: take review72-app's (`git checkout --theirs`); it is slice2-app's plus F60.
- `lib/l10n/app_ar.arb`: keep both sides' new keys (slice 3's `messages*`, `dm*`, `chat*`, and review 72's), and drop `daybookDueStripEarlier` (F61 removed it; `app_en.arb` merges by itself).
- `lib/l10n/gen/*`: don't merge by hand, run `flutter gen-l10n`.
- `test/helpers/pump_app.dart`: keep `dmRepositoryProvider.overrideWithValue(fakeDm)` and one `filePreviewProvider` override, and remove the second `daybook_photos.dart` import.
- `test_screens/slice2_test.dart`: keep both blocks (slice 3's S7/S7-N shots, then review 72's), closing the first with `    });`.
- `claude/review72-db` then merges with nothing left to do (the same two commits).

**Who has which branch:** this cloud session has `claude/review72-app` (done; nobody else on it). `claude/review72-db` belongs to the PC.

## Lead update: 21 Oct 2026, noon (cloud, the lead's chat)
- **The build 375 retest so far** (review 50): photo location, step 1 (Due today, run by the lead on the emulator as Omar) and step 2 (the Note) pass. **Steps 3–7 are still to test**, and they go first next time.
- **Review 72** is the next round: F59–F63 (app) plus migration 33. When the founder says "apply review 72", do it on `slice2-app`.
- **Migration 33 is written** (the lead, cloud), on branch **`claude/review72-db`** (from `slice2-app`): the send-back date (F62). It has 24 checks, and all 2,275 SQL checks pass on the stand-in. **Not live.**
  - Merge that branch into `slice2-app` first, then `supabase test db`.
  - Push live only with the founder's yes, as the only file: `20261023120000_send_back_due.sql`.
- **The 3D model views are now migration 34** (review 71).
- **Nobody is working on `claude/review72-db`;** the PC takes it.

## Last update: 21 Oct 2026, PC session

**Done on the PC:**
- `claude/test-tw7wuv` merged into `slice2-live-db` and `slice2-app`; main (reviews 50 and 69, the founder's D1–D6) merged into both. Generated l10n files come from `flutter gen-l10n` and match.
- Local checks: 2,251 SQL checks in 32 files, `flutter analyze` clean, 1,318 app tests.
- Local Realtime check (13 of 13): members join the private `daybook:`, `thread:` and `dm:` channels and receive live; outsiders, and a Space member outside a DM, are refused. With public channels off locally, a public join is refused and a chat message still arrives live.
  - The local Realtime server rewrites its tenant row on every start, so to test "public off" set `_realtime.tenants.private_only` as `supabase_admin` **without** restarting it.
- **Live: migrations 29, 30, 31 and 32**, one file per push, each with a read-only check. `main` has them.
- **Public channels on the live project are still ON.** The founder says when to turn them off, once the new build is on every test phone.
- Review 69's wording fixes in `docs/legal/`, `docs/store/listing-draft.md`, `docs/pilot/quick-guide.md`, and the D3 positioning line in `docs/product/rules.md`.
- **Slice 2 retest build 375** from branch `slice2-retest` (38a3d37) = `a2e330f` (tag `slice2-candidate`) + the code of 8af5dee (photo location removal). It applied cleanly, and 1,288 tests pass. It is on the emulator (Omar signed in).
- Screenshots re-shot on the PC (Windows fonts), 211 checks, on `slice2-app` (a4adec7).

**Waiting:**
- **The founder's phone:** build 375 isn't on it yet (wireless debugging address needed). Install, then the founder's retest (order below).
- **Step 6, photo location:** on the founder's phone with location on, take a photo, post it, download it from Storage and check that it has no GPS and keeps its orientation. Needs the phone.
- **Retest order for the founder:**
  1. Due today strip (F38/F57);
  2. the Note;
  3. the who row;
  4. no "Late";
  5. the tick feel;
  6. an announcement edited after Got it;
  7. live updates on both devices.
- **After the retest passes:** the rest of slice 3 (DM4–DM5 Put in a Space, S8m Turn into a work item), then slice 4 (review 67, with review 69 §1). Not before.
- **Review 69, still to do:**
  - D4: the store reviewer's Edge Function and demo Space seed, on their own branch, before 13 Dec; going live needs its own yes.
  - Store listing items outside the listed fixes: the English long description and the header note still say "AECO" (D3 says "construction"); "the place" in "Proof that is yours" could say "typed on the work item"; old lead notes on lines 78 and 115.

**On the PC, not in git:**
- The main folder has the lead's uncommitted `docs/reviews/2026-10-20-63-model-views-3d.md` and an edit to `docs/product/model-views.md`. Left untouched. Note that review 63 also names the cloud's `2026-10-20-63-migration29-review.md`, so the 3D review needs another number.
- The `BuildVibes-slice1` worktree has a stash, "PC agent partial F54-F58, 20 Oct", superseded by the cloud's work. Drop it once the retest passes.

**Who has which branch:**
- PC: `slice2-app` (slice 2 + slice 3 part 1, worktree `BuildVibes-slice1`) and `slice2-retest` (the retest build, worktree `BuildVibes-phone`).
- `slice2-live-db` equals main.
- `claude/test-tw7wuv` is merged; a new cloud session starts its own `claude/...` branch from `slice2-app`.
