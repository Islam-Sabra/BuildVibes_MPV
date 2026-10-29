# Review 105A: the shots that change (after J1–J4)

`flutter test test_screens` on the PC, on `claude/r105a` after J1–J4 and the deletions, without `--update-goldens`: 230 pass, 224 fail, every failure a changed picture. Goldens are not updated.

For each changed shot, `<folder>--<name>_<lang>-old.png` is the golden in `docs/screens/<folder>/` and `-new.png` is what the branch draws now.

**123 shots changed (246 images), all Space screens, all expected under review 105A.**

J1 (back in the header) and J4 ("Write in this Space" in the post bar) show in every Work shot.

| Shot | EN | AR | Expected | Note |
|---|---|---|---|---|
| f104/pinned_line_3_got_it | 40.95% | 41.94% | yes: Space Work |  |
| f104/pinned_line_5_got_it | 40.95% | 41.94% | yes: Space Work |  |
| f60/H2-photos-preparing | 48.60% | 47.96% | yes: Space Work |  |
| f68b/F68b-docket-1 | 50.40% | 52.37% | yes: Space Work |  |
| f68b/F68b-docket-12 | 50.40% | 52.37% | yes: Space Work |  |
| f68b/F68b-docket-2 | 50.40% | 52.37% | yes: Space Work |  |
| f68b/F69-picker-you-first | 41.31% | 37.40% | yes: Space Work |  |
| hold-confirm/H1-hold-at-rest | 61.89% | 60.55% | yes: Space Work |  |
| hold-confirm/H2-hold-half | 61.88% | 60.52% | yes: Space Work |  |
| hold-confirm/H3-checked-undo | 66.85% | 65.33% | yes: Space Work |  |
| r95/R1-numbers | 42.40% | 40.15% | yes: Space Work |  |
| r95/R2-header-search | 96.38% | 97.11% | yes: Space Work |  |
| review72/F59-masthead-today | 44.87% | 46.81% | yes: Space Work |  |
| review72/F62-send-back-date | 29.07% | 29.65% | yes: Space Work |  |
| review72/F62-sent-back-new-date | 44.99% | 45.73% | yes: Space Work |  |
| review72/F63-kind-menu | 48.76% | 43.80% | yes: content changed under its old name; renamed when the goldens are made |  |
| review72/F66-who-row-chosen | 55.32% | 46.38% | yes: Space Work |  |
| review80/F70-library-empty | 10.53% | 10.63% | yes: a Space tab (the Library; the header) |  |
| review80/F71-replaces-choice | 26.04% | 28.21% | yes: Space Work |  |
| review80/F71-replaces-picked | 25.94% | 28.11% | yes: Space Work |  |
| review80/F71-version-picker | 25.92% | 28.09% | yes: Space Work |  |
| review80/F71-writing-replaces | 27.80% | 28.89% | yes: Space Work |  |
| review80/F72-attach | 26.04% | 28.21% | yes: Space Work |  |
| review80/F73-sending | 40.78% | 42.85% | yes: Space Work |  |
| review80/F75-F76-versions | 54.72% | 53.84% | yes: Space Work |  |
| review80/F79-person-sheet | 9.49% | 10.37% | yes: People (SP8) |  |
| review80/F82-F85-pinned | 57.65% | 52.53% | yes: Space Work |  |
| review80/F82-pin-add-time | 35.93% | 37.76% | yes: Space Work |  |
| review80/F82-pin-with-time | 35.82% | 37.67% | yes: Space Work |  |
| review80/F89-F90-page-editor | 11.63% | 12.12% | yes: Space Work |  |
| review80/F92-point-menu | 11.54% | 12.03% | yes: Space Work |  |
| review82/F71-replaces-picked | 26.27% | 28.48% | yes: Space Work |  |
| review82/S1-checklist-ticks | 34.67% | 35.74% | yes: Space Work |  |
| review82/S1-history-lines | 57.47% | 54.39% | yes: Space Work |  |
| slice1/A1-times-12h | 61.01% | 59.63% | yes: Space Work |  |
| slice1/B1-long-press-proof | 65.39% | 64.66% | yes: Space Work |  |
| slice1/B2-send-back-reasons | 29.07% | 29.65% | yes: Space Work |  |
| slice1/C6-long-press-other-item | 64.04% | 62.23% | yes: Space Work | J2: the opened item shows |
| slice1/D-F20-highlight | 70.07% | 71.35% | yes: Space Work |  |
| slice1/D-F24-send-back-keyboard | 6.43% | 3.81% | yes: Space Work |  |
| slice1/D-F24-update-sheet-keyboard | 33.37% | 28.80% | yes: Space Work | also changed at 132d84e, left out of that list |
| slice1/D2-proof-slip-note-only | 46.34% | 43.17% | yes: Space Work |  |
| slice1/D3-signed-undo | 65.22% | 61.51% | yes: Space Work |  |
| slice1/DY1-yesterday | 73.19% | 73.46% | yes: Space Work |  |
| slice1/DY2-calendar | 44.00% | 44.47% | yes: Space Work |  |
| slice1/DY3-day-one | 43.17% | 44.29% | yes: Space Work |  |
| slice1/E1-write | 47.83% | 42.58% | yes: Space Work |  |
| slice1/E2-more-menu | 50.85% | 46.20% | yes: content changed under its old name; renamed when the goldens are made |  |
| slice1/E3-assign | 48.31% | 42.91% | yes: Space Work |  |
| slice1/E3-filled-card | 42.82% | 39.89% | yes: Space Work |  |
| slice1/E4-draft | 51.67% | 47.50% | yes: Space Work |  |
| slice1/E5-posted | 60.61% | 55.36% | yes: Space Work |  |
| slice1/E6-kind-chip | 48.76% | 43.80% | yes: content changed under its old name; renamed when the goldens are made |  |
| slice1/E7-waiting-to-send | 64.35% | 65.72% | yes: Space Work |  |
| slice1/E8-could-not-send | 53.49% | 56.43% | yes: Space Work |  |
| slice1/L1-late-due-today | 50.40% | 52.37% | yes: Space Work |  |
| slice1/O1-omars-daybook | 51.85% | 44.02% | yes: Space Work |  |
| slice1/O3-proof-posted | 60.40% | 60.69% | yes: Space Work |  |
| slice1/O5-could-not-send | 61.25% | 59.84% | yes: Space Work |  |
| slice1/SI1-space-info | 35.57% | 37.50% | yes: Space info |  |
| slice1/SP1-space-people | 30.47% | 34.73% | yes: People (SP8) | J3: the People screen |
| slice1/V1-viewer | 55.42% | 55.26% | yes: Space Work |  |
| slice1/V13-add-update | 48.12% | 46.38% | yes: Space Work |  |
| slice1/V13-checked-undo | 66.85% | 65.33% | yes: Space Work |  |
| slice1/V13-islams-daybook | 61.34% | 59.43% | yes: Space Work |  |
| slice1/V13-islams-daybook-top | 61.71% | 59.85% | yes: Space Work |  |
| slice1/V13-omar-sent-back | 60.84% | 61.04% | yes: Space Work |  |
| slice1/X1-own-item-menu | 70.58% | 67.80% | yes: Space Work | J2: the opened item shows |
| slice1/X2-give-to | 99.96% | 99.94% | yes: Space Work | J2/J3: drawn now (Give to from the For line) |
| slice1/X2-given | 58.55% | 53.17% | yes: Space Work |  |
| slice1/X3-cancelled | 43.52% | 44.91% | yes: Space Work |  |
| slice1/Y1-swipe-update | 92.38% | 91.90% | yes: content changed under its old name; renamed when the goldens are made | J2: the opened item shows |
| slice10/OF-no-signal | 59.85% | 59.00% | yes: Space Work |  |
| slice10/page-leave | 14.58% | 14.35% | yes: Space Work |  |
| slice10/page-no-signal | 14.60% | 14.37% | yes: Space Work |  |
| slice2/E6-kind-menu | 48.76% | 43.80% | yes: content changed under its old name; renamed when the goldens are made |  |
| slice2/F34-facts-line | 61.34% | 59.43% | yes: Space Work |  |
| slice2/F45-people-picker-done | 18.11% | 16.95% | yes: People (SP8) |  |
| slice2/F48-received-sheet | 45.41% | 44.37% | yes: Space Work |  |
| slice2/F50-kind-menu | 48.76% | 43.80% | yes: content changed under its old name; renamed when the goldens are made |  |
| slice2/F51-two-photos | 52.98% | 54.91% | yes: Space Work |  |
| slice2/F56-to-menu | 40.51% | 40.55% | yes: Space Work |  |
| slice2/F56-who-asks | 48.35% | 40.22% | yes: Space Work |  |
| slice2/F56-who-row | 48.23% | 40.04% | yes: Space Work |  |
| slice2/F57-due-strip | 50.40% | 52.37% | yes: Space Work |  |
| slice2/K1-announcement-checklist | 45.15% | 43.15% | yes: Space Work | also changed at 132d84e, left out of that list |
| slice2/K1-announcement-folded | 44.22% | 45.75% | yes: Space Work |  |
| slice2/K1-checklist-for-sara | 38.22% | 39.67% | yes: Space Work |  |
| slice2/K2-activity-file | 63.08% | 62.81% | yes: Space Work |  |
| slice2/K3-activity-on-its-day | 38.51% | 40.32% | yes: Space Work |  |
| slice2/K4-attach | 38.60% | 32.14% | yes: Space Work |  |
| slice2/K5-note | 48.25% | 49.47% | yes: Space Work |  |
| slice2/W-activity | 47.17% | 41.96% | yes: Space Work |  |
| slice2/W-announcement | 47.74% | 44.89% | yes: Space Work |  |
| slice2/W-checklist | 26.35% | 26.52% | yes: Space Work |  |
| slice2/W-file | 39.20% | 40.81% | yes: Space Work |  |
| slice2/W-file-chooser | 29.35% | 24.54% | yes: Space Work |  |
| slice3/DM5-writing-quote | 44.99% | 46.56% | yes: Space Work |  |
| slice3/S7-chat | 27.18% | 28.20% | yes: a Space tab (the header, Work · Chat) |  |
| slice3/S7N-new-chat | 17.24% | 17.85% | yes: a Space tab (the header, Work · Chat) |  |
| slice3/S8m-card-quote | 39.38% | 41.54% | yes: a Space tab (the header, Work · Chat) |  |
| slice4/LV1-library | 18.74% | 18.59% | yes: a Space tab (the Library; the header) |  |
| slice4/P1-people | 35.33% | 33.45% | yes: People (SP8) |  |
| slice4/P1-people-end | 29.33% | 30.58% | yes: People (SP8) |  |
| slice4/P2-let-in-choose | 31.00% | 30.29% | yes: People (SP8) |  |
| slice4/P2-let-in-crew | 31.87% | 31.86% | yes: People (SP8) |  |
| slice4/V1-crew-locked | 30.49% | 31.51% | yes: People (SP8) |  |
| slice5/N1-page | 37.82% | 37.41% | yes: Space Work |  |
| slice5/N1-page-end | 40.77% | 40.53% | yes: Space Work |  |
| slice5/N2-edit | 13.63% | 14.19% | yes: Space Work |  |
| slice5/N3-add-block | 13.37% | 13.93% | yes: Space Work |  |
| slice5/N4-turn-into | 13.37% | 13.93% | yes: Space Work |  |
| slice5/card-open-page | 34.66% | 35.91% | yes: Space Work |  |
| slice6/R1b-walk-card | 58.14% | 54.91% | yes: the walk |  |
| slice7/R2-daily-report | 45.65% | 47.11% | yes: Space Work |  |
| slice7/R2-writing | 31.77% | 32.63% | yes: Space Work |  |
| slice7/R2-writing-done-today | 31.67% | 32.54% | yes: Space Work |  |
| slice7/T0-more-template | 40.67% | 42.07% | yes: Space Work |  |
| slice7/T1-template-picker | 26.78% | 28.20% | yes: Space Work |  |
| slice7/T2-checklist-from-template | 47.23% | 42.58% | yes: Space Work | also changed at 132d84e, left out of that list |
| slice7/T2-from-template | 38.29% | 37.27% | yes: Space Work |  |
| slice7/T3-menu-save-as-template | 99.85% | 99.84% | yes: Space Work | also changed at 132d84e, left out of that list |
| slice7/T3-name-template | 31.96% | 34.27% | yes: Space Work |  |

## Since the list at `132d84e`

- **Deleted:** review72 F61-to-do-strip and A1-to-do-sheet, with their scenarios; the MN1-space-menu goldens in slice1, slice7 and slice9.
  - No scenario had drawn MN1 since Part 1, so "MN1 passes unchanged" at 132d84e was wrong: nothing drew those files.
- **New in the list:** X2-give-to (it draws now).
- **Missed at 132d84e:** D-F24-update-sheet-keyboard, K1-announcement-checklist, T2-checklist-from-template and T3-menu-save-as-template changed then too.
  - The list was read from the log with a pattern that missed a line break inside the message: it had 248 images, not 240.
- **F71-replaces-picked is in two folders** (review80 and review82). Each new image is taken from its own test file. At 132d84e both pairs had the same new image, from whichever of the two ran last.
- **Unchanged, as the lead accepts:** F95-walk-place, R1-walk-start, R1-walk-photo.
