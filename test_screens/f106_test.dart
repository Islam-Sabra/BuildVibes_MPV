// F106 (review 90): My notebook writes in place, against NBW1–NBW5 (EN
// 2613:36507, 2613:36619, 2613:36731, 2613:36843, 2613:36956; AR
// 2613:37050, 2613:37162, 2613:37274, 2613:37386, 2613:37499). English and
// Arabic, at 390 × 844 on a 12-hour phone, in the app's fonts. The frames
// draw a keyboard under the tools; a test has none.
// Run:
//   flutter test test_screens/f106_test.dart --update-goldens
import 'package:buildvibes/data/models/note.dart';
import 'package:buildvibes/features/work/daybook_writing.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../test/helpers/notebook_fakes.dart';
import '../test/helpers/notebook_samples.dart';
import '../test/helpers/pump_app.dart';
import 'shot.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

/// Saves the app as it is now to `docs/screens/f106/<name>_<lang>.png`.
Future<void> _snap(WidgetTester tester, String name, String lang) async {
  tester.view.physicalSize = shotSize * shotPixelRatio;
  tester.view.devicePixelRatio = shotPixelRatio;
  debugDisableShadows = false;
  try {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byType(MaterialApp).first,
      matchesGoldenFile('../docs/screens/f106/${name}_$lang.png'),
    );
  } finally {
    debugDisableShadows = true;
  }
}

/// "Ask Lina for the door schedule before Sunday." at 11:40 today (NBW3).
Note _lina(NotebookSamples n) => Note(
  id: 'note-lina',
  kind: NoteKind.text,
  body: n.yesterday().body,
  createdAt: DateTime(2026, 10, 15, 11, 40),
);

/// The frames' times, in the order the pickers are asked: by when at
/// 4:00 pm, then Remind me at 3:45 pm.
Future<TestApp> _open(
  WidgetTester tester,
  String lang,
  List<Note> notes,
) async {
  final times = [DateTime(2026, 10, 15, 16), DateTime(2026, 10, 15, 15, 45)];
  var asked = 0;
  final app = await pumpApp(
    tester,
    language: lang,
    now: NotebookSamples.now,
    notebook: FakeNotebookRepository(notes: notes),
    overrides: [
      pickDueProvider.overrideWithValue((context, {required now, day, at}) {
        final t = times[asked++ % times.length];
        return Future.value((day: DateTime(t.year, t.month, t.day), at: t));
      }),
    ],
  );
  tester.view.physicalSize = shotSize * shotPixelRatio;
  tester.view.devicePixelRatio = shotPixelRatio;
  addTearDown(tester.view.reset);
  GoRouter.of(tester.element(find.byType(Navigator).first)).push('/notebook');
  await tester.pumpAndSettle();
  return app;
}

Future<void> _todo(WidgetTester tester, AppLocalizations l10n, String w) async {
  await _tap(tester, _key('post-bar-notepad'));
  await _tap(tester, _key('writing-kind-chip'));
  await _tap(tester, find.text(l10n.notebookTodo).last);
  await tester.enterText(_key('note-todo-line'), w);
  await tester.pumpAndSettle();
  await _tap(tester, _key('note-tool-due'));
  await _tap(tester, _key('note-tool-remind'));
}

void main() {
  setUpAll(loadAppFonts);

  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);
    final n = NotebookSamples(lang);

    testWidgets('NBW1 Tap Note: a slip at the end of today [$lang]', (
      tester,
    ) async {
      await _open(tester, lang, [n.checklist()]);
      await _tap(tester, _key('post-bar-notepad'));
      await _snap(tester, 'NBW1-slip', lang);
    });

    testWidgets('NBW2 The kind chip: Note, To-do or Checklist [$lang]', (
      tester,
    ) async {
      await _open(tester, lang, [n.checklist()]);
      await _tap(tester, _key('post-bar-notepad'));
      await _tap(tester, _key('writing-kind-chip'));
      await _snap(tester, 'NBW2-kind-menu', lang);
    });

    testWidgets('NBW3 A to-do with by when and Remind me [$lang]', (
      tester,
    ) async {
      await _open(tester, lang, [_lina(n)]);
      await _todo(tester, l10n, n.sleevesTodo);
      await _snap(tester, 'NBW3-todo', lang);
    });

    testWidgets('NBW4 A checklist typed in place [$lang]', (tester) async {
      await _open(tester, lang, [n.todo()]);
      await _tap(tester, _key('post-bar-notepad'));
      await _tap(tester, _key('writing-kind-chip'));
      await _tap(tester, find.text(l10n.daybookKindChecklist).last);
      await tester.enterText(_key('writing-title'), n.walkTitle);
      await tester.pumpAndSettle();
      Finder empty() => find
          .descendant(
            of: _key('writing-points'),
            matching: find.byType(TextField),
          )
          .last;
      for (final p in n.walkPoints.take(2)) {
        await tester.enterText(empty(), p);
        await tester.pumpAndSettle();
      }
      await tester.tap(empty());
      await tester.pumpAndSettle();
      await _snap(tester, 'NBW4-checklist', lang);
    });

    testWidgets('NBW5 Left unsent: kept as a draft [$lang]', (tester) async {
      await _open(tester, lang, [n.checklist(), _lina(n)]);
      await _todo(tester, l10n, n.sleevesTodo);
      // Back: the slip is put down, kept as the Draft.
      await Navigator.of(tester.element(_key('note-tools'))).maybePop();
      await tester.pumpAndSettle();
      await _snap(tester, 'NBW5-draft', lang);
    });
  }
}
