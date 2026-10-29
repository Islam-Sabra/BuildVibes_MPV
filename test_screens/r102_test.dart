// Review 102: the shots it adds, in English and Arabic at 390 × 844 in the
// app's fonts. N2: the time wheels (a reminder today at 10:57, so the times
// already passed are greyed). N5: a page's Filter card with SORT, and the
// chip of a sort that isn't the default. Review 104 N11: the one picker
// opens on the clock face; the wheels are its second mode. Run:
//   flutter test test_screens/r102_test.dart --update-goldens
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_time_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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
    Future<void> time(WidgetTester tester, BvTimeMode mode) async {
      await pumpApp(
        tester,
        language: lang,
        now: NotebookPageSamples.now,
        notebook: NotebookPageSamples(lang).repository(),
        stored: {timePickerModeKey: mode.name},
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(Navigator).first);
      showBvTimePicker(
        context,
        initial: const TimeOfDay(hour: 11, minute: 55),
        title: lookupAppLocalizations(Locale(lang)).notebookRemindTime,
        after: const TimeOfDay(hour: 10, minute: 57),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('N2 the time wheels [$lang]', (tester) async {
      await time(tester, BvTimeMode.wheels);
      await _snap(tester, 'N2-time-wheel', lang);
    });

    testWidgets('N11 the clock face, the default [$lang]', (tester) async {
      await time(tester, BvTimeMode.clock);
      await _snap(tester, 'N11-time-clock', lang);
    });

    Future<void> page(WidgetTester tester) async {
      await pumpApp(
        tester,
        language: lang,
        now: NotebookPageSamples.now,
        notebook: NotebookPageSamples(lang).repository(),
      );
      GoRouter.of(
        tester.element(find.byType(Navigator).first),
      ).push('/notebook/pages/${NotebookPageSamples.siteA}');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('page-filter')));
      await tester.pumpAndSettle();
    }

    testWidgets('N5 the Filter card with SORT in a page [$lang]', (
      tester,
    ) async {
      await page(tester);
      await _snap(tester, 'N5-page-filter', lang);
    });

    testWidgets('N5 the chip of Oldest first [$lang]', (tester) async {
      await page(tester);
      await tester.tap(find.byKey(const Key('sort-oldest')));
      await tester.pumpAndSettle();
      await _snap(tester, 'N5-sort-chip', lang);
    });
  }
}
