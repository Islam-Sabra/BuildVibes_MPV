# Review 113 shots (claude/r113)

English and Arabic, 390 × 844, in the app's fonts. Rendered by `test_screens/r113_test.dart` and `r113b_test.dart` on the merged branch (parts A, B and the server), so the images show the parts together. After the lead's check (Z1–Z13) the goldens were updated to these images; CV3_long_press has the Z8 menu order. `changed/` keeps each old golden beside its new one.

- `new/`: 38 screens, `<name>_<lang>.png` (76 images).
- `changed/`: 154 existing screens that differ from their goldens (308 old/new pairs), compared in full colour, one test file at a time so same-named goldens can't overwrite each other. Named `<folder>__<name>_<lang>_old.png` (the golden) and `_new.png` (now).
- **The Need you now line under Work · Chat has no frame:** NN3-sender-waiting, NN3-sender-answered, NN4-call-in-space, for the lead to judge.
- **Check-in's pinned lines are four,** not three: Type · For · Check-in · Place (NUDGE-composer).

Part A's section below names changed files as it found them; part B's five screens (F70-library-empty, LV1-library, F79-person-sheet, N3-refused-for-yourself, SP9-removal-sheet) are in `changed/` under their folders too.

Rendered by `test_screens/r113_test.dart`, English and Arabic, 390 × 844, in the app's fonts. `new/` holds this part's screens; `changed/` holds every existing golden that now differs. Part B's images and `README-b.md` are its own.

## New (`new/`, `<name>_en.png` and `<name>_ar.png`)

| Shot | What it shows | Frame |
|---|---|---|
| ST1_spaces_tab | Spaces tab: Messages and Notebook, no Search; one "3 need you · in 2 Spaces" line; each Space with its pass, new today or quiet, and its mark; small New Space · Join with a code; bottom bar with no Home | ST1 `2730:40062` / `2730:40522` |
| ST1_empty | No Space yet: a short note and the same word buttons | ST1 (words of the review) |
| RX1_cards | A Space opening on Work; a card with React · Share and reactions as icons with faces, no number | RX1 `2730:39887` / `2730:40347` |
| RX1_picker | The picker: Like · Heart · Bravo | RX1 |
| RX1_names | Who reacted, after a tap on the faces | RX1 (words) |
| RX1_share | Share into this Space's Chat: Everyone, or a Team chat I'm in | RX1 (words) |
| HOLD_delete | Hold my post nobody acted on: Delete | Hold (words) |
| HOLD_archive | Hold my post someone acted on: Archive | Hold (words) |
| HOLD_archive_open | Archive of an open work item: the question that says it stops it and tells the owner | Hold (words) |
| CV3_composer | Discard; title and details above; Type · For · Team pinned; + · camera · mic · Send | CV3 `2730:39817` / `2730:40277` |
| CV3_discard | "Discard this draft?" | CV3 (words) |
| CV3_type | Type opens the kinds' grid | CV3 |
| CV3_long_press | The long-press menu, its overflow open. **Its labels draw as blocks here**: the phone's own toolbar uses the system font, which the test renderer doesn't have. The labels are proved in `composer_cv3_test.dart`. Check this one on a phone | CV3 (words) |
| CV3_slash | "/" at the start of a line: the same short menu | CV3 (words) |
| CV3_recording | Holding the mic: the time and "Slide away to cancel" | CV3 (words) |
| CV3_voice_chip | The note as a chip above the lines | CV3 |
| CV3_voice_card | A card with a voice note to play | CV3 (words) |

Deliberate difference from RX1/ST1: a Space row says "new today", not "2 new today", because the server gives no count of a Space's news.

## Changed goldens (`changed/<folder>__<name>_old.png` and `_new.png`)

Each pair was compared in full colour (RGBA arrays): all differ. Three causes:

1. **Cards:** the React · Share row at the foot of every card makes cards taller, so what sits below moves. This is the cause wherever a Work page, or a sheet or dialog over one, is in the shot. The smallest changes (0.0% to 0.14%) are a dimmed page behind a sheet.
2. **Composer CV3:** Discard, the pinned lines, the bar without # and with the mic.
3. **Feed hidden:** shots taken through the whole app that showed Home now show the Spaces tab. Frames of the feed itself render with the switch on (`shot.dart`), so they didn't change.

`F71-replaces-picked` has the same name in `review80` and `review82`; each file was run alone, so both pairs are its own.

