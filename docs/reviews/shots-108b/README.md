# Review 108: shots after the lead's check (V1–V10)

All shots are 390 × 844, in English and Arabic, drawn in the app's fonts. Names are `r108--<shot>_<lang>.png`.

## How these were made
- `test_screens/r108_test.dart` drew them with `--update-goldens`. They were moved here, so `docs/screens/r108/` does not exist yet.
- No golden in the repo has changed.

## New
| Shot | Fix | What it shows |
|---|---|---|
| PL2c-scheduled-failed | V2 | Scheduled with a failed post on top: "Couldn't post: you can't post there any more." It has only **Post now · Cancel**, because Edit is not offered on a failed one. A waiting post below it keeps Post now · Edit · Cancel. |
| RM1b-reminder-two-people | V6 | The Reminder sheet on Someone with two people. The Who row reads "Omar Haddad + Rakesh Nair", full names with no first-name split. |
| RM1c-reminder-daily-most | V4 | Set reminder after 20 that day: "You've set the most reminders for today." («تم ضبط أقصى عدد من التذكيرات لهذا اليوم.») The sheet stays open. |
| PL1b-later-not-yet | V7 | A work item with a place from the Space's list. The clock is grey, and tapping it says "Items with files or a place can't be scheduled yet." («لا يمكن جدولة بند فيه ملفات أو مكان حاليًا.») |

## Not changed
- **The 10 r108 shots in `docs/reviews/shots-108/`:** RM1, RM2, PL1, PL2 and PL2b were drawn again and are byte-identical.
- **The 54 writing-bar shots (60 images) that show the clock:** they were drawn again and are byte-identical to their `-new.png` in shots-108.
- **V3 (the Space's clock and calendar):** it changes times, not how anything looks. The shot Space has no time zone, so it uses the phone's clock, and its project's market is Kuwait's. Tests cover V3 instead, with a Space in another zone and a Saturday–Sunday weekend.
- **V1, V5, V8, V9 and V10:** these are server changes, covered by pgTAP. Nothing on screen changes.
