// Review 108 PL1, PL2: Post later. The writing bar of a Space, the Feed
// and a notebook share gets a clock beside Send; it opens Post later, one
// choice of Tomorrow 7:00 · {next working day} 7:00 · Pick…, the line "It
// goes out at that time, even if your phone is off." and Schedule. The
// working days are the market pack's. Scheduled lists mine still waiting,
// each with Post now · Edit · Cancel; it opens from Profile and from a
// "{n} scheduled" line in the Space. In English and Arabic.
import 'package:buildvibes/core/l10n/bidi.dart';
import 'package:buildvibes/core/push/push_messaging.dart';
import 'package:buildvibes/data/repositories/schedule_repository.dart';
import 'package:buildvibes/features/feed/feed_state.dart' show PendingPost;
import 'package:buildvibes/features/notebook/notebook_page_screen.dart'
    show reminderWhen;
import 'package:buildvibes/features/work/daybook_words.dart';
import 'package:buildvibes/features/work/daybook_writing.dart';
import 'package:buildvibes/features/work/post_later_sheet.dart';
import 'package:buildvibes/features/work/work_outbox.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_give_to_picker.dart';
import 'package:buildvibes/shared/widgets/bv_writing_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/later_fakes.dart';
import '../../helpers/notebook_page_samples.dart';
import '../../helpers/post_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/push_fakes.dart';
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

/// Thursday 15 October 2026, 10:30. In Kuwait the weekend is Friday and
/// Saturday (the market pack's), so after tomorrow the next working day
/// is Sunday 18 October.
final _now = DaybookSamples.thursday;
final _tomorrow7 = DateTime(2026, 10, 16, 7);
final _sunday7 = DateTime(2026, 10, 18, 7);

