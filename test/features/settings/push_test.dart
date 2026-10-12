import 'package:buildvibes/core/push/push_messaging.dart';
import 'package:buildvibes/features/feed/post_screen.dart';
import 'package:buildvibes/features/settings/notifications_screen.dart';
import 'package:buildvibes/features/settings/push_host.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/push_fakes.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

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

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);

    testWidgets('the first time the tabs open: asked once, then this phone '
        'is registered in the app language [$lang]', (tester) async {
      final app = await pumpApp(tester, language: lang);
      expect(app.push.asked, 1);
      expect(app.prefs.getBool(pushAskedKey), isTrue);
      expect(
        app.pushes.calls,
        contains('register fcm-test-token-0123456789 android $lang'),
      );
      // A new token is registered too.
      app.push.refreshToken('fcm-new-token-0123456789');
      await tester.pumpAndSettle();
      expect(
        app.pushes.calls.last,
        'register fcm-new-token-0123456789 android $lang',
      );
    });

    testWidgets('said no: nothing registered, and S4 says how to turn it on '
        '[$lang]', (tester) async {
      final push = FakePushMessaging(answer: PushPermission.denied);
      final app = await pumpApp(tester, language: lang, push: push);
      expect(app.pushes.calls, isEmpty);
      await _openNotifications(tester);
      expect(find.byType(NotificationsScreen), findsOneWidget);
      expect(find.text(l10n.pushOffTitle), findsOneWidget);
      // No "Email alerts still work": the MVP sends no email alerts.
      expect(find.text(l10n.pushOffBody), findsOneWidget);
      await _tap(tester, 'push-open-settings');
      expect(push.openedSettings, 1);
    });

    testWidgets('S3: the MVP switches, saved on the server [$lang]', (
      tester,
    ) async {
      final app = await pumpApp(tester, language: lang);
      await _openNotifications(tester);
      expect(find.byKey(const Key('push-off')), findsNothing);
      expect(find.text(l10n.notifFollowers), findsOneWidget);
      expect(find.text(l10n.notifReplies), findsOneWidget);
      expect(find.text(l10n.notifLockText), findsOneWidget);
      expect(find.text(l10n.notifFooter), findsOneWidget);
      // Work items and requests follow each Space's level: no switch.
      expect(find.text(l10n.notifSpacesLine), findsOneWidget);
      await _tap(tester, 'notif-followers');
      expect(app.pushes.calls.last, 'settings false true false');
      await _tap(tester, 'notif-lock-text');
      expect(app.pushes.calls.last, 'settings false true true');
    });

    testWidgets('signing out: this phone gets no more pushes [$lang]', (
      tester,
    ) async {
      final app = await pumpApp(tester, language: lang);
      await _tap(tester, 'nav-profile');
      await _tap(tester, 'profile-settings');
      await _tap(tester, 'row-sign-out');
      expect(
        app.pushes.calls,
        contains('unregister fcm-test-token-0123456789'),
      );
    });

    testWidgets('a tapped push opens what it is about [$lang]', (tester) async {
      final push = FakePushMessaging(
        current: PushPermission.granted,
        firstTap: {'kind': 'post_reply', 'route': '/posts/p1', 'post_id': 'p1'},
      );
      final app = await pumpApp(tester, language: lang, push: push);
      expect(app.push.asked, 0, reason: 'already allowed: no prompt');
      expect(find.byType(PostScreen), findsOneWidget);
      // A link to somewhere outside the app's pages is ignored.
      push.tap({'kind': 'x', 'route': 'https://example.com'});
      await tester.pumpAndSettle();
      expect(find.byType(PostScreen), findsOneWidget);
    });

    testWidgets('guests are never asked [$lang]', (tester) async {
      final app = await pumpApp(tester, language: lang, signedIn: false);
      await tester.tap(find.byKey(const Key('welcome-skip')));
      await tester.pumpAndSettle();
      expect(app.push.asked, 0);
    });
  }
}
