import 'dart:convert';
import 'dart:io';

import 'package:buildvibes/app.dart';
import 'package:buildvibes/core/l10n/locale_controller.dart';
import 'package:buildvibes/core/share.dart';
import 'package:buildvibes/data/repositories/account_repository.dart';
import 'package:buildvibes/data/repositories/activity_repository.dart';
import 'package:buildvibes/core/push/push_messaging.dart';
import 'package:buildvibes/data/repositories/auth_repository.dart';
import 'package:buildvibes/data/repositories/push_repository.dart';
import 'package:buildvibes/data/repositories/safety_repository.dart';
import 'package:buildvibes/data/models/library.dart';
import 'package:buildvibes/data/repositories/chat_repository.dart';
import 'package:buildvibes/data/repositories/daybook_repository.dart';
import 'package:buildvibes/data/repositories/library_repository.dart';
import 'package:buildvibes/data/repositories/post_repository.dart';
import 'package:buildvibes/data/repositories/market_repository.dart';
import 'package:buildvibes/data/repositories/profile_page_repository.dart';
import 'package:buildvibes/data/repositories/project_repository.dart';
import 'package:buildvibes/data/repositories/profile_repository.dart';
import 'package:buildvibes/data/repositories/reference_repository.dart';
import 'package:buildvibes/data/repositories/space_repository.dart';
import 'package:buildvibes/data/repositories/work_repository.dart';
import 'package:buildvibes/features/chat/chat_state.dart';
import 'package:buildvibes/features/chat/voice.dart';
import 'package:buildvibes/features/entry/entry_state.dart';
import 'package:buildvibes/features/library/library_parts.dart';
import 'package:buildvibes/features/profile/edit/experience_screens.dart';
import 'package:buildvibes/features/work/work_outbox.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'account_fakes.dart';
import 'activity_fakes.dart';
import 'chat_fakes.dart';
import 'daybook_fakes.dart';
import 'fakes.dart';
import 'library_fakes.dart';
import 'post_fakes.dart';
import 'push_fakes.dart';
import 'safety_fakes.dart';
import 'voice_fakes.dart';
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

/// A tiny PDF on disk, the stand-in for a drawing picked on the phone.
final String testPdfPath = () {
  final dir = Directory.systemTemp.createTempSync('bv_test_pdf');
  return (File(
    '${dir.path}/plan.pdf',
  )..writeAsStringSync('%PDF-1.4\n%test\n')).path;
}();

