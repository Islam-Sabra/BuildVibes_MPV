# Review 106: the shots that change (after G1–G5)

`flutter test test_screens` on the PC, branch `r106` after the lead's fixes G1–G5, without `--update-goldens`: 434 pass, 28 fail. The 28 are 20 tests with a changed shot (22 images; "Remind me" takes two) and the 8 new review 106 shots, which have no golden yet. Goldens are not updated.

For each changed shot, `<name>_<lang>-old.png` is the golden in `docs/screens/` and `<name>_<lang>-new.png` is what the branch draws now. The new shots are `-new.png` only.

## Changed (EN and AR)

| Shot | Golden | Pixels EN / AR | From | What changes |
|---|---|---|---|---|
| BH2-entry-selected | r100 | 21.93% / 19.62% | T1, T2 | the status row at the bottom end; the fold control in the head; lines in full |
| BH3-swipe | r100 | 20.82% / 18.47% | T1, T2 | the same |
| NB-reminder-slip | slice10 | 21.91% / 18.20% | T1, T2, G2 | pin and reminder in the status row; untitled entries: fold · time in the head, the words in the body at normal weight, no kind word |
| NB-remind-menu | slice10 | 24.26% / 20.56% | T1, T2, G2 | the same page as NB-reminder-slip |
| BH4-share | r100 | 12.63% / 9.73% | T1, T2 | the selected entry's Space icon moves from its top line to the status row |
| BH5-message-preview | r100 | 6.29% / 2.35% | T1, T2 | the same, behind the preview |
| NB-put-in-space | slice8 | 9.24% / 8.75% | T1, T2, G2, G3 | behind the sheet: the pinned note's pin in the status row; its head is the time alone and its words stay in the body (G2); one line, so no fold control (G3) |
| PG4-page | r99 | 17.56% / 8.92% | T2 | every entry in a page: the fold chevron, the title in the head, lines in full |
| N5-sort-chip | r102 | 14.32% / 9.93% | T2 | the entries under the chip, as PG4 |
| BH9-filter | r100 | 7.09% / 6.64% | T3 | the Filter card: the switch "Filter", SHOW without Reminders, STATUS, IN |
| N5-page-filter | r102 | 33.58% / 28.93% | T3 | the card inside a page opens in Sort mode (NS4): the switch "Sort", five sorts with the Type and Status hints |

Against the pairs at `fbe1691`, only the six NB images (NB-reminder-slip, NB-remind-menu, NB-put-in-space; EN and AR) are new. The other 16 changed-shot images and the 8 new shots are byte-identical. G1 (archived entries) and G5 (the Status groups) change no shot.

## New (no golden yet)

| Shot | Frame | What it shows |
|---|---|---|
| r106/NS1-status-card | NS1 `2680:38781` / `2680:38875` | the status row; the Space icon's card open with its two Spaces |
| r106/NS2-folded | NS2 `2682:38819` / `2682:38903` | a page in full, "Pump booked 2 pm" folded: "1 line hidden" and its status icons |
| r106/NS3-filter-status | NS3 `2685:38859` / `2685:38978` | My notebook's card in Filter mode, To-dos open and Shared to a Space on |
| r106/NS4-sort | NS4 `2688:38923` / `2688:39062` | the card in Sort mode inside a page |
