# Handoff

Where the work stopped, for whichever place picks it up next: the founder's PC, a cloud session, or the lead's chat in the Claude project. Each session rewrites this file before it stops. The full history stays in `progress.md`.

## Cloud update: 22 Oct 2026, night — slice 6 plan drafted (branch `claude/slice6-plan`, from `claude/slice5-plan`)

- **Founder's decision (22 Oct, "ok"):** a tap on a card keeps opening its menu (F16). The page opens from "Open the page ›".
- **Review 77** (`docs/reviews/2026-10-22-77-slice6-plan.md`): the slice 6 plan (walk mode, work items under one; R1 `2539:34353`, R1b `2539:34396`, N5 `2538:34302`).
  - It asks the lead three things. The first is whether a walk's work items fold into the target card (migration 37, recommended) or also show as their own cards.
  - R1b and N5 must be redrawn without the hour spine before the build.
  - The build waits for the lead's answers.
- Slices 4 and 5 are on `claude/slice4` and `claude/slice5` (see their handoffs).
- **Who has which branch:** this cloud session made `claude/slice6-plan` (docs only); done, nobody on it.

## Cloud update: 22 Oct 2026 — slice 5 plan drafted (branch `claude/slice5-plan`, from main)

- **Founder's decision (22 Oct, "ok"):** Team-only Library files are not in the pilot. A Team file comes in only through that Team's chat; file posts and the Library's "Add a file" are for the whole Space.
- **Review 76** (`docs/reviews/2026-10-22-76-slice5-plan.md`): the slice 5 plan (opening a post in place, frames N1–N5 = W1 v13 to v13e), drafted in the cloud for the lead. It proposes migration 36, `turn_point_into_item` (Turn into in one step), and "Open the page ›" on cards. The lead confirms or changes it before the build.
- Slice 4 is on `claude/slice4` (see its handoff there); merge order on the PC: `claude/f68b-f69`, `claude/slice3-rest`, `claude/slice4`.
- **Who has which branch:** this cloud session made `claude/slice5-plan` (docs only); done, nobody on it.

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
