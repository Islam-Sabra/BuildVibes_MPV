// The lead's check of review 115, small fixes, in English and Arabic at
// 390 × 844 in the app's fonts: WD1 the Xiaomi lock line's "Show me", WD2
// the whole-Space chat thread called "Whole Space" (the Chat tab and the
// thread's header), WD3 a direct message that couldn't go ("Couldn't send
// · Tap to fix") and its sheet. Run:
//   flutter test test_screens/r115_words_test.dart --update-goldens
import 'dart:async';

import 'package:buildvibes/core/push/push_messaging.dart';
import 'package:buildvibes/data/models/chat.dart';
import 'package:buildvibes/data/models/dm.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/onboarding/alerts_setup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../test/helpers/alert_fakes.dart';
import '../test/helpers/chat_fakes.dart';
import '../test/helpers/daybook_samples.dart';
import '../test/helpers/dm_fakes.dart';
import '../test/helpers/pump_app.dart';
import '../test/helpers/push_fakes.dart';
import '../test/helpers/space_fakes.dart';
import 'shot.dart';

/// Saves the app as it is now to `docs/screens/r115/<name>_<lang>.png`.
Future<void> _snap(WidgetTester tester, String name, String lang) async {
  debugDisableShadows = false;
  try {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byType(MaterialApp).first,
      matchesGoldenFile('../docs/screens/r115/${name}_$lang.png'),
    );
  } finally {
    debugDisableShadows = true;
  }
}

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Navigator).first));

const _space = 'space-1';
const _everyone = 'thread-everyone';
const _mep = 'thread-mep';
const _me = 'user-1';

void main() {
  setUpAll(loadAppFonts);

  for (final lang in ['en', 'ar']) {
    final s = DaybookSamples(lang);

    testWidgets('WD1 the Xiaomi lock line says Show me [$lang]', (
      tester,
    ) async {
      await pumpApp(
        tester,
        language: lang,
        push: FakePushMessaging(
          current: PushPermission.granted,
          makers: const ['xiaomi', 'redmi'],
        ),
        alertPhone: FakeAlertSettingsPhone(),
      );
      await tester.pumpAndSettle();
      _router(tester).go(alertsSetupRoute(next: '/onboarding/space'));
      await tester.pumpAndSettle();
      await _snap(tester, 'WD1_show_me', lang);
    });

    Future<void> openChat(WidgetTester tester) async {
      final spaces = FakeSpaceRepository(now: testNow)
        ..details[_space] = SpaceDetail(
          id: _space,
          name: s.t('NBKCH Site team', 'فريق موقع NBKCH'),
          myPass: SpacePass.lead,
          iAmAdmin: false,
          myRights: const MemberRights(createItems: true),
        )
        ..spacePeople[_space] = SpacePeople(
          members: [
            SpaceMember(
              person: const SpacePerson(
                id: _me,
                firstName: 'Omar',
                lastName: 'Haddad',
              ),
              pass: SpacePass.lead,
              isAdmin: false,
              confirmedAt: testNow,
            ),
          ],
        );
      final at = testNow.add(const Duration(hours: 9));
      final gate = s.t(
        'Gate 2 is blocked by the crane.',
        'البوابة 2 مغلقة بسبب الرافعة.',
      );
      final chat = FakeChatRepository(now: testNow)
        ..threadsBySpace[_space] = [
          ChatThread(
            id: _everyone,
            lastKind: ChatKind.text,
            lastBody: gate,
            lastAuthorId: 'p-rakesh',
            lastAt: at,
            unread: 1,
          ),
          ChatThread(
            id: _mep,
            teamId: 'team-mep',
            teamName: s.t('MEP Team', 'فريق MEP'),
            lastKind: ChatKind.text,
            lastBody: s.t('Sending after the walk.', 'أرسلها بعد الجولة.'),
            lastAuthorId: _me,
            lastAt: at.subtract(const Duration(minutes: 20)),
          ),
        ]
        ..messagesByThread[_everyone] = [
          ChatMessage(
            id: 'm1',
            threadId: _everyone,
            kind: ChatKind.text,
            createdAt: at,
            authorId: 'p-rakesh',
            authorName: 'Rakesh Nair',
            body: gate,
          ),
        ];
      await pumpApp(tester, language: lang, spaces: spaces, chat: chat);
      unawaited(_router(tester).push('/spaces/$_space'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('space-switch-chat')));
      await tester.pumpAndSettle();
    }

    testWidgets('WD2 the Chat tab: Whole Space first [$lang]', (tester) async {
      await openChat(tester);
      await _snap(tester, 'WD2_whole_space_chat', lang);
    });

    testWidgets('WD2 the Whole Space thread\'s header [$lang]', (tester) async {
      await openChat(tester);
      await tester.tap(find.byKey(const Key('chat-thread-$_everyone')));
      await tester.pumpAndSettle();
      await _snap(tester, 'WD2_whole_space_thread', lang);
    });

    Future<void> openDm(WidgetTester tester) async {
      final dm = FakeDmRepository()
        ..pages['t-omar'] = DmThreadPage(
          threadId: 't-omar',
          person: const DmPerson(
            id: 'p-omar',
            name: 'Omar Haddad',
            headline: 'Site Engineer',
          ),
          messages: [
            DmMessage(
              id: 'm1',
              fromMe: false,
              kind: ChatKind.text,
              createdAt: testNow.add(const Duration(hours: 9)),
              body: s.t('At the gate at 7?', 'عند البوابة الساعة 7؟'),
            ),
          ],
        );
      await pumpApp(tester, language: lang, dm: dm);
      unawaited(_router(tester).push('/messages/t-omar'));
      await tester.pumpAndSettle();
      // No signal while it goes.
      dm.offline = true;
      await tester.enterText(
        find.byKey(const Key('chat-input')),
        s.t('Yes, 7.', 'نعم، الساعة 7.'),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('chat-send')));
      await tester.pumpAndSettle();
    }

    testWidgets('WD3 a direct message that couldn\'t go: Tap to fix '
        '[$lang]', (tester) async {
      await openDm(tester);
      await _snap(tester, 'WD3_dm_tap_to_fix', lang);
    });

    testWidgets('WD3 Tap to fix: Try again or Remove [$lang]', (tester) async {
      await openDm(tester);
      await tester.tap(
        find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith('dm-fix-'),
        ),
      );
      await tester.pumpAndSettle();
      await _snap(tester, 'WD3_dm_fix_sheet', lang);
    });
  }
}
