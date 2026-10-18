// The daybook page (slice 1b, with review 45 B1–B3), writing in place
// (slice 1c, with review 46) and the loop (slice 1d), against Figma D1
// 2518:33001, L1 2539:34633, DY1 2541:34679, DY2 2541:34813, DY3
// 2541:35060, V1 2542:35109, E 2524:33180, 2524:33369, 2524:33577,
// 2524:33780, 2524:33936, 2535:34221, the assign picker 2540:34840, the
// loop's O1 2529:33382, O2 2529:33493, O3 2529:33514, S1 2530:33826, Y1
// 2530:33953, Y2 2530:34038, B1 2530:33480, B2 2530:33643, B3 2519:33049,
// X1 2530:34134, X2 2540:34693, X2-given 2540:34880, X3 2530:34263, and the
// AR frames 2547:35195, 2547:35369 and 2547:35543; part 1e's Space menu
// MN1 2566:35619, review 47's answers 3 (O4, the item switch) and 5
// (O5, a refused sign-off), and review 51's Part D (D1 without a photo,
// D2 its proof slip, D3 the undo bar after Send as done). Run:
//   flutter test test_screens/daybook_test.dart --update-goldens
import 'dart:convert';

import 'package:buildvibes/core/l10n/locale_controller.dart';
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/repositories/activity_repository.dart';
import 'package:buildvibes/data/repositories/daybook_repository.dart';
import 'package:buildvibes/data/repositories/space_repository.dart';
import 'package:buildvibes/data/repositories/work_repository.dart';
import 'package:buildvibes/features/account/account_parts.dart';
import 'package:buildvibes/features/entry/entry_state.dart';
import 'package:buildvibes/features/profile/edit/experience_screens.dart';
import 'package:buildvibes/features/spaces/space_screen.dart';
import 'package:buildvibes/features/work/daybook_draft.dart';
import 'package:buildvibes/features/work/daybook_entry.dart';
import 'package:buildvibes/features/work/daybook_writing.dart';
import 'package:buildvibes/features/work/work_outbox.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_daybook_masthead.dart';
import 'package:buildvibes/shared/widgets/bv_give_to_picker.dart';
import 'package:buildvibes/shared/widgets/bv_slip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers/activity_fakes.dart';
import '../test/helpers/daybook_fakes.dart';
import '../test/helpers/daybook_samples.dart';
import '../test/helpers/fakes.dart';
import '../test/helpers/space_fakes.dart';
import '../test/helpers/work_fakes.dart';
import 'shot.dart';

/// E3's due: Sunday 18 October, no time.
final _sunday = DateTime(2026, 10, 18);

/// E5: posted at 11:20.
final _elevenTwenty = DateTime(2026, 10, 15, 11, 20);

Future<List<Override>> _overrides(
  DaybookSamples s, {
  required List<DaybookRecord> posts,
  required String me,
  required DateTime now,
  SpacePass pass = SpacePass.lead,
  bool admin = true,
  DateTime? siteStart,
  List<CalendarWorkItem> calendar = const [],
  DaybookMonth month = const DaybookMonth(),
  Map<String, Object> phone = const {},
  FakeDaybookRepository? daybook,
  FakeWorkRepository? work,
}) async {
  // The phone's storage for drafts and the outbox; test_screens/ is a test
  // folder the analyzer doesn't know.
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues(phone);
  final prefs = await SharedPreferences.getInstance();
  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    spaceRepositoryProvider.overrideWithValue(
      FakeSpaceRepository()
        ..details[DaybookSamples.space] = s.detail(
          pass: pass,
          admin: admin,
          siteStart: siteStart,
        )
        ..spacePeople[DaybookSamples.space] = s.people(),
    ),
    activityRepositoryProvider.overrideWithValue(FakeActivityRepository()),
    authUserIdProvider.overrideWithValue(AsyncData(me)),
    myMarketProvider.overrideWithValue(kuwait),
    clockProvider.overrideWithValue(() => now),
    workRepositoryProvider.overrideWithValue(work ?? FakeWorkRepository()),
    daybookRepositoryProvider.overrideWithValue(
      (daybook ?? FakeDaybookRepository())
        ..posts[DaybookSamples.space] = posts
        ..calendar.addAll(calendar)
        ..months['${DaybookSamples.space} ${now.year}-${now.month}'] = month,
    ),
    // Every photo is the prototype's site photo.
    daybookPhotoProvider.overrideWith((ref, path) => samplePhoto),
    localPhotoProvider.overrideWith((ref, path) => samplePhoto),
    pickPhotoProvider.overrideWithValue(
      ({required camera}) async => XFile('camera.jpg'),
    ),
    keepPhotoProvider.overrideWithValue((photo) async => 'kept.jpg'),
    pickDueProvider.overrideWithValue(
      (context, {required now, day, at}) async => (day: _sunday, at: null),
    ),
    outboxRetryDelaysProvider.overrideWithValue(const []),
    // One id, so the posted slip's torn edge is the same every run.
    newPostIdProvider.overrideWithValue(() => 'post-trays-new'),
  ];
}

