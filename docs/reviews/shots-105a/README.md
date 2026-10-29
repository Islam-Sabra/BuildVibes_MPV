# Review 105A: the shots that change

`flutter test test_screens` on the PC, on `claude/r105a` with `slice2-app` merged in, without `--update-goldens`: 230 pass, 228 fail. Goldens are not updated.

For each changed shot, `<folder>--<name>_<lang>-old.png` is the golden in `docs/screens/<folder>/` and `-new.png` is what the branch draws now.

**120 shots changed (240 images).** Every one is a Space screen: Work, People, Space info, the walk, a Space tab with the new header, and the shots whose content changed under their old names. All are expected under review 105A.

| Shot | EN | AR | Expected |
|---|---|---|---|
| f104/pinned_line_3_got_it | 40.95% | 41.95% | yes: Space Work |
| f104/pinned_line_5_got_it | 40.95% | 41.95% | yes: Space Work |
| f60/H2-photos-preparing | 47.10% | 46.80% | yes: Space Work |
| f68b/F68b-docket-1 | 48.90% | 51.21% | yes: Space Work |
| f68b/F68b-docket-12 | 48.90% | 51.21% | yes: Space Work |
| f68b/F68b-docket-2 | 48.90% | 51.21% | yes: Space Work |
| f68b/F69-picker-you-first | 39.81% | 36.24% | yes: Space Work |
| hold-confirm/H1-hold-at-rest | 60.39% | 59.38% | yes: Space Work |
| hold-confirm/H2-hold-half | 60.38% | 59.36% | yes: Space Work |
| hold-confirm/H3-checked-undo | 65.35% | 64.16% | yes: Space Work |
| r95/R1-numbers | 42.40% | 40.15% | yes: Space Work |
| r95/R2-header-search | 96.38% | 97.11% | yes: Space Work |
| review72/A1-to-do-sheet | 78.11% | 71.64% | yes: the To do strip, removed (Needs you); can be deleted |
| review72/F59-masthead-today | 43.37% | 45.65% | yes: Space Work |
| review72/F61-to-do-strip | 48.90% | 51.21% | yes: the To do strip, removed (Needs you); can be deleted |
| review72/F62-send-back-date | 28.74% | 29.56% | yes: Space Work |
| review72/F62-sent-back-new-date | 43.49% | 44.57% | yes: Space Work |
| review72/F63-kind-menu | 47.26% | 42.64% | yes: content changed under its old name; renamed when the goldens are made |
| review72/F66-who-row-chosen | 53.82% | 45.22% | yes: Space Work |
| review80/F70-library-empty | 10.53% | 10.63% | yes: a Space tab (the Library; the header) |
| review80/F71-replaces-choice | 26.04% | 28.21% | yes: Space Work |
| review80/F71-replaces-picked | 25.94% | 28.11% | yes: Space Work |
| review80/F71-version-picker | 25.92% | 28.09% | yes: Space Work |
| review80/F71-writing-replaces | 27.80% | 28.89% | yes: Space Work |
| review80/F72-attach | 26.04% | 28.21% | yes: Space Work |
| review80/F73-sending | 40.78% | 42.85% | yes: Space Work |
| review80/F75-F76-versions | 54.72% | 53.84% | yes: Space Work |
| review80/F79-person-sheet | 9.49% | 10.37% | yes: People (SP8) |
| review80/F82-F85-pinned | 57.65% | 52.53% | yes: Space Work |
| review80/F82-pin-add-time | 35.93% | 37.76% | yes: Space Work |
| review80/F82-pin-with-time | 35.82% | 37.67% | yes: Space Work |
| review80/F89-F90-page-editor | 11.63% | 12.12% | yes: Space Work |
| review80/F92-point-menu | 11.54% | 12.03% | yes: Space Work |
| review82/F71-replaces-picked | 26.27% | 28.48% | yes: Space Work |
| review82/S1-checklist-ticks | 34.67% | 35.74% | yes: Space Work |
| review82/S1-history-lines | 57.47% | 54.39% | yes: Space Work |
| slice1/A1-times-12h | 59.51% | 58.47% | yes: Space Work |
| slice1/B1-long-press-proof | 65.08% | 64.57% | yes: Space Work |
| slice1/B2-send-back-reasons | 28.74% | 29.56% | yes: Space Work |
| slice1/C6-long-press-other-item | 63.65% | 61.53% | yes: Space Work |
| slice1/D-F20-highlight | 68.57% | 70.19% | yes: Space Work |
| slice1/D-F24-send-back-keyboard | 6.35% | 3.77% | yes: Space Work |
| slice1/D2-proof-slip-note-only | 44.84% | 42.01% | yes: Space Work |
| slice1/D3-signed-undo | 63.72% | 60.35% | yes: Space Work |
| slice1/DY1-yesterday | 71.69% | 72.30% | yes: Space Work |
| slice1/DY2-calendar | 42.82% | 43.57% | yes: Space Work |
| slice1/DY3-day-one | 41.67% | 43.13% | yes: Space Work |
| slice1/E1-write | 46.33% | 41.41% | yes: Space Work |
| slice1/E2-more-menu | 49.35% | 45.03% | yes: content changed under its old name; renamed when the goldens are made |
| slice1/E3-assign | 46.81% | 41.75% | yes: Space Work |
| slice1/E3-filled-card | 41.32% | 38.73% | yes: Space Work |
| slice1/E4-draft | 50.17% | 46.34% | yes: Space Work |
| slice1/E5-posted | 59.11% | 54.19% | yes: Space Work |
| slice1/E6-kind-chip | 47.26% | 42.64% | yes: content changed under its old name; renamed when the goldens are made |
| slice1/E7-waiting-to-send | 62.85% | 64.56% | yes: Space Work |
| slice1/E8-could-not-send | 51.99% | 55.26% | yes: Space Work |
| slice1/L1-late-due-today | 48.90% | 51.21% | yes: Space Work |
| slice1/O1-omars-daybook | 50.35% | 42.86% | yes: Space Work |
| slice1/O3-proof-posted | 58.90% | 59.53% | yes: Space Work |
| slice1/O5-could-not-send | 59.75% | 58.68% | yes: Space Work |
| slice1/SI1-space-info | 35.57% | 37.50% | yes: Space info |
| slice1/SP1-space-people | 91.51% | 91.43% | yes: People (SP8) |
| slice1/V1-viewer | 53.92% | 54.10% | yes: Space Work |
| slice1/V13-add-update | 47.77% | 46.25% | yes: Space Work |
| slice1/V13-checked-undo | 65.35% | 64.16% | yes: Space Work |
| slice1/V13-islams-daybook | 59.84% | 58.27% | yes: Space Work |
| slice1/V13-islams-daybook-top | 60.21% | 58.68% | yes: Space Work |
| slice1/V13-omar-sent-back | 59.34% | 59.88% | yes: Space Work |
| slice1/X1-own-item-menu | 70.37% | 67.36% | yes: Space Work |
| slice1/X2-given | 57.05% | 52.01% | yes: Space Work |
| slice1/X3-cancelled | 42.02% | 43.75% | yes: Space Work |
| slice1/Y1-swipe-update | 92.29% | 91.86% | yes: content changed under its old name; renamed when the goldens are made |
| slice10/OF-no-signal | 59.85% | 59.00% | yes: Space Work |
| slice10/page-leave | 14.58% | 14.35% | yes: Space Work |
| slice10/page-no-signal | 14.60% | 14.37% | yes: Space Work |
| slice2/E6-kind-menu | 47.26% | 42.64% | yes: content changed under its old name; renamed when the goldens are made |
| slice2/F34-facts-line | 59.84% | 58.27% | yes: Space Work |
| slice2/F45-people-picker-done | 16.61% | 15.79% | yes: People (SP8) |
| slice2/F48-received-sheet | 43.91% | 43.20% | yes: Space Work |
| slice2/F50-kind-menu | 47.26% | 42.64% | yes: content changed under its old name; renamed when the goldens are made |
| slice2/F51-two-photos | 51.48% | 53.75% | yes: Space Work |
| slice2/F56-to-menu | 39.01% | 39.39% | yes: Space Work |
| slice2/F56-who-asks | 46.85% | 39.06% | yes: Space Work |
| slice2/F56-who-row | 46.73% | 38.87% | yes: Space Work |
| slice2/F57-due-strip | 48.90% | 51.21% | yes: Space Work |
| slice2/K1-announcement-folded | 42.72% | 44.58% | yes: Space Work |
| slice2/K1-checklist-for-sara | 36.72% | 38.51% | yes: Space Work |
| slice2/K2-activity-file | 61.58% | 61.65% | yes: Space Work |
| slice2/K3-activity-on-its-day | 37.01% | 39.16% | yes: Space Work |
| slice2/K4-attach | 37.10% | 30.98% | yes: Space Work |
| slice2/K5-note | 46.75% | 48.31% | yes: Space Work |
| slice2/W-activity | 45.67% | 40.79% | yes: Space Work |
| slice2/W-announcement | 46.24% | 43.73% | yes: Space Work |
| slice2/W-checklist | 24.85% | 25.36% | yes: Space Work |
| slice2/W-file | 37.70% | 39.64% | yes: Space Work |
| slice2/W-file-chooser | 27.85% | 23.37% | yes: Space Work |
| slice3/DM5-writing-quote | 43.49% | 45.40% | yes: a Space tab (the header without ⋯, Work · Chat) |
| slice3/S7-chat | 25.68% | 27.04% | yes: a Space tab (the header without ⋯, Work · Chat) |
| slice3/S7N-new-chat | 15.74% | 16.69% | yes: a Space tab (the header without ⋯, Work · Chat) |
| slice3/S8m-card-quote | 37.88% | 40.37% | yes: a Space tab (the header without ⋯, Work · Chat) |
| slice4/LV1-library | 18.74% | 18.59% | yes: a Space tab (the Library; the header) |
| slice4/P1-people | 35.33% | 33.45% | yes: People (SP8) |
| slice4/P1-people-end | 29.33% | 30.58% | yes: People (SP8) |
| slice4/P2-let-in-choose | 31.00% | 30.29% | yes: People (SP8) |
| slice4/P2-let-in-crew | 31.87% | 31.86% | yes: People (SP8) |
| slice4/V1-crew-locked | 28.99% | 30.35% | yes: People (SP8) |
| slice5/N1-page | 36.32% | 36.25% | yes: Space Work |
| slice5/N1-page-end | 39.27% | 39.37% | yes: Space Work |
| slice5/N2-edit | 12.13% | 13.02% | yes: Space Work |
| slice5/N3-add-block | 11.88% | 12.77% | yes: Space Work |
| slice5/N4-turn-into | 11.88% | 12.77% | yes: Space Work |
| slice5/card-open-page | 33.16% | 34.75% | yes: Space Work |
| slice6/R1b-walk-card | 56.64% | 53.75% | yes: the walk |
| slice7/R2-daily-report | 45.65% | 47.11% | yes: Space Work |
| slice7/R2-writing | 31.77% | 32.63% | yes: Space Work |
| slice7/R2-writing-done-today | 31.67% | 32.54% | yes: Space Work |
| slice7/T0-more-template | 40.67% | 42.07% | yes: Space Work |
| slice7/T1-template-picker | 26.78% | 28.20% | yes: Space Work |
| slice7/T2-from-template | 38.29% | 37.27% | yes: Space Work |
| slice7/T3-name-template | 31.96% | 34.27% | yes: Space Work |

## Not as expected

- **F95-walk-place** (review80) passes unchanged: it was expected to change.
- **MN1-space-menu** (slice1, slice7, slice9) passes unchanged in all three. The lead says it can be deleted; it still draws.
- **R1-walk-start** and **R1-walk-photo** (slice6) pass unchanged.
- **Two scenarios fail with an error on `claude/r105a` itself** (checked at 86eff0e, before the merge), so they are not from the merge:
  - **X2 give it to someone else** (`test_screens/daybook_test.dart`): "Bad state: No element" in `openedPick(l10n.daybookGiveTo)`. No new X2-give-to image is drawn, so it is not in the list.
  - **SP1 the Space: People** (`test_screens/around_test.dart`): "No GoRouter found in context", from `SpaceScreen.initState` pushing People with `context.push` in a scenario that has no router. Its slice1/SP1-space-people image is drawn and listed; the error comes after.

## Can be deleted (the lead)

- The To do strip: review72/F61-to-do-strip, review72/A1-to-do-sheet (both listed above).
- MN1: slice1, slice7 and slice9 MN1-space-menu (unchanged).
