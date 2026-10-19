// The daybook page in v13 (review 53 Part B: one card per work item, full
// width, no hour spine), against Figma EN 2581:35611 (Islam's daybook),
// 2582:35982 (Omar after a send-back), 2582:36114 (checked, with Undo),
// 2582:77206 (Add update) and AR 2583:373. The earlier states keep their
// names, now drawn on v13's cards: L1 2539:34633, DY1 2541:34679, DY2
// 2541:34813, DY3 2541:35060, V1 2542:35109, writing in place E1–E8
// (2524:33180, 2524:33369, 2524:33577, 2524:33780, 2524:33936,
// 2535:34221, the assign picker 2540:34840), the loop's O1 2529:33382, O2
// 2529:33493, O3 2529:33514, Y1 2530:33953, B1 2530:33480, B2 2530:33643,
// X1 2530:34134, X2 2540:34693, X3 2530:34263, part 1e's MN1 2566:35619,
// review 47's O4 and O5, and review 51's Part D (D1 without a photo, D2 a
// note-only proof, D3 the undo bar after Send as done). Run:
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
import 'package:buildvibes/features/work/daybook_photos.dart';
import 'package:buildvibes/features/work/daybook_target.dart';
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

/// v13: just after Omar's second sign-off; the check at 10:58.
final _afterSignOff = DateTime(2026, 10, 15, 10, 57);
final _checkAt = DateTime(2026, 10, 15, 10, 58);

