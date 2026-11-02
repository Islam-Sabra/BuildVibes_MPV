// Review 114 B1: a notification that started the app is taken once. It used
// to come back on every new shell, so the Space's ← opened the Space again.
import 'package:buildvibes/core/push/reminders.dart';
import 'package:buildvibes/data/models/check_in.dart';
import 'package:buildvibes/features/spaces/need_you_notice.dart';
import 'package:buildvibes/features/spaces/need_you_phone.dart';
import 'package:buildvibes/features/spaces/space_screen.dart';
import 'package:buildvibes/features/spaces/spaces_tab.dart';
import 'package:buildvibes/features/work/check_in_notice.dart';
import 'package:buildvibes/features/work/check_in_phone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/reminder_fakes.dart';
import '../../helpers/space_fakes.dart';

const _space = DaybookSamples.space;

NotificationResponse _response(String payload) => NotificationResponse(
  notificationResponseType: NotificationResponseType.selectedNotification,
  payload: payload,
);

/// As the plugin does: the same launch, however often it is asked.
class _LaunchedApp extends FakePhoneReminders {
  _LaunchedApp(this.response);

  final NotificationResponse response;

  @override
  Future<String?> launchedBy() async => takeLaunchTap(response);
}

Future<void> _open(
  WidgetTester tester,
  String lang,
  NotificationResponse response,
) async {
  final s = DaybookSamples(lang);
  await pumpApp(
    tester,
    language: lang,
    spaces: FakeSpaceRepository()
      ..details[_space] = s.detail()
      ..spacePeople[_space] = s.people(),
    daybook: FakeDaybookRepository()..posts[_space] = s.d1(),
    now: DaybookSamples.thursday,
    reminders: _LaunchedApp(response),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    forgetLaunchTap();
    PhoneNotificationHooks.claim = (r) =>
        claimNeedYouTap(r) || claimCheckInTap(r);
  });
  tearDown(() {
    forgetLaunchTap();
    PhoneNotificationHooks.claim = null;
  });

  test('the launch goes through claim once, however often it is asked', () {
    var claims = 0;
    PhoneNotificationHooks.claim = (_) {
      claims++;
      return true;
    };
    final launch = _response('anything');
    expect(takeLaunchTap(launch), isNull);
    expect(takeLaunchTap(launch), isNull);
    expect(claims, 1);
  });

  test('a reminder of a note is given once too', () {
    PhoneNotificationHooks.claim = (_) => false;
    final launch = _response('note-1');
    expect(takeLaunchTap(launch), 'note-1');
    expect(takeLaunchTap(launch), isNull);
  });

  final launches = {
    'Need you now': _response(
      const NeedYouPush(callId: 'call-1', spaceId: _space).payload,
    ),
    'a check-in': _response(
      const CheckInPush(
        postId: 'post-rebar',
        spaceId: _space,
        kind: CheckInMarkKind.checkIn,
      ).payload,
    ),
  };

  for (final lang in ['en', 'ar']) {
    for (final MapEntry(key: name, value: launch) in launches.entries) {
      testWidgets('$name started the app: the Space\'s ← reaches the Spaces '
          'tab [$lang]', (tester) async {
        await _open(tester, lang, launch);
        expect(find.byType(SpaceScreen), findsOneWidget);
        // Opened over the tabs, not in their place.
        expect(
          GoRouter.of(tester.element(find.byType(SpaceScreen))).canPop(),
          isTrue,
        );
        await tester.tap(find.byKey(const Key('space-back')));
        await tester.pumpAndSettle();
        expect(find.byType(SpaceScreen), findsNothing);
        expect(find.byType(SpacesTabScreen), findsOneWidget);
      });

      testWidgets('$name started the app: a new shell doesn\'t open the Space '
          'again [$lang]', (tester) async {
        await _open(tester, lang, launch);
        expect(find.byType(SpaceScreen), findsOneWidget);
        final router = GoRouter.of(
          tester.element(find.byType(Navigator).first),
        );
        router.go('/spaces/$_space');
        await tester.pumpAndSettle();
        router.go('/home');
        await tester.pumpAndSettle();
        expect(find.byType(SpaceScreen), findsNothing);
      });
    }
  }
}