Widget _space(BuildContext _) =>
    const SpaceScreen(spaceId: DaybookSamples.space);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pumpAndSettle();
}

/// Opens the card and fills it as E3: title, text, owner, due, place and
/// the cover.
Future<void> _fill(
  WidgetTester tester,
  DaybookSamples s,
  AppLocalizations l10n,
) async {
  await _tap(tester, find.byKey(const Key('post-bar-notepad')));
  await _type(tester, 'writing-title', s.cableTraysTitle);
  await _type(tester, 'writing-body', s.traysBody);
  // Assign through More: picking from Post would post at once.
  await _tap(tester, find.bySemanticsLabel(l10n.daybookMore));
  await _tap(tester, find.text(l10n.daybookAssign));
  await _tap(
    tester,
    find.descendant(
      of: find.byType(BvGiveToPicker),
      matching: find.text(s.omarName),
    ),
  );
  await _tap(tester, find.bySemanticsLabel(l10n.daybookMore));
  await _tap(tester, find.text(l10n.daybookDueDateMenu));
  await _tap(tester, find.bySemanticsLabel(l10n.daybookMore));
  await _tap(tester, find.text(l10n.daybookLocation));
  await _type(tester, 'popover-field', s.traysPlace);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
  await _tap(tester, find.bySemanticsLabel(l10n.daybookCamera));
}

