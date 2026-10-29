# Review 106: the shots that change

`flutter test test_screens` on the PC, branch `r106`, without `--update-goldens`: 434 pass, 28 fail. The 28 are 20 tests with a changed shot (22 images; "Remind me" takes two) and the 8 new review 106 shots, which have no golden yet. Goldens are not updated.

For each changed shot, `<name>_<lang>-old.png` is the golden in `docs/screens/` and `<name>_<lang>-new.png` is what the branch draws now. The new shots are `-new.png` only.

Review 106 names these as changing on purpose: BH2, BH3, NB-reminder-slip, NB-remind-menu, and every notebook shot with a pinned or shared entry (T1). T2 and T3 name no shots. Any change below that is not named in the review is listed for the lead and is not accepted.

## Changed (EN and AR)

| Shot | Golden | Pixels EN / AR | Named in review 106 | What changes |
|---|---|---|---|---|
| BH2-entry-selected | r100 | 21.93% / 19.62% | yes (T1) | the status row at the bottom end; T2: entries in full with the fold control |
| BH3-swipe | r100 | 20.82% / 18.47% | yes (T1) | the same |
| NB-reminder-slip | slice10 | 20.96% / 16.87% | yes (T1) | pin and reminder in the status row; T2 head |
| NB-remind-menu | slice10 | 22.22% / 18.05% | yes (T1) | the same page as NB-reminder-slip |
| BH4-share | r100 | 12.63% / 9.73% | yes (T1: a shared entry) | the selected entry's Space icon moves from its top line to the status row; T2 head |
| BH5-message-preview | r100 | 6.29% / 2.35% | yes (T1, as BH4) | the same, behind the preview |
| NB-put-in-space | slice8 | 7.20% / 7.58% | yes (T1: a pinned entry) | the pinned entry behind the sheet: its pin in the status row; T2: an untitled entry's first line is its head |
| PG4-page | r99 | 17.56% / 8.92% | no (T2) | every entry in a page: the fold chevron, the title in the head, lines in full |
| N5-sort-chip | r102 | 14.32% / 9.93% | no (T2) | the entries under the chip, as PG4 |
| BH9-filter | r100 | 7.09% / 6.64% | no (T3) | the Filter card: the switch "Filter", SHOW without Reminders, STATUS, IN |
| N5-page-filter | r102 | 33.58% / 28.93% | no (T3) | the card inside a page opens in Sort mode now (NS4): the switch "Sort", five sorts with the Type and Status hints |

## New (no golden yet)

| Shot | Frame | What it shows |
|---|---|---|
| r106/NS1-status-card | NS1 `2680:38781` / `2680:38875` | the status row; the Space icon's card open with its two Spaces |
| r106/NS2-folded | NS2 `2682:38819` / `2682:38903` | a page in full, "Pump booked 2 pm" folded: "1 line hidden" and its status icons |
| r106/NS3-filter-status | NS3 `2685:38859` / `2685:38978` | My notebook's card in Filter mode, To-dos open and Shared to a Space on |
| r106/NS4-sort | NS4 `2688:38923` / `2688:39062` | the card in Sort mode inside a page |

## For the lead

- **N5's scenario changed.** `test_screens/r102_test.dart` opens the card in Sort mode (the switch's kept mode), because SORT is behind the switch now. Without this, N5-sort-chip couldn't be drawn at all. N5-page-filter therefore shows Sort mode.
- **The switch's off colour** is `BvSwitch`'s own off track (`borderInput`). NS3 draws it lighter. I kept the component's colour; say if NS3's should win.
- **An untitled entry's head** is its first line (T2). A long one-line note becomes a three-line bold head with no body (NB-put-in-space, "Pump booking: …"). A to-do or a voice note keeps its kind word as the head, so its box or player isn't lost.
- **The fold control's 44 tap area** makes the head 44 high, so the gap under the title is about 6 px larger than NS2's.
