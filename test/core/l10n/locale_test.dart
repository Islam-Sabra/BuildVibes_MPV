import 'package:buildvibes/core/l10n/locale_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  group('resolveAppLocale', () {
    test('uses Arabic when the phone is in Arabic', () {
      expect(resolveAppLocale(const [Locale('ar', 'KW')]), const Locale('ar'));
    });

    test('falls back to English for other languages', () {
      expect(resolveAppLocale(const [Locale('fr')]), const Locale('en'));
      expect(resolveAppLocale(null), const Locale('en'));
    });
  });

  testWidgets('switching to Arabic turns the app right to left and is saved', (
    tester,
  ) async {
    final prefs = (await pumpApp(tester)).prefs;
    expect(appDirection(tester), TextDirection.ltr);

    await tester.tap(find.byKey(const Key('nav-profile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('row-language')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('language-ar')));
    await tester.pumpAndSettle();

    expect(appDirection(tester), TextDirection.rtl);
    expect(find.text('لغة التطبيق'), findsOneWidget);
    expect(prefs.getString('app_language'), 'ar');
  });

  testWidgets('a saved language is used on start', (tester) async {
    await pumpApp(tester, language: 'ar');
    expect(appDirection(tester), TextDirection.rtl);
  });
}
