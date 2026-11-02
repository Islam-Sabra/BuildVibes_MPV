# Review 113 Part B: shots

Rendered from `test_screens/r113b_test.dart` on branch `claude/r113-b`, 390 × 844, English and Arabic. Every image was looked at.

## new/ (28 tests, 40 images, each `_en` and `_ar`)
| Shot | What |
|---|---|
| NN0-person-sheet | The person sheet from People, with Need you now |
| NN1-sheet, NN1-sheet-filled | NN1: the sheet empty; with a reason and Add place used |
| NN1-refusal | The 3-an-hour refusal, inside the sheet |
| NN3-sender-waiting, NN3-sender-answered | The sender's line in the Space |
| NN4-call-in-space | A call I got, with On my way · Can't now, for when the notification has gone |
| LB1-folders, LB1-add-menu, LB1-inside-folder | LB1, + menu, a folder's files |
| LB1-share-team-picker, LB1-share-team-picked | The sharing choice with its Team pick |
| LB2-link-folder, LB2-wrong-link | LB2: service found; a link of another service, Add off |
| B7-too-big | 38 MB refused before it goes, with Link folder |
| B7-draft-could-not-send, B7-composer-line | The refused Draft on Work, and the line in the composer |
| B7-tap-to-fix, B7-tap-to-fix-generic | Tap to fix: storage said too big; another refusal |
| NUDGE-composer | The composer opened from the nudge |

**NN2 isn't here:** it is the phone's own notification, not a widget. Its words, tag, id, channel and buttons are tested in `test/features/need_you/need_you_notice_test.dart`.

## changed/ (10 existing goldens, `_old` and `_new`; full-colour RGBA comparison)
| Golden | Why it changed | Expected? |
|---|---|---|
| F70-library-empty, LV1-library | LB1: Space name under Library; + for folders (LV1) | Yes |
| F79-person-sheet | Need you now row added | Yes |
| N3-refused-for-yourself | The refused line is now tappable: 4 px padding moves it down | Yes |
| SP9-removal-sheet | "Their private folders … will be deleted." added | Yes (the lead's ruling) |

## Where these differ from the frames, for the lead
- LB1 keeps **Search files** above the folders (the frame has none): existing files and search needed a place.
- LB2: "Whole Space" wraps to a second line in English, because `BvChip` is wider than the frame's chips.
- LB2: the link icon is at the field's end, not its start (`BvTextField` has only an end icon).
- **The Space line (NN3, NN4) has no frame.** The review only says "the sender sees the answer". It uses the brand-soft box under Work · Chat; my own calls show for 2 hours, unanswered calls I got for 24 hours.
- B7-tap-to-fix says "This file is too big. The most is 25 MB." without a size: the sample file is 4.8 MB, and the app quotes a number only when the phone's size is over the limit.
