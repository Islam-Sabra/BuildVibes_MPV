# Review 105C: the shots, on `r105c`

`r105c` is `slice2-app` with `claude/r105c-a` (M1–M3), then `claude/r105c-b` (N1–N5), each merged with `--no-ff`.

`flutter test test_screens` on the PC, without `--update-goldens`:
- **433 pass and 47 fail.**
  - **33 differ:** 18 shots, in EN and AR, except F69, K4 and E4, which change only in EN.
  - **14 are new** (7 shots in EN and AR), failing only because they have no golden yet ("non-existent file").
- No golden is updated.

## How these were made

- **`-old.png`** is the committed golden from `docs/screens/<folder>/`, copied byte for byte.
- **`-new.png`** is the image `test_screens` drew on `r105c`, from `test_screens/failures/`, copied byte for byte.
- Names are `<folder>--<shot>_<lang>-old.png` and `-new.png`.
- The share of changed pixels is worked out from each pair (RGB, any difference).

## Changed (old and new)

| Shot | EN | AR | What changed | From |
|---|---|---|---|---|
| slice1/E1-write | 16.86% | 0.33% | The work item's details hint is now "Add details. + for bullet points, a table or a table of tasks." In English it takes two lines, so the card is taller and Work above it moves up. In Arabic it fits on one line, so only its words change. | C-B (SP4) |
| slice1/E2-more-menu | 16.83% | 0.33% | the same hint | C-B |
| slice1/E3-assign | 17.32% | 0.33% | the same hint | C-B |
| slice1/E4-draft | 17.10% | — | the same hint (the AR shot is unchanged) | C-B |
| slice1/E6-kind-chip | 16.86% | 0.33% | the same hint | C-B |
| slice2/E6-kind-menu | 16.86% | 0.33% | the same hint | C-B |
| slice2/F50-kind-menu | 16.86% | 0.33% | the same hint | C-B |
| slice2/F56-who-asks | 14.69% | 0.33% | the same hint | C-B |
| slice2/F56-who-row | 14.70% | 0.33% | the same hint | C-B |
| review72/F63-kind-menu | 16.86% | 0.33% | the same hint | C-B |
| review72/F66-who-row-chosen | 5.66% | 0.33% | the same hint | C-B |
| f68b/F69-picker-you-first | 9.07% | — | the same hint, behind the picker (the AR shot is unchanged) | C-B |
| f60/H2-photos-preparing | 10.22% | 0.33% | the same hint | C-B |
| slice2/K4-attach | 16.50% | — | the same hint, behind the attach sheet (the AR shot is unchanged) | C-B |
| slice3/DM5-writing-quote | 11.30% | 0.33% | the same hint | C-B |
| slice5/N3-add-block | 26.24% | 29.16% | **The + sheet inside a work item (SP4):** "Add to this work item" and its rows: Text, Bullet points, Checklist, Table ("A plain table, no owners"), Table of tasks ("Rows the owner ticks, then signs once"), Photo, File or scan, Heading, Toggle, and Work item under this one. | C-B (SP4) |
| slice1/E3-filled-card | 0.01% | 0.02% | **Only the text cursor**, at the end of the details. The place is now picked from the Space's list, which keeps the focus in the field; typing the old free-text place ended with Done, which took it away. | C-A (driver) |
| slice2/W-activity | 0.01% | 0.02% | **Only the text cursor**, at the end of the title, for the same reason | C-A (driver) |

## The shot drivers changed (no new look)

The Place row now opens the Space's places, so a free-text place can't be typed any more. The drivers were changed to match the app tests (C-A's 30ebce3):
- `daybook_test.dart` E3, E5, E7 and E8, and `slice2_test.dart` W, now pick the place from the picker.
- Each scenario's fake Space has that place, with the same name as before.
- E7 (no signal) and E8 (refused) now cut the signal, or refuse, after the place is picked. The picker reads the Space's places first.
- E5, E7 and E8 draw exactly as before.

## New (no golden yet)

They are in `test_screens/r105c_test.dart`, in the folder `r105c`.
- They were drawn by running that one file alone with `--update-goldens`, which wrote them into a new `docs/screens/r105c/`.
- They were copied here as `r105c--<shot>_<lang>-new.png`, and `docs/screens/r105c/` was then deleted.

| Shot | What it shows |
|---|---|
| r105c/P1-place-picker | Place on a new work item: "Roof" is typed, and the Space has no such place, so the picker offers only **Add place "Roof"**. |
| r105c/P2-site-tag | A work item's card with its site tag, **L3 · Grid B4** (sand, with a pin). |
| r105c/P3-place-filter | After a tap on that tag, Work shows only L3 · Grid B4's items. The chip with ✕ sits under the Work · Chat switch, and L2's item is hidden. |
| r105c/BA1-before-after | A Checked item: **Before · 8:10 am** and **After · 9:56 am** side by side, with the CHECKED stamp on After. In Arabic, After is at the left. Both photos are from today, so no day is shown (M3). |
| r105c/SP4-add-sheet | The + sheet inside a work item, opened from Edit page. It is the same sheet as N3-add-block's new image, drawn here on its own item. |
| r105c/SP3-task-table | Omar's card in Work with its table of tasks: "For you · 1 of 3 ticked" (AR «1 من 3 معلَّمة», N1). The ticked row is crossed out; an empty note reads "—"; then Add a row and Sign as done, once. |
| r105c/SP9-removal-sheet | Remove Omar Haddad, who has 2 open work items. KCT-022 goes by default to Sara, who made it and may own it; KCT-025, made by a Viewer, reads "Choose someone". "Give and remove" stays off until both have someone. |

## For the lead

- The site tag's tap area is its chip, at the start of a tag as wide as the card. A tap at the card's middle opens the item. The app's own tests and P3 tap the chip.
- **Not drawn:**
  - a Lead's Rename and Delete on a place;
  - Search finding a place;
  - Leave with open work (the same sheet as SP9, with "Give and leave");
  - M3's days on photos from two days.

  They are covered in `test/features/work/places_test.dart`, `before_after_test.dart` and `test/features/spaces/removal_sheet_test.dart`, in EN and AR. Say which of them you want drawn.