/// Islam (Lead) in the Space.
Future<TestApp> _space(
  WidgetTester tester,
  String lang, {
  FakeScheduleRepository? schedule,
}) async {
  final s = DaybookSamples(lang);
  final app = await pumpApp(
    tester,
    language: lang,
    spaces: FakeSpaceRepository()
      ..details[DaybookSamples.space] = s.detail()
      ..spacePeople[DaybookSamples.space] = s.people(),
    daybook: FakeDaybookRepository()..posts[DaybookSamples.space] = s.d1(),
    schedule: schedule,
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

/// A work item for Omar, ready to post.
Future<void> _writeItem(WidgetTester tester, DaybookSamples s) async {
  if (_key('writing-title').evaluate().isEmpty) {
    await _tap(tester, _key('post-bar-notepad'));
  }
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

void main() {
  group('the next working day comes from the market pack', () {
    // 0 is Sunday (markets.weekend).
    test('Kuwait (Fri, Sat): Thursday → Sunday', () {
      expect(nextWorkingDay(DateTime(2026, 10, 15, 10), [5, 6]), _sunday7);
    });
    test('Kuwait: Sunday → Tuesday, the first working day after tomorrow', () {
      expect(
        nextWorkingDay(DateTime(2026, 10, 18, 10), [5, 6]),
        DateTime(2026, 10, 20, 7),
      );
    });
    test('a Saturday-Sunday weekend: Friday → Monday', () {
      expect(
        nextWorkingDay(DateTime(2026, 10, 16, 10), [6, 0]),
        DateTime(2026, 10, 19, 7),
      );
    });
    test('no weekend: the day after tomorrow', () {
      expect(
        nextWorkingDay(DateTime(2026, 10, 15, 10), const []),
        DateTime(2026, 10, 17, 7),
      );
    });
  });

  group('kept on the phone until the signal is back', () {
    test('a Space post keeps its time', () {
      final item = PendingItem(
        id: 'p1',
        spaceId: 's1',
        title: 'Morning brief',
        ownerId: 'o1',
        ownerName: 'Omar',
        kind: PendingKind.workItem,
        scheduleAt: _tomorrow7,
      );
      expect(PendingItem.fromJson(item.toJson()).scheduleAt, _tomorrow7);
      expect(item.copyWith(sent: true).scheduleAt, _tomorrow7);
      expect(item.withoutSource().scheduleAt, _tomorrow7);
    });
    test('a Feed post keeps its time', () {
      final post = PendingPost(
        id: 'p1',
        body: 'Slab done',
        lang: 'en',
        madeAt: _now,
        scheduleAt: _sunday7,
      );
      expect(PendingPost.fromJson(post.toJson()).scheduleAt, _sunday7);
      expect(post.copyWith(sent: true).scheduleAt, _sunday7);
    });
  });

  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    final s = DaybookSamples(lang);
    final words = DaybookWords(l10n, lang, use24: false);
    String when(DateTime at) => reminderWhen(l10n, words, at, _now);

    group('PL1 Post later in a Space [$lang]', () {
      testWidgets('the clock is off until the post is ready', (tester) async {
        await _space(tester, lang);
        await _tap(tester, _key('post-bar-notepad'));
        BvWritingToolbar bar() =>
            tester.widget<BvWritingToolbar>(find.byType(BvWritingToolbar));
        expect(bar().onLater, isNull);
        await _writeItem(tester, s);
        expect(bar().onLater, isNotNull);
      });

      testWidgets('Schedule keeps the create call on the server for Tomorrow '
          '7:00; nothing is posted now and the card is gone', (tester) async {
        final app = await _space(tester, lang);
        await _writeItem(tester, s);
        await _tap(tester, _key('writing-later'));
        expect(_key('later-sheet'), findsOneWidget);
        expect(find.text(l10n.plTitle), findsWidgets);
        expect(
          find.descendant(
            of: _key('later-tomorrow'),
            matching: find.text(l10n.rmTomorrowAt(words.time.clock(_sunday7))),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: _key('later-workday'),
            matching: find.text(
              l10n.plDayAt(words.weekday(_sunday7), words.time.clock(_sunday7)),
            ),
          ),
          findsOneWidget,
        );
        expect(_key('later-pick'), findsOneWidget);
        expect(find.text(l10n.plGoesOut), findsOneWidget);
        await _tap(tester, _key('later-schedule'));

        final sent = app.schedule.scheduled.single;
        expect(sent.call, ScheduledCall.workItem);
        expect(sent.at, _tomorrow7);
        expect(sent.params['p_space'], DaybookSamples.space);
        expect(sent.params['p_owner'], DaybookSamples.omar);
        expect(sent.params['p_id'], sent.id);
        expect(
          sent.params['p_title'],
          s.t('Morning brief: pour at level 3', 'إحاطة الصباح: صب الطابق 3'),
        );
        expect(app.daybook.created, isEmpty);
        expect(_key('daybook-card-${sent.id}'), findsNothing);
        expect(_key('writing-title'), findsNothing);
        expect(
          find.text(l10n.plScheduledFor(when(_tomorrow7))),
          findsOneWidget,
        );
      });

      testWidgets('the next working day, and Pick…', (tester) async {
        final app = await _space(tester, lang);
        await _writeItem(tester, s);
        await _tap(tester, _key('writing-later'));
        await _tap(tester, _key('later-workday'));
        await _tap(tester, _key('later-schedule'));
        expect(app.schedule.scheduled.single.at, _sunday7);

        await _writeItem(tester, s);
        await _tap(tester, _key('writing-later'));
        await _tap(tester, _key('later-pick'));
        await _tap(tester, _key('later-schedule'));
        expect(app.schedule.scheduled.last.at, DateTime(2026, 10, 20, 9));
      });

      testWidgets('"1 scheduled" in the Space opens Scheduled', (tester) async {
        await _space(
          tester,
          lang,
          schedule: FakeScheduleRepository()
            ..posts.add(
              ScheduledPost(
                id: 'sch-1',
                title: s.t('Morning brief', 'إحاطة الصباح'),
                publishAt: _tomorrow7,
                spaceId: DaybookSamples.space,
                spaceName: s.spaceName,
              ),
            ),
        );
        expect(
          find.descendant(
            of: _key('space-scheduled'),
            matching: find.text(l10n.plCount(1)),
          ),
          findsOneWidget,
        );
        await _tap(tester, _key('space-scheduled'));
        expect(_key('scheduled-screen'), findsOneWidget);
      });
    });

    group('PL1 Post later in the Feed [$lang]', () {
      testWidgets('the clock beside Post; Schedule keeps create_post', (
        tester,
      ) async {
        final posts = FakePostRepository();
        final app = await pumpApp(
          tester,
          language: lang,
          posts: posts,
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
        final sent = app.schedule.scheduled.single;
        expect(sent.call, ScheduledCall.feedPost);
        expect(sent.at, _sunday7);
        expect(sent.params['p_id'], sent.id);
        expect(
          sent.params['p_body'],
          s.t('Level 3 slab done', 'بلاطة الطابق 3 منجزة'),
        );
        expect(sent.params['p_lang'], lang);
        expect(posts.calls.where((c) => c.startsWith('create')), isEmpty);
        expect(_key('post-writing-card'), findsNothing);
      });
    });

    group('PL1 Post later from a notebook share [$lang]', () {
      testWidgets('the clock beside Post; Schedule keeps share_note_to_feed', (
        tester,
      ) async {
        final notebook = NotebookPageSamples(lang).repository();
        final app = await pumpApp(
          tester,
          language: lang,
          now: NotebookPageSamples.now,
          notebook: notebook,
        );
        _router(tester).push('/notebook/pages/${NotebookPageSamples.siteA}');
        await tester.pumpAndSettle();
        await tester.longPress(_key('note-entry-pour'));
        await tester.pumpAndSettle();
        await _tap(tester, _key('note-status-entry-pour-feed'));
        await _tap(tester, _key('share-later'));
        await _tap(tester, _key('later-schedule'));
        final sent = app.schedule.scheduled.single;
        expect(sent.call, ScheduledCall.noteToFeed);
        expect(sent.params['p_note'], 'entry-pour');
        expect(sent.params['p_post'], sent.id);
        expect(
          notebook.calls.where((c) => c.startsWith('share-feed')),
          isEmpty,
        );
      });
    });

    group('PL2 Scheduled [$lang]', () {
      FakeScheduleRepository two() => FakeScheduleRepository()
        ..posts.addAll([
          ScheduledPost(
            id: 'sch-1',
            title: s.t(
              'Morning brief: pour at level 3 starts 10:00',
              'إحاطة الصباح: صب الطابق 3 يبدأ 10:00',
            ),
            publishAt: _tomorrow7,
            spaceId: DaybookSamples.space,
            spaceName: s.spaceName,
          ),
          ScheduledPost(
            id: 'sch-2',
            title: s.t('Level 3 slab done', 'بلاطة الطابق 3 منجزة'),
            publishAt: _sunday7,
          ),
        ]);

      Future<FakeScheduleRepository> open(WidgetTester tester) async {
        final schedule = two();
        await pumpApp(tester, language: lang, schedule: schedule, now: _now);
        _router(tester).push('/scheduled-posts');
        await tester.pumpAndSettle();
        return schedule;
      }

      testWidgets('each with when, where, Post now · Edit · Cancel', (
        tester,
      ) async {
        await open(tester);
        expect(find.text(l10n.plScheduled), findsOneWidget);
        final first = _key('scheduled-sch-1');
        for (final t in [when(_tomorrow7), inOwnDirection(s.spaceName)]) {
          expect(
            find.descendant(of: first, matching: find.text(t)),
            findsOneWidget,
            reason: t,
          );
        }
        expect(
          find.descendant(
            of: _key('scheduled-sch-2'),
            matching: find.text(l10n.plFeed),
          ),
          findsOneWidget,
        );
        for (final k in ['post-now', 'edit', 'cancel']) {
          expect(_key('scheduled-$k-sch-1'), findsOneWidget, reason: k);
        }
      });

      testWidgets('Post now and Cancel take it off the list', (tester) async {
        final schedule = await open(tester);
        await _tap(tester, _key('scheduled-post-now-sch-1'));
        expect(schedule.postedNow, ['sch-1']);
        expect(_key('scheduled-sch-1'), findsNothing);
        await _tap(tester, _key('scheduled-cancel-sch-2'));
        expect(schedule.cancelled, ['sch-2']);
        expect(_key('scheduled-sch-2'), findsNothing);
        expect(find.text(l10n.plEmpty), findsOneWidget);
      });

      testWidgets('Edit changes its time in Post later', (tester) async {
        final schedule = await open(tester);
        await _tap(tester, _key('scheduled-edit-sch-1'));
        expect(_key('later-sheet'), findsOneWidget);
        await _tap(tester, _key('later-workday'));
        await _tap(tester, _key('later-schedule'));
        expect(
          schedule.posts.firstWhere((p) => p.id == 'sch-1').publishAt,
          _sunday7,
        );
        expect(
          find.descendant(
            of: _key('scheduled-sch-1'),
            matching: find.text(when(_sunday7)),
          ),
          findsOneWidget,
        );
      });

      testWidgets('one that couldn\'t go says why', (tester) async {
        final schedule = FakeScheduleRepository()
          ..posts.add(
            ScheduledPost(
              id: 'sch-3',
              title: s.t('Morning brief', 'إحاطة الصباح'),
              publishAt: _tomorrow7,
              state: ScheduledState.failed,
              error: 'not_allowed',
              spaceId: DaybookSamples.space,
              spaceName: s.spaceName,
            ),
          );
        await pumpApp(tester, language: lang, schedule: schedule, now: _now);
        _router(tester).push('/scheduled-posts');
        await tester.pumpAndSettle();
        expect(
          find.text(l10n.plFailed(l10n.plReasonNotAllowed)),
          findsOneWidget,
        );
      });

      testWidgets('Profile has Scheduled while one waits', (tester) async {
        await pumpApp(tester, language: lang, schedule: two(), now: _now);
        _router(tester).go('/profile');
        await tester.pumpAndSettle();
        await _tap(tester, _key('profile-scheduled'));
        expect(_key('scheduled-screen'), findsOneWidget);
      });

      testWidgets('the push for a failed post opens Scheduled', (tester) async {
        await pumpApp(
          tester,
          language: lang,
          schedule: two(),
          now: _now,
          push: FakePushMessaging(
            current: PushPermission.granted,
            firstTap: {
              'kind': 'scheduled_failed',
              'route': '/scheduled-posts',
              'scheduled_id': 'sch-1',
            },
          ),
        );
        expect(_key('scheduled-screen'), findsOneWidget);
      });

      testWidgets('no Scheduled on Profile with none waiting', (tester) async {
        await pumpApp(tester, language: lang, now: _now);
        _router(tester).go('/profile');
        await tester.pumpAndSettle();
        expect(_key('profile-scheduled'), findsNothing);
      });
    });
  }
}
