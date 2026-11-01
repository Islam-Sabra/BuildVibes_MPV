// Review 109 CI3 (2706:39486 EN, 2706:39815 AR) and CI4 (2706:39534,
// 2706:39863): the person's card shows only their own stamp, then Check
// out (off until its time); the warning comes before the location is
// first read; Accept → the phone's prompt → read; without location →
// "location not shared", and the warning comes back next time; location
// off → not shared, with no error. In English and Arabic.
import 'package:buildvibes/core/l10n/bv_time.dart';
import 'package:buildvibes/core/location/location_reader.dart';
import 'package:buildvibes/data/models/check_in.dart';
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/work/check_in_marking.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/check_in_fakes.dart';
import '../../helpers/check_in_samples.dart';
import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/location_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

const _id = CheckInSamples.id;

/// The sample Space on Kuwait's clock, with [card] on Work, at [h]:[m]
/// there. Islam is Crew unless [pass] says otherwise.
Future<TestApp> openCard(
  WidgetTester tester,
  String lang,
  DaybookCard card, {
  int h = 7,
  int m = 0,
  SpacePass pass = SpacePass.crew,
  bool accepted = false,
  FakeLocationReader? location,
  FakeCheckInRepository? checkIns,
}) async {
  final s = DaybookSamples(lang);
  final app = await pumpApp(
    tester,
    language: lang,
    spaces: FakeSpaceRepository()
      ..details[DaybookSamples.space] = s.detail(
        pass: pass,
        admin: false,
        timeZone: CheckInSamples.zone,
      )
      ..spacePeople[DaybookSamples.space] = s.people(),
    daybook: FakeDaybookRepository()..posts[DaybookSamples.space] = [card],
    now: CheckInSamples.at(h, m),
    location: location,
    checkIns: checkIns,
    stored: {if (accepted) checkInConsentKey('user-1'): true},
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/${DaybookSamples.space}');
  await tester.pumpAndSettle();
  return app;
}

String _label(WidgetTester tester, String key) =>
    tester.widget<BvButton>(_key(key)).label;

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    // A time as the app writes it in this language.
    String t(String hm) {
      final p = hm.split(':');
      return BvTime(
        l10n,
        lang,
        use24: false,
      ).clock(DateTime(2000, 1, 1, int.parse(p[0]), int.parse(p[1])));
    }

    group('CI4 the person’s card [$lang]', () {
      testWidgets('open: the kind, Every day, the times, and Check in by its '
          'on-time limit', (tester) async {
        await openCard(tester, lang, CheckInSamples.card(lang));
        expect(_key('check-in-card-$_id'), findsOneWidget);
        expect(find.text(l10n.daybookKindCheckIn), findsWidgets);
        expect(
          tester.widget<Text>(_key('check-in-repeat-$_id')).data,
          l10n.checkInEveryDay,
        );
        expect(
          find.text(l10n.checkInTimes(t('7:00'), t('14:00'))),
          findsOneWidget,
        );
        expect(_label(tester, 'check-in-$_id'), l10n.checkInBy(t('7:15')));
        expect(_key('check-in-list-$_id'), findsNothing);
      });

      testWidgets('before it opens: Check in, off, from its opening', (
        tester,
      ) async {
        await openCard(tester, lang, CheckInSamples.card(lang), h: 6, m: 30);
        expect(_label(tester, 'check-in-$_id'), l10n.checkInFrom(t('6:45')));
        expect(
          tester.widget<BvButton>(_key('check-in-$_id')).onPressed,
          isNull,
        );
      });

      testWidgets('CI3 first time: the warning; Accept reads the location '
          'once and marks with it; the result says so; next time no '
          'warning', (tester) async {
        final app = await openCard(tester, lang, CheckInSamples.card(lang));
        await _tap(tester, _key('check-in-$_id'));
        expect(_key('check-in-warning'), findsOneWidget);
        expect(find.text(l10n.checkInWarnTitle), findsOneWidget);
        expect(find.text(l10n.checkInWarnBody), findsOneWidget);
        expect(app.location.reads, 0);
        await _tap(tester, _key('check-in-accept'));
        expect(app.location.reads, 1);
        final mark = app.checkIns.marks.single;
        expect(mark.kind, CheckInMarkKind.checkIn);
        expect(mark.lat, isNotNull);
        expect(
          find.text(
            l10n.checkInResultIn(
              t('7:00'),
              '${l10n.checkInOnTime} · ${l10n.checkInOnSite}',
            ),
          ),
          findsOneWidget,
        );
        expect(app.prefs.getBool(checkInConsentKey('user-1')), isTrue);
        await _tap(tester, _key('check-in-$_id'));
        expect(_key('check-in-warning'), findsNothing);
        expect(app.checkIns.marks, hasLength(2));
      });

      testWidgets('Check in without location: not shared, nothing read, and '
          'the warning comes back next time', (tester) async {
        final app = await openCard(tester, lang, CheckInSamples.card(lang));
        await _tap(tester, _key('check-in-$_id'));
        expect(
          tester.widget<BvButton>(_key('check-in-without')).label,
          l10n.checkInWithout,
        );
        await _tap(tester, _key('check-in-without'));
        expect(app.location.reads, 0);
        expect(app.checkIns.marks.single.lat, isNull);
        expect(app.checkIns.marks.single.lng, isNull);
        expect(app.prefs.getBool(checkInConsentKey('user-1')), isNull);
        await _tap(tester, _key('check-in-$_id'));
        expect(_key('check-in-warning'), findsOneWidget);
      });

      testWidgets('location turned off later: checked in without it, no '
          'error screen', (tester) async {
        final app = await openCard(
          tester,
          lang,
          CheckInSamples.card(lang),
          accepted: true,
          location: FakeLocationReader([
            const LocationRead.miss(LocationMiss.off),
          ]),
        );
        await _tap(tester, _key('check-in-$_id'));
        expect(_key('check-in-warning'), findsNothing);
        expect(app.checkIns.marks.single.lat, isNull);
        expect(find.text(l10n.errorGeneric), findsNothing);
      });

      testWidgets('the permission refused at the prompt: not shared', (
        tester,
      ) async {
        final app = await openCard(
          tester,
          lang,
          CheckInSamples.card(lang),
          location: FakeLocationReader([
            const LocationRead.miss(LocationMiss.refused),
          ]),
        );
        await _tap(tester, _key('check-in-$_id'));
        await _tap(tester, _key('check-in-accept'));
        expect(app.checkIns.marks.single.lat, isNull);
      });

      testWidgets('a refusal says why, in plain words', (tester) async {
        await openCard(
          tester,
          lang,
          CheckInSamples.card(lang),
          accepted: true,
          checkIns: FakeCheckInRepository()
            ..refuseMark = const SpaceException(
              SpaceFailure.badInput,
              'closed',
            ),
        );
        await _tap(tester, _key('check-in-$_id'));
        expect(find.text(l10n.checkInRefusedClosed), findsOneWidget);
      });

      testWidgets('✓ on time · on site; then Check out, off until 13:45', (
        tester,
      ) async {
        await openCard(
          tester,
          lang,
          CheckInSamples.card(lang, myIn: CheckInSamples.mark(6, 58)),
          h: 10,
        );
        expect(
          find.text(
            '${l10n.checkInIn(t('6:58'))} · ${l10n.checkInOnTime} · '
            '${l10n.checkInOnSite}',
          ),
          findsOneWidget,
        );
        expect(_label(tester, 'check-out-$_id'), l10n.checkOutFrom(t('13:45')));
        expect(
          tester.widget<BvButton>(_key('check-out-$_id')).onPressed,
          isNull,
        );
        expect(_key('check-in-$_id'), findsNothing);
      });

      testWidgets('check-out open: Check out marks Out', (tester) async {
        final app = await openCard(
          tester,
          lang,
          CheckInSamples.card(lang, myIn: CheckInSamples.mark(6, 58)),
          h: 14,
          accepted: true,
        );
        await _tap(tester, _key('check-out-$_id'));
        expect(app.checkIns.marks.single.kind, CheckInMarkKind.checkOut);
      });

      testWidgets('late (amber)', (tester) async {
        await openCard(
          tester,
          lang,
          CheckInSamples.card(
            lang,
            myIn: CheckInSamples.mark(7, 24, onTime: false),
          ),
          h: 8,
        );
        expect(
          find.text('${l10n.checkInIn(t('7:24'))} · ${l10n.checkInLate}'),
          findsOneWidget,
        );
      });

      testWidgets('not at site: Try again while check-in is open', (
        tester,
      ) async {
        final app = await openCard(
          tester,
          lang,
          CheckInSamples.card(
            lang,
            myIn: CheckInSamples.mark(7, 1, place: 'away'),
          ),
          h: 7,
          m: 5,
          accepted: true,
        );
        expect(
          find.text('${l10n.checkInIn(t('7:01'))} · ${l10n.checkInAway}'),
          findsOneWidget,
        );
        await _tap(tester, _key('check-in-again-$_id'));
        expect(app.checkIns.marks.single.kind, CheckInMarkKind.checkIn);
      });

      testWidgets('not at site after check-in closed: no Try again', (
        tester,
      ) async {
        await openCard(
          tester,
          lang,
          CheckInSamples.card(
            lang,
            myIn: CheckInSamples.mark(7, 1, place: 'away'),
          ),
          h: 14,
        );
        expect(_key('check-in-again-$_id'), findsNothing);
      });

      testWidgets('location not shared (grey)', (tester) async {
        await openCard(
          tester,
          lang,
          CheckInSamples.card(
            lang,
            myIn: CheckInSamples.mark(7, 3, place: 'not_shared'),
          ),
          h: 8,
        );
        expect(
          find.text('${l10n.checkInIn(t('7:03'))} · ${l10n.checkInNotShared}'),
          findsOneWidget,
        );
      });

      testWidgets('missed: no In once check-in closed', (tester) async {
        await openCard(tester, lang, CheckInSamples.card(lang), h: 14);
        expect(_key('check-in-missed-$_id'), findsOneWidget);
        expect(_key('check-in-$_id'), findsNothing);
      });

      testWidgets('Y5: no In, Check out is still offered in its window; '
          'In: missed', (tester) async {
        final app = await openCard(
          tester,
          lang,
          CheckInSamples.card(lang),
          h: 14,
          accepted: true,
        );
        expect(find.text(l10n.checkInInMissed), findsOneWidget);
        expect(_label(tester, 'check-out-$_id'), l10n.checkOutButton);
        await _tap(tester, _key('check-out-$_id'));
        expect(app.checkIns.marks.single.kind, CheckInMarkKind.checkOut);
        expect(find.text(l10n.checkInRefusedNotAllowed), findsNothing);
      });

      testWidgets('Y5: checked out without an In: In: missed plus the Out '
          'stamp', (tester) async {
        await openCard(
          tester,
          lang,
          CheckInSamples.card(lang, myOut: CheckInSamples.mark(14, 5)),
          h: 14,
          m: 10,
        );
        expect(find.text(l10n.checkInInMissed), findsOneWidget);
        expect(_key('check-in-stamp-out-$_id'), findsOneWidget);
        expect(_key('check-out-$_id'), findsNothing);
      });

      testWidgets('Y4: the reading’s accuracy and mock flag go with the '
          'mark', (tester) async {
        final app = await openCard(
          tester,
          lang,
          CheckInSamples.card(lang),
          accepted: true,
          location: FakeLocationReader([
            const LocationRead.point(29.37, 47.97, 12, mocked: true),
          ]),
        );
        await _tap(tester, _key('check-in-$_id'));
        expect(app.checkIns.marks.single.accuracy, 12);
        expect(app.checkIns.marks.single.mocked, isTrue);
      });

      testWidgets('Y4: too many tries says so', (tester) async {
        await openCard(
          tester,
          lang,
          CheckInSamples.card(lang),
          accepted: true,
          checkIns: FakeCheckInRepository()
            ..refuseMark = const SpaceException(
              SpaceFailure.badInput,
              'too many tries',
            ),
        );
        await _tap(tester, _key('check-in-$_id'));
        expect(find.text(l10n.checkInRefusedTooMany), findsOneWidget);
      });

      testWidgets('Y1: times show in the check-in’s own clock (tz), not the '
          'Space’s', (tester) async {
        // Dubai is an hour ahead of Kuwait.
        await openCard(
          tester,
          lang,
          CheckInSamples.card(lang, tz: 'Asia/Dubai'),
        );
        expect(_label(tester, 'check-in-$_id'), l10n.checkInBy(t('8:15')));
      });

      testWidgets('a past once-only check-in keeps its stamps and missed', (
        tester,
      ) async {
        await openCard(
          tester,
          lang,
          CheckInSamples.card(lang, daily: false, runs: false, missed: true),
        );
        expect(_key('check-in-missed-$_id'), findsOneWidget);
        expect(_key('check-in-$_id'), findsNothing);
      });

      testWidgets('not asked (another Team): no button and no list', (
        tester,
      ) async {
        await openCard(tester, lang, CheckInSamples.card(lang, asked: false));
        expect(_key('check-in-$_id'), findsNothing);
        expect(_key('check-in-list-$_id'), findsNothing);
      });

      testWidgets('its creator: Who checked in opens the list', (tester) async {
        await openCard(
          tester,
          lang,
          CheckInSamples.card(
            lang,
            authorId: DaybookSamples.islam,
            asked: false,
            seesList: true,
          ),
          pass: SpacePass.lead,
        );
        await _tap(tester, _key('check-in-list-$_id'));
        expect(_key('check-in-list-title'), findsOneWidget);
      });
    });
  }
}
