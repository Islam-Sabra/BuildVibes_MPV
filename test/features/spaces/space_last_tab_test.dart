// Review 113 (5): inside a Space, Work · Chat in that order; the first open
// is Work, then the Space remembers the last tab used in it, per Space, on
// the phone. In English and Arabic.
import 'package:buildvibes/data/models/chat.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/chat/chat_tab.dart';
import 'package:buildvibes/features/work/daybook_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/chat_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

Finder _key(String k) => find.byKey(Key(k));

const _omar = SpacePerson(id: 'user-1', firstName: 'Omar', lastName: 'Haddad');

FakeSpaceRepository _spaces() {
  final spaces = FakeSpaceRepository(now: testNow);
  for (final id in ['space-1', 'space-2']) {
    spaces.details[id] = SpaceDetail(
      id: id,
      name: 'Tower $id',
      myPass: SpacePass.lead,
      iAmAdmin: true,
      myRights: const MemberRights(invite: true, createItems: true),
    );
    spaces.spaces.add(
      SpaceSummary(
        id: id,
        name: 'Tower $id',
        pass: SpacePass.lead,
        isAdmin: true,
      ),
    );
    spaces.spacePeople[id] = SpacePeople(
      requests: const [],
      members: [
        SpaceMember(
          person: _omar,
          pass: SpacePass.lead,
          isAdmin: true,
          confirmedAt: testNow,
        ),
      ],
    );
  }
  return spaces;
}

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Navigator).first));

Future<void> _openSpace(WidgetTester tester, String id) async {
  _router(tester).push('/spaces/$id');
  await tester.pumpAndSettle();
}

Future<void> _leave(WidgetTester tester) async {
  _router(tester).pop();
  await tester.pumpAndSettle();
}

void main() {
  for (final lang in ['en', 'ar']) {
    testWidgets('Work · Chat in that order; the first open is Work, then the '
        'last tab used, per Space [$lang]', (tester) async {
      await pumpApp(
        tester,
        language: lang,
        spaces: _spaces(),
        chat: FakeChatRepository(now: testNow)
          ..threadsBySpace['space-1'] = [const ChatThread(id: 'all-1')]
          ..threadsBySpace['space-2'] = [const ChatThread(id: 'all-2')],
      );
      await _openSpace(tester, 'space-1');
      expect(find.byType(DaybookTab), findsOneWidget);
      // Work first in reading order: left in English, right in Arabic.
      final work = tester.getCenter(_key('space-switch-work')).dx;
      final chat = tester.getCenter(_key('space-switch-chat')).dx;
      expect(lang == 'en' ? work < chat : work > chat, isTrue);

      await tester.tap(_key('space-switch-chat'));
      await tester.pumpAndSettle();
      await _leave(tester);

      // Space 1 opens on Chat now; Space 2 still on Work.
      await _openSpace(tester, 'space-1');
      expect(find.byType(ChatTab), findsOneWidget);
      await _leave(tester);
      await _openSpace(tester, 'space-2');
      expect(find.byType(DaybookTab), findsOneWidget);
      await _leave(tester);

      // Back to Work in Space 1: it opens on Work again.
      await _openSpace(tester, 'space-1');
      await tester.tap(_key('space-switch-work'));
      await tester.pumpAndSettle();
      await _leave(tester);
      await _openSpace(tester, 'space-1');
      expect(find.byType(DaybookTab), findsOneWidget);
    });

    testWidgets('kept on the phone: a new app start opens the Space on its '
        'last tab [$lang]', (tester) async {
      await pumpApp(
        tester,
        language: lang,
        spaces: _spaces(),
        stored: const {'space_tab:user-1:space-1': 'chat'},
        chat: FakeChatRepository(now: testNow)
          ..threadsBySpace['space-1'] = [const ChatThread(id: 'all-1')],
      );
      await _openSpace(tester, 'space-1');
      expect(find.byType(ChatTab), findsOneWidget);
    });
  }
}
