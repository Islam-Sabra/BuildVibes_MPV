# Review 105B: the shots, after the lead's check (L1–L11)

`flutter test test_screens` on the PC, branch `r105b`, without `--update-goldens`: **454 pass, 10 fail.**
- The 454 are every accepted shot: **none changed**, so there are no old/new pairs.
- The 10 failures are the new L11 shots (5 scenarios × EN and AR). They fail only because they have no golden yet ("non-existent file").
- Goldens are not updated, and nothing in `docs/screens/` changed.

## New (no golden yet)

The new shots are in `test_screens/r105b_test.dart`, in the folder `r105b`.
- They were drawn by running that one file alone with `--update-goldens`, which wrote them into a new `docs/screens/r105b/`.
- They were copied here as `r105b--<name>_<lang>-new.png`, and `docs/screens/r105b/` was then deleted, so none is accepted.
- They become goldens only when the lead accepts them.

| Shot | What it shows |
|---|---|
| r105b/W1-my-pins | My 4 pins under the Space's line: 3 slim lines, then "+1 more" (L9). A tap on "+1 more" opens the rest on a sheet; that sheet has no shot. |
| r105b/W2-archive-swipe | A Lead's swipe toward the start on a Checked item: Archive. |
| r105b/W3-archived-undo | After Archive, the item leaves Work: "Archived · Undo" (L7). |
| r105b/W4-share-threads | Share from the hold bar: the sheet with this Space's threads, Everyone and the MEP Team's. |
| r105b/C1-shared-cards | Two shared cards in the Everyone thread: one Open (OPEN) and one Checked (CHECKED), each with its kind, title and For line (L8). |

## Why no accepted shot changed

- No existing scenario swipes a Work card toward its end, holds one, or shows pins, an archived post or a shared card.
- The fakes know no time zone. A new announcement is pinned to the phone's day as before, and the Space's midnight is worked out only on Post (L6).
- `lib/features/notebook/` is untouched.

## For the lead

- **The chat thread is drawn bare** in C1, as in the other thread shots (S8m): the thread drawn alone shows its Space line at the top, with no app bar.
- **"+1 more" in Arabic** reads "+1 أخرى", with the digit and sign in Latin type, as with the other numbers.
- **Not drawn:**
  - the "+n more" sheet;
  - Unpin in the hold bar;
  - Unarchive in an archived item's ⋯;
  - the shared card's "You can't see this item", "This post isn't in Work any more" and the no-signal error;
  - Give to before a Send back to someone who has left.

  They are covered in `test/features/work/work_extras_test.dart`, in EN and AR. Say which of them you want drawn.
