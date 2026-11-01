# Review 109 shots, after the lead's check (Y1–Y12)

Rendered again with `flutter test test_screens/r109_test.dart --update-goldens`, then compared pixel by pixel (both converted to RGBA and compared as arrays) with `docs/reviews/shots-109/new/`. Only the shots that changed, and the new ones, are here. The rest of `shots-109/new/` is unchanged, including CI1-composer in Arabic: at 15 minutes it still reads «سماح 15 دقيقة», which is correct.

## new/

| Shot | Y | What it shows |
|---|---|---|
| `CI4-missed` (changed) | Y5 | No In once check-in closed: the stamp now reads "In: missed" / «دخول: لم يسجّل» (this check-in has a check-out), and **Check out** is offered in its window. Before: "Missed" and no button. |
| `Y5-out-without-in` (new) | Y5 | Checked out without checking in: "In: missed" and then the Out stamp. Nothing left to tap. |
| `CI5-list`, `CI5-day-picker`, `CI5-stop-confirm` (changed) | Y5 | The sample list has one more line, Lina Khalil, who checked out without checking in: "In: missed" over "Out 2:55 pm". The other lines are unchanged. The day picker and Stop shots changed only because that line is behind them. |
| `Y4-too-many` (new) | Y4 | After the day's 10 tries, the line "Too many tries today. Ask your Lead." / «محاولات كثيرة اليوم. اسأل المسؤول.» |
| `Y10-allowance-10` (new) | Y10 | Check-in at 10 minutes: Arabic reads «سماح 10 دقائق» (the `few` form); English reads "10 min allowance". |

Y1 (the check-in's own time zone) shows no visible change here, because the samples' check-in and Space are both on Kuwait's clock; it is covered by tests (`check_in_card_test.dart`: a check-in on Dubai's clock shows "by 8:15"). Y11 (24-hour time in the notification) and Y12 (the iPhone entitlement) have nothing to draw.

## changed/

None. A plain run of `flutter test test_screens` fails only in:
- `r109_test.dart`'s own shots, which have no goldens yet (on purpose);
- `r110_test.dart` CP2 "# the kinds", already explained in `shots-109/changed/`.
