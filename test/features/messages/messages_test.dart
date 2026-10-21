import 'package:buildvibes/core/l10n/bidi.dart';
import 'package:buildvibes/data/models/chat.dart';
import 'package:buildvibes/data/models/dm.dart';
import 'package:buildvibes/data/models/people.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/dm_fakes.dart';
import '../../helpers/pump_app.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

/// Thursday 15 October, 11:00: "today" for the list.
final _now = DateTime(2026, 10, 15, 11);

DmRow _row(
  String thread,
  String person,
  String name, {
  required DateTime at,
  bool unread = false,
  bool fromMe = false,
  ChatKind kind = ChatKind.text,
  String? text,
  int? durationMs,
}) => DmRow(
  threadId: thread,
  person: DmPerson(id: person, name: name),
  lastMessageAt: at,
  unread: unread,
  last: DmPreview(
    fromMe: fromMe,
    kind: kind,
    at: at,
    text: text,
    durationMs: durationMs,
  ),
);

/// DM1's people: Omar (unread, today), Sara (my last message, today),
/// Lina (yesterday), and Yousef's request.
DmInbox _inbox() => DmInbox(
  threads: [
    _row(
      't-omar',
      'p-omar',
      'Omar Haddad',
      at: DateTime(2026, 10, 15, 10, 42),
      unread: true,
      text: 'Also the pump is booked for Sunday 2 pm.',
    ),
    _row(
      't-sara',
      'p-sara',
      'Sara Al-Mutairi',
      at: DateTime(2026, 10, 15, 9, 20),
      fromMe: true,
      text: 'Sent you the photos',
    ),
    _row(
      't-rakesh',
      'p-rakesh',
      'Rakesh Nair',
      at: DateTime(2026, 10, 15, 8, 5),
      unread: true,
      kind: ChatKind.voice,
      durationMs: 24000,
    ),
    _row(
      't-lina',
      'p-lina',
      'Lina Khalil',
      at: DateTime(2026, 10, 14, 17),
      text: 'Thanks',
    ),
  ],
  newestRequest: _row(
    't-yousef',
    'p-yousef',
    'Yousef Karam',
    at: DateTime(2026, 10, 15, 10),
    unread: true,
    text: 'Salam, can we talk about the finishing work?',
  ),
);

DmThreadPage _omar({DmState state = DmState.open, bool tapToShow = false}) =>
    DmThreadPage(
      threadId: 't-omar',
      person: const DmPerson(
        id: 'p-omar',
        name: 'Omar Haddad',
        headline: 'Site Engineer',
        company: 'Al Hamra Contracting',
      ),
      state: state,
      sharedSpaceId: 's-kct',
      sharedSpaceName: 'Kuwait City Tower',
      messages: [
        DmMessage(
          id: 'm2',
          fromMe: false,
          kind: ChatKind.photo,
          createdAt: DateTime(2026, 10, 15, 10, 42),
          tapToShow: tapToShow,
          files: const [DmFile(path: 'p-omar/m2/a.jpg', mime: 'image/jpeg')],
        ),
        DmMessage(
          id: 'm1',
          fromMe: false,
          kind: ChatKind.text,
          createdAt: DateTime(2026, 10, 15, 10, 40),
          body: 'At the gate at 7?',
        ),
      ],
    );

Future<void> _go(WidgetTester tester, String path) async {
  GoRouter.of(tester.element(find.byType(Scaffold).first)).push(path);
  await tester.pumpAndSettle();
}

