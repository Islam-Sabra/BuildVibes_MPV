# Handoff

Where the work stopped, for whichever place picks it up next: the founder's PC, a cloud session, or the lead's chat in the Claude project. Each session rewrites this file before it stops. The full history stays in `progress.md`.

## PC update: 23 Oct 2026, 08:36 — push v9, migrations 34 and 39 live, build 547

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

## PC update: 22 Oct 2026 — migrations 36 and 37 live

- **Live:** migrations 36 and 37 (founder's yes, review 79 Result), one file per push from `slice2-app` 586e017, with a read-only check after each. Live is now at `20261027120000`, so the founder's ⏸ steps can run on build 473.
- **Migration 34** (`claude/store-reviewer`) must be **renamed to a timestamp after 37** (e.g. `20261028120000_review_sign_in.sql`, test file unchanged) when review 75 B5 is added there. Supabase refuses a file older than the last one applied. The 3D model views take the number after it.
- Nothing else changed on live. Public channels are still on.

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
