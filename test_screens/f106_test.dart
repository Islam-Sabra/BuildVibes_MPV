// F106 (review 90): My notebook writes in place, against NBW1–NBW5 (EN
// 2613:36507, 2613:36619, 2613:36731, 2613:36843, 2613:36956; AR
// 2613:37050, 2613:37162, 2613:37274, 2613:37386, 2613:37499). English and
// Arabic, at 390 × 844 on a 12-hour phone, in the app's fonts. The frames
// draw a keyboard under the tools; a test has none. F107 (review 92): the
// slip is a page and the kind chip has gone, so NBW2 has no shot. Review
// 100 H22: NBW3, NBW4 and NBW5 are retired (BH6, BH7 and BH3 replace
// them); NBW1 stays.
// Run:
//   flutter test test_screens/f106_test.dart --update-goldens
import 'package:buildvibes/data/models/note.dart';
import 'package:buildvibes/features/work/daybook_writing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../test/helpers/notebook_fakes.dart';
import '../test/helpers/notebook_samples.dart';
import '../test/helpers/pump_app.dart';
import 'shot.dart';

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
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/notebook/pages/page-my-notes');
  await tester.pumpAndSettle();
  return app;
}

void main() {
  setUpAll(loadAppFonts);

  for (final lang in ['en', 'ar']) {
    final n = NotebookSamples(lang);

    testWidgets('NBW1 Tap Note: a slip at the end of today [$lang]', (
      tester,
    ) async {
      await _open(tester, lang, [n.checklist()]);
      await _tap(tester, _key('page-write'));
      await _snap(tester, 'NBW1-slip', lang);
    });
  }
}