/// Holds the mic for [hold], then lets go (after sliding by [slide]).
Future<void> _record(
  WidgetTester tester,
  Duration hold, {
  Offset slide = Offset.zero,
}) async {
  final mic = tester.getCenter(find.byKey(const Key('chat-record')));
  final gesture = await tester.startGesture(mic);
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
  await tester.pump(hold);
  if (slide != Offset.zero) {
    await gesture.moveBy(slide);
    await tester.pump();
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);

    testWidgets('Home: Messages beside Search, with a dot while something '
        'is unread [$lang]', (tester) async {
      final dm = FakeDmRepository()..inboxValue = _inbox();
      await pumpApp(tester, language: lang, dm: dm, now: _now);
      expect(find.byKey(const Key('home-messages')), findsOneWidget);
      expect(find.byKey(const Key('home-messages-dot')), findsOneWidget);
      await _tap(tester, find.byKey(const Key('home-messages')));
      expect(find.text(l10n.messagesTitle), findsOneWidget);
    });

    testWidgets('Home: no dot when everything is read [$lang]', (tester) async {
      await pumpApp(tester, language: lang, now: _now);
      expect(find.byKey(const Key('home-messages')), findsOneWidget);
      expect(find.byKey(const Key('home-messages-dot')), findsNothing);
    });

    testWidgets('DM1: the request on top, Today and Earlier, dots and '
        'previews, never a number [$lang]', (tester) async {
      final dm = FakeDmRepository()..inboxValue = _inbox();
      await pumpApp(tester, language: lang, dm: dm, now: _now);
      await _go(tester, '/messages');
      expect(find.byKey(const Key('messages-request')), findsOneWidget);
      expect(find.text(l10n.messagesRequest), findsOneWidget);
      expect(find.text(l10n.messagesToday), findsOneWidget);
      expect(find.text(l10n.messagesEarlier), findsOneWidget);
      // Omar and Rakesh are unread; Sara's last line is mine.
      expect(find.byKey(const Key('messages-unread-dot')), findsNWidgets(2));
      expect(
        find.text(l10n.messagesYou(inOwnDirection('Sent you the photos'))),
        findsOneWidget,
      );
      expect(find.text(l10n.messagesVoice('0:24')), findsOneWidget);
      // The request comes before Today.
      expect(
        tester.getTopLeft(find.byKey(const Key('messages-request'))).dy,
        lessThan(tester.getTopLeft(find.text(l10n.messagesToday)).dy),
      );
      expect(find.textContaining(RegExp(r'\b[2-9] unread')), findsNothing);
    });

    testWidgets('DM1: search finds a name [$lang]', (tester) async {
      final dm = FakeDmRepository()..inboxValue = _inbox();
      await pumpApp(tester, language: lang, dm: dm, now: _now);
      await _go(tester, '/messages');
      await _tap(tester, find.byKey(const Key('messages-search-toggle')));
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('messages-search')),
          matching: find.byType(TextField),
        ),
        'lina',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('messages-row-t-lina')), findsOneWidget);
      expect(find.byKey(const Key('messages-row-t-omar')), findsNothing);
      expect(find.byKey(const Key('messages-request')), findsNothing);
    });

    testWidgets('DM2: a row opens the thread: who, Both in, the messages; '
        'it is marked read [$lang]', (tester) async {
      final dm = FakeDmRepository()
        ..inboxValue = _inbox()
        ..pages['t-omar'] = _omar();
      await pumpApp(tester, language: lang, dm: dm, now: _now);
      await _go(tester, '/messages');
      await _tap(tester, find.byKey(const Key('messages-row-t-omar')));
      expect(
        find.text('Site Engineer · ${inOwnDirection('Al Hamra Contracting')}'),
        findsOneWidget,
      );
      expect(
        find.text(l10n.dmBothIn(inOwnDirection('Kuwait City Tower'))),
        findsOneWidget,
      );
      expect(find.text('At the gate at 7?'), findsOneWidget);
      expect(dm.calls, contains('read t-omar'));
      expect(find.byKey(const Key('dm-request-strip')), findsNothing);
    });

    testWidgets('DM2: Send, and a reply from holding a message (DM3) '
        '[$lang]', (tester) async {
      final dm = FakeDmRepository()..pages['t-omar'] = _omar();
      await pumpApp(tester, language: lang, dm: dm, now: _now);
      await _go(tester, '/messages/t-omar');
      await tester.enterText(find.byKey(const Key('chat-input')), 'Yes, 7.');
      await tester.pump();
      await _tap(tester, find.byKey(const Key('chat-send')));
      expect(dm.calls, contains('send t-omar Yes, 7.'));
      await tester.longPress(find.byKey(const Key('chat-message-m1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dm-action-reply')), findsOneWidget);
      expect(find.byKey(const Key('dm-action-copy')), findsOneWidget);
      expect(find.byKey(const Key('dm-action-report')), findsOneWidget);
      expect(find.byKey(const Key('dm-action-delete')), findsNothing);
      await _tap(tester, find.byKey(const Key('dm-action-reply')));
      expect(find.byKey(const Key('chat-replying')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('chat-input')), 'Sure');
      await tester.pump();
      await _tap(tester, find.byKey(const Key('chat-send')));
      expect(dm.calls, contains('send t-omar Sure reply m1'));
    });

    testWidgets('voice notes: hold the mic and let go to send; slide away '
        'to cancel; a received one plays in its bubble [$lang]', (
      tester,
    ) async {
      final page = _omar();
      final dm = FakeDmRepository()
        ..pages['t-omar'] = DmThreadPage(
          threadId: page.threadId,
          person: page.person,
          messages: [
            DmMessage(
              id: 'v1',
              fromMe: false,
              kind: ChatKind.voice,
              createdAt: DateTime(2026, 10, 15, 10, 40),
              files: const [
                DmFile(
                  path: 'p-omar/v1/a.m4a',
                  mime: 'audio/mp4',
                  durationMs: 18000,
                ),
              ],
            ),
            ...page.messages,
          ],
        );
      await pumpApp(tester, language: lang, dm: dm, now: _now);
      await _go(tester, '/messages/t-omar');
      expect(find.byKey(const Key('chat-voice-v1')), findsOneWidget);
      expect(find.byKey(const Key('chat-record')), findsOneWidget);
      await _record(tester, const Duration(seconds: 2));
      expect(dm.calls, contains('send t-omar null files 1'));
      await _record(
        tester,
        const Duration(seconds: 2),
        slide: const Offset(-200, 0),
      );
      expect(
        dm.calls.where((c) => c.startsWith('send t-omar null')),
        hasLength(1),
      );
    });

    testWidgets('DM6: a request: Not in your Spaces · Decline · Block, and '
        'photos behind Tap to show [$lang]', (tester) async {
      final dm = FakeDmRepository()
        ..pages['t-omar'] = _omar(state: DmState.request, tapToShow: true);
      await pumpApp(tester, language: lang, dm: dm, now: _now);
      await _go(tester, '/messages/t-omar');
      expect(find.text(l10n.dmNotInSpaces), findsOneWidget);
      expect(find.byKey(const Key('dm-tap-to-show')), findsOneWidget);
      await _tap(tester, find.byKey(const Key('dm-tap-to-show')));
      expect(find.byKey(const Key('dm-tap-to-show')), findsNothing);
      await _tap(tester, find.byKey(const Key('dm-decline')));
      expect(dm.calls, contains('decline t-omar'));
      expect(
        find.text(l10n.dmDeclined(inOwnDirection('Omar Haddad'))),
        findsOneWidget,
      );
    });

    testWidgets('DM2 ⋯: Mute, Report the person, Block [$lang]', (
      tester,
    ) async {
      final dm = FakeDmRepository()..pages['t-omar'] = _omar();
      await pumpApp(tester, language: lang, dm: dm, now: _now);
      await _go(tester, '/messages/t-omar');
      await _tap(tester, find.byKey(const Key('dm-more')));
      expect(find.byKey(const Key('dm-menu-report')), findsOneWidget);
      expect(find.byKey(const Key('dm-menu-block')), findsOneWidget);
      await _tap(tester, find.byKey(const Key('dm-menu-mute')));
      expect(dm.calls, contains('mute t-omar true'));
    });

    testWidgets('a new conversation from a profile: the first message makes '
        'the thread (start_dm) [$lang]', (tester) async {
      final dm = FakeDmRepository();
      final app = await pumpApp(tester, language: lang, dm: dm, now: _now);
      app.profiles.profiles['p-layla'] = const MyProfile(
        id: 'p-layla',
        firstName: 'Layla',
        lastName: 'Haddad',
        locale: 'en',
        tradeId: 'site_engineer',
        homeMarketId: 'kw',
      );
      await _go(tester, '/people/p-layla');
      expect(find.text(l10n.profileMessage), findsOneWidget);
      await _tap(tester, find.byKey(const Key('profile-message')));
      expect(find.text(inOwnDirection('Layla Haddad')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('chat-input')), 'Hello');
      await tester.pump();
      await _tap(tester, find.byKey(const Key('chat-send')));
      expect(dm.calls, contains('start p-layla Hello'));
    });

    testWidgets('paused by the spam guard: nothing is sent, it says when '
        '[$lang]', (tester) async {
      final dm = FakeDmRepository()
        ..startAnswer = (_) => DmStart(
          threadId: null,
          state: 'paused',
          warning: true,
          until: DateTime(2026, 10, 18),
        );
      await pumpApp(tester, language: lang, dm: dm, now: _now);
      await _go(tester, '/messages/with/p-new');
      await tester.enterText(find.byKey(const Key('chat-input')), 'Hi');
      await tester.pump();
      await _tap(tester, find.byKey(const Key('chat-send')));
      expect(find.textContaining(l10n.dmPaused('').split(' ').first), findsOne);
      expect(find.text('Hi'), findsNothing);
    });
  }
}
