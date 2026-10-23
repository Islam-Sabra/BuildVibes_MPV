// F100 (review 50): with the app open, a new direct message shows at once,
// push or no push. The dm: channels open once signed in, open again after
// a new token or a new sign-in, and a little after one closes or fails;
// a live message shows the banner once.
import 'package:buildvibes/core/design/bv_specs.dart';
import 'package:buildvibes/data/models/chat.dart';
import 'package:buildvibes/data/models/dm.dart';
import 'package:buildvibes/data/repositories/push_repository.dart';
import 'package:buildvibes/features/messages/dm_live.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_message_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/dm_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/push_fakes.dart';

final _now = DateTime(2026, 10, 15, 11);
final _l10n = lookupAppLocalizations(const Locale('en'));

DmRow _omar(String text, {bool unread = true}) => DmRow(
  threadId: 't-omar',
  person: const DmPerson(id: 'p-omar', name: 'Omar Haddad'),
  lastMessageAt: _now,
  unread: unread,
  last: DmPreview(fromMe: false, kind: ChatKind.text, at: _now, text: text),
);

Finder get _banner => find.byType(BvMessageBanner);

/// The banner's words, as the person reads them.
String _bannerText(WidgetTester tester) {
  final b = tester.widget<BvMessageBanner>(_banner);
  return '${b.title} ${b.body}';
}

Map<String, String> _push(String kind, {String message = 'm9'}) => {
  'kind': kind,
  'route': '/messages/t-omar',
  'dm_thread_id': 't-omar',
  'message_id': message,
  pushTitleKey: 'Message from Omar Haddad',
  pushBodyKey: 'Open BuildVibes to read it.',
};

