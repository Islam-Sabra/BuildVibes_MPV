// Review 114 PS1–PS3: so urgent alerts reach you. Only the lines this
// phone's maker needs; each button opens its exact page; ticks only where
// the phone confirms, or after coming back; Send me a test until it
// arrives (PS2); Later skips; Fix it opens the same screen; PS3 once per
// account. In English and Arabic.
import 'dart:async';

import 'package:buildvibes/core/push/alert_settings_phone.dart';
import 'package:buildvibes/core/push/push_messaging.dart';
import 'package:buildvibes/data/repositories/alert_test_repository.dart';
import 'package:buildvibes/features/onboarding/alert_makers.dart';
import 'package:buildvibes/features/onboarding/alerts_setup.dart';
import 'package:buildvibes/features/onboarding/alerts_setup_screen.dart';
import 'package:buildvibes/features/settings/push_host.dart' show pushAskedKey;
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_bottom_bar.dart';
import 'package:buildvibes/core/l10n/bidi.dart';
import 'package:buildvibes/data/models/need_you.dart';
import 'package:buildvibes/features/spaces/need_you_notice.dart';
import 'package:buildvibes/features/spaces/need_you_phone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/alert_fakes.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/need_you_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/push_fakes.dart';

Finder _key(String k) => find.byKey(Key(k));

const _xiaomi = ['xiaomi', 'redmi'];

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Navigator).first));

Future<TestApp> _open(
  WidgetTester tester,
  String lang, {
  List<String> makers = _xiaomi,
  PushPermission permission = PushPermission.granted,
  String platform = 'android',
  AlertPhoneStatus status = const AlertPhoneStatus(),
  Map<String, Object> stored = const {},
}) async {
  final app = await pumpApp(
    tester,
    language: lang,
    push: FakePushMessaging(
      current: permission,
      makers: makers,
      platform: platform,
    ),
    alertPhone: FakeAlertSettingsPhone(current: status),
    stored: stored,
  );
  await tester.pumpAndSettle();
  unawaited(_router(tester).push(alertsSetupRoute()));
  await tester.pumpAndSettle();
  return app;
}

/// The person leaves for the phone's settings and comes back.
Future<void> _comeBack(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  await tester.pump();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpAndSettle();
}

