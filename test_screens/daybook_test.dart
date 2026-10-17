// The daybook page (slice 1b) against Figma D1 2518:33001, L1 2539:34633,
// DY1 2541:34679, DY2 2541:34813, DY3 2541:35060, V1 2542:35109 and the AR
// daybook 2547:35195. Run:
//   flutter test test_screens/daybook_test.dart --update-goldens
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
import 'package:buildvibes/shared/widgets/bv_daybook_masthead.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../test/helpers/activity_fakes.dart';
import '../test/helpers/daybook_fakes.dart';
import '../test/helpers/daybook_samples.dart';
import '../test/helpers/fakes.dart';
import '../test/helpers/space_fakes.dart';
import '../test/helpers/work_fakes.dart';
import 'shot.dart';

List<Override> _overrides(
  DaybookSamples s, {
  required List<DaybookPost> posts,
  required String me,
  required DateTime now,
  SpacePass pass = SpacePass.lead,
  bool admin = true,
  DateTime? siteStart,
  List<CalendarWorkItem> calendar = const [],
  DaybookMonth month = const DaybookMonth(),
}) {
  return [
    spaceRepositoryProvider.overrideWithValue(
      FakeSpaceRepository()
        ..details[DaybookSamples.space] = s.detail(
          pass: pass,
          admin: admin,
          siteStart: siteStart,
        ),
    ),
    activityRepositoryProvider.overrideWithValue(FakeActivityRepository()),
    authUserIdProvider.overrideWithValue(AsyncData(me)),
    myMarketProvider.overrideWithValue(kuwait),
    clockProvider.overrideWithValue(() => now),
    workRepositoryProvider.overrideWithValue(FakeWorkRepository()),
    daybookRepositoryProvider.overrideWithValue(
      FakeDaybookRepository()
        ..posts[DaybookSamples.space] = posts
        ..calendar.addAll(calendar)
        ..months['${DaybookSamples.space} ${now.year}-${now.month}'] = month,
    ),
  ];
}

Widget _space(BuildContext _) =>
    const SpaceScreen(spaceId: DaybookSamples.space);

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

    testWidgets('D1 the daybook [$lang]', (tester) async {
      await shoot(
        tester,
        'D1-daybook',
        lang,
        _space,
        overrides: _overrides(
          s,
          posts: [s.sleevesDone(), s.rebar()],
          me: DaybookSamples.islam,
          now: DaybookSamples.thursday,
        ),
      );
    });

    testWidgets('L1 late, and due today [$lang]', (tester) async {
      await shoot(
        tester,
        'L1-late-due-today',
        lang,
        _space,
        overrides: _overrides(
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
      await shoot(
        tester,
        'DY1-yesterday',
        lang,
        _space,
        overrides: _overrides(
          s,
          posts: s.d1(),
          me: DaybookSamples.islam,
          now: DaybookSamples.thursday,
        ),
        before: (tester) async {
          await tester.drag(
            find.byKey(const Key('daybook')),
            const Offset(0, 1200),
          );
          await tester.pumpAndSettle();
        },
      );
    });

    testWidgets('DY2 the calendar [$lang]', (tester) async {
      await shoot(
        tester,
        'DY2-calendar',
        lang,
        _space,
        overrides: _overrides(
          s,
          posts: [s.sleevesDone(), s.rebar()],
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
        before: (tester) async {
          await tester.tap(find.byType(BvDaybookMasthead));
          await tester.pumpAndSettle();
        },
      );
    });

    testWidgets('DY3 day one, empty daybook [$lang]', (tester) async {
      final sunday = DateTime(2026, 11, 1, 9);
      await shoot(
        tester,
        'DY3-day-one',
        lang,
        _space,
        overrides: _overrides(
          s,
          posts: const [],
          me: DaybookSamples.islam,
          now: sunday,
          siteStart: DateTime(2026, 11, 1),
        ),
      );
    });

    testWidgets('V1 a Viewer\'s daybook [$lang]', (tester) async {
      await shoot(
        tester,
        'V1-viewer',
        lang,
        _space,
        overrides: _overrides(
          s,
          posts: [s.sleevesDone(needsMe: false), s.rebar(needsMe: false)],
          me: DaybookSamples.mona,
          now: DaybookSamples.thursday,
          pass: SpacePass.viewer,
          admin: false,
        ),
      );
    });
  }
}
