import 'package:buildvibes/core/push/push_messaging.dart';
import 'package:buildvibes/features/feed/post_screen.dart';
import 'package:buildvibes/features/settings/notifications_screen.dart';
import 'package:buildvibes/features/settings/push_fix.dart';
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
  test("a work item's push opens its Space's daybook (the exact slip is "
      'slice 10)', () {
    expect(pushRoute('/spaces/s1/items/i1'), '/spaces/s1');
    expect(pushRoute('/spaces/s1'), '/spaces/s1');
    expect(pushRoute('/spaces/s1/chat/t1'), '/spaces/s1/chat/t1');
    expect(pushRoute('/posts/p1'), '/posts/p1');
  });

  test('F9: Xiaomi, Redmi and POCO phones get the background steps', () {
    expect(needsBackgroundSteps(['xiaomi', 'redmi']), isTrue);
    expect(needsBackgroundSteps(['Xiaomi', 'POCO']), isTrue);
    expect(needsBackgroundSteps(['samsung', 'samsung']), isFalse);
    expect(needsBackgroundSteps(const []), isFalse);
  });

  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);

    testWidgets('F9: the token fails at first: tried again until it comes, '
        'then registered; nothing to fix [$lang]', (tester) async {
      final push = FakePushMessaging(
        current: PushPermission.granted,
        tokenFailures: 2,
      );
      final app = await pumpApp(tester, language: lang, push: push);
      expect(push.tokenAsks, 3);
      expect(
        app.pushes.calls,
        contains('register fcm-test-token-0123456789 android $lang'),
      );
      expect(find.byKey(const Key('push-not-reaching')), findsNothing);
      expect(push.noTokenReports, 0);
    });

    testWidgets('F9: registered on every start, already allowed and asked '
        'before (signed in from an older build) [$lang]', (tester) async {
      final push = FakePushMessaging(current: PushPermission.granted);
      final app = await pumpApp(tester, language: lang, push: push);
      expect(push.asked, 0);
      expect(
        app.pushes.calls.single,
        'register fcm-test-token-0123456789 android $lang',
      );
    });

    testWidgets('F9: no token after the tries: the quiet line on Home and in '
        'Settings, counted once; Fix it opens the notification settings '
        '[$lang]', (tester) async {
      final push = FakePushMessaging(
        current: PushPermission.granted,
        tokenFailures: 99,
      );
      final app = await pumpApp(tester, language: lang, push: push);
      expect(app.pushes.calls, isEmpty);
      expect(push.noTokenReports, 1);
      expect(find.byKey(const Key('push-not-reaching')), findsOneWidget);
      expect(find.text(l10n.pushNotReaching), findsOneWidget);
      expect(find.text(l10n.pushFixIt), findsOneWidget);
      await _openNotifications(tester);
      expect(find.byKey(const Key('push-not-reaching')), findsOneWidget);
      // Not a Xiaomi family phone: straight to the phone's settings.
      await tester.tap(find.text(l10n.pushFixIt));
      await tester.pumpAndSettle();
      expect(push.openedSettings, 1);
      expect(find.byKey(const Key('push-fix-steps')), findsNothing);
    });

    testWidgets('F9: allowed but the phone gives no token: the same line '
        '[$lang]', (tester) async {
      final push = FakePushMessaging(
        current: PushPermission.granted,
        phoneToken: null,
      );
      await pumpApp(tester, language: lang, push: push);
      expect(find.byKey(const Key('push-not-reaching')), findsOneWidget);
    });

    testWidgets('F9: on a Xiaomi, Fix it shows the steps and opens the '
        "app's page [$lang]", (tester) async {
      final push = FakePushMessaging(
        current: PushPermission.granted,
        tokenFailures: 99,
        makers: const ['xiaomi', 'redmi'],
      );
      await pumpApp(tester, language: lang, push: push);
      await tester.tap(find.text(l10n.pushFixIt));
      await tester.pumpAndSettle();
      expect(find.text(l10n.pushFixTitle), findsOneWidget);
      for (final step in [
        l10n.pushFixAutostart,
        l10n.pushFixBattery,
        l10n.pushFixPlayServices,
        l10n.pushFixRestart,
      ]) {
        expect(find.text(step), findsOneWidget);
      }
      await tester.tap(find.byKey(const Key('push-fix-open')));
      await tester.pumpAndSettle();
      expect(push.openedAppSettings, 1);
      expect(push.openedSettings, 0);
    });

    testWidgets('F9: fixed on the phone, then back to the app: the token '
        'comes, it is registered and the line goes [$lang]', (tester) async {
      final push = FakePushMessaging(
        current: PushPermission.granted,
        tokenFailures: 3,
      );
      final app = await pumpApp(tester, language: lang, push: push);
      expect(find.byKey(const Key('push-not-reaching')), findsOneWidget);
      expect(app.pushes.calls, isEmpty);
      await backToTheApp(tester);
      expect(
        app.pushes.calls.single,
        'register fcm-test-token-0123456789 android $lang',
      );
      expect(find.byKey(const Key('push-not-reaching')), findsNothing);
    });

    testWidgets('F9: notifications off: S4 says so, not the line [$lang]', (
      tester,
    ) async {
      final push = FakePushMessaging(answer: PushPermission.denied);
      await pumpApp(tester, language: lang, push: push);
      expect(find.byKey(const Key('push-not-reaching')), findsNothing);
      expect(push.tokenAsks, 0);
    });

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

    testWidgets('changing the app language registers the phone again, in '
        'the new language [$lang]', (tester) async {
      final app = await pumpApp(tester, language: lang);
      final other = lang == 'en' ? 'ar' : 'en';
      await _tap(tester, 'nav-profile');
      await _tap(tester, 'profile-settings');
      await _tap(tester, 'row-language');
      await _tap(tester, 'language-$other');
      expect(
        app.pushes.calls.last,
        'register fcm-test-token-0123456789 android $other',
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
      await _tap(tester, 'bv-dialog-confirm');
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
