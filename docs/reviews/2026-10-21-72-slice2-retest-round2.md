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

## Server: migration 34 (F62), on its own branch, not live
- `send_back` takes an optional new due (`p_due_at`, or `p_due` for a date only), set in the same transaction as the `sent_back` event, and recorded on that event so the history line can show it.
- Only the author (or `acts_for_author`) sets it, as for an edit.
- **Tests:**
  - a send-back with and without a new date, and the card's due after each;
  - a non-author can't set it;
  - the Due today / To do strip after each.
- It's numbered **34**, because **33 is reserved for the 3D model views** (review 71).
- Same routine as 29–32: an independent check, then the lead's review, then the founder's yes, then a push as the only file.

## Then
- Run the checks, re-shoot the changed screenshots in EN and AR, make a new build, and put it on the founder's phone and the emulator.
- The founder's next test starts with steps 3–7 of the build 375 list, then checks F59, F61, F62 and F63.
- Rewrite `docs/handoff.md`.

## Not in this round
- Slice 3's rest (Put in a Space, Turn into a work item), slice 4 and the 3D work wait until slice 2 passes (founder, 21 Oct).