/// Long-presses the slip of entry [id]: lifted over the dim, its menu.
Future<void> _longPress(WidgetTester tester, String id) async {
  final slip = find.descendant(
    of: find.byKey(Key('daybook-entry-$id')),
    matching: find.byType(BvSlip),
  );
  await tester.ensureVisible(slip.first);
  await tester.pumpAndSettle();
  await tester.longPress(slip.first);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  setUp(() {
    // One clock on the screen, as the prototype's 24-hour times.
    TestWidgetsFlutterBinding
            .instance
            .platformDispatcher
            .alwaysUse24HourFormatTestValue =
        true;
  });
  tearDown(
    () => TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearAlwaysUse24HourTestValue(),
  );

  for (final lang in ['en', 'ar']) {
    final s = DaybookSamples(lang);
    final l10n = lookupAppLocalizations(Locale(lang));

    testWidgets('D1 the daybook [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'D1-daybook',
        lang,
        _space,
        overrides: await _overrides(
          s,
          posts: s.d1(),
          me: DaybookSamples.islam,
          now: DaybookSamples.thursday,
        ),
      );
    });

    testWidgets('L1 late, and due today [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'L1-late-due-today',
        lang,
        _space,
        overrides: await _overrides(
          s,
          posts: s.l1(),
          me: DaybookSamples.omar,
          now: DaybookSamples.friday,
          pass: SpacePass.crew,
          admin: false,
          calendar: [s.cableTraysDue()],
        ),
      );
    });

    testWidgets('DY1 yesterday\'s page [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'DY1-yesterday',
        lang,
        _space,
        overrides: await _overrides(
          s,
          posts: s.d1(),
          me: DaybookSamples.islam,
          now: DaybookSamples.thursday,
        ),
        before: (tester) async {
          await tester.drag(
            find.byKey(const Key('daybook')),
            const Offset(0, 1500),
          );
          await tester.pumpAndSettle();
        },
      );
    });

    testWidgets('DY2 the calendar [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'DY2-calendar',
        lang,
        _space,
        overrides: await _overrides(
          s,
          posts: s.d1(),
          me: DaybookSamples.islam,
          now: DaybookSamples.thursday,
          month: DaybookMonth(
            postDays: {
              for (final d in [4, 5, 6, 7, 8, 11, 12, 13, 14, 15])
                DateTime(2026, 10, d),
            },
            dueDays: {
              for (final d in [16, 18, 19]) DateTime(2026, 10, d),
            },
          ),
        ),
        before: (tester) => _tap(tester, find.byType(BvDaybookMasthead)),
      );
    });

    testWidgets('DY3 day one, empty daybook [$lang]', (tester) async {
      final sunday = DateTime(2026, 11, 1, 9);
      await shoot(
        tester,
        'DY3-day-one',
        lang,
        _space,
        overrides: await _overrides(
          s,
          posts: const [],
          me: DaybookSamples.islam,
          now: sunday,
          siteStart: DateTime(2026, 11, 1),
        ),
      );
    });

    testWidgets('V1 a Viewer\'s daybook [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'V1-viewer',
        lang,
        _space,
        overrides: await _overrides(
          s,
          posts: s.d1(viewer: true),
          me: DaybookSamples.mona,
          now: DaybookSamples.thursday,
          pass: SpacePass.viewer,
          admin: false,
        ),
      );
    });

    // Writing in place (1c).

    testWidgets('E1 a work item at Now [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'E1-write',
        lang,
        _space,
        overrides: await _overrides(
          s,
          posts: s.d1(),
          me: DaybookSamples.islam,
          now: DaybookSamples.thursday,
        ),
        before: (tester) =>
            _tap(tester, find.byKey(const Key('post-bar-notepad'))),
      );
    });

    testWidgets('E2 the More menu [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'E2-more-menu',
        lang,
        _space,
        overrides: await _overrides(
          s,
          posts: s.d1(),
          me: DaybookSamples.islam,
          now: DaybookSamples.thursday,
        ),
        before: (tester) async {
          await _tap(tester, find.byKey(const Key('post-bar-notepad')));
          await _tap(tester, find.bySemanticsLabel(l10n.daybookMore));
        },
      );
    });

    testWidgets('E3 the filled card [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'E3-filled-card',
        lang,
        _space,
        overrides: await _overrides(
          s,
          posts: s.d1(),
          me: DaybookSamples.islam,
          now: DaybookSamples.thursday,
        ),
        before: (tester) => _fill(tester, s, l10n),
      );
    });

    testWidgets('E3 the assign picker [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'E3-assign',
        lang,
        _space,
        overrides: await _overrides(
          s,
          posts: s.d1(),
          me: DaybookSamples.islam,
          now: DaybookSamples.thursday,
        ),
        before: (tester) async {
          await _tap(tester, find.byKey(const Key('post-bar-notepad')));
          await _type(tester, 'writing-title', s.cableTraysTitle);
          // Post with nobody to do it: the picker opens.
          await _tap(tester, find.byKey(const Key('writing-post')));
        },
      );
    });

    testWidgets('E4 back to a draft [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      final draft = WorkItemDraft(
        id: 'draft-trays',
        title: s.cableTraysTitle,
        body: s.t(
          'Fix the hangers every 1.5 m before the ceiling',
          'ركّب العلّاقات كل 1.5 م قبل إغلاق السقف',
        ),
      );
      await shoot(
        tester,
        'E4-draft',
        lang,
        _space,
        overrides: await _overrides(
          s,
          posts: [s.sleevesDone(), s.sleevesSignOff()],
          me: DaybookSamples.islam,
          now: DaybookSamples.thursday,
          phone: {
            'daybook_draft:${DaybookSamples.islam}:${DaybookSamples.space}':
                jsonEncode(draft.toJson()),
          },
        ),
      );
    });

    testWidgets('E5 posted: a slip at 11:20 [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      final daybook = FakeDaybookRepository()
        ..asPosted = (i) => s.posted(i, _elevenTwenty);
      await shoot(
        tester,
        'E5-posted',
        lang,
        _space,
        overrides: await _overrides(
          s,
          posts: [s.sleevesDone(), s.sleevesSignOff()],
          me: DaybookSamples.islam,
          now: _elevenTwenty,
          daybook: daybook,
        ),
        before: (tester) async {
          await _fill(tester, s, l10n);
          await _tap(tester, find.byKey(const Key('writing-post')));
        },
      );
    });

    testWidgets('E6 the kind chip: Work item only [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'E6-kind-chip',
        lang,
        _space,
        overrides: await _overrides(
          s,
          posts: s.d1(),
          me: DaybookSamples.islam,
          now: DaybookSamples.thursday,
        ),
        before: (tester) async {
          await _tap(tester, find.byKey(const Key('post-bar-notepad')));
          // One kind in slice 1: the chip opens nothing.
          await _tap(tester, find.byKey(const Key('writing-kind-chip')));
        },
      );
    });

    testWidgets('E7 no signal: waiting to send [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      final daybook = FakeDaybookRepository()..offline = true;
      await shoot(
        tester,
        'E7-waiting-to-send',
        lang,
        _space,
        overrides: await _overrides(
          s,
          posts: [s.sleevesDone(), s.sleevesSignOff()],
          me: DaybookSamples.islam,
          now: _elevenTwenty,
          daybook: daybook,
        ),
        before: (tester) async {
          await _fill(tester, s, l10n);
          await _tap(tester, find.byKey(const Key('writing-post')));
        },
      );
    });

    testWidgets('E8 a refused post: back to the Draft [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      final daybook = FakeDaybookRepository()..refuse = true;
      await shoot(
        tester,
        'E8-could-not-send',
        lang,
        _space,
        overrides: await _overrides(
          s,
          posts: [s.sleevesDone(), s.sleevesSignOff()],
          me: DaybookSamples.islam,
          now: _elevenTwenty,
          daybook: daybook,
        ),
        before: (tester) async {
          await _fill(tester, s, l10n);
          await _tap(tester, find.byKey(const Key('writing-post')));
        },
      );
    });

    // The loop (1d).

    testWidgets('O1 Omar\'s daybook [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'O1-omars-daybook',
        lang,
        _space,
        overrides: await _overrides(
          s,
          posts: s.o1(),
          me: DaybookSamples.omar,
          now: DaybookSamples.thursday,
          pass: SpacePass.crew,
          admin: false,
        ),
      );
    });

    testWidgets('O2 sign as done: the proof and a note [$lang]', (
      tester,
    ) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'O2-sign-as-done',
        lang,
        _space,
        overrides: await _overrides(
          s,
          posts: s.o1(),
          me: DaybookSamples.omar,
          now: DateTime(2026, 10, 15, 9, 40),
          pass: SpacePass.crew,
          admin: false,
        ),
        before: (tester) async {
          await _tap(tester, find.text(l10n.daybookSignAsDone).first);
          await _tap(tester, find.byKey(const Key('proof-take-photo')));
          await _type(tester, 'proof-note', s.sleevesNote);
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
        },
      );
    });

    testWidgets('O3 the proof posted, Omar\'s view [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'O3-proof-posted',
        lang,
        _space,
        overrides: await _overrides(
          s,
          posts: [s.sleevesDone(), s.sleevesSignOff(needsMe: false)],
          me: DaybookSamples.omar,
          now: DateTime(2026, 10, 15, 9, 41),
          pass: SpacePass.crew,
          admin: false,
        ),
      );
    });

    testWidgets('S1 sent back, Omar\'s view [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'S1-sent-back-owner',
        lang,
        _space,
        overrides: await _overrides(
          s,
          posts: s.s1(),
          me: DaybookSamples.omar,
          now: DateTime(2026, 10, 15, 10, 15),
          pass: SpacePass.crew,
          admin: false,
        ),
      );
    });

    testWidgets('Y1 swipe a work item to add an update [$lang]', (
      tester,
    ) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'Y1-swipe-update',
        lang,
        _space,
        overrides: await _overrides(
          s,
          posts: s.o1(),
          me: DaybookSamples.omar,
          now: DaybookSamples.thursday,
          pass: SpacePass.crew,
          admin: false,
        ),
        before: (tester) async {
          await tester.drag(
            find.descendant(
              of: find.byKey(const Key('daybook-entry-post-sleeves')),
              matching: find.byKey(const Key('swipe-reveal')),
            ),
            Offset(lang == 'ar' ? -80 : 80, 0),
          );
          await tester.pumpAndSettle();
        },
      );
    });

    testWidgets('Y2 the update hangs under its work item [$lang]', (
      tester,
    ) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'Y2-update-posted',
        lang,
        _space,
        overrides: await _overrides(
          s,
          posts: [s.o1().first, s.sleevesUpdate()],
          me: DaybookSamples.omar,
          now: DateTime(2026, 10, 15, 9, 6),
          pass: SpacePass.crew,
          admin: false,
        ),
      );
    });

    testWidgets('B1 long-press Omar\'s proof [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'B1-long-press-proof',
        lang,
        _space,
        overrides: await _overrides(
          s,
          posts: s.d1(),
          me: DaybookSamples.islam,
          now: DaybookSamples.thursday,
        ),
        before: (tester) => _longPress(tester, 'event-sleeves-done'),
      );
    });

    testWidgets('B2 send back with a reason [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'B2-send-back-reasons',
        lang,
        _space,
        overrides: await _overrides(
          s,
          posts: s.d1(),
          me: DaybookSamples.islam,
          now: DaybookSamples.thursday,
        ),
        before: (tester) async {
          await _longPress(tester, 'event-sleeves-done');
          await _tap(tester, find.text(l10n.daybookSendBack));
          await _tap(tester, find.text(l10n.daybookReasonNotAsAsked));
          await tester.enterText(
            find.descendant(
              of: find.byKey(const Key('send-back-card')),
              matching: find.byType(TextField),
            ),
            s.sentBackNote,
          );
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
        },
      );
    });

    testWidgets('B3 checked, with Undo [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'B3-checked-undo',
        lang,
        _space,
        overrides: await _overrides(
          s,
          posts: s.d1(),
          me: DaybookSamples.islam,
          now: DateTime(2026, 10, 15, 10, 12),
        ),
        before: (tester) async {
          final photo = find.descendant(
            of: find.byKey(const Key('daybook-entry-event-sleeves-done')),
            matching: find.byKey(const Key('slip-photo')),
          );
          await tester.tap(photo);
          await tester.pump(const Duration(milliseconds: 100));
          await tester.tap(photo);
          await tester.pumpAndSettle();
        },
      );
      // The undo bar's 5 seconds, then the check is sent.
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    });

    testWidgets('X1 long-press your own work item [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'X1-own-item-menu',
        lang,
        _space,
        overrides: await _overrides(
          s,
          posts: [
            s.sleevesDone(),
            s.sleevesSignOff(needsMe: false),
            s.traysForOmar(needsMe: false),
          ],
          me: DaybookSamples.islam,
          now: _elevenTwenty,
        ),
        before: (tester) => _longPress(tester, 'post-trays'),
      );
    });

    // Review 51 F16: no Figma frame (X1's menu). Rakesh (Crew) neither
    // wrote nor owns the sleeves item: Add update is his too.
    testWidgets("C6 long-press someone else's work item [$lang]", (
      tester,
    ) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'C6-long-press-other-item',
        lang,
        _space,
        overrides: await _overrides(
          s,
          posts: s.s1(),
          me: DaybookSamples.rakesh,
          pass: SpacePass.crew,
          admin: false,
          now: DaybookSamples.thursday,
        ),
        before: (tester) => _longPress(tester, 'post-sleeves'),
      );
    });

    testWidgets('X2 give it to someone else [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'X2-give-to',
        lang,
        _space,
        overrides: await _overrides(
          s,
          posts: [
            s.sleevesDone(),
            s.sleevesSignOff(needsMe: false),
            s.traysForOmar(needsMe: false),
          ],
          me: DaybookSamples.islam,
          now: _elevenTwenty,
        ),
        before: (tester) async {
          await _longPress(tester, 'post-trays');
          await _tap(tester, find.text(l10n.daybookGiveTo));
        },
      );
    });

    testWidgets('X2 given to Rakesh instead [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'X2-given',
        lang,
        _space,
        overrides: await _overrides(
          s,
          posts: [
            s.sleevesDone(),
            s.sleevesSignOff(needsMe: false),
            s.traysForOmar(
              needsMe: false,
              givenTo: DaybookGivenTo(
                at: DateTime(2026, 10, 15, 12, 30),
                fromName: s.omarName,
                toName: s.rakeshName,
              ),
            ),
          ],
          me: DaybookSamples.islam,
          now: DateTime(2026, 10, 15, 12, 31),
        ),
      );
    });

    testWidgets('MN1 the Space menu [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'MN1-space-menu',
        lang,
        _space,
        overrides: await _overrides(
          s,
          posts: s.d1(),
          me: DaybookSamples.islam,
          now: DaybookSamples.thursday,
        ),
        before: (tester) => _tap(tester, find.byKey(const Key('space-more'))),
      );
    });

    testWidgets('O4 prove another work item [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'O4-switch-item',
        lang,
        _space,
        overrides: await _overrides(
          s,
          posts: s.o1(),
          me: DaybookSamples.omar,
          now: DateTime(2026, 10, 15, 9, 40),
          pass: SpacePass.crew,
          admin: false,
        ),
        before: (tester) async {
          await tester.longPress(find.byKey(const Key('post-bar-camera')));
          await tester.pumpAndSettle();
          await _tap(tester, find.byKey(const Key('proof-switch-open')));
        },
      );
    });

    testWidgets('O5 a refused sign-off keeps its photos [$lang]', (
      tester,
    ) async {
      await warmSamplePhoto(tester);
      final work = FakeWorkRepository()
        ..refuse = const SpaceException(
          SpaceFailure.rule,
          'this work item was cancelled',
        );
      await shoot(
        tester,
        'O5-could-not-send',
        lang,
        _space,
        overrides: await _overrides(
          s,
          posts: s.o1(),
          me: DaybookSamples.omar,
          now: DateTime(2026, 10, 15, 9, 40),
          pass: SpacePass.crew,
          admin: false,
          work: work,
        ),
        before: (tester) async {
          await _tap(tester, find.text(l10n.daybookSignAsDone).first);
          await _tap(tester, find.byKey(const Key('proof-take-photo')));
          await _type(tester, 'proof-note', s.sleevesNote);
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          await _tap(tester, find.byKey(const Key('proof-send')));
          // The undo bar's 5 seconds, then the server says no.
          await tester.pump(const Duration(seconds: 6));
          await tester.pumpAndSettle();
        },
      );
    });

    // Review 51, Part D: signing without a photo (F6), and Undo (F7).

    testWidgets('D1 proof without a photo, the note [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'D1-proof-without-photo',
        lang,
        _space,
        overrides: await _overrides(
          s,
          posts: s.o1(),
          me: DaybookSamples.omar,
          now: DateTime(2026, 10, 15, 9, 40),
          pass: SpacePass.crew,
          admin: false,
        ),
        before: (tester) async {
          await _tap(tester, find.text(l10n.daybookSignAsDone).first);
          await _tap(tester, find.byKey(const Key('proof-without-photo')));
          await _type(tester, 'proof-note', s.sleevesNote);
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
        },
      );
    });

    testWidgets('D2 a proof slip with a note only [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'D2-proof-slip-note-only',
        lang,
        _space,
        overrides: await _overrides(
          s,
          posts: [
            s.sleevesDone(),
            s.sleevesSignOff(photos: const []),
            s.rebar(),
          ],
          me: DaybookSamples.islam,
          now: DateTime(2026, 10, 15, 10, 12),
        ),
      );
    });

    testWidgets('D3 signed as done, with Undo [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'D3-signed-undo',
        lang,
        _space,
        overrides: await _overrides(
          s,
          posts: s.o1(),
          me: DaybookSamples.omar,
          now: DateTime(2026, 10, 15, 9, 40),
          pass: SpacePass.crew,
          admin: false,
        ),
        before: (tester) async {
          await _tap(tester, find.text(l10n.daybookSignAsDone).first);
          await _tap(tester, find.byKey(const Key('proof-take-photo')));
          await _type(tester, 'proof-note', s.sleevesNote);
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          await _tap(tester, find.byKey(const Key('proof-send')));
        },
      );
      // The undo bar's 5 seconds, then the sign-off is sent.
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    });

    testWidgets('X3 edited and cancelled work items [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      final trays = s.traysForOmar(needsMe: false);
      await shoot(
        tester,
        'X3-cancelled',
        lang,
        _space,
        overrides: await _overrides(
          s,
          posts: [
            s.sleevesDone(),
            s.sleevesSignOff(needsMe: false),
            s.item(
              id: trays.id,
              at: trays.createdAt,
              title: trays.title,
              authorId: DaybookSamples.islam,
              authorName: s.islamName,
              ownerId: DaybookSamples.omar,
              ownerName: s.omarName,
              due: DateTime(2026, 10, 19),
              cover: trays.coverPath,
              edit: DaybookDueEdit(
                from: DateTime(2026, 10, 18),
                to: DateTime(2026, 10, 19),
              ),
            ),
            s.doorHardware(),
          ],
          me: DaybookSamples.islam,
          now: DateTime(2026, 10, 15, 12, 6),
        ),
      );
    });
  }
}
