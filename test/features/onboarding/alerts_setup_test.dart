// Review 114: the alerts setup's decisions, without a phone: which lines a
// maker's phone needs, when a line is on, when an urgent alert was late,
// and the server's refusal of a test.
import 'package:buildvibes/core/push/alert_settings_phone.dart';
import 'package:buildvibes/core/push/push_messaging.dart';
import 'package:buildvibes/data/repositories/alert_test_repository.dart';
import 'package:buildvibes/features/onboarding/alert_makers.dart';
import 'package:buildvibes/features/onboarding/alerts_setup.dart';
import 'package:buildvibes/features/spaces/need_you_notice.dart';
import 'package:buildvibes/features/work/check_in_notice.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/alert_fakes.dart';
import '../../helpers/push_fakes.dart';

const _four = [
  AlertLine.notifications,
  AlertLine.autostart,
  AlertLine.floating,
  AlertLine.battery,
];

void main() {
  group('the maker list → which lines show', () {
    for (final maker in [
      'xiaomi',
      'redmi',
      'poco',
      'oppo',
      'realme',
      'vivo',
      'huawei',
      'honor',
    ]) {
      test('$maker: all four lines', () {
        expect(alertLinesFor(ios: false, makers: [maker, maker]), _four);
      });
    }

    test('the names Android gives, in any case, manufacturer or brand', () {
      expect(alertLinesFor(ios: false, makers: ['Xiaomi', 'POCO']), _four);
      expect(alertLinesFor(ios: false, makers: ['unknown', 'Redmi']), _four);
    });

    test('Samsung: Notifications and Battery', () {
      expect(alertLinesFor(ios: false, makers: ['samsung', 'samsung']), [
        AlertLine.notifications,
        AlertLine.battery,
      ]);
    });

    test('any other Android: Notifications only', () {
      expect(alertLinesFor(ios: false, makers: ['google', 'google']), [
        AlertLine.notifications,
      ]);
      expect(alertLinesFor(ios: false, makers: const []), [
        AlertLine.notifications,
      ]);
    });

    test('iOS: Notifications only', () {
      expect(alertLinesFor(ios: true, makers: ['apple']), [
        AlertLine.notifications,
      ]);
    });

    test('every maker with Autostart has its pages; Xiaomi its battery '
        'page, never the battery popup', () {
      for (final m in phoneMakers) {
        if (m.lines.contains(AlertLine.autostart)) {
          expect(m.autostart, isNotEmpty, reason: '${m.names}');
        }
        for (final p in [...m.autostart, ...m.battery]) {
          expect(p.action ?? '', isNot(contains('IGNORE_BATTERY')));
        }
      }
      expect(
        phoneMakerOf(['xiaomi'])!.autostart.first.activity,
        'com.miui.permcenter.autostart.AutoStartManagementActivity',
      );
      expect(phoneMakerOf(['redmi'])!.battery, isNotEmpty);
    });
  });

  group('each tick state', () {
    const unknown = AlertPhoneStatus();
    bool on(
      AlertLine line, {
      PushPermission permission = PushPermission.granted,
      AlertPhoneStatus status = unknown,
      Set<AlertLine> visited = const {},
    }) => alertLineOn(
      line,
      permission: permission,
      status: status,
      visited: visited,
    );

    test('Notifications: on only once allowed', () {
      expect(on(AlertLine.notifications), isTrue);
      expect(
        on(AlertLine.notifications, permission: PushPermission.denied),
        isFalse,
      );
      expect(
        on(AlertLine.notifications, permission: PushPermission.notAsked),
        isFalse,
      );
    });

    test('Autostart: no phone reports it; on after coming back from its '
        'page', () {
      expect(on(AlertLine.autostart), isFalse);
      expect(on(AlertLine.autostart, visited: {AlertLine.autostart}), isTrue);
    });

    test('Floating: on after coming back, unless the phone says the '
        'channel is low or off', () {
      expect(on(AlertLine.floating), isFalse);
      expect(on(AlertLine.floating, visited: {AlertLine.floating}), isTrue);
      expect(
        on(
          AlertLine.floating,
          visited: {AlertLine.floating},
          status: const AlertPhoneStatus(needYouChannelOn: false),
        ),
        isFalse,
      );
    });

    test('Battery: the phone confirms optimisation off; coming back alone '
        "isn't enough when the phone can tell", () {
      expect(
        on(
          AlertLine.battery,
          status: const AlertPhoneStatus(batteryUnrestricted: true),
        ),
        isTrue,
      );
      expect(
        on(
          AlertLine.battery,
          visited: {AlertLine.battery},
          status: const AlertPhoneStatus(batteryUnrestricted: false),
        ),
        isFalse,
      );
    });
  });

  group('after sign-up', () {
    Future<SharedPreferences> prefs() async {
      SharedPreferences.setMockInitialValues({});
      return SharedPreferences.getInstance();
    }

    test('once per account, before where it was going', () async {
      final p = await prefs();
      Future<String> next() => routeAfterSignUp(
        userId: 'u1',
        next: '/onboarding/space',
        messaging: FakePushMessaging(makers: const ['xiaomi', 'redmi']),
        phone: FakeAlertSettingsPhone(),
        prefs: p,
      );
      expect(await next(), '/onboarding/alerts?next=%2Fonboarding%2Fspace');
      expect(await next(), '/onboarding/space');
    });

    test('not when every line this phone needs is already on', () async {
      final p = await prefs();
      expect(
        await routeAfterSignUp(
          userId: 'u1',
          next: '/home',
          messaging: FakePushMessaging(current: PushPermission.granted),
          phone: FakeAlertSettingsPhone(),
          prefs: p,
        ),
        '/home',
      );
    });
  });

  group('the late check', () {
    final sent = DateTime.utc(2026, 11, 3, 9);
    Map<String, String> push(String kind, {String? name}) => {
      'kind': kind,
      'sent_at': sent.toIso8601String(),
      'from_name': ?name,
    };

    test('Need you now opened more than 5 minutes after it was sent', () {
      expect(
        lateAlertOf(
          push('need_you', name: 'Omar'),
          sent.add(const Duration(minutes: 6)),
        ),
        (name: 'Omar', minutes: 6),
      );
      expect(
        lateAlertOf(push('need_you'), sent.add(const Duration(minutes: 5))),
        isNull,
      );
    });

    test('a check-in opening counts too, with no name', () {
      expect(
        lateAlertOf(
          push('check_in_open', name: 'x'),
          sent.add(const Duration(minutes: 12)),
        ),
        (name: null, minutes: 12),
      );
    });

    test('other pushes, or none sent_at, never', () {
      final later = sent.add(const Duration(hours: 1));
      expect(lateAlertOf(push('chat_message'), later), isNull);
      expect(lateAlertOf({'kind': 'need_you'}, later), isNull);
      expect(lateAlertOf(push(alertTestKind), later), isNull);
    });

    test('a phone clock in another zone reads the same', () {
      expect(
        lateAlertOf(
          push('need_you'),
          sent.add(const Duration(minutes: 7)).toLocal(),
        )?.minutes,
        7,
      );
    });
  });

  test("a notification's payload keeps sent_at (a time, never words), so a "
      'tap tells how late it came', () {
    const at = '2026-11-03T09:00:00.000Z';
    final need = NeedYouPush.fromData({
      'kind': 'need_you',
      'call_id': 'c1',
      'space_id': 's1',
      'from_name': 'Omar Haddad',
      'sent_at': at,
    })!;
    expect(NeedYouPush.fromPayload(need.payload)!.sentAt, at);
    expect(need.payload, isNot(contains('Omar')));
    final checkIn = CheckInPush.fromData({
      'kind': 'check_in_open',
      'post_id': 'p1',
      'space_id': 's1',
      'mark': 'in',
      'sent_at': at,
    })!;
    expect(CheckInPush.fromPayload(checkIn.payload)!.sentAt, at);
  });

  test("the server's refusal: at most 3 an hour", () {
    expect(
      alertTestFailureFor('22023', 'at most 3 an hour'),
      AlertTestFailure.tooMany,
    );
    expect(alertTestFailureFor('42501', 'not allowed'), AlertTestFailure.other);
  });
}
