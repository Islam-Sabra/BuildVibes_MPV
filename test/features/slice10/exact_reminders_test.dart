import 'package:buildvibes/data/models/note.dart';
import 'package:buildvibes/features/work/daybook_writing.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/notebook_fakes.dart';
import '../../helpers/notebook_samples.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/reminder_fakes.dart';

/// On-time reminders (founder, 25 Oct): on a phone that keeps alarms
/// inexact, the first Remind me asks once, with one line why, to open the
/// phone's exact alarms setting; refused, reminders stay inexact.
Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

Future<TestApp> _open(
  WidgetTester tester,
  String lang, {
  required List<Note> notes,
  required bool exact,
}) async {
  final app = await pumpApp(
    tester,
    language: lang,
    now: NotebookSamples.now,
    notebook: FakeNotebookRepository(notes: notes),
    reminders: FakePhoneReminders()..exact = exact,
    overrides: [
      pickDueProvider.overrideWithValue(
        (context, {required now, day, at}) async =>
            (day: DateTime(2026, 10, 15), at: DateTime(2026, 10, 15, 16)),
      ),
    ],
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/notebook/pages/page-my-notes');
  await tester.pumpAndSettle();
  return app;
}

Future<void> _remind(WidgetTester tester, String id) async {
  await tester.tap(_key('note-menu-$id'));
  await tester.pumpAndSettle();
  await _tap(tester, _key('note-remind'));
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    final s = NotebookSamples(lang);

    testWidgets('inexact phone: the first Remind me asks once, and Open '
        'opens the phone setting [$lang]', (tester) async {
      final app = await _open(tester, lang, notes: [s.todo()], exact: false);
      await _remind(tester, 'note-sleeves');
      expect(find.text(l10n.notebookExactTitle), findsOneWidget);
      expect(find.text(l10n.notebookExactBody), findsOneWidget);
      await _tap(tester, find.text(l10n.notebookExactOpen));
      expect(app.reminders.calls, contains('exact setting'));
      expect(
        app.reminders.onPhone['note-sleeves']!.at,
        DateTime(2026, 10, 15, 16),
      );

      // Still inexact (refused in the setting): never asked again.
      await _remind(tester, 'note-sleeves');
      expect(find.text(l10n.notebookExactTitle), findsNothing);
      expect(
        app.reminders.calls.where((c) => c == 'exact setting'),
        hasLength(1),
      );
    });

    testWidgets('Not now: the reminder is still set (inexact) and never '
        'asked again [$lang]', (tester) async {
      final app = await _open(tester, lang, notes: [s.todo()], exact: false);
      await _remind(tester, 'note-sleeves');
      await _tap(tester, find.text(l10n.notebookExactNotNow));
      expect(app.reminders.calls, isNot(contains('exact setting')));
      expect(
        app.notebook.kept['note-sleeves']!.remindAt,
        DateTime(2026, 10, 15, 16),
      );
      expect(app.reminders.onPhone, contains('note-sleeves'));
      expect(app.prefs.getBool('notebook_exact_asked'), isTrue);

      await _remind(tester, 'note-sleeves');
      expect(find.text(l10n.notebookExactTitle), findsNothing);
    });

    testWidgets('exact alarms already allowed: never asks [$lang]', (
      tester,
    ) async {
      final app = await _open(tester, lang, notes: [s.todo()], exact: true);
      await _remind(tester, 'note-sleeves');
      expect(find.text(l10n.notebookExactTitle), findsNothing);
      expect(app.reminders.onPhone, contains('note-sleeves'));
      expect(app.prefs.getBool('notebook_exact_asked'), isNull);
    });
  }
}
