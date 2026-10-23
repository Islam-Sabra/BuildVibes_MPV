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

Map<String, String> _dmPush(
  String thread, {
  String message = 'm9',
  String title = 'Message from Omar Haddad',
  String body = 'Gate 2 is blocked',
}) => {
  'kind': 'dm_message',
  'route': '/messages/$thread',
  'dm_thread_id': thread,
  'message_id': message,
  pushTitleKey: title,
  pushBodyKey: body,
};

Finder get _banner => find.byType(BvMessageBanner);

/// The banner's place now: Offset.zero once it has slid in.
Offset _slid(WidgetTester tester) => tester
    .widget<SlideTransition>(find.byKey(const Key('dm-banner-slide')))
    .position
    .value;

/// [time] passing as on a phone, one frame each 16 ms.
Future<void> _frames(WidgetTester tester, Duration time) async {
  const frame = Duration(milliseconds: 16);
  for (var t = Duration.zero; t < time; t += frame) {
    await tester.pump(time - t < frame ? time - t : frame);
  }
}

Key? _bannerKey(WidgetTester tester) => tester
    .widget<Dismissible>(
      find.ancestor(of: _banner, matching: find.byType(Dismissible)),
    )
    .key;

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

  group('F99: the banner stays long enough to read and tap', () {
    testWidgets('a Messages refresh, a live change and the same push again '
        'leave it: there at 3.9 s, gone at 4.5 s', (tester) async {
      final push = FakePushMessaging();
      final dm = FakeDmRepository()
        ..inboxValue = DmInbox(threads: [_omar('At the gate at 7?')]);
      await pumpApp(tester, dm: dm, push: push, now: _now);
      push.arrive(_dmPush('t-omar'));
      await tester.pump();
      await tester.pump();
      final shown = tester.binding.clock.now();
      expect(_banner, findsOneWidget);
      // The Messages refresh the push and Realtime cause, and the same
      // message's push a second time (a phone with two tokens).
      await tester.pump(const Duration(milliseconds: 100));
      dm.inboxValue = DmInbox(threads: [_omar('Gate 2 is blocked')]);
      dm.push('t-omar', 'm9');
      push.arrive(_dmPush('t-omar'));
      await tester.pump(const Duration(milliseconds: 100));
      await backToTheApp(tester);
      expect(_banner, findsOneWidget);
      await tester.pump(
        const Duration(milliseconds: 3900) -
            tester.binding.clock.now().difference(shown),
      );
      expect(_banner, findsOneWidget);
      expect(find.text('Gate 2 is blocked'), findsOneWidget);
      await _frames(tester, const Duration(milliseconds: 600));
      expect(_banner, findsNothing);
    });

    testWidgets('a second message of the same conversation changes the '
        'words in place, with no new slide-in, and starts the 4 s again: '
        'there at 6.9 s, gone by 7.5 s', (tester) async {
      final push = FakePushMessaging();
      await pumpApp(tester, push: push, now: _now);
      push.arrive(_dmPush('t-omar'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      final key = _bannerKey(tester);
      expect(_slid(tester), Offset.zero);
      await tester.pump(const Duration(seconds: 2));
      // 3 s: the next message.
      push.arrive(_dmPush('t-omar', message: 'm10', body: 'Pump is late'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Pump is late'), findsOneWidget);
      expect(find.text('Gate 2 is blocked'), findsNothing);
      // The same banner, where it was: no slide-in.
      expect(_bannerKey(tester), key);
      expect(_slid(tester), Offset.zero);
      await tester.pump(const Duration(milliseconds: 3900));
      expect(_banner, findsOneWidget);
      await _frames(tester, const Duration(milliseconds: 600));
      expect(_banner, findsNothing);
    });

    testWidgets('another conversation replaces it, sliding in', (tester) async {
      final push = FakePushMessaging();
      await pumpApp(tester, push: push, now: _now);
      push.arrive(_dmPush('t-omar'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      final key = _bannerKey(tester);
      push.arrive(
        _dmPush(
          't-sara',
          message: 'm20',
          title: 'Message from Sara Ali',
          body: 'Rebar is here',
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(_banner, findsOneWidget);
      expect(find.text('Message from Sara Ali'), findsOneWidget);
      expect(find.text('Message from Omar Haddad'), findsNothing);
      expect(_bannerKey(tester), isNot(key));
      expect(_slid(tester), isNot(Offset.zero));
      await tester.pumpAndSettle();
      expect(_slid(tester), Offset.zero);
    });

    testWidgets('a swipe up takes it away at once', (tester) async {
      final push = FakePushMessaging();
      await pumpApp(tester, push: push, now: _now);
      push.arrive(_dmPush('t-omar'));
      await tester.pumpAndSettle();
      await tester.fling(_banner, const Offset(0, -200), 1000);
      await tester.pumpAndSettle();
      expect(_banner, findsNothing);
      expect(find.byType(DmThreadScreen), findsNothing);
    });

    testWidgets('it goes when its conversation opens', (tester) async {
      final push = FakePushMessaging();
      final dm = FakeDmRepository()
        ..pages['t-omar'] = _page('t-omar', 'Omar Haddad', [
          _m('m9', 'Gate 2 is blocked'),
        ]);
      await pumpApp(tester, dm: dm, push: push, now: _now);
      push.arrive(_dmPush('t-omar'));
      await tester.pump();
      await tester.pump();
      expect(_banner, findsOneWidget);
      await _go(tester, '/messages/t-omar');
      expect(_banner, findsNothing);
    });
  });
}
