# Handoff

Where the work stopped, for whichever place picks it up next: the founder's PC, a cloud session, or the lead's chat in the Claude project. Each session rewrites this file before it stops. The full history stays in `progress.md`.

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