const _textScale =
    int.fromEnvironment('BV_TEXT_SCALE_PERCENT', defaultValue: 100) / 100;

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
    required this.daybook,
    required this.chat,
    required this.library,
    required this.recorder,
    required this.posts,
    required this.playback,
    required this.saved,
    required this.sharedFiles,
    required this.activity,
    required this.push,
    required this.pushes,
    required this.safety,
    required this.account,
    required this.opened,
  });

  final SharedPreferences prefs;
  final FakeAuthRepository auth;
  final FakeProfileRepository profiles;
  final FakeProfilePageRepository pages;
  final FakeProjectRepository projects;
  final FakeSpaceRepository spaces;
  final FakeWorkRepository work;
  final FakeDaybookRepository daybook;
  final FakeChatRepository chat;
  final FakeLibraryRepository library;
  final FakeVoiceRecorder recorder;
  final FakePostRepository posts;
  final FakeVoicePlayback playback;
  final FakeActivityRepository activity;

  /// The phone's push side, and the server calls (register, settings).
  final FakePushMessaging push;
  final FakePushRepository pushes;

  /// Report, block and appeal calls.
  final FakeSafetyRepository safety;

  /// Delete account, Download my data, the home market.
  final FakeAccountRepository account;

  /// Links and email addresses opened with the phone.
  final List<Uri> opened;

  /// Files saved with Download, and shared through the phone (F1).
  final List<String> saved;
  final List<String> sharedFiles;

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

  /// The phone's "now" (default [testNow]).
  DateTime? now,
  FakeAuthRepository? auth,
  FakeProfileRepository? profiles,
  FakeSpaceRepository? spaces,
  FakeWorkRepository? work,
  FakeDaybookRepository? daybook,
  FakeChatRepository? chat,
  FakeLibraryRepository? library,
  FakeVoiceRecorder? recorder,
  FakePostRepository? posts,
  FakeActivityRepository? activity,
  FakePushMessaging? push,
  FakeSafetyRepository? safety,
  FakeAccountRepository? account,

  /// What the phone's file picker returns (default: a PDF drawing).
  PhoneFile? Function()? pickDocument,
  void Function(FakeProfilePageRepository, FakeProjectRepository)? setUp,
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(390, 844);
  // The Arabic pass runs every test at a larger text size too:
  // flutter test --dart-define=BV_TEXT_SCALE_PERCENT=130
  tester.platformDispatcher.textScaleFactorTestValue = _textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
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
  final fakeDaybook = daybook ?? FakeDaybookRepository();
  final fakeChat = chat ?? FakeChatRepository(now: testNow);
  final fakeLibrary = library ?? FakeLibraryRepository(now: testNow);
  final fakeRecorder = recorder ?? FakeVoiceRecorder();
  final fakePosts = posts ?? FakePostRepository(now: testNow);
  final fakePlayback = FakeVoicePlayback();
  final fakeActivity = activity ?? FakeActivityRepository();
  final fakePush = push ?? FakePushMessaging();
  final fakePushes = FakePushRepository();
  final fakeSafety = safety ?? FakeSafetyRepository();
  final fakeAccount = (account ?? FakeAccountRepository())
    ..profiles ??= fakeProfiles;
  final opened = <Uri>[];
  final saved = <String>[];
  final sharedFiles = <String>[];

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
        clockProvider.overrideWithValue(() => now ?? testNow),
        spaceRepositoryProvider.overrideWithValue(fakeSpaces),
        workRepositoryProvider.overrideWithValue(fakeWork),
        daybookRepositoryProvider.overrideWithValue(fakeDaybook),
        chatRepositoryProvider.overrideWithValue(fakeChat),
        libraryRepositoryProvider.overrideWithValue(fakeLibrary),
        voiceRecorderProvider.overrideWithValue(fakeRecorder),
        postRepositoryProvider.overrideWithValue(fakePosts),
        activityRepositoryProvider.overrideWithValue(fakeActivity),
        pushMessagingProvider.overrideWithValue(fakePush),
        pushRepositoryProvider.overrideWithValue(fakePushes),
        safetyRepositoryProvider.overrideWithValue(fakeSafety),
        accountRepositoryProvider.overrideWithValue(fakeAccount),
        openLinkProvider.overrideWithValue((uri) async {
          opened.add(uri);
          return true;
        }),
        voicePlaybackProvider.overrideWithValue(fakePlayback),
        pickDocumentProvider.overrideWithValue(
          ({bool pdfOnly = false}) async =>
              pickDocument?.call() ??
              PhoneFile(
                local: testPdfPath,
                name: 'Level 3 plan.pdf',
                mime: 'application/pdf',
                bytes: 4800000,
              ),
        ),
        keepFileProvider.overrideWithValue(
          (path, ext) async => File(path)
              .copySync(
                '${Directory.systemTemp.createTempSync('bv_kept').path}/kept.$ext',
              )
              .path,
        ),
        saveFileProvider.overrideWithValue((name, bytes) async {
          saved.add(name);
          return true;
        }),
        shareFileProvider.overrideWithValue(
          (name, mime, bytes) async => sharedFiles.add(name),
        ),
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
    daybook: fakeDaybook,
    chat: fakeChat,
    library: fakeLibrary,
    recorder: fakeRecorder,
    posts: fakePosts,
    playback: fakePlayback,
    saved: saved,
    sharedFiles: sharedFiles,
    activity: fakeActivity,
    push: fakePush,
    pushes: fakePushes,
    safety: fakeSafety,
    account: fakeAccount,
    opened: opened,
  );
}

TextDirection appDirection(WidgetTester tester) =>
    Directionality.of(tester.element(find.byType(Scaffold).first));
