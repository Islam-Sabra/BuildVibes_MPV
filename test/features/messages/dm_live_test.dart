// F81 (review 80): direct messages live app-wide; a quiet banner for a
// direct message push while the app is open.
import 'package:buildvibes/data/models/chat.dart';
import 'package:buildvibes/data/models/dm.dart';
import 'package:buildvibes/features/messages/dm_live.dart';
import 'package:buildvibes/features/messages/dm_thread_screen.dart';
import 'package:buildvibes/shared/widgets/bv_message_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/dm_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/push_fakes.dart';

final _now = DateTime(2026, 10, 15, 11);

DmRow _omar(String text) => DmRow(
  threadId: 't-omar',
  person: const DmPerson(id: 'p-omar', name: 'Omar Haddad'),
  lastMessageAt: _now,
  unread: true,
  last: DmPreview(fromMe: false, kind: ChatKind.text, at: _now, text: text),
);

DmThreadPage _page(String id, String name, List<DmMessage> messages) =>
    DmThreadPage(
      threadId: id,
      person: DmPerson(id: 'p-$id', name: name),
      state: DmState.open,
      messages: messages,
    );

DmMessage _m(String id, String body) => DmMessage(
  id: id,
  fromMe: false,
  kind: ChatKind.text,
  createdAt: _now,
  body: body,
);

Map<String, String> _dmPush(String thread) => {
  'kind': 'dm_message',
  'route': '/messages/$thread',
  'dm_thread_id': thread,
  pushTitleKey: 'Message from Omar Haddad',
  pushBodyKey: 'Gate 2 is blocked',
};

Future<void> _go(WidgetTester tester, String path) async {
  GoRouter.of(tester.element(find.byType(Scaffold).first)).push(path);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a new message shows on the Messages list at once, live, '
      'with the app open on the list', (tester) async {
    final dm = FakeDmRepository()
      ..inboxValue = DmInbox(threads: [_omar('At the gate at 7?')]);
    await pumpApp(tester, dm: dm, now: _now);
    await _go(tester, '/messages');
    expect(find.textContaining('At the gate at 7?'), findsOneWidget);
    // Followed app-wide, not only in an open conversation.
    expect(dm.listened, contains('t-omar'));
    dm.inboxValue = DmInbox(threads: [_omar('Gate 2 is blocked')]);
    dm.push('t-omar', 'm9');
    await tester.pumpAndSettle();
    expect(find.textContaining('Gate 2 is blocked'), findsOneWidget);
  });

  testWidgets('back in front, Messages reads again', (tester) async {
    final dm = FakeDmRepository()
      ..inboxValue = DmInbox(threads: [_omar('At the gate at 7?')]);
    await pumpApp(tester, dm: dm, now: _now);
    await _go(tester, '/messages');
    dm.inboxValue = DmInbox(threads: [_omar('Gate 2 is blocked')]);
    await backToTheApp(tester);
    expect(find.textContaining('Gate 2 is blocked'), findsOneWidget);
  });

  testWidgets('a direct message push with the app open: a quiet banner; '
      'a tap opens the conversation', (tester) async {
    final push = FakePushMessaging();
    final dm = FakeDmRepository()
      ..inboxValue = DmInbox(threads: [_omar('Gate 2 is blocked')])
      ..pages['t-omar'] = _page('t-omar', 'Omar Haddad', [
        _m('m9', 'Gate 2 is blocked'),
      ]);
    await pumpApp(tester, dm: dm, push: push, now: _now);
    push.arrive(_dmPush('t-omar'));
    await tester.pumpAndSettle();
    expect(find.byType(BvMessageBanner), findsOneWidget);
    expect(find.textContaining('Message from Omar Haddad'), findsOneWidget);
    await tester.tap(find.byType(BvMessageBanner));
    await tester.pumpAndSettle();
    expect(find.byType(BvMessageBanner), findsNothing);
    expect(find.byType(DmThreadScreen), findsOneWidget);
  });

  testWidgets('no banner for the conversation on screen; it reads again '
      'instead', (tester) async {
    final push = FakePushMessaging();
    final dm = FakeDmRepository()
      ..inboxValue = DmInbox(threads: [_omar('At the gate at 7?')])
      ..pages['t-omar'] = _page('t-omar', 'Omar Haddad', [
        _m('m1', 'At the gate at 7?'),
      ]);
    await pumpApp(tester, dm: dm, push: push, now: _now);
    await _go(tester, '/messages/t-omar');
    dm.pages['t-omar'] = _page('t-omar', 'Omar Haddad', [
      _m('m9', 'Gate 2 is blocked'),
      _m('m1', 'At the gate at 7?'),
    ]);
    push.arrive(_dmPush('t-omar'));
    await tester.pumpAndSettle();
    expect(find.byType(BvMessageBanner), findsNothing);
    expect(find.textContaining('Gate 2 is blocked'), findsOneWidget);
  });

  testWidgets('the banner goes by itself', (tester) async {
    final push = FakePushMessaging();
    await pumpApp(tester, push: push, now: _now);
    push.arrive(_dmPush('t-omar'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(BvMessageBanner), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(find.byType(BvMessageBanner), findsNothing);
  });
}