void main() {
  testWidgets('a channel that closes and then fails to open is opened '
      'again: 2 s, 5 s, 15 s, then every 30 s', (tester) async {
    final dm = FakeDmRepository()
      ..inboxValue = DmInbox(threads: [_omar('At the gate at 7?')]);
    await pumpApp(tester, dm: dm, now: _now);
    expect(dm.opens['t-omar'], 1);
    expect(dm.listened, contains('t-omar'));
    // The socket drops, and the next three joins are refused.
    dm.failOpens['t-omar'] = 3;
    dm.drop('t-omar');
    await tester.pump();
    expect(dm.listened, isNot(contains('t-omar')));
    Future<void> wait(int seconds) => tester.pump(Duration(seconds: seconds));
    await tester.pump(const Duration(milliseconds: 1900));
    expect(dm.opens['t-omar'], 1, reason: 'not before 2 s');
    await tester.pump(const Duration(milliseconds: 100));
    expect(dm.opens['t-omar'], 2);
    await wait(4);
    expect(dm.opens['t-omar'], 2, reason: 'then 5 s');
    await wait(1);
    expect(dm.opens['t-omar'], 3);
    await wait(15);
    expect(dm.opens['t-omar'], 4);
    await wait(29);
    expect(dm.opens['t-omar'], 4, reason: 'then 30 s');
    await wait(1);
    expect(dm.opens['t-omar'], 5);
    expect(dm.listened, contains('t-omar'));
    // Joined: the next drop starts from the first wait again.
    dm.drop('t-omar');
    await tester.pump();
    await wait(2);
    expect(dm.opens['t-omar'], 6);
    expect(dm.listened, contains('t-omar'));
  });

  testWidgets('a channel that fails to open at the start is opened again', (
    tester,
  ) async {
    final dm = FakeDmRepository()
      ..inboxValue = DmInbox(threads: [_omar('At the gate at 7?')])
      ..failOpens['t-omar'] = 1;
    await pumpApp(tester, dm: dm, now: _now);
    await tester.pump(const Duration(seconds: 2));
    expect(dm.opens['t-omar'], greaterThanOrEqualTo(2));
    expect(dm.listened, contains('t-omar'));
  });

  testWidgets('a channel opened before the sign-in token is new is opened '
      'again after it; signed out, none stays open; signed in again, it '
      'opens', (tester) async {
    final dm = FakeDmRepository()
      ..inboxValue = DmInbox(threads: [_omar('At the gate at 7?')]);
    final app = await pumpApp(tester, dm: dm, now: _now);
    expect(dm.opens['t-omar'], 1);
    app.auth.renew();
    await tester.pumpAndSettle();
    expect(dm.opens['t-omar'], 2);
    expect(dm.listened, {'t-omar'});

    await app.auth.signOut();
    await tester.pumpAndSettle();
    expect(dm.listened, isEmpty);
    app.auth.signInAgain('user-1');
    await tester.pumpAndSettle();
    expect(dm.listened, {'t-omar'});
    expect(dm.opens['t-omar'], greaterThan(2));
  });

  testWidgets('back in front, the channels open again', (tester) async {
    final dm = FakeDmRepository()
      ..inboxValue = DmInbox(threads: [_omar('At the gate at 7?')]);
    await pumpApp(tester, dm: dm, now: _now);
    expect(dm.opens['t-omar'], 1);
    await backToTheApp(tester);
    expect(dm.opens['t-omar'], 2);
    expect(dm.listened, {'t-omar'});
  });

  testWidgets('a message that arrives live with no push shows the banner '
      'and the unread dot', (tester) async {
    final dm = FakeDmRepository()
      ..inboxValue = DmInbox(
        threads: [_omar('At the gate at 7?', unread: false)],
      );
    await pumpApp(tester, dm: dm, now: _now);
    expect(find.byKey(const Key('home-messages-dot')), findsNothing);
    dm.inboxValue = DmInbox(threads: [_omar('Stop the pour')]);
    dm.arrive('t-omar', 'm9', authorId: 'p-omar', body: 'Stop the pour');
    await tester.pumpAndSettle();
    expect(_banner, findsOneWidget);
    // The lock-screen setting hides message text (the default): so does
    // the banner.
    expect(_bannerText(tester), contains('Omar Haddad'));
    expect(_bannerText(tester), contains(_l10n.dmBannerHidden));
    expect(_bannerText(tester), isNot(contains('Stop the pour')));
    expect(find.byKey(const Key('home-messages-dot')), findsOneWidget);
  });

  testWidgets('with message text shown on the lock screen, the banner has '
      'the words; my own message shows none', (tester) async {
    final dm = FakeDmRepository()
      ..inboxValue = DmInbox(threads: [_omar('At the gate at 7?')]);
    final app = await pumpApp(tester, dm: dm, now: _now);
    app.pushes.saved = const PushSettings(messageText: true);
    dm.arrive('t-omar', 'm1', authorId: 'user-1', body: 'On my way');
    await tester.pumpAndSettle();
    expect(_banner, findsNothing);
    dm.arrive('t-omar', 'm9', authorId: 'p-omar', body: 'Stop the pour');
    await tester.pumpAndSettle();
    expect(_bannerText(tester), contains('Stop the pour'));
  });

  testWidgets('the same message live and by push shows one banner, in '
      'either order, even after the first has gone', (tester) async {
    final push = FakePushMessaging();
    final dm = FakeDmRepository()
      ..inboxValue = DmInbox(threads: [_omar('At the gate at 7?')]);
    await pumpApp(tester, dm: dm, push: push, now: _now);
    dm.arrive('t-omar', 'm9', authorId: 'p-omar', body: 'Stop the pour');
    await tester.pumpAndSettle();
    expect(_banner, findsOneWidget);
    final first = _bannerText(tester);
    push.arrive(_push('dm_message'));
    await tester.pumpAndSettle();
    expect(_banner, findsOneWidget);
    expect(_bannerText(tester), first, reason: 'the same banner');
    // Gone; the push for it comes late: nothing again.
    await tester.pump(BvMessageBannerSpec.shown + const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(_banner, findsNothing);
    push.arrive(_push('dm_message'));
    await tester.pumpAndSettle();
    expect(_banner, findsNothing);

    // Push first, then live.
    push.arrive(_push('dm_message', message: 'm10'));
    await tester.pumpAndSettle();
    expect(_banner, findsOneWidget);
    dm.arrive('t-omar', 'm10', authorId: 'p-omar', body: 'Now');
    await tester.pumpAndSettle();
    expect(_banner, findsOneWidget);
    expect(_bannerText(tester), contains('Open BuildVibes to read it.'));
  });

  testWidgets('a follow-up push reads the list again and shows no banner', (
    tester,
  ) async {
    final push = FakePushMessaging();
    final dm = FakeDmRepository()
      ..inboxValue = DmInbox(
        threads: [_omar('At the gate at 7?', unread: false)],
      );
    await pumpApp(tester, dm: dm, push: push, now: _now);
    GoRouter.of(tester.element(find.byType(Scaffold).first)).push('/messages');
    await tester.pumpAndSettle();
    dm.inboxValue = DmInbox(threads: [_omar('Stop the pour')]);
    push.arrive(_push('dm_follow_up'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Stop the pour'), findsOneWidget);
    expect(_banner, findsNothing);
    expect(dmPushKinds, contains('dm_follow_up'));
  });

  testWidgets('no live banner for the conversation on screen', (tester) async {
    final dm = FakeDmRepository()
      ..inboxValue = DmInbox(threads: [_omar('At the gate at 7?')])
      ..pages['t-omar'] = DmThreadPage(
        threadId: 't-omar',
        person: const DmPerson(id: 'p-omar', name: 'Omar Haddad'),
      );
    await pumpApp(tester, dm: dm, now: _now);
    GoRouter.of(
      tester.element(find.byType(Scaffold).first),
    ).push('/messages/t-omar');
    await tester.pumpAndSettle();
    final opens = dm.opens['t-omar'];
    final reads = dm.pageReads['t-omar']!;
    dm.arrive('t-omar', 'm9', authorId: 'p-omar', body: 'Stop the pour');
    await tester.pumpAndSettle();
    expect(_banner, findsNothing);
    // One channel for the thread: the screen opens none of its own.
    expect(dm.opens['t-omar'], opens);
    // The screen reads the conversation again.
    expect(dm.pageReads['t-omar'], greaterThan(reads));
  });
}