void _expectLines(List<String> on, List<String> off) {
  for (final l in on) {
    expect(_key('alerts-on-$l'), findsOneWidget, reason: '$l on');
    expect(_key('alerts-turn-on-$l'), findsNothing, reason: '$l on');
  }
  for (final l in off) {
    expect(_key('alerts-turn-on-$l'), findsOneWidget, reason: '$l off');
    expect(_key('alerts-on-$l'), findsNothing, reason: '$l off');
  }
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));

    testWidgets('PS1 on a Xiaomi: five lines (review 115: Lock in recent '
        'apps), Notifications on; the copy [$lang]', (tester) async {
      await _open(tester, lang);
      expect(find.byType(AlertsSetupScreen), findsOneWidget);
      expect(find.text(l10n.alertsTitle), findsOneWidget);
      expect(find.text(l10n.alertsSub(5)), findsOneWidget);
      for (final t in [
        l10n.alertsNotifications,
        l10n.alertsNotificationsSub,
        l10n.alertsAutostart,
        l10n.alertsAutostartSub,
        l10n.alertsFloating,
        l10n.alertsFloatingSub,
        l10n.alertsBattery,
        l10n.alertsBatterySub,
        l10n.alertsLockRecents,
        l10n.alertsLockRecentsSub,
        l10n.alertsHint,
        l10n.alertsSendTest,
        l10n.alertsLater,
      ]) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      _expectLines(
        ['notifications'],
        ['autostart', 'floating', 'battery', 'lockRecents'],
      );
      expect(find.text(l10n.alertsOn), findsOneWidget);
      // Lock in recent apps opens a how-to, so it says "Show me".
      expect(find.text(l10n.alertsTurnOn), findsNWidgets(3));
      expect(
        find.descendant(
          of: _key('alerts-line-lockRecents'),
          matching: find.text(lang == 'en' ? 'Show me' : 'أرني'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _key('alerts-line-lockRecents'),
          matching: find.text(l10n.alertsTurnOn),
        ),
        findsNothing,
      );
      expect(_key('alerts-done'), findsNothing);
    });

    testWidgets('review 114c: every line already on: "All set", not the '
        'settings it needs [$lang]', (tester) async {
      await _open(
        tester,
        lang,
        status: const AlertPhoneStatus(
          needYouChannelOn: true,
          batteryUnrestricted: true,
        ),
        stored: {
          alertVisitedKey(AlertLine.autostart): true,
          alertVisitedKey(AlertLine.floating): true,
          alertVisitedKey(AlertLine.lockRecents): true,
        },
      );
      _expectLines([
        'notifications',
        'autostart',
        'floating',
        'battery',
        'lockRecents',
      ], []);
      expect(find.text(l10n.alertsAllSet), findsOneWidget);
      expect(find.text(l10n.alertsSub(5)), findsNothing);
    });

    testWidgets('review 115: Lock in recent apps off is one more setting, '
        'not "All set" [$lang]', (tester) async {
      await _open(
        tester,
        lang,
        status: const AlertPhoneStatus(
          needYouChannelOn: true,
          batteryUnrestricted: true,
        ),
        stored: {
          alertVisitedKey(AlertLine.autostart): true,
          alertVisitedKey(AlertLine.floating): true,
        },
      );
      _expectLines(
        ['notifications', 'autostart', 'floating', 'battery'],
        ['lockRecents'],
      );
      expect(find.text(l10n.alertsAllSet), findsNothing);
      expect(find.text(l10n.alertsSub(5)), findsOneWidget);
    });

    testWidgets('review 114c: the last line turned on: the subtitle becomes '
        '"All set" [$lang]', (tester) async {
      final app = await _open(
        tester,
        lang,
        makers: const ['google', 'google'],
        permission: PushPermission.notAsked,
        // Not asked at the tabs: the one line stays off.
        stored: {pushAskedKey: true},
      );
      expect(find.text(l10n.alertsSub(1)), findsOneWidget);
      expect(find.text(l10n.alertsAllSet), findsNothing);
      app.push.current = PushPermission.granted;
      await _comeBack(tester);
      expect(find.text(l10n.alertsAllSet), findsOneWidget);
      expect(find.text(l10n.alertsSub(1)), findsNothing);
    });

    testWidgets('Samsung: Notifications and Battery; another Android and an '
        'iPhone: Notifications only [$lang]', (tester) async {
      await _open(tester, lang, makers: const ['samsung', 'samsung']);
      expect(find.text(l10n.alertsSub(2)), findsOneWidget);
      expect(_key('alerts-line-notifications'), findsOneWidget);
      expect(_key('alerts-line-battery'), findsOneWidget);
      expect(_key('alerts-line-autostart'), findsNothing);
      expect(_key('alerts-line-floating'), findsNothing);
      expect(_key('alerts-line-lockRecents'), findsNothing);
    });

    testWidgets('review 115: only Xiaomi, Redmi and POCO lock in recent '
        'apps; an Oppo has four lines [$lang]', (tester) async {
      await _open(tester, lang, makers: const ['oppo', 'oppo']);
      expect(find.text(l10n.alertsSub(4)), findsOneWidget);
      expect(_key('alerts-line-autostart'), findsOneWidget);
      expect(_key('alerts-line-lockRecents'), findsNothing);
    });

    for (final (name, makers, platform) in [
      ('another Android', const ['google', 'google'], 'android'),
      ('an iPhone', const <String>[], 'ios'),
    ]) {
      testWidgets('$name: one line [$lang]', (tester) async {
        await _open(
          tester,
          lang,
          makers: makers,
          platform: platform,
          permission: PushPermission.notAsked,
          // Not asked at the tabs: the one line stays off.
          stored: {pushAskedKey: true},
        );
        expect(find.text(l10n.alertsSub(1)), findsOneWidget);
        expect(_key('alerts-line-notifications'), findsOneWidget);
        for (final l in ['autostart', 'floating', 'battery', 'lockRecents']) {
          expect(_key('alerts-line-$l'), findsNothing);
        }
      });
    }

    testWidgets("Notifications: the phone's own popup, then a tick; once "
        "refused, the app's notification settings [$lang]", (tester) async {
      final app = await _open(
        tester,
        lang,
        permission: PushPermission.notAsked,
        // Signed in on an older build: the tabs asked once already, and
        // the person didn't answer.
        stored: {pushAskedKey: true},
      );
      _expectLines([], ['notifications']);
      await _tap(tester, _key('alerts-turn-on-notifications'));
      expect(app.push.asked, 1);
      expect(app.push.openedSettings, 0);
      _expectLines(['notifications'], []);

      app.push
        ..current = PushPermission.denied
        ..answer = PushPermission.denied;
      await _comeBack(tester);
      _expectLines([], ['notifications']);
      await _tap(tester, _key('alerts-turn-on-notifications'));
      expect(app.push.asked, 1);
      expect(app.push.openedSettings, 1);
    });

    testWidgets('each button opens its exact page; Autostart and Floating '
        'show On after coming back [$lang]', (tester) async {
      final app = await _open(tester, lang);
      await _tap(tester, _key('alerts-turn-on-autostart'));
      expect(app.alertPhone.opened.last, startsWith('autostart com.miui'));
      // Not before the person comes back.
      _expectLines(
        ['notifications'],
        ['autostart', 'floating', 'battery', 'lockRecents'],
      );
      await _comeBack(tester);
      _expectLines(
        ['notifications', 'autostart'],
        ['floating', 'battery', 'lockRecents'],
      );

      final channels = app.needYouNotices.channels;
      await _tap(tester, _key('alerts-turn-on-floating'));
      // The Need you now channel, made first so its page exists.
      expect(app.alertPhone.opened.last, 'channel need_you');
      expect(app.needYouNotices.channels, channels + 1);
      await _comeBack(tester);
      _expectLines(['autostart', 'floating'], ['battery']);

      await _tap(tester, _key('alerts-turn-on-battery'));
      expect(
        app.alertPhone.opened.last,
        'battery com.miui.powerkeeper.ui.HiddenAppsConfigActivity',
      );
      // The phone says battery optimisation is still on: no tick.
      app.alertPhone.current = const AlertPhoneStatus(
        batteryUnrestricted: false,
      );
      await _comeBack(tester);
      _expectLines([], ['battery']);
      app.alertPhone.current = const AlertPhoneStatus(
        batteryUnrestricted: true,
      );
      await _comeBack(tester);
      _expectLines(
        ['notifications', 'autostart', 'floating', 'battery'],
        ['lockRecents'],
      );
      // Coming back is remembered on this phone.
      expect(app.prefs.getBool(alertVisitedKey(AlertLine.autostart)), isTrue);
    });

    testWidgets('review 115: Lock in recent apps opens no page (no app can '
        'lock itself there): the how-to, then On after coming back from '
        'recent apps; remembered [$lang]', (tester) async {
      final app = await _open(tester, lang);
      final opened = app.alertPhone.opened.length;
      await _tap(tester, _key('alerts-turn-on-lockRecents'));
      expect(find.text(l10n.alertsLockRecentsNow), findsOneWidget);
      expect(app.alertPhone.opened.length, opened);
      expect(app.push.openedSettings, 0);
      // Not before the person leaves for recent apps and comes back.
      _expectLines([], ['lockRecents']);
      await _comeBack(tester);
      _expectLines(['notifications', 'lockRecents'], ['autostart']);
      expect(app.prefs.getBool(alertVisitedKey(AlertLine.lockRecents)), isTrue);
    });

    testWidgets('a channel the phone says is low takes Floating off again '
        '[$lang]', (tester) async {
      await _open(
        tester,
        lang,
        stored: {alertVisitedKey(AlertLine.floating): true},
        status: const AlertPhoneStatus(needYouChannelOn: false),
      );
      _expectLines([], ['floating']);
    });

    testWidgets('Later skips: back where it was, nothing blocked [$lang]', (
      tester,
    ) async {
      await _open(tester, lang);
      await _tap(tester, _key('alerts-later'));
      expect(find.byType(AlertsSetupScreen), findsNothing);
      expect(find.byType(BvBottomBar), findsOneWidget);
    });

    testWidgets('Later after sign-up goes where it was going [$lang]', (
      tester,
    ) async {
      await pumpApp(
        tester,
        language: lang,
        push: FakePushMessaging(makers: _xiaomi),
      );
      await tester.pumpAndSettle();
      _router(tester).go(alertsSetupRoute(next: '/notebook'));
      await tester.pumpAndSettle();
      await _tap(tester, _key('alerts-later'));
      expect(find.byType(AlertsSetupScreen), findsNothing);
      expect(
        _router(tester).routeInformationProvider.value.uri.path,
        '/notebook',
      );
    });

    testWidgets('PS2: Send me a test registers this phone, then asks the '
        'server; the test arrives, the line shows, Done [$lang]', (
      tester,
    ) async {
      final app = await _open(tester, lang);
      await _tap(tester, _key('alerts-send-test'));
      expect(
        app.pushes.calls,
        contains('register fcm-test-token-0123456789 android $lang'),
      );
      expect(app.alertTests.sent, 1);
      expect(find.text(l10n.alertsTestSent), findsOneWidget);
      expect(_key('alerts-arrived'), findsNothing);
      // Another push is not the test.
      app.push.arrive({'kind': 'chat_message'});
      await tester.pumpAndSettle();
      expect(_key('alerts-arrived'), findsNothing);
      app.push.arrive({
        'kind': alertTestKind,
        'sent_at': DateTime.utc(2026, 11, 3).toIso8601String(),
      });
      await tester.pumpAndSettle();
      expect(find.text(l10n.alertsArrived), findsOneWidget);
      expect(_key('alerts-send-test'), findsNothing);
      expect(_key('alerts-later'), findsNothing);
      await _tap(tester, _key('alerts-done'));
      expect(find.byType(AlertsSetupScreen), findsNothing);
    });

    testWidgets('the test opened from its notification counts too [$lang]', (
      tester,
    ) async {
      final app = await _open(tester, lang);
      await _tap(tester, _key('alerts-send-test'));
      app.push.tap({'kind': alertTestKind});
      await tester.pumpAndSettle();
      expect(find.byType(AlertsSetupScreen), findsOneWidget);
      expect(_key('alerts-arrived'), findsOneWidget);
    });

    testWidgets('the test from the background: back in the app, the mark '
        'the background left shows it arrived [$lang]', (tester) async {
      final app = await _open(tester, lang);
      await _tap(tester, _key('alerts-send-test'));
      await app.prefs.setString(
        alertTestArrivedKey,
        DateTime.now()
            .toUtc()
            .add(const Duration(seconds: 5))
            .toIso8601String(),
      );
      await _comeBack(tester);
      expect(_key('alerts-arrived'), findsOneWidget);
    });

    testWidgets('the test refused: at most 3 an hour, in plain words '
        '[$lang]', (tester) async {
      final app = await _open(tester, lang);
      app.alertTests.refuse = const AlertTestException(
        AlertTestFailure.tooMany,
      );
      await _tap(tester, _key('alerts-send-test'));
      expect(find.text(l10n.alertsTestTooMany), findsOneWidget);
      expect(_key('alerts-arrived'), findsNothing);
    });

    testWidgets('notifications off: nothing can arrive, said plainly, no '
        'call [$lang]', (tester) async {
      final app = await _open(tester, lang, permission: PushPermission.denied);
      await _tap(tester, _key('alerts-send-test'));
      expect(find.text(l10n.alertsTestAllowFirst), findsOneWidget);
      expect(app.alertTests.sent, 0);
    });

    testWidgets('no push token on this phone: said plainly, no call '
        '[$lang]', (tester) async {
      final app = await pumpApp(
        tester,
        language: lang,
        push: FakePushMessaging(
          current: PushPermission.granted,
          makers: _xiaomi,
          phoneToken: null,
        ),
      );
      await tester.pumpAndSettle();
      unawaited(_router(tester).push(alertsSetupRoute()));
      await tester.pumpAndSettle();
      await _tap(tester, _key('alerts-send-test'));
      expect(find.text(l10n.pushNotReaching), findsWidgets);
      expect(app.alertTests.sent, 0);
    });

    testWidgets('a tap on the test push with the app closed opens the setup '
        'with the line [$lang]', (tester) async {
      await pumpApp(
        tester,
        language: lang,
        push: FakePushMessaging(
          current: PushPermission.granted,
          makers: _xiaomi,
          firstTap: {
            'kind': alertTestKind,
            'route': '/profile/settings/notifications',
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertsSetupScreen), findsOneWidget);
      expect(_key('alerts-arrived'), findsOneWidget);
      expect(_key('alerts-done'), findsOneWidget);
    });

    testWidgets('Settings → Notifications → Fix it opens the same screen '
        '[$lang]', (tester) async {
      await pumpApp(
        tester,
        language: lang,
        push: FakePushMessaging(
          current: PushPermission.granted,
          tokenFailures: 99,
          makers: _xiaomi,
        ),
      );
      await _tap(tester, _key('nav-profile'));
      await _tap(tester, _key('profile-settings'));
      await _tap(tester, _key('row-notifications'));
      await _tap(tester, find.text(l10n.pushFixIt));
      expect(find.byType(AlertsSetupScreen), findsOneWidget);
    });

    group('PS3, asked again once [$lang]', () {
      final sent = DaybookSamples.thursday.toUtc();
      Map<String, String> needYou(Duration after) => {
        'kind': 'need_you',
        'call_id': 'call-1',
        'space_id': DaybookSamples.space,
        'from_name': 'Omar Haddad',
        'sent_at': sent.subtract(after).toIso8601String(),
      };

      Future<TestApp> start(
        WidgetTester tester, {
        PushPermission permission = PushPermission.granted,
        List<String> makers = _xiaomi,
      }) async {
        final app = await pumpApp(
          tester,
          language: lang,
          now: DaybookSamples.thursday,
          push: FakePushMessaging(current: permission, makers: makers),
        );
        await tester.pumpAndSettle();
        return app;
      }

      testWidgets('an urgent alert opened late with a line off: the sheet; '
          'Fix now opens PS1; never again', (tester) async {
        final app = await start(tester);
        app.push.tap(needYou(const Duration(minutes: 6)));
        await tester.pumpAndSettle();
        expect(_key('alerts-late'), findsOneWidget);
        expect(find.text(l10n.alertsLate), findsOneWidget);
        expect(find.textContaining(l10n.alertsOffCount(4)), findsOneWidget);
        await _tap(tester, _key('alerts-fix-now'));
        expect(_key('alerts-late'), findsNothing);
        expect(find.byType(AlertsSetupScreen), findsOneWidget);
        expect(app.prefs.getBool(alertLateAskedKey('user-1')), isTrue);
        await _tap(tester, _key('alerts-later'));
        app.push.tap(needYou(const Duration(minutes: 20)));
        await tester.pumpAndSettle();
        expect(_key('alerts-late'), findsNothing);
      });

      testWidgets('Not now closes it, and it never comes back', (tester) async {
        final app = await start(tester);
        app.push.tap(needYou(const Duration(minutes: 9)));
        await tester.pumpAndSettle();
        await _tap(tester, _key('alerts-not-now'));
        expect(_key('alerts-late'), findsNothing);
        expect(find.byType(AlertsSetupScreen), findsNothing);
        app.push.tap(needYou(const Duration(minutes: 9)));
        await tester.pumpAndSettle();
        expect(_key('alerts-late'), findsNothing);
      });

      testWidgets('on time, or every line on: no sheet', (tester) async {
        final app = await start(tester, makers: const ['google', 'google']);
        app.push.tap(needYou(const Duration(minutes: 3)));
        await tester.pumpAndSettle();
        expect(_key('alerts-late'), findsNothing);
        app.push.tap(needYou(const Duration(minutes: 30)));
        await tester.pumpAndSettle();
        expect(_key('alerts-late'), findsNothing);
        // Not used up: it may still come when a line is off.
        expect(app.prefs.getBool(alertLateAskedKey('user-1')), isNull);
      });

      testWidgets("Need you now's own notification, tapped late: the name "
          'from the call (its payload has no words)', (tester) async {
        final needYou = FakeNeedYouRepository()
          ..callsList.add(
            NeedYouCall(
              id: 'call-1',
              spaceId: DaybookSamples.space,
              fromId: 'p-omar',
              toId: 'user-1',
              fromName: 'Omar Haddad',
              createdAt: sent,
            ),
          );
        await pumpApp(
          tester,
          language: lang,
          now: DaybookSamples.thursday,
          needYou: needYou,
          push: FakePushMessaging(
            current: PushPermission.granted,
            makers: _xiaomi,
          ),
        );
        await tester.pumpAndSettle();
        claimNeedYouTap(
          NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotification,
            payload: NeedYouPush(
              callId: 'call-1',
              spaceId: DaybookSamples.space,
              sentAt: sent
                  .subtract(const Duration(minutes: 8))
                  .toIso8601String(),
            ).payload,
          ),
        );
        await tester.pumpAndSettle();
        expect(_key('alerts-late'), findsOneWidget);
        expect(
          find.textContaining(
            l10n.alertsLateBy(inOwnDirection('Omar Haddad'), 8),
          ),
          findsOneWidget,
        );
      });

      testWidgets('a check-in opening counts too, with no name', (
        tester,
      ) async {
        final app = await start(tester);
        app.push.tap({
          'kind': 'check_in_open',
          'post_id': 'post-rebar',
          'space_id': DaybookSamples.space,
          'mark': 'in',
          'sent_at': sent
              .subtract(const Duration(minutes: 11))
              .toIso8601String(),
        });
        await tester.pumpAndSettle();
        expect(_key('alerts-late'), findsOneWidget);
        expect(find.textContaining(l10n.alertsLateByPlain(11)), findsOneWidget);
      });
    });
  }
}
