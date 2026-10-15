import 'package:buildvibes/core/l10n/bidi.dart';
import 'package:buildvibes/data/models/chat.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/models/work_item.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/chat_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';
import '../../helpers/work_fakes.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)).first);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)).first);
  await tester.pumpAndSettle();
}

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Navigator).first));

const _space = 'space-1';
const _everyone = 'thread-everyone';
const _mep = 'thread-mep';
const _me = 'user-1';

DateTime _at(int h, int m) => DateTime(2026, 10, 11, h, m);

const _rakesh = SpacePerson(
  id: 'p-rakesh',
  firstName: 'Rakesh',
  lastName: 'Nair',
);
const _omar = SpacePerson(id: _me, firstName: 'Omar', lastName: 'Haddad');

FakeSpaceRepository _spaces({bool admin = true}) =>
    FakeSpaceRepository(now: testNow)
      ..details[_space] = SpaceDetail(
        id: _space,
        name: 'Site team',
        myPass: SpacePass.lead,
        iAmAdmin: admin,
        myRights: const MemberRights(createItems: true),
      )
      ..spacePeople[_space] = SpacePeople(
        members: [
          SpaceMember(
            person: _omar,
            pass: SpacePass.lead,
            isAdmin: admin,
            confirmedAt: testNow,
          ),
          SpaceMember(
            person: _rakesh,
            pass: SpacePass.crew,
            isAdmin: false,
            confirmedAt: testNow,
          ),
        ],
      );

ChatMessage _msg(
  String id,
  String author,
  String name,
  String body,
  DateTime at, {
  String thread = _everyone,
  bool deleted = false,
}) => ChatMessage(
  id: id,
  threadId: thread,
  kind: ChatKind.text,
  createdAt: at,
  authorId: author,
  authorName: name,
  body: deleted ? null : body,
  deletedAt: deleted ? at : null,
);

FakeChatRepository _chat() => FakeChatRepository(now: _at(10, 30))
  ..threadsBySpace[_space] = [
    ChatThread(
      id: _everyone,
      lastKind: ChatKind.text,
      lastBody: 'Gate 2 is blocked by the crane.',
      lastAuthorId: 'p-rakesh',
      lastAt: _at(10, 15),
      unread: 2,
    ),
    ChatThread(
      id: _mep,
      teamId: 'team-mep',
      teamName: 'MEP Team',
      lastKind: ChatKind.text,
      lastBody: 'Sending after the walk.',
      lastAuthorId: _me,
      lastAt: _at(10, 21),
    ),
    // A Team whose last message is a work item card.
    ChatThread(
      id: 'thread-st',
      teamId: 'team-st',
      teamName: 'Structure',
      lastMessageId: 'card-1',
      lastKind: ChatKind.workItem,
      lastAuthorId: 'p-rakesh',
      lastAt: _at(10, 25),
    ),
  ]
  ..messagesByThread[_everyone] = [
    ChatMessage(
      id: 'card-1',
      threadId: _everyone,
      kind: ChatKind.workItem,
      createdAt: _at(10, 25),
      authorId: 'p-rakesh',
      authorName: 'Rakesh Nair',
      workItemId: 'item-17',
      eventKind: WorkEventKind.done,
    ),
    _msg(
      'm3',
      _me,
      'Omar Haddad',
      'Noted. I’ll bring the level 3 drawings.',
      _at(10, 20),
    ),
    _msg(
      'm2',
      'p-rakesh',
      'Rakesh Nair',
      'Gate 2 is blocked by the crane.',
      _at(10, 15),
    ),
    _msg(
      'm1',
      'p-rakesh',
      'Rakesh Nair',
      'Old news',
      _at(10, 12),
      deleted: true,
    ),
  ];

FakeWorkRepository _work() => FakeWorkRepository()
  ..itemsBySpace[_space] = [
    WorkItem(
      id: 'item-17',
      spaceId: _space,
      ref: 'KCT-017',
      title: 'Sleeves at grid C7 before the pour',
      status: WorkStatus.done,
      createdAt: testNow,
      ownerId: 'p-rakesh',
      ownerName: 'Rakesh Nair',
      createdById: _me,
      createdByName: 'Omar Haddad',
      place: 'Level 2 · Grid C7',
    ),
  ]
  ..needsBySpace[_space] = const WorkNeeds(toCheck: {'item-17'});

