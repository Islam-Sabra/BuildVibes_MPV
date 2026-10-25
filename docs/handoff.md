# Handoff

Where the work stopped, for whichever place picks it up next: the founder's PC, a cloud session, or the lead's chat in the Claude project. Each session rewrites this file before it stops. The full history stays in `progress.md`.

## PC update: 25 Oct 2026, 15:35 Kuwait — review 94 merged into `slice2-app`; build 612 waits for the phone's address

**Standing rule (review 74):** nothing but the BuildVibes build goes on the founder's phone without his yes in chat.

- **NST-025 (read-only):** Omar Haddad, its author and owner (Crew), signed it as done himself on 22 Oct at 11:19; the founder did not. `sign_done` allows only the owner, so no one can sign for someone else: no gap. Acting for someone exists only for Check and Cancel, when the author has gone.
- **Step 2 done, live:** NST-023 "Lead test: cracked tile at the stair" was signed as done by the founder (15:13). Omar held Check in its own sheet on the emulator, and it went through: **Checked on live at 15:15**.
- **Step 1 not done, and a bug found and fixed:**
  - In a walk row's own sheet, Hold to check left the DONE stamp until the server answered.
  - Its "Checked · Undo" opened on the app's messenger behind the sheet, out of reach, so Undo couldn't be tapped and the check went through.
  - The bug was older than review 94 (the double-tap had it too).
  - Fixed on `claude/hold-confirm` (bc269ec): the sheet shows CHECKED or CANCELLED at once, with its line, and its undo bar opens on the sheet. Test in `walk_test`.
  - Nothing else for Omar to check is Done on live, so Check then Undo hasn't been redone for real.
