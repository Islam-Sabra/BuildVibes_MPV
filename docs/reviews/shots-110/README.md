# Review 110 shots (claude/r110)

English and Arabic, 390 × 844, in the app's fonts, rendered by `flutter test test_screens` (not updating). No goldens were changed: these wait for the lead.

- `new/`: 19 new screens, `<name>_en.png` and `<name>_ar.png` (38 images), from `test_screens/r110_test.dart`.
- `changed/`: 67 existing screens that differ from their goldens, as `<name>_<lang>_old.png` (the golden) and `<name>_<lang>_new.png` (now), 134 pairs.

## New screens (`new/`)

| Shot | What | Frame |
|---|---|---|
| A1-spaces-loading | Notebook share → Space: "Loading your Spaces…" (never an empty card) | review 110 A |
| A2-spaces-error | The same when the Spaces can't be read: the error line, with the error's type and first line small under it | review 110 A |
| B1-reminder-me-only | Reminder on an announcement: Me only, no Someone | review 110 B |
| B2-reminder-refused | Reminder → Someone refused: "Only the person who made it, the person it's for, or a Lead can remind someone." | review 110 B |
| RM1d-picked | Reminder: the picked time alone, selected, with × | RM1d `2707:39666` |
| RM1d-later-picked | The same in Post later | RM1d |
| CP1-composer | The composer over the whole screen: × · New work item · Space · Drafts; title, details; For and Team | CP1 `2707:39361` |
| CP2-kinds | # : the kinds as a round-icon grid (Note · Work item · Announcement · Scheduled activity · Thanks · Walk) | CP2 `2707:39412` |
| CP3-extras | + : a work item's extras (Place · Due · Tag · Photos · File · Checklist · Bullets · Table · Table of tasks) | CP3 `2707:39502` |
| CP4-added | What was added: a due and a table, as chips with × | CP4 `2707:39600` |
| CP5-hold-send | Hold Send: "Post later…" | CP5 `2708:39511` |
| TH1-thanks-composer | Thanks: the words, To (a person or a Team), For (optional) | TH1 `2715:39559` |
| TH2-thanks-card | A Thanks card as the person thanked sees it: Show on my profile | TH2 `2715:39608` |
| TG1-tag | + → Tag: the market's list in place of the keyboard, Safety chosen (red) | TG1 `2715:39661` |
| TG1b-work-by-tag | A tap on a card's tag: Work shows only that tag's items, with × | review 110 E |
| S5-checklist-chip | + → Checklist on a work item: "Checklist · 2" with × | review 110 step 5 |
| ACT-activity-extras | A scheduled activity: When · Team by default; + offers People | founder, 31 Oct |
| HV1-short-cards | Short cards: a work item (2-line title and details, info, tag, "2 files · 1 table · See more"), a checklist (first 3 lines, "2 of 5 ticked · See more"), a Thanks | HV1 `2721:39795` |
| HV2-see-more | See more: the whole post, opened in place as before | HV2 `2721:39906` |

## Changed screens (`changed/`), by reason

All are image differences only: no shot step failed and nothing overflowed.

- **The composer replaces the in-list writing card (D):** E1-write, E2-more-menu, E3-assign, E3-filled-card, E6-kind-chip, E6-kind-menu, E8-could-not-send, F45-people-picker-done, F50-kind-menu, F56-to-menu, F56-who-asks, F56-who-row, F63-kind-menu, F66-who-row-chosen, F69-picker-you-first, F71-replaces-choice, F71-replaces-picked, F71-version-picker, F71-writing-replaces, F72-attach, F82-pin-add-time, F82-pin-with-time, H2-photos-preparing, K4-attach, P1-place-picker, PL1-post-later, R2-writing, R2-writing-done-today, T0-more-template, T1-template-picker, T2-checklist-from-template, T2-from-template, W-activity, W-announcement, W-checklist, W-file, W-file-chooser, DM5-writing-quote, NB-put-in-space.
- **No clock on the writing bar; Post later on holding Send (CP5):** H2-write-post, H3-write-post-filled (the Feed), PL1b-later-not-yet (the held menu says why).
- **The short card (F):** BA1-before-after, D-F20-highlight, DY1-yesterday, F51-two-photos, F57-due-strip, F68b-docket-1, F68b-docket-2, F68b-docket-12, K1-announcement-checklist, K1-announcement-folded, K1-checklist-for-sara, K5-note, L1-late-due-today, P2-site-tag, P3-place-filter, R1-numbers, R2-header-search, S1-checklist-ticks, S1-history-lines, SP3-task-table, W2-archive-swipe, W4-share-threads, card-open-page (now See more), pinned_line_3_got_it, pinned_line_5_got_it.
  - The site tag is now only as wide as its words, so the place and the tag sit on one line (HV1).
