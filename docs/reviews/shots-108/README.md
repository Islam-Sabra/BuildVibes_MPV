# Review 108: reminders for someone else, and Post later

All shots are 390 × 844, in English and Arabic, drawn in the app's fonts. File names are `<folder>--<shot>_<lang>.png`.

## How these were made
- **New shots:** `test_screens/r108_test.dart` drew them with `--update-goldens`. They were moved here, so `docs/screens/r108/` does not exist yet.
- **Changed shots:**
  - The six shot files that changed were drawn again with `--update-goldens`.
  - For each change, `-old.png` is the committed golden (from `git show HEAD`) and `-new.png` is the new drawing.
  - Then `docs/screens/` was restored from git, so no golden in the repo has changed.
- All of these become goldens when the lead accepts them.

## New (frames 2701:*)
| Shot | Frame | What it shows |
|---|---|---|
| r108--RM1-reminder-someone | RM1 | The Reminder sheet on **Someone**, as Islam (Lead) on Omar's item. Me · Someone; Who has the owner chosen; Tomorrow 7:00 · 1 h before due · Pick…; a note; Set reminder. |
| r108--RM2-item-reminders | RM2 | The opened item's **Reminders** line: who · when, with ✕ (shown only to someone who may remove it). |
| r108--PL1-post-later | PL1 | **Post later** over a work item that is ready: Tomorrow 7:00 · Sunday 7:00 · Pick…, the line, and Schedule. Sunday comes from Kuwait's market pack weekend (Fri, Sat). |
| r108--PL2-scheduled | PL2 | **Scheduled**: one item in a Space and one in the Feed. Each card has when · where, then Post now · Edit · Cancel. |
| r108--PL2b-space-scheduled-line | PL2 | The Space's small **"1 scheduled"** line above the post bar. It opens Scheduled. |

### Differences from the frames, on purpose
- **Times:** the test phone uses a 12-hour clock, so the times read "7:00 am". On a 24-hour phone they read "7:00", as in the frames. Because of the longer label, Pick… wraps onto a second line in PL1 and RM1.
- **Edit in PL2:** the pill is grey with dark words, as in the frame. This needed a new `BvPillButton.grey` option.

## Changed: the clock beside Send (54 tests, 60 shots)
The writing bar in a Space and in the Feed now has a **clock** just before Send (PL1).
- It is grey and does nothing until the post could go now, the same as Post.
- In a Space, it stays off for a work item with Library files or a place chosen from the list, because those are added after the item is made.
- Nothing else in these shots moves.

| Folder | Shots |
|---|---|
| slice1 | E1-write, E2-more-menu, E3-assign, E3-filled-card, E6-kind-chip, H2-write-post, H3-write-post-filled |
| slice2 | E6-kind-menu, F50-kind-menu, F56-to-menu, F56-who-asks, F56-who-row, W-activity, W-announcement, W-checklist, W-file |
| slice3 | DM5-writing-quote |
| slice7 | R2-writing, R2-writing-done-today, T0-more-template, T2-checklist-from-template, T2-from-template |
| slice8 | NB-put-in-space |
| review72 | F63-kind-menu, F66-who-row-chosen |
| review80 | F71-writing-replaces, F82-pin-add-time, F82-pin-with-time |
| f60 | H2-photos-preparing |
| f68b | F69-picker-you-first |

## Not here
- **OB1:** `r107/OB1-welcome` differs from its golden because of review 107 S1. Its old and new shots are in `docs/reviews/shots-107b/`.
- **The notebook share preview:** it gets the clock beside Post. No existing shot shows that preview with a Space or the Feed, so there is no shot of it here.
