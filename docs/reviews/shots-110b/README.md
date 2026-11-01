# Review 110 shots, after the lead's check (W1–W12)

English and Arabic, 390 × 844, in the app's fonts, rendered by `flutter test test_screens` (not updating). No goldens were changed: these wait for the lead. Shots that look the same as in `../shots-110/` are not repeated here.

- `new/`: 14 screens from `test_screens/r110_test.dart`, `<name>_en.png` and `<name>_ar.png` (28 images). Three are new; eleven were already in shots-110 and now look different.
- `changed/`: 2 existing screens whose golden differs and which were not in shots-110's `changed/`, as `<name>_<lang>_old.png` (the golden) and `<name>_<lang>_new.png` (now), 4 pairs.

## New r110 shots (`new/`)

| Shot | What | W |
|---|---|---|
| V1-viewer-thank | A Viewer's bar: "Viewer · Read only" and **Thank someone** (founder: a Viewer may post a Thanks) | founder |
| W10-tags-more | A long place and a tag: one line, the tag becomes **+1**; See more because the details run past 2 lines | W10 |
| W8-share-kinds | Notebook → Space: **Note · Work item** only (no Checklist) | W8 |

## r110 shots that changed since shots-110 (`new/`)

| Shot | What changed | W |
|---|---|---|
| A2-spaces-error | Localised words, then a short code (`Code: TypeError`), then **Try again**. The raw message is gone from the screen; it goes to Crashlytics with the restart count | W1, W2 |
| CP1-composer | Top bar: × · title · Space. **Drafts is gone.** Templates shows here only when the Space has templates for that kind (see slice7 T1/T2) | W9 |
| CP2-kinds | Same grid; the background screen follows CP1 | W9 |
| CP3-extras | A work item's + is exactly **9 tiles**: Place · Due · Tag · Photos · File · Checklist · Bullets · Table · Table of tasks. No Template | W9 |
| CP4-added, CP5-hold-send | The top bar follows CP1 | W9 |
| RM1d-later-picked | Post later: the top bar follows CP1 | W9 |
| S5-checklist-chip | "Checklist · 2" with ×; the top bar follows CP1 | W9 |
| TG1-tag | The top bar follows CP1 | W9 |
| ACT-activity-extras | The activity's +: Place · People · Photos · File · Bullets (no Template) | W9 |
| TH1-thanks-composer | **Details (optional)** under the words; the line under To: "They can show this on their profile." / «يمكنه عرض هذا في ملفه.» | W6, founder |

Not shown as a picture (they're tested): W3, W4 and W7 (server, pgTAP), W5 (two reminder refusals in plain words, `reminder_refusals_test`), W7 in the app (Thanks can be posted later, `composer_thanks_tags_test`), W9's announcement + (Photos · File · Bullets · Table · Pin, `composer_test`), W11 (the opening kind checks rights, `composer_test`), W12 (a doc comment).

## Changed existing screens (`changed/`)

- **V1-crew-locked, V1-viewer** (`review82`): the bar of a Viewer, and of a Crew pass with posting locked, now ends with **Thank someone** (founder: a Viewer may post a Thanks).

## The rest of the run

- Every other existing screen that differs from its golden (132 images) is pixel-identical to its `_new.png` in `../shots-110/changed/`: nothing new to look at.
- `slice7` T1-template-picker, T2-from-template and T2-checklist-from-template now open Templates from the top bar (W9); their pictures are unchanged from shots-110. **T0-more-template is removed** (the + menu no longer holds Template; the + menu is CP3-extras), with its two goldens.
- r110's own shots have no committed goldens yet, so their 44 tests fail as "no golden", as in shots-110.
