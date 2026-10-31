// Review 108: reminders for someone else and Post later, the shots in
// English and Arabic at 390 × 844 in the app's fonts. RM1 the Reminder
// sheet on Someone, the owner chosen and a note; RM2 the opened item's
// Reminders; PL1 Post later over a work item ready to post; PL2 Scheduled;
// PL2b the Space's "1 scheduled" line. Run:
//   flutter test test_screens/r108_test.dart --update-goldens
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/repositories/schedule_repository.dart';
import 'package:buildvibes/data/repositories/work_reminder_repository.dart';
import 'package:buildvibes/shared/widgets/bv_give_to_picker.dart';
import 'package:buildvibes/shared/widgets/bv_slip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../test/helpers/daybook_fakes.dart';
import '../test/helpers/daybook_rows.dart';
import '../test/helpers/daybook_samples.dart';
import '../test/helpers/later_fakes.dart';
import '../test/helpers/pump_app.dart';
import '../test/helpers/space_fakes.dart';
import 'shot.dart';

/// Saves the app as it is now to `docs/screens/r108/<name>_<lang>.png`.
Future<void> _snap(WidgetTester tester, String name, String lang) async {
  debugDisableShadows = false;
  try {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byType(MaterialApp).first,
      matchesGoldenFile('../docs/screens/r108/${name}_$lang.png'),
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

final _now = DaybookSamples.thursday;
final _tomorrow7 = DateTime(2026, 10, 16, 7);

void main() {
  setUpAll(loadAppFonts);

  for (final lang in ['en', 'ar']) {
    final s = DaybookSamples(lang);

    /// Islam's work item for Omar, due tomorrow at 10:00 (the frames').
    DaybookPost formwork() => s.item(
      id: 'post-formwork',
      at: DateTime(2026, 10, 15, 8, 30),
      title: s.t('Formwork check, level 3', 'فحص القوالب، الطابق 3'),
      authorId: DaybookSamples.islam,
      ownerId: DaybookSamples.omar,
      due: DateTime(2026, 10, 16),
      dueAt: DateTime(2026, 10, 16, 10),
    );

    /// The Space as Islam (Lead).
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
          ..details[DaybookSamples.space] = s.detail()
          ..spacePeople[DaybookSamples.space] = s.people(),
        daybook: FakeDaybookRepository()
          ..posts[DaybookSamples.space] = posts ?? [s.card(formwork())],
        workReminders: reminders,
        schedule: schedule,
        now: _now,
      );
      GoRouter.of(
        tester.element(find.byType(Navigator).first),
      ).push('/spaces/${DaybookSamples.space}');
      await tester.pumpAndSettle();
      return app;
    }

    testWidgets('RM1 the Reminder sheet: Someone [$lang]', (tester) async {
      await space(tester);
      final card = _key('daybook-card-post-formwork');
      await scrollToRow(tester, card);
      await tester.drag(
        find.descendant(of: card, matching: find.byType(BvSlip)).first,
        Offset(lang == 'ar' ? -160 : 160, 0),
      );
      await tester.pumpAndSettle();
      await _tap(tester, _key('swipe-remind-post-formwork'));
      await _tap(tester, _key('reminder-someone'));
      await tester.enterText(
        find.descendant(
          of: _key('reminder-note'),
          matching: find.byType(TextField),
        ),
        s.t('Check the formwork before the pour', 'افحص القوالب قبل الصب'),
      );
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await _snap(tester, 'RM1-reminder-someone', lang);
    });

    testWidgets('RM2 the opened item\'s Reminders [$lang]', (tester) async {
      await space(
        tester,
        reminders: FakeWorkReminderRepository()
          ..byPost['post-formwork'] = [
            WorkReminder(
              id: 'rem-1',
              remindAt: _tomorrow7,
              people: [(id: DaybookSamples.omar, name: s.omarName)],
              canRemove: true,
            ),
          ],
      );
      await _tap(
        tester,
        find.descendant(
          of: _key('daybook-card-post-formwork'),
          matching: find.byType(BvSlipTitle),
        ),
      );
      await _snap(tester, 'RM2-item-reminders', lang);
    });

    testWidgets('PL1 Post later [$lang]', (tester) async {
      await space(tester);
      await _tap(tester, _key('post-bar-notepad'));
      await tester.enterText(
        _key('writing-title'),
        s.t(
          'Morning brief: pour at level 3 starts 10:00',
          'إحاطة الصباح: صب الطابق 3 يبدأ 10:00',
        ),
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
      await _tap(tester, _key('writing-later'));
      await _snap(tester, 'PL1-post-later', lang);
    });

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
          spaceName: s.t('Kuwait City Tower', 'برج مدينة الكويت'),
        ),
        ScheduledPost(
          id: 'sch-2',
          title: s.t(
            'Level 3 slab done, 28 days ahead of plan',
            'بلاطة الطابق 3 منجزة، قبل الخطة بـ 28 يومًا',
          ),
          publishAt: DateTime(2026, 10, 18, 9),
        ),
      ]);

    testWidgets('PL2 Scheduled [$lang]', (tester) async {
      await pumpApp(tester, language: lang, schedule: two(), now: _now);
      GoRouter.of(
        tester.element(find.byType(Navigator).first),
      ).push('/scheduled-posts');
      await tester.pumpAndSettle();
      await _snap(tester, 'PL2-scheduled', lang);
    });

    testWidgets('PL2b the Space\'s "1 scheduled" line [$lang]', (tester) async {
      await space(
        tester,
        schedule: FakeScheduleRepository()..posts.add(two().posts.first),
      );
      await _snap(tester, 'PL2b-space-scheduled-line', lang);
    });

    // The lead's check (V2, V4, V6, V7).
    testWidgets('PL2c a failed one: Post now · Cancel [$lang]', (tester) async {
      await pumpApp(
        tester,
        language: lang,
        schedule: FakeScheduleRepository()
          ..posts.addAll([
            ScheduledPost(
              id: 'sch-3',
              title: s.t(
                'Night shift starts 19:00',
                'الوردية الليلية تبدأ 19:00',
              ),
              publishAt: DateTime(2026, 10, 15, 7),
              state: ScheduledState.failed,
              error: 'not_allowed',
              spaceId: DaybookSamples.space,
              spaceName: s.t('Kuwait City Tower', 'برج مدينة الكويت'),
            ),
            two().posts.first,
          ]),
        now: _now,
      );
      GoRouter.of(
        tester.element(find.byType(Navigator).first),
      ).push('/scheduled-posts');
      await tester.pumpAndSettle();
      await _snap(tester, 'PL2c-scheduled-failed', lang);
    });

    Future<void> someone(WidgetTester tester) async {
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

    testWidgets('RM1b two people, full names [$lang]', (tester) async {
      await space(tester);
      await someone(tester);
      await _tap(tester, _key('reminder-who'));
      await _tap(tester, _key('reminder-person-${DaybookSamples.rakesh}'));
      await _tap(tester, _key('reminder-who-done'));
      await _snap(tester, 'RM1b-reminder-two-people', lang);
    });

    testWidgets('RM1c the most for today [$lang]', (tester) async {
      await space(
        tester,
        reminders: FakeWorkReminderRepository()..failure = SpaceFailure.limit,
      );
      await someone(tester);
      await _tap(tester, _key('reminder-set'));
      await _snap(tester, 'RM1c-reminder-daily-most', lang);
    });

    testWidgets('PL1b a work item with a place: not yet [$lang]', (
      tester,
    ) async {
      await pumpApp(
        tester,
        language: lang,
        spaces: FakeSpaceRepository()
          ..details[DaybookSamples.space] = s.detail()
          ..spacePeople[DaybookSamples.space] = s.people(),
        daybook: FakeDaybookRepository()
          ..posts[DaybookSamples.space] = [s.card(formwork())]
          ..placesBySpace[DaybookSamples.space] = [
            SpacePlace(
              id: 'place-l3',
              name: s.t('Level 3 core', 'لب الطابق 3'),
            ),
          ],
        now: _now,
      );
      GoRouter.of(
        tester.element(find.byType(Navigator).first),
      ).push('/spaces/${DaybookSamples.space}');
      await tester.pumpAndSettle();
      await _tap(tester, _key('post-bar-notepad'));
      await tester.enterText(
        _key('writing-title'),
        s.t('Seal the riser at level 3', 'إغلاق الرايزر في الطابق 3'),
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
      await _tap(tester, _key('writing-place-row'));
      await _tap(tester, _key('place-row-place-l3'));
      await _tap(tester, _key('writing-later'));
      await _snap(tester, 'PL1b-later-not-yet', lang);
    });
  }
}
