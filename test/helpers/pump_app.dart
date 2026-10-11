import 'package:buildvibes/app.dart';
import 'package:buildvibes/core/l10n/locale_controller.dart';
import 'package:buildvibes/data/repositories/auth_repository.dart';
import 'package:buildvibes/data/repositories/market_repository.dart';
import 'package:buildvibes/data/repositories/profile_repository.dart';
import 'package:buildvibes/data/repositories/reference_repository.dart';
import 'package:buildvibes/features/entry/entry_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

/// The fakes behind a pumped app, for assertions.
class TestApp {
  TestApp(this.prefs, this.auth, this.profiles);

  final SharedPreferences prefs;
  final FakeAuthRepository auth;
  final FakeProfileRepository profiles;
}

/// Pumps the whole app on a 390×844 phone, with no network.
///
/// By default the person is signed in and onboarded, so the app opens on
/// Home. [signedIn] false opens Welcome; [onboarded] false opens About you.
Future<TestApp> pumpApp(
  WidgetTester tester, {
  String? language,
  bool signedIn = true,
  bool onboarded = true,
  String region = 'KW',
  FakeAuthRepository? auth,
  FakeProfileRepository? profiles,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.localesTestValue = const [Locale('en')];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);

  SharedPreferences.setMockInitialValues({'app_language': ?language});
  final prefs = await SharedPreferences.getInstance();

  final fakeAuth =
      auth ??
      FakeAuthRepository(
        userId: signedIn ? 'user-1' : null,
        phone: signedIn ? '+96550000001' : null,
      );
  final fakeProfiles = profiles ?? FakeProfileRepository();
  if (signedIn && onboarded && fakeAuth.currentUserId != null) {
    fakeProfiles.profiles[fakeAuth.currentUserId!] = completeProfile(
      fakeAuth.currentUserId!,
    );
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authRepositoryProvider.overrideWithValue(fakeAuth),
        profileRepositoryProvider.overrideWithValue(fakeProfiles),
        referenceRepositoryProvider.overrideWithValue(
          FakeReferenceRepository(),
        ),
        marketsProvider.overrideWith((ref) async => testMarkets),
        deviceRegionProvider.overrideWithValue(region),
      ],
      child: const BuildVibesApp(),
    ),
  );
  await tester.pumpAndSettle();
  return TestApp(prefs, fakeAuth, fakeProfiles);
}

TextDirection appDirection(WidgetTester tester) =>
    Directionality.of(tester.element(find.byType(Scaffold).first));
