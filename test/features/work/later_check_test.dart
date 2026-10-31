// Review 108, the lead's check of claude/r108 (V2, V3, V4, V6, V7, V8), in
// English and Arabic:
// V2 a failed post is cleared: Post now tries it again, Cancel removes it
//    (and the Profile clock goes); no Edit on it.
// V3 one clock and one calendar per place: in a Space, Post later and the
//    reminder's Pick… are in the Space's time zone, with the Space's market
//    weekend; in the Feed, the phone's zone and my own market.
// V4 20 reminders a day: "You've set the most reminders for today".
// V6 the Who row has full names.
// V7 the clock on a work item with a Space place says why it can't go.
// V8 one put in from My notebook takes its note with it.
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/repositories/schedule_repository.dart';
import 'package:buildvibes/features/work/daybook_writing.dart';
import 'package:buildvibes/features/work/space_day.dart';
import 'package:buildvibes/features/work/work_outbox.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_give_to_picker.dart';
import 'package:buildvibes/shared/widgets/bv_slip.dart';
import 'package:buildvibes/shared/widgets/bv_writing_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_rows.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/fakes.dart';
import '../../helpers/later_fakes.dart';
import '../../helpers/post_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Navigator).first));

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(Navigator).first));

/// Thursday 15 October 2026, 10:30 on the phone.
final _now = DaybookSamples.thursday;

/// Far from any phone running the tests: the Space's own clock.
const _zone = 'Pacific/Kiritimati';

/// A market whose weekend is Saturday and Sunday (0 is Sunday).
final _satSun = marketWith(id: 'xs', weekend: [6, 0]);