Future<TestApp> _openThread(
  WidgetTester tester,
  String lang, {
  String thread = _everyone,
  FakeChatRepository? chat,
  bool admin = true,
}) async {
  final app = await pumpApp(
    tester,
    language: lang,
    spaces: _spaces(admin: admin),
    work: _work(),
    chat: chat ?? _chat(),
  );
  _router(tester).push('/spaces/$_space/chat/$thread');
  await tester.pumpAndSettle();
  return app;
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);

    testWidgets('S7k: Everyone first, last lines, unread [$lang]', (
      tester,
    ) async {
      final chat = _chat();
      await pumpApp(
        tester,
        language: lang,
        spaces: _spaces(),
        work: _work(),
        chat: chat,
      );
      _router(tester).push('/spaces/$_space');
      await tester.pumpAndSettle();
      await _tap(tester, 'space-tab-chat');

      final everyone = tester.getTopLeft(
        find.byKey(const Key('chat-thread-$_everyone')),
      );
      final mep = tester.getTopLeft(find.byKey(const Key('chat-thread-$_mep')));
      expect(everyone.dy, lessThan(mep.dy));
      expect(find.text(l10n.chatEveryone), findsOneWidget);
      expect(
        find.text(
          l10n.chatLastLine(
            'Rakesh',
            inOwnDirection('Gate 2 is blocked by the crane.'),
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          l10n.chatLastLine(
            l10n.chatYou,
            inOwnDirection('Sending after the walk.'),
          ),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('chat-unread-$_everyone')), findsOneWidget);
      expect(find.byKey(const Key('chat-unread-$_mep')), findsNothing);
      // Review 13: a card says what happened; Everyone has the group icon.
      expect(find.text(l10n.chatLastDone('Rakesh', 'KCT-017')), findsOneWidget);
      expect(find.byKey(const Key('chat-everyone-tile')), findsOneWidget);
      // Admins see every Team.
      expect(find.text(l10n.chatThreadsNoteAdmin), findsOneWidget);

      await _tap(tester, 'chat-thread-$_everyone');
      expect(chat.calls, contains('read $_everyone'));
    });

    testWidgets('S8k: messages, a deleted one, and a work item card [$lang]', (
      tester,
    ) async {
      await _openThread(tester, lang);
      expect(find.text('Gate 2 is blocked by the crane.'), findsOneWidget);
      expect(find.text(l10n.chatDeleted), findsOneWidget);
      expect(find.text('Old news'), findsNothing);
      // Review 13: a bubble hugs its text, never wider than 75%.
      final short = tester.getSize(find.byKey(const Key('chat-message-m3')));
      final long = tester.getSize(find.byKey(const Key('chat-message-m2')));
      expect(short.width, lessThanOrEqualTo(390 * 0.75));
      expect(long.width, lessThanOrEqualTo(390 * 0.75));
      // Each message in the language it was written in.
      expect(
        tester
            .widget<Text>(find.text('Gate 2 is blocked by the crane.'))
            .textDirection,
        TextDirection.ltr,
      );
      // Mine at the end side, theirs at the start side.
      final mine = tester.getCenter(find.byKey(const Key('chat-message-m3')));
      final theirs = tester.getCenter(find.byKey(const Key('chat-message-m2')));
      expect(lang == 'ar' ? mine.dx < theirs.dx : mine.dx > theirs.dx, isTrue);
      // The card says who did what, then shows the item as it is now.
      expect(
        find.textContaining(l10n.chatCardDone('Rakesh Nair')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('work-item-item-17')), findsOneWidget);
      expect(find.text(l10n.workCheckIt), findsOneWidget);
    });

    testWidgets('one full card per item; its older steps are a line [$lang]', (
      tester,
    ) async {
      final chat = _chat();
      chat.messagesByThread[_everyone]!.add(
        ChatMessage(
          id: 'card-0',
          threadId: _everyone,
          kind: ChatKind.workItem,
          createdAt: _at(9, 0),
          authorId: _me,
          authorName: 'Omar Haddad',
          workItemId: 'item-17',
          eventKind: WorkEventKind.raised,
        ),
      );
      await _openThread(tester, lang, chat: chat);
      expect(find.byKey(const Key('work-item-item-17')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('chat-card-card-0')),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      final line = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('chat-card-card-0')),
          matching: find.byType(Text),
        ),
      );
      expect(line.data, contains(l10n.chatCardRaised('Omar Haddad')));
      expect(line.data, contains('KCT-017'));
    });

    testWidgets('S9k: a Team thread says who can see it [$lang]', (
      tester,
    ) async {
      final chat = _chat()
        ..messagesByThread[_mep] = [
          _msg(
            's1',
            'p-rakesh',
            'Rakesh Nair',
            'OK',
            _at(10, 18),
            thread: _mep,
          ),
          _msg('s0', _me, 'Omar Haddad', 'Go', _at(10, 17), thread: _mep),
        ];
      await _openThread(tester, lang, thread: _mep, chat: chat);
      expect(
        find.text(l10n.chatTeamPrivacy(inOwnDirection('MEP Team'))),
        findsOneWidget,
      );
      // Review 13: short messages make small bubbles, yours and theirs.
      for (final id in ['s1', 's0']) {
        final bubble = tester.getSize(find.byKey(Key('chat-message-$id')));
        expect(bubble.width, lessThan(390 * 0.4));
      }
    });

    testWidgets('send: Send appears with text; the message shows [$lang]', (
      tester,
    ) async {
      final chat = _chat();
      await _openThread(tester, lang, chat: chat);
      expect(find.byKey(const Key('chat-send')), findsNothing);
      await tester.enterText(find.byKey(const Key('chat-input')), 'On my way.');
      await tester.pumpAndSettle();
      await _tap(tester, 'chat-send');
      expect(chat.calls, contains('post $_everyone On my way.'));
      expect(find.text('On my way.'), findsOneWidget);
      expect(find.text(l10n.chatSending), findsNothing);
    });

    testWidgets('live: a new message appears and is read [$lang]', (
      tester,
    ) async {
      final chat = _chat();
      await _openThread(tester, lang, chat: chat);
      final reads = chat.calls.where((c) => c == 'read $_everyone').length;
      chat.live(
        _msg(
          'm9',
          'p-rakesh',
          'Rakesh Nair',
          'Pump truck is here.',
          _at(10, 40),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pump truck is here.'), findsOneWidget);
      expect(
        chat.calls.where((c) => c == 'read $_everyone').length,
        greaterThan(reads),
      );
    });

    testWidgets('reply: the answer quotes the message [$lang]', (tester) async {
      final chat = _chat();
      await _openThread(tester, lang, chat: chat);
      await tester.longPress(find.byKey(const Key('chat-message-m2')));
      await tester.pumpAndSettle();
      await _tap(tester, 'chat-action-reply');
      expect(
        find.text(l10n.chatReplyingTo(inOwnDirection('Rakesh Nair'))),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const Key('chat-input')),
        'Use gate 3 then.',
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'chat-send');
      expect(chat.calls, contains('post $_everyone Use gate 3 then. re m2'));
      expect(find.byKey(const Key('chat-replying')), findsNothing);
      expect(find.byKey(const Key('chat-quote')), findsOneWidget);
    });

    testWidgets('copy puts the text on the clipboard [$lang]', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await _openThread(tester, lang);
      await tester.longPress(find.byKey(const Key('chat-message-m2')));
      await tester.pumpAndSettle();
      await _tap(tester, 'chat-action-copy');
      expect(copied, 'Gate 2 is blocked by the crane.');
      expect(find.text(l10n.chatCopied), findsOneWidget);
    });

    testWidgets('delete: yours, after asking; it stays as deleted [$lang]', (
      tester,
    ) async {
      final chat = _chat();
      await _openThread(tester, lang, chat: chat, admin: false);
      // Someone else's message: no Delete for a member.
      await tester.longPress(find.byKey(const Key('chat-message-m2')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat-action-delete')), findsNothing);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await tester.longPress(find.byKey(const Key('chat-message-m3')));
      await tester.pumpAndSettle();
      await _tap(tester, 'chat-action-delete');
      expect(find.text(l10n.chatDeleteTitle), findsOneWidget);
      await _tap(tester, 'bv-dialog-confirm');
      expect(chat.calls, contains('delete m3'));
      expect(find.text(l10n.chatDeleted), findsNWidgets(2));
    });

    testWidgets('S8c: report someone else’s message; never your own [$lang]', (
      tester,
    ) async {
      final app = await _openThread(tester, lang, admin: false);
      await tester.longPress(find.byKey(const Key('chat-message-m3')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat-action-report')), findsNothing);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await tester.longPress(find.byKey(const Key('chat-message-m2')));
      await tester.pumpAndSettle();
      await _tap(tester, 'chat-action-report');
      expect(find.text(l10n.reportTitle('message')), findsOneWidget);
      await _tap(tester, 'report-reason-harassment');
      expect(app.safety.calls, ['report message m2 harassment']);
      // R2, without Block: Block is offered for posts and people.
      expect(find.text(l10n.reportSentTitle), findsOneWidget);
      expect(find.byKey(const Key('report-block')), findsNothing);
      await _tap(tester, 'report-done');
    });

    testWidgets('an admin may delete anyone’s message [$lang]', (tester) async {
      await _openThread(tester, lang);
      await tester.longPress(find.byKey(const Key('chat-message-m2')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat-action-delete')), findsOneWidget);
    });

    testWidgets('weak signal: Not sent · Retry, kept on the phone [$lang]', (
      tester,
    ) async {
      final chat = _chat()..failNext = 3;
      final app = await _openThread(tester, lang, chat: chat);
      await tester.enterText(
        find.byKey(const Key('chat-input')),
        'Crane at gate 2.',
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'chat-send');
      expect(find.text('Crane at gate 2.'), findsOneWidget);
      expect(find.textContaining(l10n.chatNotSent), findsOneWidget);
      expect(app.prefs.getString('chat_outbox'), contains('Crane at gate 2.'));

      final retry = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('chat-retry-'),
      );
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(chat.calls, contains('post $_everyone Crane at gate 2.'));
      expect(find.textContaining(l10n.chatNotSent), findsNothing);
      expect(app.prefs.getString('chat_outbox'), isNot(contains('Crane')));
    });
  }
}
