// Review 110: the bottom bar at 360 dp wide (the founder's phone, 720 px
// at density 2) fits: no overflow, all five slots in reach. In English and
// Arabic.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  for (final lang in ['en', 'ar']) {
    testWidgets('360 dp: the five slots fit, no overflow [$lang]', (
      tester,
    ) async {
      await pumpApp(tester, language: lang);
      tester.view.physicalSize = const Size(360, 825);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final k in [
        'nav-home',
        'nav-explore',
        'nav-create',
        'nav-activity',
        'nav-profile',
      ]) {
        final r = tester.getRect(find.byKey(Key(k)));
        expect(r.left, greaterThanOrEqualTo(0), reason: k);
        expect(r.right, lessThanOrEqualTo(360), reason: k);
      }
    });
  }
}