Future<List<Override>> _overrides(
  DaybookSamples s, {
  required List<DaybookCard> posts,
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
    // One id, so the posted card's torn edge is the same every run.
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

Finder _inCard(String id, Finder f) =>
    find.descendant(of: find.byKey(Key('daybook-card-$id')), matching: f);

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

/// Long-presses the card [id]: lifted over the dim, its menu.
Future<void> _longPress(WidgetTester tester, String id) async {
  final slip = _inCard(id, find.byType(BvSlip));
  await tester.ensureVisible(slip.first);
  await tester.pumpAndSettle();
  await tester.longPress(slip.first);
  await tester.pumpAndSettle();
}

/// Double-taps the proof photo of card [id].
Future<void> _doubleTap(WidgetTester tester, String id) async {
  // Clear of the stamp in the middle.
  final photo =
      tester.getTopLeft(_inCard(id, find.byKey(const Key('slip-photo')))) +
      const Offset(20, 20);
  await tester.tapAt(photo);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tapAt(photo);
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

    // v13 (review 53 Part B).

    testWidgets("V13 Islam's daybook [$lang]", (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'V13-islams-daybook',
        lang,
        _space,
        overrides: await _overrides(
          s,
          posts: s.v13(),
          me: DaybookSamples.islam,
          now: _afterSignOff,
        ),
      );
    });

    // Review 54 A1: the same daybook on a 12-hour phone: "10:56 am" in
    // English; in Arabic the part of the day on a small second line under
    // the time (F15).
    testWidgets("A1 Islam's daybook, 12-hour times [$lang]", (tester) async {
      TestWidgetsFlutterBinding
              .instance
              .platformDispatcher
              .alwaysUse24HourFormatTestValue =
          false;
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'A1-times-12h',
        lang,
        _space,
        overrides: await _overrides(
          s,
          posts: s.v13(),
          me: DaybookSamples.islam,
          now: _afterSignOff,
        ),
      );
    });

    testWidgets("V13 Islam's daybook, scrolled to Wednesday [$lang]", (
      tester,
    ) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'V13-islams-daybook-top',
        lang,
        _space,
        overrides: await _overrides(
          s,
          posts: s.v13(),
          me: DaybookSamples.islam,
          now: _afterSignOff,
        ),
        before: (tester) async {
          await tester.drag(
            find.byKey(const Key('daybook')),
            const Offset(0, 2000),
          );
          await tester.pumpAndSettle();
        },
      );
    });

    testWidgets('V13 Omar after a send-back [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'V13-omar-sent-back',
        lang,
        _space,
        overrides: await _overrides(
          s,
          posts: [
            s.sleevesCard(
              me: DaybookSamples.omar,
              upTo: DaybookSamples.sleevesSentBackAt,
            ),
            s.rebar(needsMe: false),
          ],
          me: DaybookSamples.omar,
          now: DateTime(2026, 10, 15, 10, 15),
          pass: SpacePass.crew,
          admin: false,
        ),
      );
    });

    testWidgets('V13 checked, with Undo [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'V13-checked-undo',
        lang,
        _space,
        overrides: await _overrides(
          s,
          posts: s.v13(),
          me: DaybookSamples.islam,
          now: _checkAt,
        ),
        before: (tester) => _doubleTap(tester, 'post-sleeves'),
      );
      // The undo bar's 5 seconds, then the check is sent.
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    });

    testWidgets('V13 Add update [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'V13-add-update',
        lang,
        _space,
        overrides: await _overrides(
          s,
          posts: s.v13(),
          me: DaybookSamples.islam,
          now: _afterSignOff,
        ),
        before: (tester) async {
          await _longPress(tester, 'post-sleeves');
          await _tap(tester, find.text(l10n.daybookAddUpdate));
          await tester.enterText(
            find.byKey(const Key('bv-send-field')),
            s.t('Area cleaned', 'نُظّفت المنطقة'),
          );
          await tester.pumpAndSettle();
        },
      );
    });

    // Review 53 Part D.

    testWidgets('D F24 Add update over the keyboard [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'D-F24-update-sheet-keyboard',
        lang,
        _space,
        keyboard: true,
        overrides: await _overrides(
          s,
          posts: s.v13(),
          me: DaybookSamples.islam,
          now: _afterSignOff,
        ),
        before: (tester) async {
          await _longPress(tester, 'post-sleeves');
          await _tap(tester, find.text(l10n.daybookAddUpdate));
          await tester.enterText(
            find.byKey(const Key('bv-send-field')),
            s.t('Area cleaned', 'نُظّفت المنطقة'),
          );
          await tester.pumpAndSettle();
        },
      );
    });

    testWidgets('D F24 send back over the keyboard [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'D-F24-send-back-keyboard',
        lang,
        _space,
        keyboard: true,
        overrides: await _overrides(
          s,
          posts: s.v13(),
          me: DaybookSamples.islam,
          now: _afterSignOff,
        ),
        before: (tester) async {
          await _longPress(tester, 'post-sleeves');
          await _tap(tester, find.text(l10n.daybookSendBack));
          await _tap(tester, find.text(l10n.daybookReasonNotAsAsked));
          await tester.enterText(
            find.descendant(
              of: find.byKey(const Key('send-back-card')),
              matching: find.byType(TextField),
            ),
            s.sentBackNote,
          );
          await tester.pumpAndSettle();
        },
      );
    });

    // F20: an Activity row about Wednesday's gate opens the daybook at that
    // card, its history at Omar's sign-off, the ring on for a second.
    testWidgets('D F20 the card a row opened, highlighted [$lang]', (
      tester,
    ) async {
      await warmSamplePhoto(tester);
      final target = ValueNotifier<DaybookTarget?>(null);
      addTearDown(target.dispose);
      await shoot(
        tester,
        'D-F20-highlight',
        lang,
        (_) => ValueListenableBuilder(
          valueListenable: target,
          builder: (_, t, _) =>
              SpaceScreen(spaceId: DaybookSamples.space, target: t),
        ),
        overrides: await _overrides(
          s,
          posts: s.d1(),
          me: DaybookSamples.islam,
          now: _afterSignOff,
        ),
        before: (tester) async {
          target.value = const DaybookTarget(
            'post-gate',
            eventId: 'ev-gate-done',
          );
          final ring = find.byKey(const Key('bv-highlight-ring'));
          for (var i = 0; i < 20 && ring.evaluate().isEmpty; i++) {
            await tester.pump(const Duration(milliseconds: 50));
          }
          expect(ring, findsOneWidget);
        },
      );
      // The ring fades before the test ends.
      await tester.pumpAndSettle();
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
          now: _afterSignOff,
        ),
        before: (tester) async {
          await tester.drag(
            find.byKey(const Key('daybook')),
            const Offset(0, 3000),
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
          now: _afterSignOff,
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
          now: _afterSignOff,
          pass: SpacePass.viewer,
          admin: false,
        ),
      );
    });

    // Writing in place (1c): the draft card at Now.

    testWidgets('E1 a work item at Now [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'E1-write',
        lang,
        _space,
        overrides: await _overrides(
          s,
          posts: s.v13(),
          me: DaybookSamples.islam,
          now: _afterSignOff,
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
          posts: s.v13(),
          me: DaybookSamples.islam,
          now: _afterSignOff,
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
          posts: s.v13(),
          me: DaybookSamples.islam,
          now: _afterSignOff,
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
          posts: s.v13(),
          me: DaybookSamples.islam,
          now: _afterSignOff,
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
          posts: [s.sleevesCard()],
          me: DaybookSamples.islam,
          now: _afterSignOff,
          phone: {
            'daybook_draft:${DaybookSamples.islam}:${DaybookSamples.space}':
                jsonEncode(draft.toJson()),
          },
        ),
      );
    });

    testWidgets('E5 posted: a card at 11:20 [$lang]', (tester) async {
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
          posts: [s.sleevesCard()],
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
          posts: s.v13(),
          me: DaybookSamples.islam,
          now: _afterSignOff,
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
          posts: [s.sleevesCard()],
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
          posts: [s.sleevesCard()],
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

    // The loop (1d), on the cards.

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
          now: _elevenTwenty,
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
          now: DaybookSamples.sleevesFirstDoneAt,
          pass: SpacePass.crew,
          admin: false,
        ),
        before: (tester) async {
          await _tap(
            tester,
            _inCard('post-sleeves', find.text(l10n.daybookSignAsDone)),
          );
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
          posts: [
            s.sleevesCard(
              me: DaybookSamples.omar,
              upTo: DaybookSamples.sleevesFirstDoneAt,
            ),
          ],
          me: DaybookSamples.omar,
          now: DateTime(2026, 10, 15, 9, 41),
          pass: SpacePass.crew,
          admin: false,
        ),
      );
    });

    testWidgets('Y1 swipe a card to add an update [$lang]', (tester) async {
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
          now: _elevenTwenty,
          pass: SpacePass.crew,
          admin: false,
        ),
        before: (tester) async {
          await tester.drag(
            _inCard('post-trays', find.byKey(const Key('swipe-reveal'))),
            Offset(lang == 'ar' ? -80 : 80, 0),
          );
          await tester.pumpAndSettle();
        },
      );
    });

    testWidgets('B1 long-press the card to check [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'B1-long-press-proof',
        lang,
        _space,
        overrides: await _overrides(
          s,
          posts: s.v13(),
          me: DaybookSamples.islam,
          now: _afterSignOff,
        ),
        before: (tester) => _longPress(tester, 'post-sleeves'),
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
          posts: s.v13(),
          me: DaybookSamples.islam,
          now: _afterSignOff,
        ),
        before: (tester) async {
          await _longPress(tester, 'post-sleeves');
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

    testWidgets('X1 long-press your own work item [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'X1-own-item-menu',
        lang,
        _space,
        overrides: await _overrides(
          s,
          posts: [s.sleevesCard(), s.traysForOmar(needsMe: false)],
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
          posts: [
            s.sleevesCard(
              me: DaybookSamples.rakesh,
              upTo: DaybookSamples.sleevesSentBackAt,
            ),
          ],
          me: DaybookSamples.rakesh,
          pass: SpacePass.crew,
          admin: false,
          now: _afterSignOff,
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
          posts: [s.sleevesCard(), s.traysForOmar(needsMe: false)],
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
            s.sleevesCard(),
            s.traysForOmar(
              needsMe: false,
              givenAt: DateTime(2026, 10, 15, 12, 30),
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
          posts: s.v13(),
          me: DaybookSamples.islam,
          now: _afterSignOff,
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
          now: DaybookSamples.sleevesFirstDoneAt,
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
          now: DaybookSamples.sleevesFirstDoneAt,
          pass: SpacePass.crew,
          admin: false,
          work: work,
        ),
        before: (tester) async {
          await _tap(
            tester,
            _inCard('post-sleeves', find.text(l10n.daybookSignAsDone)),
          );
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
          now: DaybookSamples.sleevesFirstDoneAt,
          pass: SpacePass.crew,
          admin: false,
        ),
        before: (tester) async {
          await _tap(
            tester,
            _inCard('post-sleeves', find.text(l10n.daybookSignAsDone)),
          );
          await _tap(tester, find.byKey(const Key('proof-without-photo')));
          await _type(tester, 'proof-note', s.sleevesNote);
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
        },
      );
    });

    testWidgets('D2 a card whose proof is a note only [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'D2-proof-slip-note-only',
        lang,
        _space,
        overrides: await _overrides(
          s,
          posts: [
            s.rebar(),
            s.sleevesCard(photos: const []),
          ],
          me: DaybookSamples.islam,
          now: _afterSignOff,
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
          now: DaybookSamples.sleevesFirstDoneAt,
          pass: SpacePass.crew,
          admin: false,
        ),
        before: (tester) async {
          await _tap(
            tester,
            _inCard('post-sleeves', find.text(l10n.daybookSignAsDone)),
          );
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
      final trays = s.traysForOmar(needsMe: false).post;
      await shoot(
        tester,
        'X3-cancelled',
        lang,
        _space,
        overrides: await _overrides(
          s,
          posts: [
            s.card(
              s.item(
                id: trays.id,
                at: trays.createdAt,
                title: trays.title,
                ref: 'KCT-020',
                authorId: DaybookSamples.islam,
                ownerId: DaybookSamples.omar,
                due: DateTime(2026, 10, 19),
                cover: trays.coverPath,
              ),
              events: [
                s.event(
                  'ev-trays-edit',
                  DaybookEventKind.edited,
                  DateTime(2026, 10, 15, 11, 45),
                  DaybookSamples.islam,
                  dueEdit: DaybookDueEdit(
                    from: DateTime(2026, 10, 18),
                    to: DateTime(2026, 10, 19),
                  ),
                ),
              ],
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
