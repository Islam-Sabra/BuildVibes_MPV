// The lead's check of review 115, one gesture model, in English and Arabic
// at 390 × 844 in the app's fonts: a Lead holds a Checked work item, and the
// hold bar holds Pin · Reminder · Archive, Archive last in red. Mirrored in
// Arabic. Run:
//   flutter test test_screens/r115_hold_test.dart --update-goldens
import 'dart:async';

import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/shared/widgets/bv_slip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../test/helpers/daybook_fakes.dart';
import '../test/helpers/daybook_samples.dart';
import '../test/helpers/fakes.dart';
import '../test/helpers/pump_app.dart';
import '../test/helpers/space_fakes.dart';
import 'shot.dart';

/// Saves the app as it is now to `docs/screens/r115/<name>_<lang>.png`.
Future<void> _snap(WidgetTester tester, String name, String lang) async {
  debugDisableShadows = false;
  try {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byType(MaterialApp).first,
      matchesGoldenFile('../docs/screens/r115/${name}_$lang.png'),
    );
  } finally {
    debugDisableShadows = true;
  }
}

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Navigator).first));

void main() {
  setUpAll(loadAppFonts);

  for (final lang in ['en', 'ar']) {
    final s = DaybookSamples(lang);

    testWidgets('HB1 a Lead holds a Checked work item: Pin · Reminder · '
        'Archive [$lang]', (tester) async {
      await pumpApp(
        tester,
        language: lang,
        auth: FakeAuthRepository(
          userId: DaybookSamples.islam,
          phone: '+96550000001',
        ),
        spaces: FakeSpaceRepository()
          ..details[DaybookSamples.space] = s.detail(pass: SpacePass.lead)
          ..spacePeople[DaybookSamples.space] = s.people(),
        daybook: FakeDaybookRepository()
          ..posts[DaybookSamples.space] = [s.gate()],
        now: DaybookSamples.thursday,
      );
      unawaited(_router(tester).push('/spaces/${DaybookSamples.space}'));
      await tester.pumpAndSettle();
      final card = find.byKey(const Key('daybook-card-post-gate'));
      await tester.longPress(
        find.descendant(of: card, matching: find.byType(BvSlip)).first,
      );
      await tester.pumpAndSettle();
      for (final k in ['select-pin', 'select-remind', 'select-archive']) {
        expect(find.byKey(Key(k)), findsOneWidget, reason: k);
      }
      await _snap(tester, 'HB1_hold_bar', lang);
    });
  }
}