- **Tried the fixed sheet on build 612** (emulator), with Cancel on NST-024 "Lead test: hanger missing at door 2.04": CANCELLED landed at once and "Cancelled · Undo" showed on the sheet. My automated Undo tap missed (the screen-reader dump didn't find the bar in time), so **NST-024 is now cancelled on live**, a test item of Omar's.
- **Step 3:**
  - `slice2-app` fast-forwarded to bc269ec, pushed.
  - Analyze clean; 1,936 app tests; 404 screenshots (SQL unchanged, 2,696).
  - **Build 612** (bc269ec) is on the emulator.
  - **Not on the founder's phone yet:** 192.168.8.24:40329 refused the connection; waiting for the new wireless-debugging address.
- **Review 95** waits until 612 is on the phone, as it says; `claude/r95` isn't made yet.
- **Who has which branch:** `claude/hold-confirm` is merged and done (worktree `BuildVibes-hold` can be removed). PC has `slice2-app` (worktree `BuildVibes-slice1`).

## PC update: 25 Oct 2026 — the live Check test is still blocked; nothing merged or installed

- The founder signed **NST-025** "Lead test: debris on the walkway" as done.
- Live (read-only) shows its author **and** its owner are Omar, and `may_check` is false for him. The owner never checks their own work, so Omar's Hold to check would be refused by the server.
- The emulator test of Check did not run, and nothing was sent.
- **Next:** the founder signs one of the Omar-authored items he owns as done (NST-023 "cracked tile at the stair", NST-024, NST-027 or NST-016). Then: Omar holds Check, Undo within 2 s, stays Done after 5 s; hold again, let it go through, and live shows Checked.
- After that, with the founder's yes already given: merge `claude/hold-confirm` into `slice2-app`, run analyze and the tests, build 612, install on the founder's phone. **Not started.**

## PC update: 25 Oct 2026, 12:40 Kuwait — review 94 (Hold to confirm) on `claude/hold-confirm`, waiting for the founder

**Standing rule (review 74):** nothing but the BuildVibes build goes on the founder's phone without his yes in chat.

**Not done (they wait for the founder):** no merge; nothing pushed to the database or deployed; nothing installed on his phone. No server change is needed.

**Built, on `claude/hold-confirm`** (ec477b0, from `slice2-app` 4ada8d9):
- **`BvHoldButton`** (`lib/shared/widgets/bv_hold_button.dart`):
  - a 600 ms hold acts; the fill runs from the start side (right to left in Arabic);
  - a light tick starts the hold and a firm one ends it;
  - let go early, the fill runs back in 150 ms, and the first two times on a phone it says "Keep holding to confirm";
  - it takes the finger at once, so a card's long-press menu (500 ms) or the page's scroll can't cut a hold short;
  - with TalkBack or VoiceOver on, a double-tap asks first ("Check this work item? It can't be changed after." · Check / Not now);
  - with Reduce motion on, nothing moves, and the button turns solid at 600 ms.
- The colours, 600 ms and 150 ms are tokens in `bv_tokens`.
- **Check:**
  - "Hold to check" on the card replaces the double-tap on the proof photo; a double-tap is still two taps that can happen by accident;
  - a proof with only a note gets the button too;
  - the menu's Check opens a short sheet answered by holding.
- **Cancel work item** (from the card's menu): a sheet ("Cancel this work item?") answered by "Hold to cancel", in red. Cancel on other kinds of post is unchanged.
- **Remove from Space** (People tab and a member's pass):
  - "Hold to remove" on the sheet;
  - the person leaves the list at once, and "Removed · Undo" shows for 5 seconds;
  - only then does `remove_member` go, through the outbox (new kind `remove`);
  - if the server refuses, the person comes back and a line says "Couldn't remove".
- **Undo through the outbox:**
  - the existing 5-second hold for Check and Cancel is reused (a `holdFor` didn't need adding; it is `hold(item, duration)`);
  - leaving the Space, or hiding the app, sends what an undo bar still holds and hides the bar;
  - an Undo after that changes nothing (`undo` now returns false).
- Unchanged, one tap as before: Sign as done, Send back, ticks, Got it and the rest.
- **Checks:** analyze clean; 1,934 app tests; 2,696 SQL checks in 44 files; 404 screenshots.
- **Screenshots** in EN and AR, in `docs/screens/hold-confirm/`: H1 at rest, H2 half held, H3 Checked · Undo.
- Re-shot because the card's hint became the button: 40 frames in `slice1/` and 12 in `slice2/`. Only the card's button and the layout below it moved.

**Tried for real on the emulator** (build 611, ec477b0; Omar on live; emulator only):
- **Let go early once** (on Hold to cancel): nothing happened, and "Keep holding to confirm" showed. A screenshot mid-hold showed the red fill from the start side.
- **Hold, and let it go through:** NST-033 "Hold test - delete me" was cancelled at once on the card, with "Cancelled · Undo". The tap on Undo came after the 5 seconds (my screenshot round trip was too slow), so it went to the server. Live shows it cancelled.
- **Hold, then Undo:** NST-034 "Hold test 2 - delete me": hold, then Undo within a second. The card came back open with Sign as done, and stayed open past the 5 seconds.
- **Leave the screen:** NST-034 held to cancel, then Back at once. The bar went with the screen, and the Space's last activity reads 12:36, the minute it was left. Live shows it cancelled.
- **Clean-up:** both test items are cancelled, the only clean-up the app has. They stay on NBKCH's daybook stamped CANCELLED, like the earlier test items.
- **Blocked: Check on live.**
  - Check needs someone other than the owner to check an item that is Done.
  - On live, Omar is Crew in NBKCH SITE TEAM, with the founder's account as the only other member, and a Viewer in "test site 2".
  - No item authored by Omar is Done (the four "Lead test" items are Open).
  - So Omar can't hold Check without the founder signing an item as done, and I didn't use the founder's account.
  - Hold to check, Undo, leaving and the screen-reader dialog are covered by the widget tests.
  - **To finish it:** the founder signs one of Omar's test items as done on his phone, then Omar holds Check on the emulator: Undo once, then let it go through.
- **Not tried for real:** Remove from Space, because Omar isn't an admin anywhere on live and it would remove a real member. Covered by the widget tests.

**Who has which branch:** PC has `claude/hold-confirm` (worktree `BuildVibes-hold`) and `slice2-app` (worktree `BuildVibes-slice1`). The emulator has build 611 (hold-confirm); the founder's phone still has 610.

## PC update: 25 Oct 2026, 11:30 Kuwait — F108 merged, migration 45 live, build 610

**Standing rule (review 74):** nothing but the BuildVibes build goes on the founder's phone without his yes in chat.

- **The lead's two changes**, on `claude/f108` (4ada8d9):
  - folds are kept (`folded` on text, to-do, bulleted and numbered lines with children), so a note reopens as it was left;
  - the line's ⋮⋮ menu fits one screen: Continue numbering, Restart at 1, Turn into › (the kinds on their own sheet), then Delete. L3 was shot again.
- **`slice2-app`** is fast-forwarded to 4ada8d9. Checks: analyze clean, 1,913 app tests, 2,696 SQL checks in 44 files, 398 screenshots.
- **Live** is at `20261106120000` (migration 45). The push listed only that file.
- **Read-only check passed:** the new check accepts levels, start and folds, and refuses level 4, a start of 0 and a fold with nothing under it. Old pages still pass, and the one saved page on live is still valid. Signed-out can't run the check; RLS on notes is on.
- **Build 610** (4ada8d9) is on the founder's Xiaomi and the emulator. Only BuildVibes was installed.
- **To try on the phone:** Backspace at the start of a line that has words; dragging a line that has children; ⇥ ⇤ on the bar.
- **Error during the migration 45 push (25 Oct, 11:30 Kuwait):** `echo Y | supabase db push --linked` (CLI v2.109.1) printed a stack trace before `Finished supabase db push.`. The output was cut to its last 6 lines (`| tail -6`), so any lines above the first frame below, including the error message itself, were not kept. Exact text kept:
  ```
      at getCertValue (file:///var/tmp/sb-compile-edge-runtime/node_modules/localhost/@supabase/pg-delta/1.0.0-alpha.27/dist/core/plan/ssl-config.js:44:27)
      at async parseSslConfig (file:///var/tmp/sb-compile-edge-runtime/node_modules/localhost/@supabase/pg-delta/1.0.0-alpha.27/dist/core/plan/ssl-config.js:62:23)
      at async createManagedPool (file:///var/tmp/sb-compile-edge-runtime/node_modules/localhost/@supabase/pg-delta/1.0.0-alpha.27/dist/core/postgres-config.js:340:23)
      at async file:///var/tmp/sb-compile-edge-runtime/index.ts:10:25

  Finished supabase db push.
  ```
  - **What produced it:**
    - The trace comes from pg-delta (`@supabase/pg-delta` 1.0.0-alpha.27). That is the CLI's experimental schema engine, switched on by `[experimental.pgdelta] enabled = true` in `supabase/config.toml`; the CLI runs it in its edge-runtime container.
    - It failed while reading the certificate for its SSL connection to the live database (`getCertValue`).
    - That certificate is `supabase/.temp/pgdelta/pgdelta-target-ca.crt`, a public CA certificate, not a secret. When the throwaway push worktree was made, `cp supabase/.temp/*` skipped the `pgdelta/` folder (`cp: -r not specified; omitting directory 'supabase/.temp/pgdelta'`), so the file wasn't there.
    - This cause is read from the stack and the missing file; the lost lines were not seen.
  - **Effect:** none on the migration.
    - The trace came at the end of the push, and the CLI still printed `Finished supabase db push.`.
    - `supabase migration list --linked` shows `20261106120000` on live.
    - The read-only check of 45 passed.
  - **Before the next push:** copy the folder whole: `cp -r supabase/.temp/. ../BuildVibes-push/supabase/.temp/`. Keep `| tail` off the real push so any error is kept in full, and confirm the push with `supabase migration list --linked` as before.
- **Who has which branch:** `claude/f108` is merged and done; the worktree `BuildVibes-f108` can be removed. PC keeps `slice2-app` (worktree `BuildVibes-slice1`).

## PC update: 25 Oct 2026 — F108 (review 93) built on `claude/f108`, waiting for the lead

**Standing rule (review 74):** nothing but the BuildVibes build goes on the founder's phone without his yes in chat.

- **`claude/f108`** (0d31b83, from `slice2-app` db16f35):
  - levels 0–3 with ⇥ ⇤ on the bar;
  - numbering by level, with Continue numbering and Restart at 1;
  - folding list items;
  - Turn into, move and delete keeping the children;
  - migration 45, `20261106120000_note_block_levels.sql`, **not live**.
- **Checks:** analyze clean; 1,907 app tests; 2,688 SQL checks in 44 files (local); 398 screenshots. The new shots are in `docs/screens/f108/`; NBW4, NBX3 and NBX4 were shot again because their bar now shows ⇥ ⇤.
- **Storage:** the line level is kept as `indent`, not `level`, because a heading's `level` is already its size.
- **Nothing is live or installed.** Next comes the lead's check. After that, with the founder's yes: merge into `slice2-app`, push migration 45 as the only file, then one build.
- **Who has which branch:** PC has `claude/f108` (worktree `BuildVibes-f108`) and `slice2-app` (worktree `BuildVibes-slice1`).

## PC update: 25 Oct 2026 — F106, F107 and the icon merged; migration 44 live; build 605

**Standing rule (review 74):** nothing but the BuildVibes build goes on the founder's phone without his yes in chat.

**State:**
- **Live:** migrations to `20261105120000` (44, `notebook_blocks`), pushed on the founder's yes with only that file listed. Read-only check: `notes.blocks`, `notes.title` and the location columns exist; `note_files.kind` accepts photo, voice and file, with a `name` column; RLS on for both; the bucket takes PDF up to 25 MB; `is_valid_note_blocks` and `note_for_space` exist and anon can't run them. The push function is still v10; public channels still on.
- **`slice2-app`:** db16f35. `claude/f106`, `claude/f107` (with the review 92 bug list) and `claude/app-icon` (icon, colour-only splash, the cube trace) are merged. Checks: analyze clean, 1,872 app tests, 392 screenshot checks.
- **Exact reminders** (founder, 25 Oct): on a phone that keeps alarms inexact (Android 12+), the first Remind me asks once, with one line why, and opens the phone's exact alarms setting. Refused or Not now, reminders stay inexact; never asked again.
- **Build 605** (db16f35) is on the founder's Xiaomi and the emulator. Only BuildVibes was installed.

**Not yet checked on a phone:** GPS location, exact reminders and the setting, the mic label, PDF picking, the new icon and splash.

**Open, for the stores:** the `SCHEDULE_EXACT_ALARM` declaration, and the location entry in Google Play's data safety form.

**Who has which branch:**
- PC: `slice2-app` (worktree `BuildVibes-slice1`); `slice2-live-db` = main (worktree `BuildVibes-db29`).
- `claude/f106`, `claude/f107` and `claude/app-icon` are merged and done; the worktrees `BuildVibes-f106`, `BuildVibes-f107` and `BuildVibes-icon` can be removed.

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
