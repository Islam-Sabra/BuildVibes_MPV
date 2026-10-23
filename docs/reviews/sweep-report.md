# Sweep report — 23 Oct 2026 (branch `claude/sweep`, from `slice2-app` d9b1cad)

A scan of all of `lib/` against CLAUDE.md's definition of done and product rules. `lib/l10n/gen/` (generated) and `lib/features/dev/` (the developer-only components gallery, not reachable in a release build) are left out.

Not edited, as asked: `lib/features/messages/dm_live.dart`, `dm_banner.dart` and `dm_thread_screen.dart` (`claude/f100-fix` changes them). None of them had a hit.

Each hit says **Fixed** (with its commit kind), **No change** (with why), or **For the lead**.

## 1. Text typed in a widget instead of the ARB files
- `lib/features/profile/edit/edit_profile_screen.dart:85`, `lib/features/profile/widgets/profile_parts.dart:179`, `lib/features/spaces/space_info_screen.dart:401`, `lib/features/entry/entry_errors.dart:42`: the list separator typed per language (`lang == 'ar' ? '، ' : ', '`). **Fixed:** they use the ARB's `daybookNamesComma`, as the daybook already does.
- `lib/shared/widgets/bv_latest_reply.dart:58` (`'$name: '`), `lib/shared/widgets/bv_card_history.dart:130` (`' ${line.detail}'`): punctuation and a space joining two parts the same way in both languages. **No change.**
- `lib/features/library/library_parts.dart:32` joins the file formats ("PDF") with ", ". Format names are written as is in every language, and today there is one. **No change.**
- No other words are typed in a widget (every `Text`, label, title, hint and tooltip literal was checked).

## 2. Raw colours, font sizes or spacing numbers
- No `Color(0x…)` and no `Colors.*` outside `bv_tokens.dart` except `Colors.transparent`. No `fontSize:` number outside the design files.
- Number literals in layout positions outside `lib/core/design/`:
  - the image picker's pixel limits (`work_outbox.dart:440–476`, `basics_screen.dart:31`: 1600 and 800 px);
  - halves of tokens (`BvSize.touchMin / 2`, `2 * BvMessagesSpec.fabMargin`);
  - indices (`bv_photo_strip.dart:86`).
  
  None is a layout size. **No change.**
