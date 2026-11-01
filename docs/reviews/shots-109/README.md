# Review 109 shots: Check-in

Rendered by `flutter test test_screens/r109_test.dart --update-goldens` at 390 × 844 in the app's fonts, in English (`_en`) and Arabic (`_ar`), then moved here. They are not goldens yet: they become goldens after the lead's check. The Space is on Kuwait's clock (`Asia/Kuwait`). The test phone uses the 12-hour clock, so times read "7:00 am" / «7:00 صباحًا»; on a 24-hour phone they read "7:00" as in the prototype.

## new/

| Shot | Frame (EN / AR) | What it shows |
|---|---|---|
| `CI1-composer` | CI1 `2729:39789` / `2729:39926` | "New check-in" over the Space; title, Details (optional); For: MEP + Site; Check-in: 7:00 · 15 min allowance; Place: **Set place here** in the action colour. Bar: # (map pin) · + · Send, no camera. Send off: the place isn't set. |
| `CI1b-plus` | CI1b `2729:39857` / `2729:39994` | + on a check-in: "Add to this check-in", exactly Check-out and Every day. |
| `CI1-for-picker` | CI1 (For) | For's sheet: Whole Space, then the Space's Teams, more than one ticked; Done. |
| `CI1-allowance` | CI1 (Check-in) | The Check-in sheet: the time, the allowance as one single choice (0 · 10 · 15 · 30 min), what it means and the fixed 100 m; Done. |
| `CI1-place-set` | CI1 | Place: ✓ Set here, and Send on. |
| `CI1-chips` | CI1 | Check-out (Out 3:00 pm · 15 min) and Every day as chips with ×. |
| `CI3-warning` | CI3 `2706:39486` / `2706:39815` | The first-time warning, word for word: Accept, or Check in without location. |
| `CI4-open` | CI4 `2706:39534` / `2706:39863` | The person's card: Check-in · Every day; times; **Check in · by 7:15**. |
| `CI4-on-time` | CI4 | ✓ In 6:58 · on time · on site (green); Check out · from 1:45 pm, off. |
| `CI4-late` | CI4 | In 7:24 · late (amber). |
| `CI4-not-at-site` | CI4 | In 7:01 · not at site (amber), with **Try again** while check-in is open. |
| `CI4-not-shared` | CI4 | In 7:03 · location not shared (grey). |
| `CI4-checked-out` | CI4 | In and Out stamps; nothing more to do. |
| `CI4-missed` | CI4 | No In once check-in closed: Missed (grey). |
| `CI4-creator` | CI4 / CI5 | The creator's own card (not asked): **Who checked in** opens the list. |
| `CI5-list` | CI5 `2706:39604` / `2706:39933` | One line per person: In and Out stamps, late, not at site, no location, Missed; "Today · only you see this"; the Library line. |
| `CI5-day-picker` | CI5 | The day picker: Today, then earlier days from `check_in_days`. |
| `CI5-stop-confirm` | CI5 | ⋯ → Stop (only when the card says `can_stop`): "Stop this check-in?", Keep it / Stop. |

CI2 (the notification, `2706:39456` / `2706:39785`) is drawn by the phone (Android's notification shade, iOS's banner), not by the app's widgets, so it has no shot here. Its contents (title and body from the server, Check in · Open, the "check_in" channel, the tag and id 0) are covered by `test/features/work/check_in_notice_test.dart`.

Known differences from the frames, for the lead:
- The card keeps the daybook's paper card (author line, KCT number) with the check-in body inside it; the prototype draws an orange-bordered card.
- The Check-out and Every day chips use the composer's existing chip (orange outline), not the prototype's sand chip.
- In Arabic at 12-hour time, two of the list's stamps wrap onto a second line ("صباحًا" is long). At 24-hour time they fit on one.
- The soft green and amber of the stamps are new tokens (`surfacePositiveSoft`, `surfaceWarningSoft`), picked by eye from the frames; please check them against the Figma variables.

## changed/

| Golden | Why it changed |
|---|---|
| `CP2-kinds_en`, `CP2-kinds_ar` (`test_screens/r110_test.dart`) | # now offers **Check-in** to a Lead (review 109 §1), between Scheduled activity and Thanks, so the grid's second row is Check-in · Thanks · Walk. Nothing else moved. `_old` is the golden, `_new` the screen now. |

No other golden changed. The 36 failures of `test_screens/r109_test.dart` in a plain run are only its missing goldens (on purpose: they come after the lead's check).
