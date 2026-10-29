# Review 105C: the shots, on `r105c`, after O1 and O2

`r105c` is `slice2-app` with `claude/r105c-a` (M1–M3), then `claude/r105c-b` (N1–N5), each merged with `--no-ff`. Then the lead's check of `r105c` added:
- **O1:** the Place picker opens on a bottom sheet, like Give to's.
- **O2:** the shorter hint, "Details, or + for lists and tables" («التفاصيل، أو + للقوائم والجداول»).

`flutter test test_screens` on the PC, without `--update-goldens`: **436 pass and 44 fail.**
- **30 images differ:** 15 shots, in EN and AR.
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
| slice1/E1-write | 0.35% | 0.38% | **Only the hint's words** (O2): "Details, or + for lists and tables" in place of "Add details." It is one line in both languages, so nothing moves. | C-B, O2 |
| slice1/E2-more-menu | 0.35% | 0.38% | only the hint's words | O2 |
| slice1/E3-assign | 0.35% | 0.38% | only the hint's words | O2 |
| slice1/E6-kind-chip | 0.35% | 0.38% | only the hint's words | O2 |
| slice2/E6-kind-menu | 0.35% | 0.38% | only the hint's words | O2 |
| slice2/F50-kind-menu | 0.35% | 0.38% | only the hint's words | O2 |
| slice2/F56-who-asks | 0.35% | 0.38% | only the hint's words | O2 |
| slice2/F56-who-row | 0.35% | 0.38% | only the hint's words | O2 |
| review72/F63-kind-menu | 0.35% | 0.38% | only the hint's words | O2 |
| review72/F66-who-row-chosen | 0.35% | 0.38% | only the hint's words | O2 |
| f68b/F69-picker-you-first | 0.11% | 0.09% | only the hint's words, the little left in sight behind the picker | O2 |
| f60/H2-photos-preparing | 0.35% | 0.38% | only the hint's words | O2 |
| slice3/DM5-writing-quote | 0.35% | 0.38% | only the hint's words | O2 |
| slice5/N3-add-block | 26.24% | 29.16% | **The + sheet inside a work item (SP4):** "Add to this work item" and its rows: Text, Bullet points, Checklist, Table ("A plain table, no owners"), Table of tasks ("Rows the owner ticks, then signs once"), Photo, File or scan, Heading, Toggle, and Work item under this one. Accepted with SP4. | C-B (SP4) |
| slice2/W-activity | 0.01% | 0.02% | **Only the text cursor**, at the end of the title. The place is now picked from the Space's list, which keeps the focus in the field; typing the old free-text place ended with Done, which took it away. Accepted. | C-A (driver) |

**No longer changed** since the last pairs:
- E4-draft and K4-attach: there the new hint is hidden or under a sheet, and the old one took two lines.
- E3-filled-card: it now draws exactly as its golden, the text cursor included. The place is now picked on the sheet.

## The shot drivers (unchanged since the last pairs)

`daybook_test.dart` E3, E5, E7 and E8, and `slice2_test.dart` W, pick the place from the Space's list, as the app tests do. E7 and E8 cut the signal, or refuse, after the pick. E5, E7 and E8 draw as their goldens.

## New (no golden yet)

They are in `test_screens/r105c_test.dart`, in the folder `r105c`.
- They were drawn by running that one file alone with `--update-goldens`, into a new `docs/screens/r105c/`.
- They were copied here as `r105c--<shot>_<lang>-new.png`, and that folder was then deleted.

| Shot | What it shows |
|---|---|
| r105c/P1-place-picker | **Redrawn for O1.** Place opens a bottom sheet over the page: its grabber, "Place" («المكان»), then the search. "Roof" is typed and the Space has no such place, so the sheet offers only **Add place "Roof"**. |
| r105c/P2-site-tag | A work item's card with its site tag, L3 · Grid B4. Accepted; the hint isn't in sight. |
| r105c/P3-place-filter | Work for L3 · Grid B4 only, with the chip and ✕ under the Work · Chat switch. Accepted. |
| r105c/BA1-before-after | A Checked item: Before · 8:10 am and After · 9:56 am, with the CHECKED stamp on After. Accepted. |
| r105c/SP4-add-sheet | The + sheet inside a work item. Accepted. |
| r105c/SP3-task-table | Omar's card with its table of tasks, "1 of 3 ticked" («1 من 3 معلَّمة»). Accepted. |
| r105c/SP9-removal-sheet | Remove Omar Haddad, with 2 open work items. Accepted. |

Only P1 looks different from the last set. The other six are drawn from the same scenarios, with no hint in sight.

## The sheet (O1), as built

- The Place row, and More → Location, open `DaybookPlaceSheet` on `showBvSheet`, as Give to does. The title is "Place".
- On the sheet:
  - the search on top;
  - the Space's places A to Z, with a check on the chosen one;
  - "Add place ‹typed›" for who may post work. It is the first row when nothing matches; when some places match, it comes after them.
  - a Lead's long press: Rename or Delete.
- A pick closes the sheet.
- The popover's place case and its leftover free-text field are gone.
- Tests in `test/features/work/places_test.dart` cover all of this in EN and AR: the sheet's grabber and title, search on top, A to Z, the check, and Add first when nothing matches.
