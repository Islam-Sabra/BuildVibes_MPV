// Review 108 RM1, RM2: the Reminder sheet's one choice, Me · Someone.
// Someone is for the item's creator, its owner or a Lead: one or more
// people (the owner chosen first), when (Tomorrow 7:00 · 1 h before due,
// only with a time · Pick…), an optional note of up to 140 characters,
// then Set reminder; the server sends it. The opened item lists the ones
// waiting, and who may removes one. In English and Arabic.
import 'package:buildvibes/core/l10n/bidi.dart';
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/repositories/work_reminder_repository.dart';
import 'package:buildvibes/features/notebook/notebook_page_screen.dart'
    show reminderWhen;
import 'package:buildvibes/features/work/daybook_words.dart';
import 'package:buildvibes/features/work/daybook_writing.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_slip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_rows.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/fakes.dart';
import '../../helpers/later_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

Finder _key(String k) => find.byKey(Key(k));
Finder _entry(String id) => _key('daybook-card-$id');

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

final _now = DaybookSamples.thursday;
final _tomorrow7 = DateTime(_now.year, _now.month, _now.day + 1, 7);
final _due = DateTime(_now.year, _now.month, _now.day + 1, 10);

Future<TestApp> _open(
  WidgetTester tester,
  String lang, {
  required DaybookPost post,
  String me = DaybookSamples.islam,
  SpacePass pass = SpacePass.lead,
  FakeWorkReminderRepository? reminders,
}) async {
  final s = DaybookSamples(lang);
  final app = await pumpApp(
    tester,
    language: lang,
    auth: FakeAuthRepository(userId: me, phone: '+96550000001'),
    spaces: FakeSpaceRepository()
      ..details[DaybookSamples.space] = s.detail(
        pass: pass,
        admin: me == DaybookSamples.islam,
      )
      ..spacePeople[DaybookSamples.space] = s.people(),
    daybook: FakeDaybookRepository()
      ..posts[DaybookSamples.space] = [s.card(post)],
    workReminders: reminders,
    now: _now,
    overrides: [
      pickDueProvider.overrideWithValue(
        (context, {required now, day, at}) async =>
            (day: DateTime(2026, 10, 16), at: DateTime(2026, 10, 16, 15, 30)),
      ),
    ],
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/${DaybookSamples.space}');
  await tester.pumpAndSettle();
  return app;
}

/// The Reminder swipe on [id].
Future<void> _remind(WidgetTester tester, String id, String lang) async {
  await scrollToRow(tester, _entry(id));
  final slip = find
      .descendant(of: _entry(id), matching: find.byType(BvSlip))
      .first;
  await tester.drag(slip, Offset(lang == 'ar' ? -160 : 160, 0));
  await tester.pumpAndSettle();
  await _tap(tester, _key('swipe-remind-$id'));
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    final s = DaybookSamples(lang);
    final words = DaybookWords(l10n, lang, use24: false);

    /// Islam's work item for Omar, due tomorrow at 10:00 ([due]).
    DaybookPost item({bool due = true}) => s.item(
      id: 'post-formwork',
      at: _now.subtract(const Duration(hours: 2)),
      title: s.t('Formwork check, level 3', 'فحص القوالب، الطابق 3'),
      authorId: DaybookSamples.islam,
      ownerId: DaybookSamples.omar,
      due: due ? DateTime(_due.year, _due.month, _due.day) : null,
      dueAt: due ? _due : null,
    );

    group('RM1 the Reminder sheet [$lang]', () {
      testWidgets('the creator: Me · Someone; Someone has the owner chosen, '
          'Tomorrow 7:00, a note, then Set reminder; the server keeps it', (
        tester,
      ) async {
        final app = await _open(tester, lang, post: item());
        await _remind(tester, 'post-formwork', lang);
        expect(find.text(l10n.rmMe), findsOneWidget);
        expect(find.text(l10n.rmSomeone), findsOneWidget);
        await _tap(tester, _key('reminder-someone'));
        expect(
          find.descendant(
            of: _key('reminder-who'),
            matching: find.text(s.omarName),
          ),
          findsOneWidget,
        );
        expect(_key('reminder-tomorrow'), findsOneWidget);
        expect(_key('reminder-before-due'), findsOneWidget);
        expect(_key('reminder-pick'), findsOneWidget);
        await tester.enterText(
          find.descendant(
            of: _key('reminder-note'),
            matching: find.byType(TextField),
          ),
          s.t('Check the formwork before the pour', 'افحص القوالب قبل الصب'),
        );
        await _tap(tester, _key('reminder-set'));
        final set = app.workReminders.sets.single;
        expect(set.postId, 'post-formwork');
        expect(set.people, [DaybookSamples.omar]);
        expect(set.at, _tomorrow7);
        expect(
          set.note,
          s.t('Check the formwork before the pour', 'افحص القوالب قبل الصب'),
        );
        expect(_key('reminder-sheet'), findsNothing);
        // The phone keeps no reminder of its own for Someone.
        expect(app.reminders.onPhone, isEmpty);
      });

      testWidgets('1 h before due; and Who adds another person', (
        tester,
      ) async {
        final app = await _open(tester, lang, post: item());
        await _remind(tester, 'post-formwork', lang);
        await _tap(tester, _key('reminder-someone'));
        await _tap(tester, _key('reminder-before-due'));
        await _tap(tester, _key('reminder-who'));
        await _tap(tester, _key('reminder-person-${DaybookSamples.rakesh}'));
        await _tap(tester, _key('reminder-who-done'));
        expect(
          find.descendant(
            of: _key('reminder-who'),
            matching: find.textContaining(s.rakeshName.split(' ').first),
          ),
          findsOneWidget,
        );
        await _tap(tester, _key('reminder-set'));
        final set = app.workReminders.sets.single;
        expect(set.at, _due.subtract(const Duration(hours: 1)));
        expect(set.people, [DaybookSamples.omar, DaybookSamples.rakesh]);
      });

      testWidgets('no time on the item: no "1 h before due"; Pick… picks', (
        tester,
      ) async {
        final app = await _open(tester, lang, post: item(due: false));
        await _remind(tester, 'post-formwork', lang);
        await _tap(tester, _key('reminder-someone'));
        expect(_key('reminder-before-due'), findsNothing);
        await _tap(tester, _key('reminder-pick'));
        await _tap(tester, _key('reminder-set'));
        expect(app.workReminders.sets.single.at, DateTime(2026, 10, 16, 15, 30));
      });

      testWidgets('the note is 140 characters at most', (tester) async {
        await _open(tester, lang, post: item());
        await _remind(tester, 'post-formwork', lang);
        await _tap(tester, _key('reminder-someone'));
        final field = tester.widget<TextField>(
          find.descendant(
            of: _key('reminder-note'),
            matching: find.byType(TextField),
          ),
        );
        expect(field.maxLength, 140);
      });

      testWidgets('the owner may remind someone too', (tester) async {
        await _open(
          tester,
          lang,
          post: item(),
          me: DaybookSamples.omar,
          pass: SpacePass.crew,
        );
        await _remind(tester, 'post-formwork', lang);
        expect(_key('reminder-someone'), findsOneWidget);
      });

      testWidgets('Crew who isn\'t its creator or owner: Me only', (
        tester,
      ) async {
        final app = await _open(
          tester,
          lang,
          post: item(),
          me: DaybookSamples.rakesh,
          pass: SpacePass.crew,
        );
        await _remind(tester, 'post-formwork', lang);
        expect(_key('reminder-sheet'), findsOneWidget);
        expect(_key('reminder-someone'), findsNothing);
        await _tap(tester, _key('reminder-tomorrow'));
        await _tap(tester, _key('reminder-set'));
        // Me: on this phone only, as before.
        expect(app.workReminders.sets, isEmpty);
        expect(app.reminders.onPhone.values.single.at, _tomorrow7);
      });
    });

    group('RM2 the opened item\'s Reminders [$lang]', () {
      testWidgets('who and when; ✕ for who may take it off', (tester) async {
        final reminders = FakeWorkReminderRepository()
          ..byPost['post-formwork'] = [
            WorkReminder(
              id: 'rem-1',
              remindAt: _tomorrow7,
              people: [(id: DaybookSamples.omar, name: s.omarName)],
              canRemove: true,
            ),
            WorkReminder(
              id: 'rem-2',
              remindAt: _tomorrow7,
              people: [(id: DaybookSamples.rakesh, name: s.rakeshName)],
            ),
          ];
        await _open(tester, lang, post: item(), reminders: reminders);
        await _tap(
          tester,
          find
              .descendant(
                of: _entry('post-formwork'),
                matching: find.byType(BvSlipTitle),
              )
              .first,
        );
        final line = _key('page-reminders');
        expect(
          find.descendant(of: line, matching: find.text(l10n.rmReminders)),
          findsOneWidget,
        );
        final when = reminderWhen(l10n, words, _tomorrow7, _now);
        expect(
          find.descendant(
            of: line,
            matching: find.text(l10n.rmLine(inOwnDirection(s.omarName), when)),
          ),
          findsOneWidget,
        );
        expect(_key('reminder-remove-rem-1'), findsOneWidget);
        expect(_key('reminder-remove-rem-2'), findsNothing);
        await _tap(tester, _key('reminder-remove-rem-1'));
        expect(reminders.removed, ['rem-1']);
        expect(
          find.descendant(
            of: line,
            matching: find.text(l10n.rmLine(inOwnDirection(s.omarName), when)),
          ),
          findsNothing,
        );
      });
    });
  }
}
