// End-to-end: the main journey on an emulator, against the LOCAL Supabase
// (never live). Run with integration_test/run_e2e.ps1, which resets the
// local database, loads supabase/dev/seed_e2e.sql, runs this test and checks
// the database afterwards.
//
// The real app and the real backend; only the camera (a test photo) and the
// push permission prompt are stood in for.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:buildvibes/app.dart';
import 'package:buildvibes/core/l10n/locale_controller.dart';
import 'package:buildvibes/core/push/push_messaging.dart';
import 'package:buildvibes/data/supabase/supabase_provider.dart';
import 'package:buildvibes/features/entry/entry_state.dart';
import 'package:buildvibes/features/work/work_outbox.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The seed (supabase/dev/seed_e2e.sql): Omar runs "E2E site"; Rakesh joins.
const _space = 'E2E site';
const _code = 'E2ETST';
const _omar = '50000001';
const _rakesh = '50000003';
const _otp = '123456';
const _item = 'E2E rebar check level 3';
const _message = 'E2E concrete at 7';
const _post = 'E2E first pour on the podium is done';

final _en = lookupAppLocalizations(const Locale('en'));

/// No permission prompt in an automated run, and no Firebase.
class _NoPush implements PushMessaging {
  @override
  Future<PushPermission> permission() async => PushPermission.denied;
  @override
  Future<PushPermission> requestPermission() async => PushPermission.denied;
  @override
  Future<String?> token() async => null;
  @override
  Stream<String> get tokenRefresh => const Stream.empty();
  @override
  Future<Map<String, String>?> initialTap() async => null;
  @override
  Stream<Map<String, String>> get taps => const Stream.empty();
  @override
  Stream<Map<String, String>> get foreground => const Stream.empty();
  @override
  Future<void> openSettings() async {}
  @override
  String get platform => 'android';
}

/// A real 1 × 1 PNG, the stand-in for a camera photo.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

Future<String> _photoCopy() async {
  final dir = await Directory.systemTemp.createTemp('e2e_photo');
  final file = File('${dir.path}/site.png')..writeAsBytesSync(_png);
  return file.path;
}

// ---------------------------------------------------------------------------
// Driving the app (real time, real network: no pumpAndSettle on spinners)
// ---------------------------------------------------------------------------

Future<void> _pumpFor(WidgetTester tester, Duration d) async {
  final end = DateTime.now().add(d);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Waits until [finder] finds something, or fails after [timeout].
Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for $finder');
}

/// The words of any snackbar the app shows now, for failure messages.
String _shown() => find
    .descendant(of: find.byType(SnackBar), matching: find.byType(Text))
    .evaluate()
    .map((e) => (e.widget as Text).data)
    .join(' | ');

/// Every text on screen now, for failure messages.
String _screen() => find
    .byType(Text)
    .evaluate()
    .map((e) => (e.widget as Text).data ?? '')
    .where((t) => t.trim().isNotEmpty)
    .join(' | ');

/// Like [_waitGone], but says what the app showed when it fails.
Future<void> _done(WidgetTester tester, String key, String step) async {
  final finder = find.byKey(Key(key));
  final end = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isEmpty) return;
  }
  fail('$step did not finish. The app showed: ${_shown()}');
}

Future<void> _tapFinder(WidgetTester tester, Finder finder) async {
  await _waitFor(tester, finder);
  await tester.ensureVisible(finder.first);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(finder.first);
  await _pumpFor(tester, const Duration(milliseconds: 800));
}

Future<void> _tap(WidgetTester tester, String key) =>
    _tapFinder(tester, find.byKey(Key(key)));

/// A key that starts with [prefix] (ids we don't know in advance).
Finder _keyStarting(String prefix) => find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith(prefix),
);

Future<void> _type(WidgetTester tester, Finder field, String text) async {
  await _waitFor(tester, field);
  await tester.enterText(field.first, text);
  await _pumpFor(tester, const Duration(milliseconds: 500));
}

Finder _fieldIn(String key) =>
    find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField));

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Navigator).first));

Future<void> _go(WidgetTester tester, String path) async {
  _router(tester).go(path);
  await _pumpFor(tester, const Duration(seconds: 1));
}

/// When each number was last sent a code: the server allows one a minute
/// per number (supabase/config.toml).
final _lastCode = <String, DateTime>{};

Future<void> _signIn(WidgetTester tester, String national) async {
  await _tap(tester, 'welcome-sign-in');
  await _tap(tester, 'join-phone');
  // The country code comes from the market pack, loaded from the server.
  await _waitFor(
    tester,
    find.descendant(
      of: find.byKey(const Key('dial-code-box')),
      matching: find.text('+965'),
    ),
  );
  await _type(tester, _fieldIn('phone-field'), national);
  final last = _lastCode[national];
  if (last != null) {
    final wait = last
        .add(const Duration(seconds: 62))
        .difference(DateTime.now());
    if (wait > Duration.zero) await _pumpFor(tester, wait);
  }
  final code = find.byKey(const Key('code-input'));
  final seen = <String>{};
  await _tap(tester, 'phone-send');
  _lastCode[national] = DateTime.now();
  // Sending a code can take a while on the local stack.
  final end = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(end) && code.evaluate().isEmpty) {
    await tester.pump(const Duration(milliseconds: 200));
    final now = _shown();
    if (now.isNotEmpty) seen.add(now);
  }
  if (code.evaluate().isEmpty) {
    fail(
      'No code screen after sending a code to $national. Snackbars: $seen. '
      'On screen: ${_screen()}',
    );
  }
  await _type(tester, code, _otp);
  await _waitFor(tester, find.byKey(const Key('nav-home')));
}

