// Review 102: the shots it adds, in English and Arabic at 390 × 844 in the
// app's fonts. N2: the time wheels (a reminder today at 10:57, so the times
// already passed are greyed). Run:
//   flutter test test_screens/r102_test.dart --update-goldens
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_time_wheel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/helpers/notebook_page_samples.dart';
import '../test/helpers/pump_app.dart';
import 'shot.dart';

/// Saves the app as it is now to `docs/screens/r102/<name>_<lang>.png`.
Future<void> _snap(WidgetTester tester, String name, String lang) async {
  debugDisableShadows = false;
  try {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byType(MaterialApp).first,
      matchesGoldenFile('../docs/screens/r102/${name}_$lang.png'),
    );
  } finally {
    debugDisableShadows = true;
  }
}

void main() {
  setUpAll(loadAppFonts);

  for (final lang in ['en', 'ar']) {
    testWidgets('N2 the time wheels [$lang]', (tester) async {
      await pumpApp(
        tester,
        language: lang,
        now: NotebookPageSamples.now,
        notebook: NotebookPageSamples(lang).repository(),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(Navigator).first);
      showBvTimeWheel(
        context,
        initial: const TimeOfDay(hour: 11, minute: 55),
        title: lookupAppLocalizations(Locale(lang)).notebookRemindTime,
        after: const TimeOfDay(hour: 10, minute: 57),
      );
      await tester.pumpAndSettle();
      await _snap(tester, 'N2-time-wheel', lang);
    });
  }
}