- Font weights in components, all from their component spec:
  - `lib/shared/widgets/bv_stamp.dart:189, 208, 218` (the ink stamp's weights per language);
  - `lib/shared/widgets/bv_calendar_leaf.dart:52` (the leaf's bold weekday band).
  
  **No change.**

## 3. Material `Icons.*`
None. (`bv_icons.dart:4` only mentions it in a comment.)

## 4. left/right instead of start/end
- `lib/shared/widgets/bv_highlight.dart:67–71`: `Positioned(left:, right:)`. The values are equal, so it looks the same either way. **Fixed** for consistency: `PositionedDirectional(start:, end:)`.
- `lib/shared/widgets/bv_text_field.dart:177–178` and `lib/features/profile/widgets/profile_parts.dart:521`: `TextAlign.right/left` picked from the page's direction on purpose. A text in the other script keeps its own direction but stays aligned with the form; `TextAlign.start` would follow the text's direction instead. **No change.**
- `lib/features/entry/widgets/entry_hero.dart:50`: the skyline is drawn left to right like a photo, inside an LTR `Stack`. **No change.**
- `lib/core/theme/bv_theme.dart:258`: `EdgeInsets.fromLTRB` with equal sides (commented). **No change.**

## 5. Arrows or chevrons that don't flip in Arabic
- `lib/core/design/bv_icons.dart:83`: `signOut` (Phosphor sign-out) is an arrow leaving a door, and it didn't mirror. **Fixed:** `matchTextDirection: true`.
- Every other arrow and caret mirrors: `caretForward`, `caretBack`, `arrowForward`, `arrowBack`, `send`, `reply`, `shareFile` and `sendBack`. The app bar's back button uses `BvIcons.arrowBack` (theme).
- `caretDown` and `newBelow` (up and down) are vertical, so they don't flip.

## 6. Eastern Arabic digits
None in `lib/` or the ARB files.

## 7. Anything country-specific not from the market pack
None in code or copy. "Kuwait", "Egypt" and "+965" appear only in comments. The week's first day comes from `myMarketProvider.weekStart`. Phone rules use the market's `isMobileNumber`; the generic 6–14 digits apply only for a country with no pack.

## 8. Counts shown as a quality signal (rule 3)
- Followers and following on profiles (`profile_parts.dart:50`): allowed (founder, 11 Oct).
- Working counts, not quality signals, so **no change**:
  - progress: "2 of 5 ticked", "2 of 4 checked", "Step 1 of 2";
  - the unread number on a Space chat thread (`chat_tab.dart:342`);
  - "N needs you";
  - the number of people blocked (`blocked_screen.dart:78`, `account_screens.dart:92`);
  - the template limit;
  - "Post 3 work items".
- `lib/features/spaces/team_screen.dart:190`: "{n} members" above a Team's member list. **For the lead** (below).

## 9. ARB keys
- `app_en.arb` and `app_ar.arb` have the same keys: none missing either way.
- 40 keys were used nowhere in `lib/`, `test/` or `test_screens/` (left from earlier designs of the Library, the Space member list and the work item). **Fixed:** removed from both files:
  - `daybookKindFile`, `daybookReplacesNone`, `dmFirstMessage`, `workNote`, `previewNewRevision`, `previewShared`;
  - `libraryAdd`, `libraryAddTitle`, `libraryAdded`, `libraryAll`, `libraryChangeFile`, `libraryFor`, `libraryName`, `libraryNameRequired`, `libraryNoteHint`, `libraryPickFile`, `libraryPickFirst`, `libraryRecent`, `libraryRev`, `libraryRevHint`, `libraryRevisionOf`, `libraryRevisionTitle`, `libraryTeamOnly`, `libraryUpload`;
  - `spacesAdminSection`, `spacesAdminTag`, `spacesAsked`, `spacesConfirm`, `spacesConfirmAs`, `spacesGivePass`, `spacesInTeam`, `spacesInvitePeople`, `spacesJoinedAs`, `spacesMembers`, `spacesNoMatch`, `spacesPassLine`, `spacesRequestsTitle`, `spacesSearchMembers`, `spacesViaCode`, `spacesViaCodeFrom`.

## 10. "late" / «متأخر» (F57)
- No ARB string says "late", "overdue" or «متأخر». "later" appears twice, in its other sense ("change it later", "a later time").
- In code, `late` is a Dart keyword, plus the names `late:`, `isLate` and `DecisionState.late` in the due logic. None of these is shown to anyone. **No change.**

## 11. Needs you: `checklist_for_you` (progress, slice 2 notes)
- **Still true on `slice2-app`:**
  - `needs_you()` (migration 19) returns `checklist_for_you` rows: a live checklist I'm one of the people for, that I may still tick, with a point unticked.
  - `my_spaces().needs_you` counts every `needs_you()` row.
  - The app's list (`activity_repository.dart` `needs()`) skipped them, so Home's "N needs you" could be higher than its list.
- **Fixed in the list, not the count.** No migration: the server already gives the rows (and test 19 covers them, including that they go once every point is ticked).
  - The app reads each checklist's title, author and due, and lists it as **"To tick"** / «للتأشير»: "Sara Al-Mutairi gave you a checklist: Before the site walk".
  - A tap opens its card in the daybook.
  - It goes once every point is ticked (the server stops returning it).

## For the lead
1. **"{n} members" on a Team's screen** (`team_screen.dart:190`, `spacesTeamMembers`): a count above the list of the Team's people, seen by everyone in the Space. Rule 3 names member counts. *Recommendation:* drop the number and keep the word "Members" as the list's heading, since the list shows who they are. "No members yet" stays.
2. **Unread numbers on Space chat threads** (`chat_tab.dart:342`): a number, not a dot, while Messages and the tabs use a dot ("never a number", rule 3 as applied to DM1). *Recommendation:* a dot, to match DM1 and the tab dots.

## Fix commits (by kind)
1. Sign out's arrow mirrors; the card highlight uses start/end.
2. List separators from the ARB.
3. 40 unused ARB keys removed.
4. Needs you lists checklists given to you.

## Checks (cloud)
- `flutter analyze`: no issues.
- `flutter test`: 1,717 pass; 1 fails, photo_privacy H1, which fails only as root in the cloud.
- New: `test/features/activity/needs_checklist_test.dart` (3 tests, English and Arabic).
- **Screenshot tests** (`test_screens/`, 363):
  - Against the committed images, 416 images differ by 1–4%, the same 416 on untouched `slice2-app`. The committed images were shot on the PC with Windows fonts.
  - Shot again here, on this branch and on `slice2-app`, all 363 tests pass and **no image differs** between the two.
  - The committed images are left as they are.
- **SQL stand-in:** 2,464 checks pass in every file. No migration on this branch.
