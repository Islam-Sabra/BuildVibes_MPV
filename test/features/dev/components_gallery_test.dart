import 'package:buildvibes/features/dev/components_gallery_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  for (final lang in ['en', 'ar']) {
    testWidgets(
      'gallery opens from Profile and shows every component [$lang]',
      (tester) async {
        await pumpApp(tester, language: lang);
        await tester.tap(find.byKey(const Key('nav-profile')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('row-components')));
        await tester.pumpAndSettle();
        expect(find.byType(ComponentsGalleryScreen), findsOneWidget);

        // Scroll through every section; any layout overflow fails the test.
        for (var i = 1; i <= 17; i++) {
          await tester.scrollUntilVisible(
            find.textContaining(RegExp('^$i · ')),
            300,
            // The list itself, not the chip rows inside it.
            scrollable: find
                .descendant(
                  of: find.byKey(const Key('gallery-list')),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
