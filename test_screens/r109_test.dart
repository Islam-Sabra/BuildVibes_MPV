// Review 109: Check-in. In English and Arabic at 390 × 844 in the app's
// fonts. CI1 the composer (2729:39789 / 2729:39926) and its pickers; CI1b
// + (2729:39857 / 2729:39994); CI3 the warning (2706:39486 / 2706:39815);
// CI4 the person's card in each state (2706:39534 / 2706:39863); CI5 the
// creator's list (2706:39604 / 2706:39933). CI2 is the phone's own
// notification, not drawn by the app's widgets. Run:
//   flutter test test_screens/r109_test.dart --update-goldens
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/work/check_in_marking.dart'
    show checkInConsentKey;
import 'package:buildvibes/features/work/composer_check_in.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../test/helpers/check_in_fakes.dart';
import '../test/helpers/check_in_samples.dart';
import '../test/helpers/daybook_fakes.dart';
import '../test/helpers/daybook_samples.dart';
import '../test/helpers/pump_app.dart';
import '../test/helpers/space_fakes.dart';
import 'shot.dart';

/// Saves the app as it is now to `docs/screens/r109/<name>_<lang>.png`.
Future<void> _snap(WidgetTester tester, String name, String lang) async {
  debugDisableShadows = false;
  try {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byType(MaterialApp).first,
      matchesGoldenFile('../docs/screens/r109/${name}_$lang.png'),
    );
  } finally {
    debugDisableShadows = true;
  }
}

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  for (final lang in ['en', 'ar']) {
    final s = DaybookSamples(lang);
    final title = s.t('Morning, Block B', 'صباح المبنى B');

    /// Islam (Lead) writing a Check-in.
    Future<void> compose(WidgetTester tester, {bool titled = true}) async {
      await pumpApp(
        tester,
        language: lang,
        composerKind: 'check_in',
        spaces: FakeSpaceRepository()
          ..details[DaybookSamples.space] = s.detail(
            timeZone: CheckInSamples.zone,
          )
          ..spacePeople[DaybookSamples.space] = s.people(),
        daybook: FakeDaybookRepository()..posts[DaybookSamples.space] = s.d1(),
        now: CheckInSamples.at(6, 10),
        overrides: [
          pickCheckInClockProvider.overrideWithValue(
            (context, {required initial, required title}) async =>
                // 7:00 for check-in; check-out at 15:00, as the prototype.
                title == lookupAppLocalizations(Locale(lang)).checkOutTimeHelp
                ? const TimeOfDay(hour: 15, minute: 0)
                : const TimeOfDay(hour: 7, minute: 0),
          ),
        ],
      );
      GoRouter.of(
        tester.element(find.byType(Navigator).first),
      ).push('/spaces/${DaybookSamples.space}');
      await tester.pumpAndSettle();
      await _tap(tester, _key('post-bar-notepad'));
      if (titled) {
        await tester.enterText(_key('writing-title'), title);
        await tester.pumpAndSettle();
      }
      await _tap(tester, _key('writing-check-in-for'));
      await _tap(tester, _key('check-in-team-t-mep'));
      await _tap(tester, _key('check-in-team-t-site'));
      await _tap(tester, _key('check-in-teams-done'));
      await _tap(tester, _key('writing-check-in-time'));
      await _tap(tester, _key('check-in-sheet-time'));
      await _tap(tester, _key('check-in-sheet-done'));
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
    }

    testWidgets('CI1 the composer: For · Check-in · Set place here [$lang]', (
      tester,
    ) async {
      await compose(tester);
      await _snap(tester, 'CI1-composer', lang);
    });

    testWidgets('CI1b + offers Check-out and Every day [$lang]', (
      tester,
    ) async {
      await compose(tester);
      await _tap(tester, _key('writing-add'));
      await _snap(tester, 'CI1b-plus', lang);
    });

    testWidgets('CI1 the For picker: Teams, more than one [$lang]', (
      tester,
    ) async {
      await compose(tester);
      await _tap(tester, _key('writing-check-in-for'));
      await _snap(tester, 'CI1-for-picker', lang);
    });

    testWidgets('CI1 Check-in: the time and the allowance [$lang]', (
      tester,
    ) async {
      await compose(tester);
      await _tap(tester, _key('writing-check-in-time'));
      await _snap(tester, 'CI1-allowance', lang);
    });

    testWidgets('Y10 the allowance at 10 minutes [$lang]', (tester) async {
      await compose(tester);
      await _tap(tester, _key('writing-check-in-time'));
      await _tap(tester, _key('check-in-allow-10'));
      await _tap(tester, _key('check-in-sheet-done'));
      await _snap(tester, 'Y10-allowance-10', lang);
    });

    testWidgets('CI1 the place set; Send on [$lang]', (tester) async {
      await compose(tester);
      await _tap(tester, _key('writing-check-in-place'));
      await _snap(tester, 'CI1-place-set', lang);
    });

    testWidgets('CI1 Check-out and Every day as chips [$lang]', (tester) async {
      await compose(tester);
      await _tap(tester, _key('writing-check-in-place'));
      await _tap(tester, _key('writing-add'));
      await _tap(tester, _key('composer-extra-check_out'));
      await _tap(tester, _key('check-in-sheet-time'));
      await _tap(tester, _key('check-in-sheet-done'));
      await _tap(tester, _key('writing-add'));
      await _tap(tester, _key('composer-extra-every_day'));
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await _snap(tester, 'CI1-chips', lang);
    });

    /// Islam (Crew, or the creator) on Work with [card], at [h]:[m].
    Future<void> work(
      WidgetTester tester,
      DaybookCard card, {
      int h = 7,
      int m = 0,
      SpacePass pass = SpacePass.crew,
      FakeCheckInRepository? checkIns,
      bool accepted = false,
    }) async {
      await pumpApp(
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
        checkIns: checkIns,
        stored: {if (accepted) checkInConsentKey('user-1'): true},
      );
      GoRouter.of(
        tester.element(find.byType(Navigator).first),
      ).push('/spaces/${DaybookSamples.space}');
      await tester.pumpAndSettle();
    }

    testWidgets('CI4 open: Check in by 7:15 [$lang]', (tester) async {
      await work(tester, CheckInSamples.card(lang));
      await _snap(tester, 'CI4-open', lang);
    });

    testWidgets('CI3 the first-time warning [$lang]', (tester) async {
      await work(tester, CheckInSamples.card(lang));
      await _tap(tester, _key('check-in-${CheckInSamples.id}'));
      await _snap(tester, 'CI3-warning', lang);
    });

    testWidgets('CI4 on time · on site; Check out from 13:45 [$lang]', (
      tester,
    ) async {
      await work(
        tester,
        CheckInSamples.card(lang, myIn: CheckInSamples.mark(6, 58)),
        h: 10,
      );
      await _snap(tester, 'CI4-on-time', lang);
    });

    testWidgets('CI4 late [$lang]', (tester) async {
      await work(
        tester,
        CheckInSamples.card(
          lang,
          myIn: CheckInSamples.mark(7, 24, onTime: false),
        ),
        h: 8,
      );
      await _snap(tester, 'CI4-late', lang);
    });

    testWidgets('CI4 not at site, Try again [$lang]', (tester) async {
      await work(
        tester,
        CheckInSamples.card(
          lang,
          myIn: CheckInSamples.mark(7, 1, place: 'away'),
        ),
        h: 7,
        m: 5,
      );
      await _snap(tester, 'CI4-not-at-site', lang);
    });

    testWidgets('CI4 location not shared [$lang]', (tester) async {
      await work(
        tester,
        CheckInSamples.card(
          lang,
          myIn: CheckInSamples.mark(7, 3, place: 'not_shared'),
        ),
        h: 8,
      );
      await _snap(tester, 'CI4-not-shared', lang);
    });

    testWidgets('CI4 checked out [$lang]', (tester) async {
      await work(
        tester,
        CheckInSamples.card(
          lang,
          myIn: CheckInSamples.mark(6, 58),
          myOut: CheckInSamples.mark(14, 5),
        ),
        h: 14,
        m: 10,
      );
      await _snap(tester, 'CI4-checked-out', lang);
    });

    testWidgets('CI4 missed [$lang]', (tester) async {
      await work(tester, CheckInSamples.card(lang), h: 14);
      await _snap(tester, 'CI4-missed', lang);
    });

    testWidgets('Y5 checked out without an In: In: missed + Out [$lang]', (
      tester,
    ) async {
      await work(
        tester,
        CheckInSamples.card(lang, myOut: CheckInSamples.mark(14, 5)),
        h: 14,
        m: 10,
      );
      await _snap(tester, 'Y5-out-without-in', lang);
    });

    testWidgets('Y4 too many tries [$lang]', (tester) async {
      await work(
        tester,
        CheckInSamples.card(lang),
        accepted: true,
        checkIns: FakeCheckInRepository()
          ..refuseMark = const SpaceException(
            SpaceFailure.badInput,
            'too many tries',
          ),
      );
      await _tap(tester, _key('check-in-${CheckInSamples.id}'));
      await _snap(tester, 'Y4-too-many', lang);
    });

    /// The creator's list.
    Future<void> list(WidgetTester tester) async {
      await pumpApp(
        tester,
        language: lang,
        spaces: FakeSpaceRepository()
          ..details[DaybookSamples.space] = s.detail(
            timeZone: CheckInSamples.zone,
          )
          ..spacePeople[DaybookSamples.space] = s.people(),
        daybook: FakeDaybookRepository()
          ..posts[DaybookSamples.space] = [
            CheckInSamples.card(
              lang,
              authorId: DaybookSamples.islam,
              asked: false,
              seesList: true,
              canStop: true,
            ),
          ],
        checkIns: FakeCheckInRepository()
          ..lines['2026-10-15'] = CheckInSamples.lines(lang)
          ..dayList = [
            DateTime(2026, 10, 15),
            DateTime(2026, 10, 14),
            DateTime(2026, 10, 13),
          ],
        now: CheckInSamples.at(16, 0),
      );
      GoRouter.of(
        tester.element(find.byType(Navigator).first),
      ).push('/spaces/${DaybookSamples.space}/check-ins/${CheckInSamples.id}');
      await tester.pumpAndSettle();
    }

    testWidgets('CI4 the creator’s card: Who checked in [$lang]', (
      tester,
    ) async {
      await work(
        tester,
        CheckInSamples.card(
          lang,
          authorId: DaybookSamples.islam,
          asked: false,
          seesList: true,
          canStop: true,
        ),
        h: 16,
        pass: SpacePass.lead,
      );
      await _snap(tester, 'CI4-creator', lang);
    });

    testWidgets('CI5 the creator’s list [$lang]', (tester) async {
      await list(tester);
      await _snap(tester, 'CI5-list', lang);
    });

    testWidgets('CI5 the day picker [$lang]', (tester) async {
      await list(tester);
      await _tap(tester, _key('check-in-list-day'));
      await _snap(tester, 'CI5-day-picker', lang);
    });

    testWidgets('CI5 ⋯ → Stop, the confirmation [$lang]', (tester) async {
      await list(tester);
      await _tap(tester, _key('check-in-list-more'));
      await _tap(tester, _key('check-in-stop'));
      await _snap(tester, 'CI5-stop-confirm', lang);
    });
  }
}