| Folder | Golden | Diff | Why |
|---|---|---|---|
| f104 | pinned_line_3_got_it_ar | 3.93% | cards: React · Share row (and the voice/reactions space it takes) |
| f104 | pinned_line_3_got_it_en | 3.71% | cards: React · Share row (and the voice/reactions space it takes) |
| f104 | pinned_line_5_got_it_ar | 3.93% | cards: React · Share row (and the voice/reactions space it takes) |
| f104 | pinned_line_5_got_it_en | 3.71% | cards: React · Share row (and the voice/reactions space it takes) |
| f60 | H2-photos-preparing_ar | 3.68% | composer CV3: Discard, pinned lines, bar, no # |
| f60 | H2-photos-preparing_en | 3.8% | composer CV3: Discard, pinned lines, bar, no # |
| f68b | F68b-docket-12_ar | 18.83% | cards: React · Share row (and the voice/reactions space it takes) |
| f68b | F68b-docket-12_en | 14.18% | cards: React · Share row (and the voice/reactions space it takes) |
| f68b | F68b-docket-1_ar | 18.83% | cards: React · Share row (and the voice/reactions space it takes) |
| f68b | F68b-docket-1_en | 14.18% | cards: React · Share row (and the voice/reactions space it takes) |
| f68b | F68b-docket-2_ar | 18.83% | cards: React · Share row (and the voice/reactions space it takes) |
| f68b | F68b-docket-2_en | 14.18% | cards: React · Share row (and the voice/reactions space it takes) |
| f68b | F69-picker-you-first_ar | 25.75% | composer CV3: Discard, pinned lines, bar, no # |
| f68b | F69-picker-you-first_en | 24.83% | composer CV3: Discard, pinned lines, bar, no # |
| hold-confirm | H1-hold-at-rest_en | 2.48% | cards: React · Share row (and the voice/reactions space it takes) |
| hold-confirm | H2-hold-half_en | 2.48% | cards: React · Share row (and the voice/reactions space it takes) |
| hold-confirm | H3-checked-undo_ar | 2.02% | cards: React · Share row (and the voice/reactions space it takes) |
| hold-confirm | H3-checked-undo_en | 4.43% | cards: React · Share row (and the voice/reactions space it takes) |
| r102 | N11-time-clock_ar | 2.53% | feed hidden: the app opens on the Spaces tab |
| r102 | N11-time-clock_en | 2.91% | feed hidden: the app opens on the Spaces tab |
| r102 | N2-time-wheel_ar | 4.59% | feed hidden: the app opens on the Spaces tab |
| r102 | N2-time-wheel_en | 5.08% | feed hidden: the app opens on the Spaces tab |
| r105b | W1-my-pins_ar | 13.69% | cards: React · Share row (and the voice/reactions space it takes) |
| r105b | W1-my-pins_en | 14.49% | cards: React · Share row (and the voice/reactions space it takes) |
| r105b | W2-archive-swipe_ar | 7.93% | cards: React · Share row (and the voice/reactions space it takes) |
| r105b | W2-archive-swipe_en | 8.52% | cards: React · Share row (and the voice/reactions space it takes) |
| r105b | W3-archived-undo_ar | 4.04% | cards: React · Share row (and the voice/reactions space it takes) |
| r105b | W3-archived-undo_en | 3.72% | cards: React · Share row (and the voice/reactions space it takes) |
| r105b | W4-share-threads_ar | 18.58% | cards: React · Share row (and the voice/reactions space it takes) |
| r105b | W4-share-threads_en | 23.56% | cards: React · Share row (and the voice/reactions space it takes) |
| r105c | BA1-before-after_ar | 4.03% | cards: React · Share row (and the voice/reactions space it takes) |
| r105c | BA1-before-after_en | 3.71% | cards: React · Share row (and the voice/reactions space it takes) |
| r105c | P1-place-picker_ar | 2.57% | composer CV3: Discard, pinned lines, bar, no # |
| r105c | P1-place-picker_en | 2.63% | composer CV3: Discard, pinned lines, bar, no # |
| r105c | P2-site-tag_ar | 4.03% | cards: React · Share row (and the voice/reactions space it takes) |
| r105c | P2-site-tag_en | 3.71% | cards: React · Share row (and the voice/reactions space it takes) |
| r105c | P3-place-filter_ar | 13.9% | cards: React · Share row (and the voice/reactions space it takes) |
| r105c | P3-place-filter_en | 12.98% | cards: React · Share row (and the voice/reactions space it takes) |
| r105c | SP3-task-table_ar | 4.03% | cards: React · Share row (and the voice/reactions space it takes) |
| r105c | SP3-task-table_en | 3.71% | cards: React · Share row (and the voice/reactions space it takes) |
| r107 | OB7-tip1-camera_ar | 11.39% | cards: React · Share row (and the voice/reactions space it takes) |
| r107 | OB7-tip1-camera_en | 13.71% | cards: React · Share row (and the voice/reactions space it takes) |
| r107 | OB7-tip2-hold_ar | 16.63% | cards: React · Share row (and the voice/reactions space it takes) |
| r107 | OB7-tip2-hold_en | 17.2% | cards: React · Share row (and the voice/reactions space it takes) |
| r107 | OB7-tip3-sign-done_ar | 18.67% | cards: React · Share row (and the voice/reactions space it takes) |
| r107 | OB7-tip3-sign-done_en | 17.84% | cards: React · Share row (and the voice/reactions space it takes) |
| r108 | PL1-post-later_ar | 3.43% | composer CV3: Discard, pinned lines, bar, no # |
| r108 | PL1-post-later_en | 3.68% | composer CV3: Discard, pinned lines, bar, no # |
| r108 | PL1b-later-not-yet_ar | 7.73% | composer CV3: Discard, pinned lines, bar, no # |
| r108 | PL1b-later-not-yet_en | 8.15% | composer CV3: Discard, pinned lines, bar, no # |
| r108 | PL2b-space-scheduled-line_ar | 4.03% | cards: React · Share row (and the voice/reactions space it takes) |
| r108 | PL2b-space-scheduled-line_en | 3.71% | cards: React · Share row (and the voice/reactions space it takes) |
| r108 | RM1-reminder-someone_ar | 2.41% | cards: React · Share row (and the voice/reactions space it takes) |
| r108 | RM1-reminder-someone_en | 3.71% | cards: React · Share row (and the voice/reactions space it takes) |
| r108 | RM1b-reminder-two-people_ar | 2.3% | cards: React · Share row (and the voice/reactions space it takes) |
| r108 | RM1b-reminder-two-people_en | 3.71% | cards: React · Share row (and the voice/reactions space it takes) |
| r108 | RM1c-reminder-daily-most_ar | 0.0% | cards: React · Share row (and the voice/reactions space it takes) |
| r108 | RM1c-reminder-daily-most_en | 3.5% | cards: React · Share row (and the voice/reactions space it takes) |
| r109 | CI1-allowance_ar | 7.03% | composer CV3: Discard, pinned lines, bar, no # |
| r109 | CI1-allowance_en | 5.92% | composer CV3: Discard, pinned lines, bar, no # |
| r109 | CI1-chips_ar | 17.29% | composer CV3: Discard, pinned lines, bar, no # |
| r109 | CI1-chips_en | 14.85% | composer CV3: Discard, pinned lines, bar, no # |
| r109 | CI1-composer_ar | 8.72% | composer CV3: Discard, pinned lines, bar, no # |
| r109 | CI1-composer_en | 7.47% | composer CV3: Discard, pinned lines, bar, no # |
| r109 | CI1-for-picker_ar | 7.03% | composer CV3: Discard, pinned lines, bar, no # |
| r109 | CI1-for-picker_en | 5.92% | composer CV3: Discard, pinned lines, bar, no # |
| r109 | CI1-place-set_ar | 8.24% | composer CV3: Discard, pinned lines, bar, no # |
| r109 | CI1-place-set_en | 7.06% | composer CV3: Discard, pinned lines, bar, no # |
| r109 | CI1b-plus_ar | 9.66% | composer CV3: Discard, pinned lines, bar, no # |
| r109 | CI1b-plus_en | 8.4% | composer CV3: Discard, pinned lines, bar, no # |
| r109 | CI3-warning_ar | 4.03% | cards: React · Share row (and the voice/reactions space it takes) |
| r109 | CI3-warning_en | 3.71% | cards: React · Share row (and the voice/reactions space it takes) |
| r109 | CI4-checked-out_ar | 4.03% | cards: React · Share row (and the voice/reactions space it takes) |
| r109 | CI4-checked-out_en | 3.71% | cards: React · Share row (and the voice/reactions space it takes) |
| r109 | CI4-creator_ar | 4.03% | cards: React · Share row (and the voice/reactions space it takes) |
| r109 | CI4-creator_en | 3.71% | cards: React · Share row (and the voice/reactions space it takes) |
| r109 | CI4-late_ar | 4.03% | cards: React · Share row (and the voice/reactions space it takes) |
| r109 | CI4-late_en | 3.71% | cards: React · Share row (and the voice/reactions space it takes) |
| r109 | CI4-missed_ar | 4.03% | cards: React · Share row (and the voice/reactions space it takes) |
| r109 | CI4-missed_en | 3.71% | cards: React · Share row (and the voice/reactions space it takes) |
| r109 | CI4-not-at-site_ar | 4.03% | cards: React · Share row (and the voice/reactions space it takes) |
| r109 | CI4-not-at-site_en | 3.71% | cards: React · Share row (and the voice/reactions space it takes) |
| r109 | CI4-not-shared_ar | 4.03% | cards: React · Share row (and the voice/reactions space it takes) |
| r109 | CI4-not-shared_en | 3.71% | cards: React · Share row (and the voice/reactions space it takes) |
| r109 | CI4-on-time_ar | 4.03% | cards: React · Share row (and the voice/reactions space it takes) |
| r109 | CI4-on-time_en | 3.71% | cards: React · Share row (and the voice/reactions space it takes) |
| r109 | CI4-open_ar | 4.03% | cards: React · Share row (and the voice/reactions space it takes) |
| r109 | CI4-open_en | 3.71% | cards: React · Share row (and the voice/reactions space it takes) |
| r109 | Y10-allowance-10_ar | 8.72% | composer CV3: Discard, pinned lines, bar, no # |
| r109 | Y10-allowance-10_en | 7.48% | composer CV3: Discard, pinned lines, bar, no # |
| r109 | Y4-too-many_ar | 4.03% | cards: React · Share row (and the voice/reactions space it takes) |
| r109 | Y4-too-many_en | 3.71% | cards: React · Share row (and the voice/reactions space it takes) |
| r109 | Y5-out-without-in_ar | 4.03% | cards: React · Share row (and the voice/reactions space it takes) |
| r109 | Y5-out-without-in_en | 3.71% | cards: React · Share row (and the voice/reactions space it takes) |
| r110 | ACT-activity-extras_ar | 4.69% | composer CV3: Discard, pinned lines, bar, no # |
| r110 | ACT-activity-extras_en | 4.69% | composer CV3: Discard, pinned lines, bar, no # |
| r110 | B1-reminder-me-only_ar | 4.03% | cards: React · Share row (and the voice/reactions space it takes) |
| r110 | B1-reminder-me-only_en | 3.71% | cards: React · Share row (and the voice/reactions space it takes) |
| r110 | CP1-composer_ar | 4.72% | composer CV3: Discard, pinned lines, bar, no # |
| r110 | CP1-composer_en | 5.06% | composer CV3: Discard, pinned lines, bar, no # |
| r110 | CP2-kinds_ar | 5.15% | composer CV3: Discard, pinned lines, bar, no # |
| r110 | CP2-kinds_en | 5.49% | composer CV3: Discard, pinned lines, bar, no # |
| r110 | CP3-extras_ar | 5.61% | composer CV3: Discard, pinned lines, bar, no # |
| r110 | CP3-extras_en | 5.95% | composer CV3: Discard, pinned lines, bar, no # |
| r110 | CP4-added_ar | 14.25% | composer CV3: Discard, pinned lines, bar, no # |
| r110 | CP4-added_en | 13.07% | composer CV3: Discard, pinned lines, bar, no # |
| r110 | CP5-hold-send_ar | 4.66% | composer CV3: Discard, pinned lines, bar, no # |
| r110 | CP5-hold-send_en | 5.0% | composer CV3: Discard, pinned lines, bar, no # |
| r110 | HV1-short-cards_ar | 13.47% | cards: React · Share row (and the voice/reactions space it takes) |
| r110 | HV1-short-cards_en | 14.59% | cards: React · Share row (and the voice/reactions space it takes) |
| r110 | RM1d-later-picked_ar | 3.43% | composer CV3: Discard, pinned lines, bar, no # |
| r110 | RM1d-later-picked_en | 3.68% | composer CV3: Discard, pinned lines, bar, no # |
| r110 | S5-checklist-chip_ar | 8.35% | composer CV3: Discard, pinned lines, bar, no # |
| r110 | S5-checklist-chip_en | 8.49% | composer CV3: Discard, pinned lines, bar, no # |
| r110 | TG1-tag_ar | 8.32% | composer CV3: Discard, pinned lines, bar, no # |
| r110 | TG1-tag_en | 8.52% | composer CV3: Discard, pinned lines, bar, no # |
| r110 | TG1b-work-by-tag_ar | 4.9% | cards: React · Share row (and the voice/reactions space it takes) |
| r110 | TG1b-work-by-tag_en | 3.71% | cards: React · Share row (and the voice/reactions space it takes) |
| r110 | TH1-thanks-composer_ar | 4.26% | composer CV3: Discard, pinned lines, bar, no # |
| r110 | TH1-thanks-composer_en | 4.98% | composer CV3: Discard, pinned lines, bar, no # |
| r110 | TH2-thanks-card_ar | 3.93% | cards: React · Share row (and the voice/reactions space it takes) |
| r110 | TH2-thanks-card_en | 3.82% | cards: React · Share row (and the voice/reactions space it takes) |
| r110 | V1-viewer-thank_ar | 15.87% | cards: React · Share row (and the voice/reactions space it takes) |
| r110 | V1-viewer-thank_en | 18.18% | cards: React · Share row (and the voice/reactions space it takes) |
| r110 | W10-tags-more_ar | 4.03% | cards: React · Share row (and the voice/reactions space it takes) |
| r110 | W10-tags-more_en | 3.71% | cards: React · Share row (and the voice/reactions space it takes) |
| r112 | N1-alone-invite_ar | 6.49% | composer CV3: Discard, pinned lines, bar, no # |
| r112 | N1-alone-invite_en | 7.04% | composer CV3: Discard, pinned lines, bar, no # |
| r112 | N3-refused-for-yourself_ar | 5.1% | composer CV3: Discard, pinned lines, bar, no # |
| r112 | N3-refused-for-yourself_en | 5.73% | composer CV3: Discard, pinned lines, bar, no # |
| r95 | R1-numbers_ar | 11.85% | cards: React · Share row (and the voice/reactions space it takes) |
| r95 | R1-numbers_en | 17.53% | cards: React · Share row (and the voice/reactions space it takes) |
| r95 | R2-header-search_ar | 16.77% | cards: React · Share row (and the voice/reactions space it takes) |
| r95 | R2-header-search_en | 22.28% | cards: React · Share row (and the voice/reactions space it takes) |
| review72 | F59-masthead-today_ar | 24.36% | cards: React · Share row (and the voice/reactions space it takes) |
| review72 | F59-masthead-today_en | 21.05% | cards: React · Share row (and the voice/reactions space it takes) |
| review72 | F62-send-back-date_en | 0.08% | cards: React · Share row (and the voice/reactions space it takes) |
| review72 | F62-sent-back-new-date_ar | 4.04% | cards: React · Share row (and the voice/reactions space it takes) |
| review72 | F62-sent-back-new-date_en | 3.72% | cards: React · Share row (and the voice/reactions space it takes) |
| review72 | F63-kind-menu_ar | 3.68% | composer CV3: Discard, pinned lines, bar, no # |
| review72 | F63-kind-menu_en | 3.8% | composer CV3: Discard, pinned lines, bar, no # |
| review72 | F66-who-row-chosen_ar | 4.92% | composer CV3: Discard, pinned lines, bar, no # |
| review72 | F66-who-row-chosen_en | 4.95% | composer CV3: Discard, pinned lines, bar, no # |
| review80 | F71-replaces-choice_ar | 1.65% | composer CV3: Discard, pinned lines, bar, no # |
| review80 | F71-replaces-choice_en | 1.53% | composer CV3: Discard, pinned lines, bar, no # |
| review80 | F71-replaces-picked_ar | 1.65% | composer CV3: Discard, pinned lines, bar, no # |
| review80 | F71-replaces-picked_en | 1.53% | composer CV3: Discard, pinned lines, bar, no # |
| review80 | F71-version-picker_ar | 1.65% | composer CV3: Discard, pinned lines, bar, no # |
| review80 | F71-version-picker_en | 1.53% | composer CV3: Discard, pinned lines, bar, no # |
| review80 | F71-writing-replaces_ar | 11.3% | composer CV3: Discard, pinned lines, bar, no # |
| review80 | F71-writing-replaces_en | 11.23% | composer CV3: Discard, pinned lines, bar, no # |
| review80 | F72-attach_ar | 1.65% | composer CV3: Discard, pinned lines, bar, no # |
| review80 | F72-attach_en | 1.53% | composer CV3: Discard, pinned lines, bar, no # |
| review80 | F75-F76-versions_ar | 25.24% | cards: React · Share row (and the voice/reactions space it takes) |
| review80 | F75-F76-versions_en | 26.09% | cards: React · Share row (and the voice/reactions space it takes) |
| review80 | F82-F85-pinned_ar | 5.16% | cards: React · Share row (and the voice/reactions space it takes) |
| review80 | F82-F85-pinned_en | 9.45% | cards: React · Share row (and the voice/reactions space it takes) |
| review80 | F82-pin-add-time_ar | 6.78% | composer CV3: Discard, pinned lines, bar, no # |
| review80 | F82-pin-add-time_en | 6.49% | composer CV3: Discard, pinned lines, bar, no # |
| review80 | F82-pin-with-time_ar | 8.22% | composer CV3: Discard, pinned lines, bar, no # |
| review80 | F82-pin-with-time_en | 7.58% | composer CV3: Discard, pinned lines, bar, no # |
| review82 | F71-replaces-picked_ar | 1.65% | composer CV3: Discard, pinned lines, bar, no # |
| review82 | F71-replaces-picked_en | 1.53% | composer CV3: Discard, pinned lines, bar, no # |
| review82 | S1-checklist-ticks_ar | 3.93% | cards: React · Share row (and the voice/reactions space it takes) |
| review82 | S1-checklist-ticks_en | 3.71% | cards: React · Share row (and the voice/reactions space it takes) |
| review82 | S1-history-lines_ar | 22.18% | cards: React · Share row (and the voice/reactions space it takes) |
| review82 | S1-history-lines_en | 24.36% | cards: React · Share row (and the voice/reactions space it takes) |
| slice1 | A1-times-12h_ar | 24.97% | cards: React · Share row (and the voice/reactions space it takes) |
| slice1 | A1-times-12h_en | 26.95% | cards: React · Share row (and the voice/reactions space it takes) |
| slice1 | B1-long-press-proof_en | 0.08% | cards: React · Share row (and the voice/reactions space it takes) |
| slice1 | B2-send-back-reasons_en | 0.08% | cards: React · Share row (and the voice/reactions space it takes) |
| slice1 | C6-long-press-other-item_ar | 2.74% | cards: React · Share row (and the voice/reactions space it takes) |
| slice1 | D-F20-highlight_ar | 10.33% | cards: React · Share row (and the voice/reactions space it takes) |
| slice1 | D-F20-highlight_en | 10.21% | cards: React · Share row (and the voice/reactions space it takes) |
| slice1 | D-F24-update-sheet-keyboard_en | 0.5% | cards: React · Share row (and the voice/reactions space it takes) |
| slice1 | D2-proof-slip-note-only_ar | 11.24% | cards: React · Share row (and the voice/reactions space it takes) |
| slice1 | D2-proof-slip-note-only_en | 15.37% | cards: React · Share row (and the voice/reactions space it takes) |
| slice1 | D3-signed-undo_ar | 22.87% | cards: React · Share row (and the voice/reactions space it takes) |
| slice1 | D3-signed-undo_en | 28.13% | cards: React · Share row (and the voice/reactions space it takes) |
| slice1 | DY1-yesterday_ar | 3.6% | cards: React · Share row (and the voice/reactions space it takes) |
| slice1 | DY1-yesterday_en | 7.21% | cards: React · Share row (and the voice/reactions space it takes) |
| slice1 | DY2-calendar_ar | 7.1% | cards: React · Share row (and the voice/reactions space it takes) |
| slice1 | DY2-calendar_en | 9.66% | cards: React · Share row (and the voice/reactions space it takes) |
| slice1 | E1-write_ar | 3.68% | composer CV3: Discard, pinned lines, bar, no # |
| slice1 | E1-write_en | 3.8% | composer CV3: Discard, pinned lines, bar, no # |
| slice1 | E2-more-menu_ar | 4.56% | composer CV3: Discard, pinned lines, bar, no # |
| slice1 | E2-more-menu_en | 4.68% | composer CV3: Discard, pinned lines, bar, no # |
| slice1 | E3-assign_ar | 3.96% | composer CV3: Discard, pinned lines, bar, no # |
| slice1 | E3-assign_en | 4.49% | composer CV3: Discard, pinned lines, bar, no # |
| slice1 | E3-filled-card_ar | 11.4% | composer CV3: Discard, pinned lines, bar, no # |
| slice1 | E3-filled-card_en | 12.22% | composer CV3: Discard, pinned lines, bar, no # |
| slice1 | E4-draft_ar | 7.38% | cards: React · Share row (and the voice/reactions space it takes) |
| slice1 | E4-draft_en | 13.95% | cards: React · Share row (and the voice/reactions space it takes) |
| slice1 | E5-posted_ar | 20.75% | cards: React · Share row (and the voice/reactions space it takes) |
| slice1 | E5-posted_en | 27.43% | cards: React · Share row (and the voice/reactions space it takes) |
| slice1 | E6-kind-chip_ar | 3.68% | composer CV3: Discard, pinned lines, bar, no # |
| slice1 | E6-kind-chip_en | 3.8% | composer CV3: Discard, pinned lines, bar, no # |
| slice1 | E7-waiting-to-send_ar | 5.71% | cards: React · Share row (and the voice/reactions space it takes) |
| slice1 | E7-waiting-to-send_en | 6.05% | cards: React · Share row (and the voice/reactions space it takes) |
| slice1 | E8-could-not-send_ar | 4.66% | cards: React · Share row (and the voice/reactions space it takes) |
| slice1 | E8-could-not-send_en | 4.94% | cards: React · Share row (and the voice/reactions space it takes) |
| slice1 | L1-late-due-today_ar | 18.83% | cards: React · Share row (and the voice/reactions space it takes) |
| slice1 | L1-late-due-today_en | 14.18% | cards: React · Share row (and the voice/reactions space it takes) |
| slice1 | O1-omars-daybook_ar | 14.03% | cards: React · Share row (and the voice/reactions space it takes) |
| slice1 | O1-omars-daybook_en | 21.33% | cards: React · Share row (and the voice/reactions space it takes) |
| slice1 | O3-proof-posted_ar | 24.04% | cards: React · Share row (and the voice/reactions space it takes) |
| slice1 | O3-proof-posted_en | 3.72% | cards: React · Share row (and the voice/reactions space it takes) |
| slice1 | O5-could-not-send_ar | 26.35% | cards: React · Share row (and the voice/reactions space it takes) |
| slice1 | O5-could-not-send_en | 29.74% | cards: React · Share row (and the voice/reactions space it takes) |
| slice1 | V1-viewer_ar | 25.22% | cards: React · Share row (and the voice/reactions space it takes) |
| slice1 | V1-viewer_en | 26.86% | cards: React · Share row (and the voice/reactions space it takes) |
| slice1 | V13-add-update_en | 0.08% | cards: React · Share row (and the voice/reactions space it takes) |
| slice1 | V13-checked-undo_ar | 2.02% | cards: React · Share row (and the voice/reactions space it takes) |
| slice1 | V13-checked-undo_en | 4.43% | cards: React · Share row (and the voice/reactions space it takes) |
| slice1 | V13-islams-daybook-top_ar | 5.13% | cards: React · Share row (and the voice/reactions space it takes) |
| slice1 | V13-islams-daybook-top_en | 9.48% | cards: React · Share row (and the voice/reactions space it takes) |
| slice1 | V13-islams-daybook_ar | 24.79% | cards: React · Share row (and the voice/reactions space it takes) |
| slice1 | V13-islams-daybook_en | 28.2% | cards: React · Share row (and the voice/reactions space it takes) |
| slice1 | V13-omar-sent-back_ar | 24.73% | cards: React · Share row (and the voice/reactions space it takes) |
| slice1 | V13-omar-sent-back_en | 27.42% | cards: React · Share row (and the voice/reactions space it takes) |
| slice1 | X1-own-item-menu_en | 0.14% | cards: React · Share row (and the voice/reactions space it takes) |
| slice1 | X2-give-to_en | 0.14% | cards: React · Share row (and the voice/reactions space it takes) |
| slice1 | X2-given_ar | 18.54% | cards: React · Share row (and the voice/reactions space it takes) |
| slice1 | X2-given_en | 25.77% | cards: React · Share row (and the voice/reactions space it takes) |
| slice1 | X3-cancelled_ar | 15.07% | cards: React · Share row (and the voice/reactions space it takes) |
| slice1 | X3-cancelled_en | 14.71% | cards: React · Share row (and the voice/reactions space it takes) |
| slice1 | Y1-swipe-update_en | 0.54% | cards: React · Share row (and the voice/reactions space it takes) |
| slice10 | A1-post-kinds_ar | 0.14% | cards: React · Share row (and the voice/reactions space it takes) |
| slice10 | A1-post-kinds_en | 0.13% | cards: React · Share row (and the voice/reactions space it takes) |
| slice10 | OF-no-signal_ar | 21.67% | cards: React · Share row (and the voice/reactions space it takes) |
| slice10 | OF-no-signal_en | 24.92% | cards: React · Share row (and the voice/reactions space it takes) |
| slice10 | S3-not-yet_ar | 0.14% | cards: React · Share row (and the voice/reactions space it takes) |
| slice10 | S3-not-yet_en | 0.13% | cards: React · Share row (and the voice/reactions space it takes) |
| slice2 | E6-kind-menu_ar | 3.68% | composer CV3: Discard, pinned lines, bar, no # |
| slice2 | E6-kind-menu_en | 3.8% | composer CV3: Discard, pinned lines, bar, no # |
| slice2 | F34-facts-line_ar | 24.79% | cards: React · Share row (and the voice/reactions space it takes) |
| slice2 | F34-facts-line_en | 28.2% | cards: React · Share row (and the voice/reactions space it takes) |
| slice2 | F45-people-picker-done_ar | 3.89% | composer CV3: Discard, pinned lines, bar, no # |
| slice2 | F45-people-picker-done_en | 4.25% | composer CV3: Discard, pinned lines, bar, no # |
| slice2 | F48-received-sheet_en | 1.33% | cards: React · Share row (and the voice/reactions space it takes) |
| slice2 | F50-kind-menu_ar | 3.68% | composer CV3: Discard, pinned lines, bar, no # |
| slice2 | F50-kind-menu_en | 3.8% | composer CV3: Discard, pinned lines, bar, no # |
| slice2 | F51-two-photos_ar | 4.04% | cards: React · Share row (and the voice/reactions space it takes) |
| slice2 | F51-two-photos_en | 3.72% | cards: React · Share row (and the voice/reactions space it takes) |
| slice2 | F56-to-menu_ar | 17.31% | composer CV3: Discard, pinned lines, bar, no # |
| slice2 | F56-to-menu_en | 17.52% | composer CV3: Discard, pinned lines, bar, no # |
| slice2 | F56-who-asks_ar | 3.96% | composer CV3: Discard, pinned lines, bar, no # |
| slice2 | F56-who-asks_en | 4.49% | composer CV3: Discard, pinned lines, bar, no # |
| slice2 | F56-who-row_ar | 3.68% | composer CV3: Discard, pinned lines, bar, no # |
| slice2 | F56-who-row_en | 3.8% | composer CV3: Discard, pinned lines, bar, no # |
| slice2 | F57-due-strip_ar | 18.83% | cards: React · Share row (and the voice/reactions space it takes) |
| slice2 | F57-due-strip_en | 14.18% | cards: React · Share row (and the voice/reactions space it takes) |
| slice2 | K1-announcement-checklist_ar | 4.04% | cards: React · Share row (and the voice/reactions space it takes) |
| slice2 | K1-announcement-checklist_en | 3.72% | cards: React · Share row (and the voice/reactions space it takes) |
| slice2 | K1-announcement-folded_ar | 4.04% | cards: React · Share row (and the voice/reactions space it takes) |
| slice2 | K1-announcement-folded_en | 3.72% | cards: React · Share row (and the voice/reactions space it takes) |
| slice2 | K1-checklist-for-sara_ar | 4.04% | cards: React · Share row (and the voice/reactions space it takes) |
| slice2 | K1-checklist-for-sara_en | 3.72% | cards: React · Share row (and the voice/reactions space it takes) |
| slice2 | K2-activity-file_ar | 32.44% | cards: React · Share row (and the voice/reactions space it takes) |
| slice2 | K2-activity-file_en | 33.56% | cards: React · Share row (and the voice/reactions space it takes) |
| slice2 | K3-activity-on-its-day_ar | 4.04% | cards: React · Share row (and the voice/reactions space it takes) |
| slice2 | K3-activity-on-its-day_en | 3.72% | cards: React · Share row (and the voice/reactions space it takes) |
| slice2 | K4-attach_ar | 2.57% | composer CV3: Discard, pinned lines, bar, no # |
| slice2 | K4-attach_en | 2.63% | composer CV3: Discard, pinned lines, bar, no # |
| slice2 | K5-note_ar | 4.04% | cards: React · Share row (and the voice/reactions space it takes) |
| slice2 | K5-note_en | 3.72% | cards: React · Share row (and the voice/reactions space it takes) |
| slice2 | W-activity_ar | 13.96% | composer CV3: Discard, pinned lines, bar, no # |
| slice2 | W-activity_en | 15.9% | composer CV3: Discard, pinned lines, bar, no # |
| slice2 | W-announcement_ar | 6.96% | composer CV3: Discard, pinned lines, bar, no # |
| slice2 | W-announcement_en | 6.71% | composer CV3: Discard, pinned lines, bar, no # |
| slice2 | W-checklist_ar | 8.73% | composer CV3: Discard, pinned lines, bar, no # |
| slice2 | W-checklist_en | 8.84% | composer CV3: Discard, pinned lines, bar, no # |
| slice2 | W-file-chooser_ar | 1.03% | composer CV3: Discard, pinned lines, bar, no # |
| slice2 | W-file-chooser_en | 1.13% | composer CV3: Discard, pinned lines, bar, no # |
| slice2 | W-file_ar | 11.04% | composer CV3: Discard, pinned lines, bar, no # |
| slice2 | W-file_en | 11.04% | composer CV3: Discard, pinned lines, bar, no # |
| slice3 | DM5-writing-quote_ar | 3.68% | composer CV3: Discard, pinned lines, bar, no # |
| slice3 | DM5-writing-quote_en | 3.8% | composer CV3: Discard, pinned lines, bar, no # |
| slice3 | S8m-card-quote_ar | 4.04% | cards: React · Share row (and the voice/reactions space it takes) |
| slice3 | S8m-card-quote_en | 3.72% | cards: React · Share row (and the voice/reactions space it takes) |
| slice5 | card-open-page_ar | 4.04% | cards: React · Share row (and the voice/reactions space it takes) |
| slice5 | card-open-page_en | 3.72% | cards: React · Share row (and the voice/reactions space it takes) |
| slice6 | R1b-walk-card_ar | 28.25% | cards: React · Share row (and the voice/reactions space it takes) |
| slice6 | R1b-walk-card_en | 28.39% | cards: React · Share row (and the voice/reactions space it takes) |
| slice7 | R2-daily-report_ar | 3.93% | cards: React · Share row (and the voice/reactions space it takes) |
| slice7 | R2-daily-report_en | 3.71% | cards: React · Share row (and the voice/reactions space it takes) |
| slice7 | R2-writing-done-today_ar | 2.17% | composer CV3: Discard, pinned lines, bar, no # |
| slice7 | R2-writing-done-today_en | 2.28% | composer CV3: Discard, pinned lines, bar, no # |
| slice7 | R2-writing_ar | 2.17% | composer CV3: Discard, pinned lines, bar, no # |
| slice7 | R2-writing_en | 2.28% | composer CV3: Discard, pinned lines, bar, no # |
| slice7 | T1-template-picker_ar | 3.78% | composer CV3: Discard, pinned lines, bar, no # |
| slice7 | T1-template-picker_en | 4.02% | composer CV3: Discard, pinned lines, bar, no # |
| slice7 | T2-from-template_ar | 10.28% | composer CV3: Discard, pinned lines, bar, no # |
| slice7 | T2-from-template_en | 11.62% | composer CV3: Discard, pinned lines, bar, no # |
| slice7 | T3-name-template_ar | 3.93% | cards: React · Share row (and the voice/reactions space it takes) |
| slice7 | T3-name-template_en | 3.71% | cards: React · Share row (and the voice/reactions space it takes) |
| slice8 | H1-notebook-icon_ar | 6.0% | feed hidden: the app opens on the Spaces tab |
| slice8 | H1-notebook-icon_en | 5.81% | feed hidden: the app opens on the Spaces tab |


---

# Review 113 Part B: shots

Rendered from `test_screens/r113b_test.dart` on branch `claude/r113-b`, 390 × 844, English and Arabic. Every image was looked at.

## new/ (30 tests, 42 images, each `_en` and `_ar`)
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
| NUDGE-composer | The composer opened from the nudge: Place · Same as last check-in, Send on |
| NUDGE-same-place-refused | The server refused the same place: back to Set place here, with the plain line |

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
- LB2: the link icon is at the field's end, not its start (`BvTextField` has only an end icon).
- The four sharing choices now share one line in both languages (`BvChip.tight`: 8 px side padding, 6 px gap, same type; a test in `r113b_test.dart` checks it in the real fonts).
- **The Space line (NN3, NN4) has no frame.** The review only says "the sender sees the answer". It uses the brand-soft box under Work · Chat; my own calls show for 2 hours, unanswered calls I got for 24 hours.
- B7-tap-to-fix says "This file is too big. The most is 25 MB." without a size: the sample file is 4.8 MB, and the app quotes a number only when the phone's size is over the limit.