Future<void> _signOut(WidgetTester tester) async {
  await _go(tester, '/profile');
  await _tap(tester, 'profile-settings');
  await _tap(tester, 'row-sign-out');
  await _tap(tester, 'bv-dialog-confirm');
  await _waitFor(tester, find.byKey(const Key('welcome-sign-in')));
}

Future<void> _openSpace(WidgetTester tester) async {
  await _go(tester, '/profile');
  await _tap(tester, 'profile-spaces');
  await _tapFinder(tester, find.text(_space));
  await _waitFor(tester, find.byKey(const Key('space-tab-work')));
}

Future<void> _openItem(WidgetTester tester) async {
  await _openSpace(tester);
  await _tap(tester, 'space-tab-work');
  // A card from the server, not one still waiting on the phone.
  await _tapFinder(tester, _keyStarting('work-item-'));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the main journey, two people, against the local database', (
    tester,
  ) async {
    await initSupabase();
    SharedPreferences.setMockInitialValues({'app_language': 'en'});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          phoneSignInProvider.overrideWithValue(true),
          pushMessagingProvider.overrideWithValue(_NoPush()),
          pickPhotoProvider.overrideWithValue(
            ({required camera}) async => XFile(await _photoCopy()),
          ),
          keepPhotoProvider.overrideWithValue((photo) async {
            final copy = await _photoCopy();
            return File(
              photo.path,
            ).copySync(copy.replaceAll('site', 'kept')).path;
          }),
        ],
        child: const BuildVibesApp(),
      ),
    );
    await _waitFor(tester, find.byKey(const Key('welcome-sign-in')));

    // 1. Rakesh signs in and asks to join "E2E site" with the code.
    await _signIn(tester, _rakesh);
    await _tapFinder(
      tester,
      find.descendant(
        of: find.byKey(const Key('home-tabs')),
        matching: find.byKey(const Key('tab-1')),
      ),
    );
    await _tap(tester, 'spaces-enter-code');
    await _type(tester, _fieldIn('invite-code-field'), _code);
    await _waitFor(tester, find.byKey(const Key('invite-preview')));
    await _tap(tester, 'ask-to-join');
    // The server said yes: "Request sent", then the waiting card.
    await _waitFor(
      tester,
      find.byWidgetPredicate(
        (w) =>
            (w is Text && w.data == _en.spacesRequestSent) ||
            (w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith(
                  'cancel-request-',
                )),
      ),
    );
    await _signOut(tester);

    // 2. Omar, the admin, confirms him as Crew and gives him a work item.
    await _signIn(tester, _omar);
    await _openSpace(tester);
    await _tap(tester, 'space-tab-people');
    await _tapFinder(tester, _keyStarting('request-confirm-'));
    await _tap(tester, 'confirm-pass-crew');
    await _tap(tester, 'confirm-sheet-confirm');
    await _pumpFor(tester, const Duration(seconds: 2));
    await _openSpace(tester);
    await _tap(tester, 'space-tab-work');
    await _tap(tester, 'work-new-item');
    await _type(tester, _fieldIn('work-title'), _item);
    await _tap(tester, 'work-owner');
    await _tapFinder(tester, find.text('Rakesh Nair'));
    await _tap(tester, 'work-create');
    await _done(tester, 'work-create', 'Create');
    await _waitFor(tester, _keyStarting('work-item-'));
    expect(_keyStarting('work-pending-'), findsNothing);
    await _signOut(tester);

    // 3. Rakesh signs it as done with a photo, writes in chat, and posts.
    await _signIn(tester, _rakesh);
    await _openItem(tester);
    await _tap(tester, 'work-sign-done');
    await _tap(tester, 'sign-done-add-photo');
    await _tap(tester, 'sign-done-confirm');
    await _done(tester, 'work-sign-done', 'Sign as done');
    await _openSpace(tester);
    await _tap(tester, 'space-tab-chat');
    await _tap(tester, 'chat-everyone-tile');
    await _type(tester, find.byKey(const Key('chat-input')), _message);
    await _tap(tester, 'chat-send');
    await _waitFor(tester, find.text(_message));
    await _go(tester, '/home');
    await _tap(tester, 'nav-create');
    await _type(tester, find.byKey(const Key('composer-text')), _post);
    await _tap(tester, 'composer-post');
    await _waitFor(tester, find.text(_post));
    await _signOut(tester);

    // 4. Omar checks and closes it.
    await _signIn(tester, _omar);
    await _openItem(tester);
    await _tap(tester, 'work-check');
    await _tap(tester, 'bv-dialog-confirm');
    await _done(tester, 'work-check', 'Check and close');
    await _signOut(tester);
  });
}
