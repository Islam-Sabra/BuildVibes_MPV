# Review 72: the next round from the build 375 retest — 21 Oct 2026

The retest of build 375 (`slice2-retest`) so far:
- **Passed:** photo location, step 1 (Due today, run by the lead on the emulator as Omar, with the founder's send-back), step 2 (the Note).
- **Still to test:** steps 3–7 (the who row, no Late, the tick feel, the announcement after Got it, live updates). They need the founder's phone and the emulator, and they go first in the next test.

The findings are written in full in review 50. **When the founder says "apply review 72", do these on `slice2-app`, in this order:**

## App
1. **F59:** at Now the masthead always reads "**Today** · date". There's always a Today divider above the writing area, with "Nothing yet today" when the day is empty. The date follows the content only when scrolled back, with the "Today ↓" chip.
2. **F61:** the strip is named **"To do"** / «مطلوب منك». The day names are grey; the label and the titles stay in the action colour.
3. **F62 (app part):**
   - no due on a card while it's Done and waiting for the check;
   - the author's Needs you row reads "Done 10:21 · waiting for your check";
   - the send-back sheet has the single choice Today · Tomorrow · Pick a date · No new date, with nothing preselected;
   - after a send-back, the card shows the new due, or none;
   - the history line carries the new date.
4. **F63:** the kind menu has no description lines (Figma E6 v14 EN `2598:36360`, AR `2599:833`).
5. **F60:** `photo_privacy.dart` also empties Make, Model, BodySerialNumber, LensSerialNumber, OwnerName / CameraOwnerName and Artist. Orientation and the time taken stay. Add a test.

## Server: migration 33 (F62), **written and checked by the lead** (21 Oct, cloud)
Branch **`claude/review72-db`** (from `slice2-app`): `20261023120000_send_back_due.sql` and `supabase/tests/33_send_back_due.test.sql`. Not live.
- **`work_item_events.new_due`** (jsonb), on a send-back only:
  - `{"date", "at"}` is the new due;
  - `{"date": null}` means no new date;
  - null means no choice was made (older builds).
- **`send_back(item, reason, note, due_set, due, due_at)`** with defaults. With `due_set`, the post's and the work item's due change in the same transaction as the event. The old three-argument call still works, and the due stays.
- **Who:** only `may_check`, as before (the author, or an admin acting for a gone author). Never the owner.
- **`post_history_rows`:** the send-back line carries `new_due`. A missing key means unchanged; `{}` means no new date. Compared with migration 28's copy, it only gains that field.
- **Checks:** 24 new checks; **all 2,275 SQL checks pass** on the stand-in. They cover:
  - an old-style call;
  - a new date;
  - a date with a time;
  - no new date;
  - the owner, an outsider, a time without a day, a time on another day, and a date without the choice, all refused;
  - an event can't be rewritten;
  - only a send-back carries a date.
- **Numbering:** this is **33**, because it was written first. The 3D model views become **34** (review 71 updated).
- **Before it goes live:** the PC merges `claude/review72-db` into `slice2-app` and runs `supabase test db`. Then, with the founder's yes, the push lists only `20261023120000_send_back_due.sql`, followed by the read-only check.

**App (F62):** the send-back sheet calls `send_back(…, p_due_set: true, p_due: …, p_due_at: …)`, with `p_due` and `p_due_at` both null for "No new date". The card shows the line's new date from `new_due`.

**"No new date" and the To do strip:** the strip lists items by their due. An item sent back with no new date has no due, so it isn't in the strip. It's in the owner's **Needs you** with the paper clip, as every sent-back item is. That replaces F62's "sits in the To do strip as sent back".

## Then
- Run the checks, re-shoot the changed screenshots in EN and AR, make a new build, and put it on the founder's phone and the emulator.
- The founder's next test starts with steps 3–7 of the build 375 list, then checks F59, F61, F62 and F63.
- Rewrite `docs/handoff.md`.

## Not in this round
- Slice 3's rest (Put in a Space, Turn into a work item), slice 4 and the 3D work wait until slice 2 passes (founder, 21 Oct).
