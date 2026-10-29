# Review 105B: the shots that change

`flutter test test_screens` on the PC, branch `r105b`, without `--update-goldens`: **454 pass, 0 fail. No shot changes**, so there are no old/new pairs here. Goldens are not updated.

## Why nothing changed

- 105B turns on Pin, Archive and Share in Work (`WorkLater`). No shot scenario swipes a Work card toward its end, holds one, or opens a Space whose pins, archive or chat cards differ. The scenarios use fake repositories with no pins and no `post` messages.
- The Space's time zone is unknown in the fakes (no `time_zone`), so a new announcement still ends at the phone's midnight in the shots.
- `lib/features/notebook/` is untouched.

## Not drawn yet (for the lead)

There is no shot of the new screens. If the lead wants them:
- my pinned lines under the masthead (`my-pin-<id>`);
- the Pin swipe reading Unpin;
- the Share sheet with the Space's threads (`share-threads`);
- a shared post's card in a thread (`chat-shared-post`).

They are covered by `test/features/work/work_extras_test.dart` (EN and AR).
