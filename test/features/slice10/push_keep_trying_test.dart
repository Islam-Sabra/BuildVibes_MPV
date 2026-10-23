import 'package:buildvibes/core/network/signal_state.dart';
import 'package:buildvibes/core/push/push_messaging.dart';
import 'package:buildvibes/core/push/push_state.dart';
import 'package:buildvibes/features/settings/push_host.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/push_fakes.dart';

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)).first);
  await tester.tap(find.byKey(Key(key)).first);
  await tester.pumpAndSettle();
}

Future<void> _openNotifications(WidgetTester tester) async {
  await _tap(tester, 'nav-profile');
  await _tap(tester, 'profile-settings');
  await _tap(tester, 'row-notifications');
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(PushHost)));

/// F96 (review 50, review 87): the phone keeps trying for its push token.
void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    // pumpApp's tries: the first and two more.
    const firstTries = 3;

    testWidgets('F96: after the tries, every 30 minutes while open, until '
        'the token comes; then it is registered and forgotten [$lang]', (
      tester,
    ) async {
      final push = FakePushMessaging(
        current: PushPermission.granted,
        tokenFailures: firstTries + 1,
      );
      final app = await pumpApp(
        tester,
        language: lang,
        push: push,
        overrides: [
          pushKeepTryingProvider.overrideWithValue(const Duration(minutes: 30)),
        ],
      );
      expect(push.tokenAsks, firstTries);
      expect(find.byKey(const Key('push-not-reaching')), findsOneWidget);
      expect(
        app.prefs.getString(pushNoTokenSinceKey),
        testNow.toUtc().toIso8601String(),
      );
      await tester.pump(const Duration(minutes: 29));
      expect(push.tokenAsks, firstTries, reason: 'not before 30 minutes');
      await tester.pump(const Duration(minutes: 1));
      await tester.pumpAndSettle();
      expect(push.tokenAsks, firstTries + 1);
      expect(app.pushes.calls, isEmpty, reason: 'that one failed too');
      await tester.pump(const Duration(minutes: 30));
      await tester.pumpAndSettle();
      expect(push.tokenAsks, firstTries + 2);
      expect(
        app.pushes.calls.single,
        'register fcm-test-token-0123456789 android $lang',
      );
      expect(find.byKey(const Key('push-not-reaching')), findsNothing);
      expect(app.prefs.containsKey(pushNoTokenSinceKey), isFalse);
      await tester.pump(const Duration(hours: 2));
      expect(push.tokenAsks, firstTries + 2, reason: 'the timer stopped');
    });

    testWidgets('F96: when the signal comes back, it tries again [$lang]', (
      tester,
    ) async {
      final push = FakePushMessaging(
        current: PushPermission.granted,
        tokenFailures: firstTries,
      );
      final app = await pumpApp(tester, language: lang, push: push);
      expect(app.pushes.calls, isEmpty);
      final signal = _container(tester).read(signalProvider.notifier);
      signal.lost();
      await tester.pumpAndSettle();
      expect(push.tokenAsks, firstTries, reason: 'not while it is lost');
      signal.back();
      await tester.pumpAndSettle();
      expect(
        app.pushes.calls.single,
        'register fcm-test-token-0123456789 android $lang',
      );
    });

    testWidgets('F96: a token the server missed is given again when the '
        'signal comes back [$lang]', (tester) async {
      final push = FakePushMessaging(current: PushPermission.granted);
      final app = await pumpApp(tester, language: lang, push: push);
      app.pushes.failNext = true;
      push.refreshToken('fcm-new-token-0123456789abcdef');
      await tester.pumpAndSettle();
      final signal = _container(tester).read(signalProvider.notifier)..lost();
      await tester.pumpAndSettle();
      signal.back();
      await tester.pumpAndSettle();
      expect(
        app.pushes.calls.last,
        'register fcm-new-token-0123456789abcdef android $lang',
      );
    });

    testWidgets('F96: after a day without a token, Settings says to restart '
        'the phone; Home keeps its line [$lang]', (tester) async {
      final push = FakePushMessaging(
        current: PushPermission.granted,
        tokenFailures: 99,
      );
      await pumpApp(
        tester,
        language: lang,
        push: push,
        stored: {
          pushNoTokenSinceKey: testNow
              .subtract(const Duration(hours: 25))
              .toUtc()
              .toIso8601String(),
        },
      );
      expect(find.text(l10n.pushNotReaching), findsOneWidget);
      await _openNotifications(tester);
      expect(find.byKey(const Key('push-not-yet')), findsOneWidget);
      expect(find.text(l10n.pushNotYet), findsOneWidget);
      expect(find.text(l10n.pushFixIt), findsWidgets);
    });

    testWidgets('F96: under a day, Settings has the F9 line [$lang]', (
      tester,
    ) async {
      final push = FakePushMessaging(
        current: PushPermission.granted,
        tokenFailures: 99,
      );
      await pumpApp(
        tester,
        language: lang,
        push: push,
        stored: {
          pushNoTokenSinceKey: testNow
              .subtract(const Duration(hours: 23))
              .toUtc()
              .toIso8601String(),
        },
      );
      await _openNotifications(tester);
      expect(find.byKey(const Key('push-not-reaching')), findsOneWidget);
      expect(find.byKey(const Key('push-not-yet')), findsNothing);
    });
  }
}
