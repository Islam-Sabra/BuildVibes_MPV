// Review 109 CI1 (2729:39789 EN, 2729:39926 AR) and CI1b (2729:39857,
// 2729:39994): a Check-in in review 110's composer. # offers it to Leads
// only; its lines are For (Teams or the whole Space), Check-in (time and
// allowance, one choice) and Place (Set place here, read once); + offers
// exactly Check-out and Every day, each a chip with ×; the bar has no
// camera; Send stays off until the place is set; hold Send for Post
// later. In English and Arabic.
import 'package:buildvibes/data/models/check_in.dart';
import 'package:buildvibes/core/location/location_reader.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/repositories/schedule_repository.dart';
import 'package:buildvibes/features/work/composer_check_in.dart';
import 'package:buildvibes/features/work/daybook_composer.dart';
import 'package:buildvibes/features/work/daybook_draft.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_writing_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/check_in_fakes.dart';
import '../../helpers/composer_steps.dart';
import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/later_fakes.dart';
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

final _now = DaybookSamples.thursday;

/// Islam (a Lead and the admin, or another [pass]) writing in the sample
/// Space, the composer open on [kind].
Future<TestApp> openComposer(
  WidgetTester tester,
  String lang, {
  String kind = 'check_in',
  SpacePass pass = SpacePass.lead,
  bool admin = true,
  FakeLocationReader? location,
  FakeScheduleRepository? schedule,
  FakeCheckInRepository? checkIns,
}) async {
  final s = DaybookSamples(lang);
  final app = await pumpApp(
    tester,
    language: lang,
    composerKind: kind,
    spaces: FakeSpaceRepository()
      ..details[DaybookSamples.space] = s.detail(pass: pass, admin: admin)
      ..spacePeople[DaybookSamples.space] = s.people(),
    daybook: FakeDaybookRepository()..posts[DaybookSamples.space] = s.d1(),
    location: location,
    schedule: schedule,
    checkIns: checkIns,
    now: _now,
    overrides: [
      pickCheckInClockProvider.overrideWithValue(
        (context, {required initial, required title}) async =>
            const TimeOfDay(hour: 7, minute: 0),
      ),
    ],
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/${DaybookSamples.space}');
  await tester.pumpAndSettle();
  await _tap(tester, _key('post-bar-notepad'));
  return app;
}

/// Title, 7:00 · 15 min, and the place set: ready to send.
Future<void> fillReady(WidgetTester tester, String title) async {
  await tester.enterText(_key('writing-title'), title);
  await tester.pumpAndSettle();
  await _tap(tester, _key('writing-check-in-time'));
  await _tap(tester, _key('check-in-sheet-time'));
  await _tap(tester, _key('check-in-allow-15'));
  await _tap(tester, _key('check-in-sheet-done'));
  await _tap(tester, _key('writing-check-in-place'));
}

void main() {
  test('W11: Check-in is for Leads and the Space admin only; a Crew '
      'member’s last kind never opens on it', () async {
    final s = DaybookSamples('en');
    expect(composerKindsFor(s.detail()), contains(DaybookKind.checkIn));
    expect(
      composerKindsFor(s.detail(pass: SpacePass.lead, admin: false)),
      contains(DaybookKind.checkIn),
    );
    final crew = composerKindsFor(
      s.detail(pass: SpacePass.crew, admin: false),
    );
    expect(crew, isNot(contains(DaybookKind.checkIn)));
    expect(crew, contains(DaybookKind.workItem));
    expect(
      composerKindsFor(s.detail(pass: SpacePass.viewer, admin: false)),
      const [DaybookKind.thanks],
    );
    SharedPreferences.setMockInitialValues({
      composerKindKey('s1'): 'check_in',
    });
    final prefs = await SharedPreferences.getInstance();
    expect(composerStartKind(prefs, 's1', crew), DaybookKind.note);
    expect(
      composerStartKind(prefs, 's1', composerKindsFor(s.detail())),
      DaybookKind.checkIn,
    );
  });

  test('a draft keeps its Check-in, and needs its time and its place', () {
    const draft = DaybookPostDraft(
      id: 'p1',
      kind: DaybookKind.checkIn,
      title: 'Morning, Block B',
      checkInTeams: [(id: 't-mep', name: 'MEP')],
      inTime: DayTime(7, 0),
      inAllow: 10,
      outTime: DayTime(15, 0),
      outAllow: 15,
      daily: true,
      siteLat: 29.3759,
      siteLng: 47.9774,
    );
    final back = DaybookPostDraft.fromJson(draft.toJson());
    expect(back.kind, DaybookKind.checkIn);
    expect(back.checkInTeams.single.id, 't-mep');
    expect(back.inTime, const DayTime(7, 0));
    expect(back.inAllow, 10);
    expect(back.outTime, const DayTime(15, 0));
    expect(back.outAllow, 15);
    expect(back.daily, isTrue);
    expect(back.siteSet, isTrue);
    expect(back.canPost(_now), isTrue);
    expect(
      const DaybookPostDraft(id: 'p', kind: DaybookKind.checkIn, title: 'x')
          .readyToTry,
      isFalse,
    );
    expect(
      const DaybookPostDraft(
        id: 'p',
        kind: DaybookKind.checkIn,
        title: 'x',
        siteLat: 1,
        siteLng: 2,
      ).missing(_now),
      DaybookMissing.checkInTime,
    );
    expect(composerExtras(DaybookKind.checkIn), const [
      ComposerExtra.checkOut,
      ComposerExtra.everyDay,
    ]);
    // Another kind takes its times and place away, and says so.
    final drops = composerDrops(draft, DaybookKind.note);
    expect(drops, contains(ComposerDrop.checkIn));
    final note = composerSwitched(draft, DaybookKind.note, drops);
    expect(note.siteSet, isFalse);
    expect(note.inTime, isNull);
    expect(note.daily, isFalse);
  });

  test('a Check-in is one of the calls Post later keeps', () {
    expect(ScheduledCall.checkIn, 'post_check_in');
  });

  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    final s = DaybookSamples(lang);

    group('CI1 a Check-in [$lang]', () {
      testWidgets('# offers Check-in to a Lead, not to Crew', (tester) async {
        await openComposer(tester, lang, kind: 'note');
        await _tap(tester, _key('writing-kind'));
        expect(
          find.descendant(
            of: _key('composer-kind-check_in'),
            matching: find.text(l10n.daybookKindCheckIn),
          ),
          findsOneWidget,
        );
      });

      testWidgets('Crew never sees the Check-in tile', (tester) async {
        await openComposer(
          tester,
          lang,
          kind: 'note',
          pass: SpacePass.crew,
          admin: false,
        );
        await _tap(tester, _key('writing-kind'));
        expect(_key('composer-kind-note'), findsOneWidget);
        expect(_key('composer-kind-check_in'), findsNothing);
      });

      testWidgets('top "New check-in" and the Space; title, Details '
          '(optional); For · Check-in · Place; # · + · Send, no camera; + '
          'offers exactly Check-out and Every day', (tester) async {
        await openComposer(tester, lang);
        expect(
          find.descendant(
            of: _key('composer-top'),
            matching: find.text(l10n.cpNewCheckIn),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: _key('composer-top'),
            matching: find.textContaining(s.spaceName),
          ),
          findsOneWidget,
        );
        expect(
          tester.widget<TextField>(_key('writing-body')).decoration?.hintText,
          l10n.cpDetails,
        );
        expect(
          find.descendant(
            of: _key('writing-check-in-for'),
            matching: find.text(l10n.daybookWholeSpace),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: _key('writing-check-in-place'),
            matching: find.text(l10n.checkInSetPlace),
          ),
          findsOneWidget,
        );
        expect(_key('writing-check-in-time'), findsOneWidget);
        expect(_key('writing-camera'), findsNothing);
        expect(_key('writing-kind'), findsOneWidget);
        expect(_key('writing-add'), findsOneWidget);
        await _tap(tester, _key('writing-add'));
        expect(
          find.descendant(
            of: _key('composer-extras'),
            matching: find.text(l10n.cpAddCheckIn),
          ),
          findsOneWidget,
        );
        final shown = {
          for (final e in ComposerExtra.values)
            if (_key('composer-extra-${e.key}').evaluate().isNotEmpty) e.key,
        };
        expect(shown, {'check_out', 'every_day'});
      });

      testWidgets('Send stays off until the place is set; Set place here '
          'reads the location once', (tester) async {
        final location = FakeLocationReader();
        await openComposer(tester, lang, location: location);
        await tester.enterText(_key('writing-title'), 'Morning, Block B');
        await tester.pumpAndSettle();
        await _tap(tester, _key('writing-check-in-time'));
        await _tap(tester, _key('check-in-sheet-time'));
        await _tap(tester, _key('check-in-sheet-done'));
        var bar = tester.widget<BvWritingToolbar>(find.byType(BvWritingToolbar));
        expect(bar.onPost, isNull);
        expect(location.reads, 0);
        await _tap(tester, _key('writing-check-in-place'));
        expect(location.reads, 1);
        expect(
          find.descendant(
            of: _key('writing-check-in-place'),
            matching: find.text(l10n.checkInPlaceSet),
          ),
          findsOneWidget,
        );
        bar = tester.widget<BvWritingToolbar>(find.byType(BvWritingToolbar));
        expect(bar.onPost, isNotNull);
        expect(bar.postReady, isTrue);
      });

      testWidgets('the location refused: nothing is set, and it says why', (
        tester,
      ) async {
        await openComposer(
          tester,
          lang,
          location: FakeLocationReader([
            const LocationRead.miss(LocationMiss.refused),
          ]),
        );
        await _tap(tester, _key('writing-check-in-place'));
        expect(find.text(l10n.checkInPlaceRefused), findsOneWidget);
        expect(composerDraft(tester)?.siteSet, isFalse);
      });

      testWidgets('Check-in: the time, and the allowance as one choice '
          '(0 · 10 · 15 · 30 min)', (tester) async {
        await openComposer(tester, lang);
        await _tap(tester, _key('writing-check-in-time'));
        expect(_key('check-in-sheet'), findsOneWidget);
        for (final m in checkInAllowances) {
          expect(_key('check-in-allow-$m'), findsOneWidget);
        }
        await _tap(tester, _key('check-in-sheet-time'));
        await _tap(tester, _key('check-in-allow-30'));
        await _tap(tester, _key('check-in-sheet-done'));
        expect(composerDraft(tester)?.inTime, const DayTime(7, 0));
        expect(composerDraft(tester)?.inAllow, 30);
        expect(
          find.descendant(
            of: _key('writing-check-in-time'),
            matching: find.textContaining(
              l10n.checkInTimeAllow('', 30).trim().split(' ').last,
            ),
          ),
          findsOneWidget,
        );
      });

      testWidgets('For: the Teams, more than one, or the whole Space', (
        tester,
      ) async {
        await openComposer(tester, lang);
        await _tap(tester, _key('writing-check-in-for'));
        expect(_key('check-in-teams-sheet'), findsOneWidget);
        await _tap(tester, _key('check-in-team-t-mep'));
        await _tap(tester, _key('check-in-team-t-site'));
        await _tap(tester, _key('check-in-teams-done'));
        expect(composerDraft(tester)?.checkInTeams.map((t) => t.id), [
          't-mep',
          't-site',
        ]);
        expect(
          find.descendant(
            of: _key('writing-check-in-for'),
            matching: find.text(
              l10n.checkInTeamsJoin(
                s.t('MEP', 'الكهروميكانيك'),
                s.t('Site', 'الموقع'),
              ),
            ),
          ),
          findsOneWidget,
        );
        await _tap(tester, _key('writing-check-in-for'));
        await _tap(tester, _key('check-in-team-all'));
        await _tap(tester, _key('check-in-teams-done'));
        expect(composerDraft(tester)?.checkInTeams, isEmpty);
      });

      testWidgets('CI1b: Check-out and Every day show as chips with ×', (
        tester,
      ) async {
        await openComposer(tester, lang);
        await addExtra(tester, 'check_out');
        expect(_key('check-out-sheet'), findsOneWidget);
        await _tap(tester, _key('check-in-sheet-time'));
        await _tap(tester, _key('check-in-allow-10'));
        await _tap(tester, _key('check-in-sheet-done'));
        expect(_key('writing-check-out-chip'), findsOneWidget);
        expect(composerDraft(tester)?.outAllow, 10);
        await addExtra(tester, 'every_day');
        expect(_key('writing-every-day-chip'), findsOneWidget);
        expect(composerDraft(tester)?.daily, isTrue);
        await _tap(tester, _key('writing-check-out-chip-clear'));
        await _tap(tester, _key('writing-every-day-chip-clear'));
        expect(_key('writing-check-out-chip'), findsNothing);
        expect(_key('writing-every-day-chip'), findsNothing);
        expect(composerDraft(tester)?.outTime, isNull);
        expect(composerDraft(tester)?.daily, isFalse);
      });

      testWidgets('Send posts post_check_in with the site, times and Teams', (
        tester,
      ) async {
        final app = await openComposer(tester, lang);
        await fillReady(tester, 'Morning, Block B');
        await _tap(tester, _key('writing-check-in-for'));
        await _tap(tester, _key('check-in-team-t-mep'));
        await _tap(tester, _key('check-in-teams-done'));
        await addExtra(tester, 'every_day');
        await _tap(tester, _key('writing-post'));
        expect(_key('composer'), findsNothing);
        final sent = app.checkIns.posted.single;
        expect(sent.title, 'Morning, Block B');
        expect(sent.teamIds, ['t-mep']);
        expect(sent.inTime, const DayTime(7, 0));
        expect(sent.inAllow, 15);
        expect(sent.outTime, isNull);
        expect(sent.daily, isTrue);
        expect(sent.siteLat, 29.3759);
        expect(sent.siteLng, 47.9774);
      });

      testWidgets('with no time, Send asks for it first', (tester) async {
        final app = await openComposer(tester, lang);
        await tester.enterText(_key('writing-title'), 'Morning');
        await tester.pumpAndSettle();
        await _tap(tester, _key('writing-check-in-place'));
        await _tap(tester, _key('writing-post'));
        expect(_key('check-in-sheet'), findsOneWidget);
        expect(app.checkIns.posted, isEmpty);
      });

      testWidgets('hold Send = Post later: post_check_in through '
          'schedule_post, nothing now', (tester) async {
        final schedule = FakeScheduleRepository();
        final app = await openComposer(tester, lang, schedule: schedule);
        await fillReady(tester, 'Morning, Block B');
        await openPostLater(tester);
        await _tap(tester, _key('later-schedule'));
        final sent = schedule.scheduled.single;
        expect(sent.call, ScheduledCall.checkIn);
        expect(sent.params['p_in_time'], '07:00');
        expect(sent.params['p_site_lat'], 29.3759);
        expect(sent.params['p_teams'], isNull);
        expect(app.checkIns.posted, isEmpty);
      });
    });
  }
}
