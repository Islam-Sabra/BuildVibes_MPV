// Review 114, in English and Arabic at 390 × 844 in the app's fonts: PS1
// the alerts setup on a Xiaomi (Notifications on), and with every line on
// already ("All set", review 114c), PS2 all four on and the
// test arrived, PS3 asked again once over the Spaces tab; RX1 React at the
// start, Share at the end, and the picker from the start. Run:
//   flutter test test_screens/r114_test.dart --update-goldens
import 'dart:async';

import 'package:buildvibes/core/push/alert_settings_phone.dart';
import 'package:buildvibes/core/push/push_messaging.dart';
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/onboarding/alert_makers.dart';
import 'package:buildvibes/features/onboarding/alerts_setup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../test/helpers/alert_fakes.dart';
import '../test/helpers/daybook_fakes.dart';
import '../test/helpers/daybook_samples.dart';
import '../test/helpers/fakes.dart';
import '../test/helpers/pump_app.dart';
import '../test/helpers/push_fakes.dart';
import '../test/helpers/space_fakes.dart';
import 'shot.dart';

/// Saves the app as it is now to `docs/screens/r114/<name>_<lang>.png`.
Future<void> _snap(WidgetTester tester, String name, String lang) async {
  debugDisableShadows = false;
  try {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byType(MaterialApp).first,
      matchesGoldenFile('../docs/screens/r114/${name}_$lang.png'),
    );
  } finally {
    debugDisableShadows = true;
  }
}

Finder _key(String k) => find.byKey(Key(k));

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Navigator).first));

const _xiaomi = ['xiaomi', 'redmi'];

void main() {
  setUpAll(loadAppFonts);

  for (final lang in ['en', 'ar']) {
    final s = DaybookSamples(lang);

    FakeSpaceRepository spaces() =>
        FakeSpaceRepository(now: testNow)
          ..spaces.addAll([
            SpaceSummary(
              id: 'space-1',
              name: s.t('NBKCH Site team', 'فريق موقع NBKCH'),
              pass: SpacePass.lead,
              isAdmin: true,
            ),
            SpaceSummary(
              id: 'space-2',
              name: s.t('Test site', 'موقع تجريبي'),
              pass: SpacePass.lead,
              isAdmin: true,
            ),
          ]);

    Future<TestApp> setup(
      WidgetTester tester, {
      Map<String, Object> stored = const {},
      AlertPhoneStatus status = const AlertPhoneStatus(),
    }) async {
      final app = await pumpApp(
        tester,
        language: lang,
        push: FakePushMessaging(
          current: PushPermission.granted,
          makers: _xiaomi,
        ),
        alertPhone: FakeAlertSettingsPhone(current: status),
        stored: stored,
      );
      await tester.pumpAndSettle();
      _router(tester).go(alertsSetupRoute(next: '/onboarding/space'));
      await tester.pumpAndSettle();
      return app;
    }

    testWidgets('PS1 the setup on a Xiaomi, Notifications on [$lang]', (
      tester,
    ) async {
      await setup(tester);
      await _snap(tester, 'PS1_setup', lang);
    });

    testWidgets('review 114c: all four on already: "All set" [$lang]', (
      tester,
    ) async {
      await setup(
        tester,
        stored: {
          alertVisitedKey(AlertLine.autostart): true,
          alertVisitedKey(AlertLine.floating): true,
        },
        status: const AlertPhoneStatus(
          needYouChannelOn: true,
          batteryUnrestricted: true,
        ),
      );
      await _snap(tester, 'PS1_all_set', lang);
    });

    testWidgets('PS2 all four on, the test arrived, Done [$lang]', (
      tester,
    ) async {
      final app = await setup(
        tester,
        stored: {
          alertVisitedKey(AlertLine.autostart): true,
          alertVisitedKey(AlertLine.floating): true,
        },
        status: const AlertPhoneStatus(
          needYouChannelOn: true,
          batteryUnrestricted: true,
        ),
      );
      app.push.arrive({'kind': alertTestKind});
      await tester.pumpAndSettle();
      await _snap(tester, 'PS2_arrived', lang);
    });

    testWidgets('PS3 asked again once, over the Spaces tab [$lang]', (
      tester,
    ) async {
      await pumpApp(
        tester,
        language: lang,
        now: DaybookSamples.thursday,
        spaces: spaces(),
        push: FakePushMessaging(
          current: PushPermission.granted,
          makers: _xiaomi,
        ),
        stored: {alertVisitedKey(AlertLine.autostart): true},
      );
      await tester.pumpAndSettle();
      ProviderScope.containerOf(
        tester.element(find.byType(Navigator).first),
      ).read(lateAlertProvider.notifier).opened({
        'kind': 'need_you',
        'from_name': s.t('Omar', 'عمر'),
        'sent_at': DaybookSamples.thursday
            .toUtc()
            .subtract(const Duration(minutes: 6))
            .toIso8601String(),
      });
      await tester.pumpAndSettle();
      expect(_key('alerts-late'), findsOneWidget);
      await _snap(tester, 'PS3_late', lang);
    });

    Future<void> space(WidgetTester tester, List<DaybookCard> posts) async {
      await pumpApp(
        tester,
        language: lang,
        auth: FakeAuthRepository(
          userId: DaybookSamples.islam,
          phone: '+96550000001',
        ),
        spaces: FakeSpaceRepository()
          ..details[DaybookSamples.space] = s.detail(pass: SpacePass.lead)
          ..spacePeople[DaybookSamples.space] = s.people(),
        daybook: FakeDaybookRepository()..posts[DaybookSamples.space] = posts,
        now: DaybookSamples.thursday,
      );
      unawaited(_router(tester).push('/spaces/${DaybookSamples.space}'));
      await tester.pumpAndSettle();
    }

    final reacted = s.rebar().copyWith(
      post: s.rebar().post.shownAs(
        reactions: [
          DaybookReactionGroup(
            kind: PostReaction.bravo,
            people: [
              DaybookPerson(
                id: DaybookSamples.omar,
                name: s.nameOf(DaybookSamples.omar),
              ),
              DaybookPerson(id: DaybookSamples.sara, name: s.saraName),
            ],
          ),
          DaybookReactionGroup(
            kind: PostReaction.like,
            people: [
              DaybookPerson(
                id: DaybookSamples.islam,
                name: s.nameOf(DaybookSamples.islam),
              ),
            ],
          ),
        ],
      ),
    );

    testWidgets('RX1 React at the start, Share at the end [$lang]', (
      tester,
    ) async {
      await space(tester, [reacted]);
      await _snap(tester, 'RX1_card_foot', lang);
    });

    testWidgets('RX1 the picker opens from the start [$lang]', (tester) async {
      await space(tester, [reacted]);
      final react = _key('card-react-post-rebar');
      await tester.ensureVisible(react);
      await tester.pumpAndSettle();
      await tester.tap(react);
      await tester.pumpAndSettle();
      await _snap(tester, 'RX1_picker', lang);
    });
  }
}
