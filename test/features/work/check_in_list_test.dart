// Review 109 CI5 (2706:39604 EN, 2706:39933 AR): the creator's list, one
// line per person with their In and Out stamps or Missed; the day picker
// goes back through check_in_days; ⋯ → Stop only when the server says
// can_stop (the creator, or a Space admin once the creator left), with a
// confirmation. In English and Arabic.
import 'package:buildvibes/core/l10n/bv_time.dart';
import 'package:buildvibes/data/models/check_in.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/check_in_fakes.dart';
import '../../helpers/check_in_samples.dart';
import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

/// The list of the sample check-in, opened by [authorId]'s card as the
/// server gives it to the reader.
Future<TestApp> openList(
  WidgetTester tester,
  String lang, {
  String authorId = DaybookSamples.islam,
  bool canStop = true,
  bool admin = false,
  List<DateTime>? days,
}) async {
  final s = DaybookSamples(lang);
  final checkIns = FakeCheckInRepository()
    ..lines['2026-10-15'] = CheckInSamples.lines(lang)
    ..lines['2026-10-14'] = [
      CheckInLine(
        userId: DaybookSamples.rakesh,
        name: s.rakeshName,
        inMark: CheckInMark(
          at: CheckInSamples.at(6, 50).subtract(const Duration(days: 1)),
          onTime: true,
          place: CheckInPlace.onSite,
        ),
      ),
    ]
    ..dayList = days ?? [DateTime(2026, 10, 15), DateTime(2026, 10, 14)];
  final app = await pumpApp(
    tester,
    language: lang,
    spaces: FakeSpaceRepository()
      ..details[DaybookSamples.space] = s.detail(
        admin: admin,
        timeZone: CheckInSamples.zone,
      )
      ..spacePeople[DaybookSamples.space] = s.people(),
    daybook: FakeDaybookRepository()
      ..posts[DaybookSamples.space] = [
        CheckInSamples.card(
          lang,
          authorId: authorId,
          asked: false,
          seesList: true,
          canStop: canStop,
        ),
      ],
    checkIns: checkIns,
    now: CheckInSamples.at(16, 0),
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/${DaybookSamples.space}/check-ins/${CheckInSamples.id}');
  await tester.pumpAndSettle();
  return app;
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    final s = DaybookSamples(lang);
    String t(int h, int m) =>
        BvTime(l10n, lang, use24: false).clock(DateTime(2000, 1, 1, h, m));

    group('CI5 the creator’s list [$lang]', () {
      testWidgets('one line per person: In and Out stamps, or Missed; only '
          'you see it; saved to the Library every evening', (tester) async {
        await openList(tester, lang);
        expect(
          tester.widget<Text>(_key('check-in-list-title')).data,
          s.t('Morning, Block B', 'صباح المبنى B'),
        );
        expect(
          find.text(l10n.checkInListSub(l10n.checkInListToday)),
          findsOneWidget,
        );
        expect(find.text(s.rakeshName), findsOneWidget);
        expect(find.text(l10n.checkInIn(t(6, 58))), findsOneWidget);
        expect(find.text(l10n.checkInOut(t(15, 5))), findsOneWidget);
        expect(
          find.text('${l10n.checkInIn(t(7, 24))} · ${l10n.checkInLate}'),
          findsOneWidget,
        );
        expect(
          find.text('${l10n.checkInIn(t(7, 1))} · ${l10n.checkInAway}'),
          findsOneWidget,
        );
        expect(
          find.text('${l10n.checkInIn(t(7, 3))} · ${l10n.checkInNoLocation}'),
          findsOneWidget,
        );
        expect(
          _key('check-in-line-missed-${DaybookSamples.sara}'),
          findsOneWidget,
        );
        expect(find.text(l10n.checkInListLibrary), findsOneWidget);
      });

      testWidgets('the day picker goes back to an earlier day', (tester) async {
        await openList(tester, lang);
        await _tap(tester, _key('check-in-list-day'));
        expect(_key('check-in-days'), findsOneWidget);
        await _tap(tester, _key('check-in-day-2026-10-14'));
        expect(find.text(l10n.checkInIn(t(6, 50))), findsOneWidget);
        expect(find.text(s.omarName), findsNothing);
      });

      testWidgets('the creator: ⋯ → Stop, confirmed, stops it', (tester) async {
        final app = await openList(tester, lang);
        await _tap(tester, _key('check-in-list-more'));
        await _tap(tester, _key('check-in-stop'));
        expect(find.text(l10n.checkInStopTitle), findsOneWidget);
        expect(find.text(l10n.checkInStopBody), findsOneWidget);
        await _tap(tester, find.text(l10n.checkInStop).last);
        expect(app.checkIns.stopped, [CheckInSamples.id]);
        expect(find.text(l10n.checkInStoppedDone), findsOneWidget);
      });

      testWidgets('Keep it stops nothing', (tester) async {
        final app = await openList(tester, lang);
        await _tap(tester, _key('check-in-list-more'));
        await _tap(tester, _key('check-in-stop'));
        await _tap(tester, find.text(l10n.checkInKeep));
        expect(app.checkIns.stopped, isEmpty);
      });

      testWidgets('a Space admin once the creator left (can_stop): Stop', (
        tester,
      ) async {
        final app = await openList(
          tester,
          lang,
          authorId: DaybookSamples.sara,
          admin: true,
        );
        await _tap(tester, _key('check-in-list-more'));
        await _tap(tester, _key('check-in-stop'));
        await _tap(tester, find.text(l10n.checkInStop).last);
        expect(app.checkIns.stopped, [CheckInSamples.id]);
      });

      testWidgets('another Lead, or a once-only one (no can_stop): no ⋯', (
        tester,
      ) async {
        await openList(
          tester,
          lang,
          authorId: DaybookSamples.sara,
          canStop: false,
        );
        expect(_key('check-in-list-more'), findsNothing);
      });
    });
  }
}
