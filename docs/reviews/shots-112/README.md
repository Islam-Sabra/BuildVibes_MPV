# Review 112 shots (claude/r112)

English and Arabic, 390 × 844, in the app's fonts, rendered by `flutter test test_screens` (not updating). No goldens were changed: these wait for the lead.

- `new/`: 4 new screens from `test_screens/r112_test.dart`, `<name>_en.png` and `<name>_ar.png` (8 images).
- `changed/`: 3 existing screens that differ from their goldens, as `<name>_<lang>_old.png` (the golden) and `<name>_<lang>_new.png` (now), 6 pairs.

## New screens (`new/`)

| Shot | What |
|---|---|
| N1-alone-invite | Alone in a Space (only a Viewer besides me): For opens on "Invite someone to give work items to." («ادعُ شخصًا لتعطيه بنود العمل.»), with "Post as a Note" under it; Post stays off |
| N2-share-for-choose | The notebook share as a work item: "For: Choose"; Post is off until someone is chosen |
| N2b-share-for-picker | Its For picker: the Space's Lead and Crew A–Z, never me, no "You" |
| N3-refused-for-yourself | If the server refuses: "A work item is for someone else. For yourself, use My notebook." («بند العمل لشخص آخر. لنفسك استخدم دفترك.») on the draft |

## Changed screens (`changed/`)

All lose F69's "You" row (and its hairline); nothing else moved.

- **F69-picker-you-first** (`f68b`): the composer's For picker.
- **X2-give-to** (`slice1`): Give to on a work item.
- **R3-owner-picker** (`slice9`): an owner for a line of meeting notes.

## The rest of the run

- `test_screens` (not updating): 556 pass, 12 fail, all expected: 6 are r112's new shots (no golden yet) and 6 are the three screens above.
- `A2-spaces-error` (r110) still matches its golden: its shot now makes the one call fail (the list no longer reads each Space's detail).
