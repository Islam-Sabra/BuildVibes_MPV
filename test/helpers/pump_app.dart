import 'package:buildvibes/app.dart';
import 'package:buildvibes/core/l10n/locale_controller.dart';
import 'package:buildvibes/data/repositories/market_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pumps the whole app on a 390×844 phone. [language] is a saved choice.
Future<SharedPreferences> pumpApp(
  WidgetTester tester, {
  String? language,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.localesTestValue = const [Locale('en')];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);

  SharedPreferences.setMockInitialValues({'app_language': ?language});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        // No network in widget tests.
        marketsProvider.overrideWith((ref) async => const []),
      ],
      child: const BuildVibesApp(),
    ),
  );
  await tester.pumpAndSettle();
  return prefs;
}

TextDirection appDirection(WidgetTester tester) =>
    Directionality.of(tester.element(find.byType(Scaffold).first));
