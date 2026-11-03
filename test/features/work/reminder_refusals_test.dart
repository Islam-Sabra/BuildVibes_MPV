// Review 110 B: the server reminds someone only of an open work item, so
// the Reminder sheet offers Someone only there; elsewhere it is Me alone.
// A refusal says why in plain words; the generic line is only for the
// unknown. In English and Arabic.
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/models/work_item.dart';
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

Future<TestApp> _open(
  WidgetTester tester,
  String lang, {
  required DaybookPost post,
  FakeWorkReminderRepository? reminders,
}) async {
  final s = DaybookSamples(lang);
  final app = await pumpApp(
    tester,
    language: lang,
    auth: FakeAuthRepository(
      userId: DaybookSamples.islam,
      phone: '+96550000001',
    ),
    spaces: FakeSpaceRepository()
      ..details[DaybookSamples.space] = s.detail(
        pass: SpacePass.lead,
        admin: true,
      )
      ..spacePeople[DaybookSamples.space] = s.people(),
    daybook: FakeDaybookRepository()
      ..posts[DaybookSamples.space] = [s.card(post)],
    workReminders: reminders,
    now: _now,
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/${DaybookSamples.space}');
  await tester.pumpAndSettle();
  return app;
}

Future<void> _remind(WidgetTester tester, String id, String lang) async {
  await scrollToRow(tester, _entry(id));
  final slip = find
      .descendant(of: _entry(id), matching: find.byType(BvSlip))
      .first;
  await tester.longPress(slip);
  await tester.pumpAndSettle();
  await _tap(tester, _key('select-remind'));
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    final s = DaybookSamples(lang);

    DaybookPost item({
      WorkStatus status = WorkStatus.open,
      bool cancelled = false,
    }) => s.item(
      id: 'post-formwork',
      at: _now.subtract(const Duration(hours: 2)),
      title: s.t('Formwork check, level 3', 'فحص القوالب، الطابق 3'),
      authorId: DaybookSamples.islam,
      ownerId: DaybookSamples.omar,
      status: status,
      cancelled: cancelled,
    );

    DaybookPost other(String kind) => DaybookPost(
      id: 'post-other',
      kind: kind,
      createdAt: _now.subtract(const Duration(hours: 2)),
      title: s.t('Gate 3 closed', 'البوابة 3 مغلقة'),
      authorId: DaybookSamples.islam,
      authorName: s.nameOf(DaybookSamples.islam),
    );

    group('Review 110 B: Someone only on an open work item [$lang]', () {
      for (final kind in [
        DaybookPost.announcementKind,
        DaybookPost.checklistKind,
        DaybookPost.noteKind,
      ]) {
        testWidgets('a $kind: Me alone, no Someone', (tester) async {
          await _open(tester, lang, post: other(kind));
          await _remind(tester, 'post-other', lang);
          expect(_key('reminder-sheet'), findsOneWidget);
          expect(_key('reminder-someone'), findsNothing);
          expect(find.text(l10n.rmSomeone), findsNothing);
        });
      }

      for (final (name, post) in [
        ('a Done work item', item(status: WorkStatus.done)),
        ('a Checked work item', item(status: WorkStatus.checked)),
        ('a cancelled work item', item(cancelled: true)),
      ]) {
        testWidgets('$name: Me alone, no Someone', (tester) async {
          await _open(tester, lang, post: post);
          await _remind(tester, 'post-formwork', lang);
          expect(_key('reminder-sheet'), findsOneWidget);
          expect(_key('reminder-someone'), findsNothing);
        });
      }

      testWidgets('an open work item still offers Someone', (tester) async {
        await _open(tester, lang, post: item());
        await _remind(tester, 'post-formwork', lang);
        expect(_key('reminder-someone'), findsOneWidget);
      });
    });

    group('Review 110 B: a refusal says why [$lang]', () {
      for (final (failure, message, line) in [
        (SpaceFailure.notAllowed, 'not allowed', l10n.rmOnlyWhoMay),
        (SpaceFailure.badInput, 'only an open work item', l10n.rmOnlyOpen),
        // Review 110 W5.
        (
          SpaceFailure.badInput,
          'at most 5 reminders wait on an item',
          l10n.rmFiveWaiting,
        ),
        (
          SpaceFailure.badInput,
          'only people in the Space who can see it',
          l10n.rmOnlyWhoSees,
        ),
        (SpaceFailure.unknown, 'something new', l10n.errorGeneric),
      ]) {
        testWidgets('"$message" → its own line', (tester) async {
          final reminders = FakeWorkReminderRepository()
            ..failure = failure
            ..failureMessage = message;
          await _open(tester, lang, post: item(), reminders: reminders);
          await _remind(tester, 'post-formwork', lang);
          await _tap(tester, _key('reminder-someone'));
          await _tap(tester, _key('reminder-set'));
          expect(tester.widget<Text>(_key('reminder-error')).data, line);
          expect(find.text(l10n.spacesNotAllowed), findsNothing);
        });
      }
    });
  }
}
