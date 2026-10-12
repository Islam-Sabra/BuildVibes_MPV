import 'dart:convert';
import 'dart:io';

import 'package:buildvibes/app.dart';
import 'package:buildvibes/core/l10n/locale_controller.dart';
import 'package:buildvibes/core/share.dart';
import 'package:buildvibes/data/repositories/auth_repository.dart';
import 'package:buildvibes/data/repositories/market_repository.dart';
import 'package:buildvibes/data/repositories/profile_page_repository.dart';
import 'package:buildvibes/data/repositories/project_repository.dart';
import 'package:buildvibes/data/repositories/profile_repository.dart';
import 'package:buildvibes/data/repositories/reference_repository.dart';
import 'package:buildvibes/data/repositories/space_repository.dart';
import 'package:buildvibes/data/repositories/work_repository.dart';
import 'package:buildvibes/features/entry/entry_state.dart';
import 'package:buildvibes/features/profile/edit/experience_screens.dart';
import 'package:buildvibes/features/work/work_outbox.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';
import 'profile_fakes.dart';
import 'space_fakes.dart';
import 'work_fakes.dart';

/// A real 1 × 1 PNG on disk, the stand-in for a camera photo.
final String testPhotoPath = () {
  final dir = Directory.systemTemp.createTempSync('bv_test_photo');
  final file = File('${dir.path}/photo.png')
    ..writeAsBytesSync(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
      ),
    );
  return file.path;
}();

/// The fixed "today" of widget tests.
final testNow = DateTime(2026, 10, 11);

/// The fakes behind a pumped app, for assertions.
class TestApp {
  TestApp(
    this.prefs,
    this.auth,
    this.profiles,
    this.pages,
    this.projects, {
    required this.spaces,
    required this.shared,
    required this.work,
  });

  final SharedPreferences prefs;
  final FakeAuthRepository auth;
  final FakeProfileRepository profiles;
  final FakeProfilePageRepository pages;
  final FakeProjectRepository projects;
  final FakeSpaceRepository spaces;
  final FakeWorkRepository work;

  /// Texts sent to the system share sheet.
  final List<String> shared;
}

/// Pumps the whole app on a 390×844 phone, with no network.
///
/// By default the person is signed in and onboarded, so the app opens on
/// Home. [signedIn] false opens Welcome; [onboarded] false opens About you.
/// [phoneSignIn] switches the phone screens on (off in the MVP).
Future<TestApp> pumpApp(
  WidgetTester tester, {
  String? language,
  bool signedIn = true,
  bool onboarded = true,
  String region = 'KW',
  bool phoneSignIn = false,
  FakeAuthRepository? auth,
  FakeProfileRepository? profiles,
  FakeSpaceRepository? spaces,
  FakeWorkRepository? work,
  void Function(FakeProfilePageRepository, FakeProjectRepository)? setUp,
  List<Override> overrides = const [],
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

  final pages = FakeProfilePageRepository(fakeProfiles);
  final projects = FakeProjectRepository(
    pages,
    me: fakeAuth.currentUserId ?? FakeAuthRepository.newUserId,
  );
  setUp?.call(pages, projects);
  final fakeSpaces = spaces ?? FakeSpaceRepository(now: testNow);
  final shared = <String>[];
  final fakeWork = work ?? FakeWorkRepository();

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
        phoneSignInProvider.overrideWithValue(phoneSignIn),
        profilePageRepositoryProvider.overrideWithValue(pages),
        projectRepositoryProvider.overrideWithValue(projects),
        clockProvider.overrideWithValue(() => testNow),
        spaceRepositoryProvider.overrideWithValue(fakeSpaces),
        workRepositoryProvider.overrideWithValue(fakeWork),
        // No camera and no waiting between tries in tests.
        pickPhotoProvider.overrideWithValue(
          ({required camera}) async => XFile(testPhotoPath),
        ),
        // A fresh copy each time: a sent item deletes its kept copy.
        keepPhotoProvider.overrideWithValue(
          (photo) async => File(photo.path)
              .copySync(
                '${Directory.systemTemp.createTempSync('bv_kept').path}/kept.png',
              )
              .path,
        ),
        outboxRetryDelaysProvider.overrideWithValue(const [
          Duration.zero,
          Duration.zero,
        ]),
        shareTextProvider.overrideWithValue((text) async => shared.add(text)),
        ...overrides,
      ],
      child: const BuildVibesApp(),
    ),
  );
  await tester.pumpAndSettle();
  return TestApp(
    prefs,
    fakeAuth,
    fakeProfiles,
    pages,
    projects,
    spaces: fakeSpaces,
    shared: shared,
    work: fakeWork,
  );
}

TextDirection appDirection(WidgetTester tester) =>
    Directionality.of(tester.element(find.byType(Scaffold).first));
