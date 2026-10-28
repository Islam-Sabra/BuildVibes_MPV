// LOCAL ONLY (review 101 K3): how the busy Space opens and scrolls, in
// profile mode on a device, against the local Supabase with
// supabase/dev/seed_busy_space.sql loaded. Never against the live project.
// The seed's lead signs in by the local test phone 96550000002 (code
// 123456, supabase/config.toml); give her that phone first:
//   update auth.users set phone = '96550000002', phone_confirmed_at = now()
//   where id = 'b05e0000-0000-0000-0000-000000000001';
// Run (the Space's id from the seed, the local env file):
//   flutter drive --profile --driver=test_driver/perf_driver.dart
//     --target=integration_test/busy_space_perf_test.dart
//     --dart-define-from-file=env/local.json --dart-define=BUSY_SPACE=<id>
//     -d <device>
// A profile build uses https only: for the run, copy
// android/app/src/debug/res/xml/network_security_config.xml into
// src/profile/res/xml and point src/profile/AndroidManifest.xml at it, then
// take both back out. Use an emulator or a phone with no release app on it
// (a profile build is signed with the debug key).
// It reports the time from opening the Space to its first card, and the
// frames while flinging up through all 500 posts. Numbers only.
import 'package:buildvibes/app.dart';
import 'package:buildvibes/core/l10n/locale_controller.dart';
import 'package:buildvibes/core/push/push_messaging.dart';
import 'package:buildvibes/data/supabase/supabase_provider.dart';
import 'package:buildvibes/features/work/daybook_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _space = String.fromEnvironment('BUSY_SPACE');
const _phone = '96550000002';

/// The oldest post (i = 499, a checklist): the page's top.
const _oldest = 'Checklist 499';

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
  Future<void> openAppSettings() async {}
  @override
  Future<void> clearNotification(String tag) async {}
  @override
  Future<List<String>> phoneMakers() async => const [];
  @override
  void reportNoToken() {}
  @override
  String get platform => 'android';
}

Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  final end = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 16));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for $finder');
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the busy Space: opened, then flung up through 500 posts', (
    tester,
  ) async {
    expect(_space, isNotEmpty, reason: '--dart-define=BUSY_SPACE=<id>');
    await initSupabase();
    final auth = Supabase.instance.client.auth;
    // The test code works without a new one sent (one a minute at most).
    try {
      await auth.verifyOTP(phone: _phone, token: '123456', type: OtpType.sms);
    } on AuthException {
      await auth.signInWithOtp(phone: _phone);
      await auth.verifyOTP(phone: _phone, token: '123456', type: OtpType.sms);
    }
    SharedPreferences.setMockInitialValues({'app_language': 'en'});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          pushMessagingProvider.overrideWithValue(_NoPush()),
        ],
        child: const BuildVibesApp(),
      ),
    );
    await _waitFor(tester, find.byKey(const Key('nav-home')));
    // Frames as the phone makes them, not as the test asks for them.
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

    final open = Stopwatch()..start();
    GoRouter.of(
      tester.element(find.byType(Navigator).first),
    ).push('/spaces/$_space');
    await _waitFor(tester, find.byType(DaybookCardView));
    open.stop();
    await Future<void>.delayed(const Duration(seconds: 2));

    var flings = 0;
    await binding.watchPerformance(() async {
      final page = find.byKey(const Key('daybook'));
      while (flings < 200 && find.text(_oldest).evaluate().isEmpty) {
        await tester.fling(page, const Offset(0, 600), 3000);
        flings++;
        await Future<void>.delayed(const Duration(milliseconds: 700));
      }
    }, reportKey: 'fling');
    binding.reportData = {
      ...?binding.reportData,
      'open_ms': open.elapsedMilliseconds,
      'flings': flings,
      'reached_oldest': find.text(_oldest).evaluate().isNotEmpty,
    };
  });
}
