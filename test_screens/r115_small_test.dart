// Review 115, small items, in English and Arabic at 390 × 844 in the app's
// fonts: a chat message whose PDF couldn't go ("Couldn't send · Tap to
// fix"), and its Tap to fix sheet. The alerts setup's fifth line is in
// r114 (PS1), the template picker's "Whole Space" in slice7 (T1). Run:
//   flutter test test_screens/r115_test.dart --update-goldens
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:buildvibes/data/models/chat.dart';
import 'package:buildvibes/data/models/library.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/chat/chat_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../test/helpers/chat_fakes.dart';
import '../test/helpers/daybook_samples.dart';
import '../test/helpers/pump_app.dart';
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
const _me = 'user-1';

void main() {
  setUpAll(loadAppFonts);

  for (final lang in ['en', 'ar']) {
    final s = DaybookSamples(lang);

    Future<void> open(WidgetTester tester) async {
      final spaces = FakeSpaceRepository(now: testNow)
        ..details[_space] = SpaceDetail(
          id: _space,
          name: s.t('NBKCH Site team', 'فريق موقع NBKCH'),
          myPass: SpacePass.lead,
          iAmAdmin: true,
          myRights: const MemberRights(createItems: true, addFiles: true),
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
              isAdmin: true,
              confirmedAt: testNow,
            ),
          ],
        );
      final chat = FakeChatRepository(now: testNow)
        ..threadsBySpace[_space] = const [ChatThread(id: _everyone)]
        ..messagesByThread[_everyone] = [
          ChatMessage(
            id: 'm1',
            threadId: _everyone,
            kind: ChatKind.text,
            createdAt: testNow.add(const Duration(hours: 9)),
            authorId: 'p-rakesh',
            authorName: 'Rakesh Nair',
            body: s.t(
              'Send me the level 3 plan, please.',
              'أرسل لي مخطط الطابق 3 من فضلك.',
            ),
          ),
        ];
      final dir = Directory.systemTemp.createTempSync('bv_r115');
      final kept = File(testPdfPath).copySync('${dir.path}/kept.pdf').path;
      // Left from an earlier start: the 9.1 MB PDF that never went.
      final left = PendingMessage(
        id: 'pending-1',
        threadId: _everyone,
        spaceId: _space,
        body: s.t('Rev C', 'المراجعة C'),
        createdAt: testNow.add(const Duration(hours: 9, minutes: 5)),
        files: [
          PendingFile(
            file: PhoneFile(
              local: kept,
              name: 'Level 3 plan.pdf',
              mime: 'application/pdf',
              bytes: 9100000,
            ),
          ),
        ],
      );
      await pumpApp(
        tester,
        language: lang,
        spaces: spaces,
        chat: chat,
        stored: {
          'chat_outbox': jsonEncode([left.toJson()]),
        },
      );
      unawaited(_router(tester).push('/spaces/$_space/chat/$_everyone'));
      await tester.pumpAndSettle();
    }

    testWidgets('a message that couldn\'t go: Tap to fix [$lang]', (
      tester,
    ) async {
      await open(tester);
      await _snap(tester, 'chat_tap_to_fix', lang);
    });

    testWidgets('Tap to fix: Try again or Remove [$lang]', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('chat-fix-pending-1')));
      await tester.pumpAndSettle();
      await _snap(tester, 'chat_fix_sheet', lang);
    });
  }
}
