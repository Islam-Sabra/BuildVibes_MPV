# Review 104: the shots that change

`flutter test test_screens` on the PC at 5888855, without `--update-goldens`: 434 pass, 20 fail (22 shots; the "Remind me" test takes two). Goldens are not updated. For each shot, `<name>-old.png` is the golden in `docs/screens/` and `<name>-new.png` is what the branch draws now.

| Shot (EN and AR) | Golden | Expected | What changes |
|---|---|---|---|
| BH3-swipe | r100 | yes | |
| BH4-share | r100 | yes | |
| BH5-message-preview | r100 | yes | |
| BH9-filter | r100 | yes (the SORT parts) | |
| N2-time-wheel | r102 | yes | 124 px |
| N11-time-clock | r102 | yes, new | no golden yet: `-new.png` only |
| BH2-entry-selected | r100 | not on the list | N12: the share icon beside the time; the "Shared to …" line under the entry gone |
| N5-page-filter | r102 | not on the list | N7: SORT inside a page adds Name A–Z and Type |
| NB-remind-menu | slice10 | not on the list | N12: the same page as NB-reminder-slip, its reminder and pin icons |
| NB-reminder-slip | slice10 | not on the list | N12: pin and reminder icons beside the time; the "Reminder · …" line gone |
| NB-put-in-space | slice8 | not on the list | N9 + N10: the Space's own kinds with icons ("Note", not "Post"); Team is a row |

PG4 was expected to change but passes unchanged (both languages).