const _place = SpacePlace(id: 'place-l3', name: 'Level 3 core');

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    final s = DaybookSamples(lang);

    /// Islam (Lead) in a Space whose clock is [_zone] and whose market's
    /// weekend is Saturday and Sunday; his own market is Kuwait (Fri, Sat).
    Future<TestApp> space(
      WidgetTester tester, {
      List<DaybookCard>? posts,
      FakeWorkReminderRepository? reminders,
      FakeScheduleRepository? schedule,
    }) async {
      final app = await pumpApp(
        tester,
        language: lang,
        spaces: FakeSpaceRepository()
          ..details[DaybookSamples.space] = s.detail(
            timeZone: _zone,
            marketId: _satSun.id,
          )
          ..spacePeople[DaybookSamples.space] = s.people(),
        daybook: FakeDaybookRepository()
          ..posts[DaybookSamples.space] = posts ?? s.d1()
          ..placesBySpace[DaybookSamples.space] = [_place],
        workReminders: reminders,
        schedule: schedule,
        markets: [...testMarkets, _satSun],
        now: _now,
        overrides: [
          pickDueProvider.overrideWithValue(
            (context, {required now, day, at}) async =>
                (day: DateTime(2026, 10, 20), at: DateTime(2026, 10, 20, 9)),
          ),
        ],
      );
      _router(tester).push('/spaces/${DaybookSamples.space}');
      await tester.pumpAndSettle();
      return app;
    }

    Future<void> writeItem(WidgetTester tester) async {
      await _tap(tester, _key('post-bar-notepad'));
      await tester.enterText(
        _key('writing-title'),
        s.t('Morning brief: pour at level 3', 'إحاطة الصباح: صب الطابق 3'),
      );
      await tester.pumpAndSettle();
      await _tap(tester, _key('writing-who'));
      await _tap(
        tester,
        find.descendant(
          of: find.byType(BvGiveToPicker),
          matching: find.text(s.omarName),
        ),
      );
    }

    group('V3 one clock and one calendar per place [$lang]', () {
      testWidgets('Post later in a Space: the Space\'s 7:00 and its market\'s '
          'next working day (Monday, after a Sat-Sun weekend)', (tester) async {
        final app = await space(tester);
        await writeItem(tester);
        await _tap(tester, _key('writing-later'));
        final words = lookupAppLocalizations(Locale(lang));
        expect(
          find.descendant(
            of: _key('later-workday'),
            matching: find.textContaining(lang == 'en' ? 'Monday' : 'الاثنين'),
          ),
          findsOneWidget,
          reason: words.plTitle,
        );
        await _tap(tester, _key('later-tomorrow'));
        await _tap(tester, _key('later-schedule'));
        final at = app.schedule.scheduled.single.at;
        expect(at, spaceTimeOn(_zone, _now, days: 1, hour: 7));
        expect(at, isNot(DateTime(2026, 10, 16, 7)));
      });

      testWidgets('Pick… in a Space is the Space\'s wall clock', (
        tester,
      ) async {
        final app = await space(tester);
        await writeItem(tester);
        await _tap(tester, _key('writing-later'));
        await _tap(tester, _key('later-pick'));
        await _tap(tester, _key('later-schedule'));
        expect(
          app.schedule.scheduled.single.at,
          spaceTimeAt(_zone, DateTime(2026, 10, 20, 9)),
        );
      });

      testWidgets('the Feed: the phone\'s 7:00 and my own market (Sunday)', (
        tester,
      ) async {
        final app = await pumpApp(
          tester,
          language: lang,
          posts: FakePostRepository(),
          markets: [...testMarkets, _satSun],
          now: _now,
        );
        await tester.pumpAndSettle();
        await _tap(tester, _key('nav-create'));
        await _tap(tester, _key('create-post'));
        await tester.enterText(
          _key('writing-body'),
          s.t('Level 3 slab done', 'بلاطة الطابق 3 منجزة'),
        );
        await tester.pumpAndSettle();
        await _tap(tester, _key('writing-later'));
        await _tap(tester, _key('later-workday'));
        await _tap(tester, _key('later-schedule'));
        expect(app.schedule.scheduled.single.at, DateTime(2026, 10, 18, 7));
      });

      testWidgets('the reminder\'s Pick… for someone is the Space\'s', (
        tester,
      ) async {
        final app = await space(
          tester,
          posts: [
            s.card(
              s.item(
                id: 'post-formwork',
                at: _now.subtract(const Duration(hours: 2)),
                title: s.t('Formwork check, level 3', 'فحص القوالب، الطابق 3'),
                authorId: DaybookSamples.islam,
                ownerId: DaybookSamples.omar,
              ),
            ),
          ],
        );
        final card = _key('daybook-card-post-formwork');
        await scrollToRow(tester, card);
        await tester.drag(
          find.descendant(of: card, matching: find.byType(BvSlip)).first,
          Offset(lang == 'ar' ? -160 : 160, 0),
        );
        await tester.pumpAndSettle();
        await _tap(tester, _key('swipe-remind-post-formwork'));
        await _tap(tester, _key('reminder-someone'));
        await _tap(tester, _key('reminder-pick'));
        await _tap(tester, _key('reminder-set'));
        expect(
          app.workReminders.sets.single.at,
          spaceTimeAt(_zone, DateTime(2026, 10, 20, 9)),
        );
      });
    });

    group('V4, V6 the reminder sheet [$lang]', () {
      Future<void> openSomeone(WidgetTester tester) async {
        final card = _key('daybook-card-post-formwork');
        await scrollToRow(tester, card);
        await tester.drag(
          find.descendant(of: card, matching: find.byType(BvSlip)).first,
          Offset(lang == 'ar' ? -160 : 160, 0),
        );
        await tester.pumpAndSettle();
        await _tap(tester, _key('swipe-remind-post-formwork'));
        await _tap(tester, _key('reminder-someone'));
      }

      List<DaybookCard> formwork() => [
        s.card(
          s.item(
            id: 'post-formwork',
            at: _now.subtract(const Duration(hours: 2)),
            title: s.t('Formwork check, level 3', 'فحص القوالب، الطابق 3'),
            authorId: DaybookSamples.islam,
            ownerId: DaybookSamples.omar,
          ),
        ),
      ];

      testWidgets('V4: the 21st today says so', (tester) async {
        await space(
          tester,
          posts: formwork(),
          reminders: FakeWorkReminderRepository()..failure = SpaceFailure.limit,
        );
        await openSomeone(tester);
        await _tap(tester, _key('reminder-set'));
        expect(
          tester.widget<Text>(_key('reminder-error')).data,
          l10n.rmDailyMost,
        );
        expect(_key('reminder-sheet'), findsOneWidget);
      });

      testWidgets('V6: Who shows each person\'s full name', (tester) async {
        await space(tester, posts: formwork());
        await openSomeone(tester);
        await _tap(tester, _key('reminder-who'));
        await _tap(tester, _key('reminder-person-${DaybookSamples.rakesh}'));
        await _tap(tester, _key('reminder-who-done'));
        expect(
          find.descendant(
            of: _key('reminder-who'),
            matching: find.textContaining(s.rakeshName),
          ),
          findsOneWidget,
        );
      });
    });

    group('V7 a work item with a place from the list [$lang]', () {
      testWidgets('the clock is grey and says why it can\'t be scheduled', (
        tester,
      ) async {
        final app = await space(tester);
        await writeItem(tester);
        await _tap(tester, _key('writing-place-row'));
        await _tap(tester, _key('place-row-${_place.id}'));
        final bar = tester.widget<BvWritingToolbar>(
          find.byType(BvWritingToolbar),
        );
        expect(bar.laterReady, isFalse);
        await _tap(tester, _key('writing-later'));
        expect(_key('later-sheet'), findsNothing);
        expect(find.text(l10n.plCantYet), findsOneWidget);
        expect(app.schedule.scheduled, isEmpty);
      });
    });

    group('V2 a failed post is cleared [$lang]', () {
      FakeScheduleRepository failed() => FakeScheduleRepository()
        ..posts.add(
          ScheduledPost(
            id: 'sch-3',
            title: s.t('Morning brief', 'إحاطة الصباح'),
            publishAt: DateTime(2026, 10, 15, 7),
            state: ScheduledState.failed,
            error: 'not_allowed',
            spaceId: DaybookSamples.space,
            spaceName: s.spaceName,
          ),
        );

      testWidgets('Post now tries it again; no Edit on it', (tester) async {
        final schedule = failed();
        await pumpApp(tester, language: lang, schedule: schedule, now: _now);
        _router(tester).push('/scheduled-posts');
        await tester.pumpAndSettle();
        expect(_key('scheduled-edit-sch-3'), findsNothing);
        await _tap(tester, _key('scheduled-post-now-sch-3'));
        expect(schedule.postedNow, ['sch-3']);
        expect(_key('scheduled-sch-3'), findsNothing);
      });

      testWidgets('Cancel removes it, and the Profile clock goes', (
        tester,
      ) async {
        final schedule = failed();
        await pumpApp(tester, language: lang, schedule: schedule, now: _now);
        _router(tester).go('/profile');
        await tester.pumpAndSettle();
        await _tap(tester, _key('profile-scheduled'));
        await _tap(tester, _key('scheduled-cancel-sch-3'));
        expect(schedule.cancelled, ['sch-3']);
        _router(tester).pop();
        await tester.pumpAndSettle();
        expect(_key('profile-scheduled'), findsNothing);
      });
    });

    group('V8 from My notebook [$lang]', () {
      testWidgets('a scheduled post takes its note with it', (tester) async {
        final app = await pumpApp(
          tester,
          language: lang,
          spaces: FakeSpaceRepository()
            ..details[DaybookSamples.space] = s.detail()
            ..spacePeople[DaybookSamples.space] = s.people(),
          now: _now,
        );
        await _container(tester)
            .read(workOutboxProvider.notifier)
            .send(
              PendingItem(
                kind: PendingKind.workItem,
                id: 'post-from-note',
                spaceId: DaybookSamples.space,
                title: s.t('Seal the riser', 'إغلاق الرايزر'),
                ownerId: DaybookSamples.omar,
                ownerName: s.omarName,
                noteId: 'note-riser',
                scheduleAt: DateTime(2026, 10, 16, 7),
              ),
            );
        expect(app.schedule.scheduled.single.noteId, 'note-riser');
      });
    });
  }
}
