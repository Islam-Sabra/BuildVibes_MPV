// F105: every way into a chat gives the same Back. From a Space thread,
// Back goes to that Space's Chat tab, then where the person came from;
// from a direct message, to Messages, then where they came from.
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/data/models/activity.dart';
import 'package:buildvibes/data/models/chat.dart';
import 'package:buildvibes/data/models/dm.dart';
import 'package:buildvibes/data/models/library.dart';
import 'package:buildvibes/data/models/people.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/models/space_search.dart';
import 'package:buildvibes/features/chat/chat_tab.dart';
import 'package:buildvibes/features/chat/thread_screen.dart';
import 'package:buildvibes/features/home/home_screen.dart';
import 'package:buildvibes/features/library/file_preview_screen.dart';
import 'package:buildvibes/features/messages/dm_live.dart';
import 'package:buildvibes/features/messages/dm_thread_screen.dart';
import 'package:buildvibes/features/messages/messages_screen.dart';
import 'package:buildvibes/features/profile/person_profile_screen.dart';
import 'package:buildvibes/features/spaces/space_screen.dart';
import 'package:buildvibes/features/spaces/space_search_screen.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_message_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/activity_fakes.dart';
import '../../helpers/chat_fakes.dart';
import '../../helpers/dm_fakes.dart';
import '../../helpers/library_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/push_fakes.dart';
import '../../helpers/search_fakes.dart';
import '../../helpers/space_fakes.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));

const _space = 'space-1';
const _thread = 'thread-everyone';

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

Future<void> _tapKey(WidgetTester tester, String key) =>
    _tap(tester, find.byKey(Key(key)));

Future<void> _push(WidgetTester tester, String path) async {
  GoRouter.of(tester.element(find.byType(Navigator).first)).push(path);
  await tester.pumpAndSettle();
}

/// The phone's Back.
Future<void> _back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

FakeSpaceRepository _spaces() => FakeSpaceRepository(now: testNow)
  ..spaces.add(
    const SpaceSummary(
      id: _space,
      name: 'Tower B — Site team',
      pass: SpacePass.lead,
      isAdmin: true,
    ),
  )
  ..details[_space] = const SpaceDetail(
    id: _space,
    name: 'Tower B — Site team',
    myPass: SpacePass.lead,
    iAmAdmin: true,
    myRights: MemberRights(createItems: true, addFiles: true),
  );

FakeChatRepository _chat() => FakeChatRepository(now: testNow)
  ..threadsBySpace[_space] = [
    ChatThread(
      id: _thread,
      lastKind: ChatKind.text,
      lastBody: 'Podium slab poured last night.',
      lastAuthorId: 'p-omar',
      lastAt: testNow,
    ),
  ]
  ..messagesByThread[_thread] = [
    ChatMessage(
      id: 'msg-1',
      threadId: _thread,
      kind: ChatKind.text,
      createdAt: testNow,
      authorId: 'p-omar',
      authorName: 'Omar Haddad',
      body: 'Podium slab poured last night.',
    ),
  ];

FakeDmRepository _dm() => FakeDmRepository()
  ..inboxValue = DmInbox(
    threads: [
      DmRow(
        threadId: 't-omar',
        person: const DmPerson(id: 'p-omar', name: 'Omar Haddad'),
        lastMessageAt: testNow,
        unread: true,
        last: DmPreview(
          fromMe: false,
          kind: ChatKind.text,
          at: testNow,
          text: 'Gate 2 is blocked',
        ),
      ),
    ],
  )
  ..pages['t-omar'] = DmThreadPage(
    threadId: 't-omar',
    person: const DmPerson(id: 'p-omar', name: 'Omar Haddad'),
    state: DmState.open,
    messages: [
      DmMessage(
        id: 'm9',
        fromMe: false,
        kind: ChatKind.text,
        createdAt: testNow,
        body: 'Gate 2 is blocked',
      ),
    ],
  );

/// Home's Spaces list says the Space's news is a chat message.
FakeActivityRepository _chatNews() => FakeActivityRepository(
  today: [
    SpaceToday(
      spaceId: _space,
      spaceName: 'Tower B — Site team',
      change: SpaceChange.chat,
      at: testNow.subtract(const Duration(hours: 1)),
      threadId: _thread,
      messageKind: 'text',
      messageBody: 'Podium slab poured last night.',
      actorName: 'Omar Haddad',
    ),
  ],
);

Future<TestApp> _pump(
  WidgetTester tester, {
  FakePushMessaging? push,
  FakeSearchRepository? search,
  FakeLibraryRepository? library,
}) => pumpApp(
  tester,
  spaces: _spaces(),
  chat: _chat(),
  dm: _dm(),
  activity: _chatNews(),
  push: push,
  search: search,
  library: library,
);

/// A Space thread is on screen; Back shows the Space on its Chat tab.
Future<void> _backToSpaceChat(WidgetTester tester) async {
  expect(find.byType(ThreadScreen), findsOneWidget);
  await _back(tester);
  expect(find.byType(ThreadScreen), findsNothing);
  expect(find.byType(SpaceScreen), findsOneWidget);
  expect(find.byType(ChatTab), findsOneWidget);
}

/// A direct message is on screen; Back shows Messages.
Future<void> _backToMessages(WidgetTester tester) async {
  expect(find.byType(DmThreadScreen), findsOneWidget);
  await _back(tester);
  expect(find.byType(DmThreadScreen), findsNothing);
  expect(find.byType(MessagesScreen), findsOneWidget);
}

/// Back once more: Home.
Future<void> _backHome(WidgetTester tester) async {
  await _back(tester);
  expect(find.byType(SpaceScreen), findsNothing);
  expect(find.byType(MessagesScreen), findsNothing);
  expect(find.byType(HomeScreen), findsOneWidget);
}

Future<void> _openFromHomeSpaces(WidgetTester tester) async {
  await _tap(tester, find.text(_l10n.homeSpaces));
  await _tapKey(tester, 'home-space-$_space');
}

void main() {
  testWidgets('Home Spaces row with chat news: the thread, then the Space\'s '
      'Chat tab, then Home, every time and after a restart', (tester) async {
    for (var start = 0; start < 2; start++) {
      await _pump(tester);
      for (var time = 0; time < 2; time++) {
        await _openFromHomeSpaces(tester);
        await _backToSpaceChat(tester);
        await _backHome(tester);
      }
    }
  });

  testWidgets('the Space\'s Chat tab: the thread, then the Chat tab, then '
      'where the Space opened from', (tester) async {
    await _pump(tester);
    await _push(tester, '/spaces/$_space');
    await _tapKey(tester, 'space-tab-chat');
    await _tapKey(tester, 'chat-thread-$_thread');
    await _backToSpaceChat(tester);
    await _backHome(tester);
  });

  testWidgets('a notification for a Space chat: the thread, then the Chat '
      'tab, then the page it opened over', (tester) async {
    final push = FakePushMessaging();
    await _pump(tester, push: push);
    push.tap({'route': '/spaces/$_space/chat/$_thread'});
    await tester.pumpAndSettle();
    await _backToSpaceChat(tester);
    await _backHome(tester);
  });

  testWidgets('a notification for a direct message: the thread, then '
      'Messages, then the page it opened over', (tester) async {
    final push = FakePushMessaging();
    await _pump(tester, push: push);
    push.tap({'route': '/messages/t-omar'});
    await tester.pumpAndSettle();
    await _backToMessages(tester);
    await _backHome(tester);
  });

  testWidgets('the message banner: the thread, then Messages, then the page '
      'it opened over', (tester) async {
    final push = FakePushMessaging();
    await _pump(tester, push: push);
    push.arrive({
      'kind': 'dm_message',
      'route': '/messages/t-omar',
      'dm_thread_id': 't-omar',
      'message_id': 'm9',
      pushTitleKey: 'Message from Omar Haddad',
      pushBodyKey: 'Gate 2 is blocked',
    });
    await tester.pumpAndSettle();
    await _tap(tester, find.byType(BvMessageBanner));
    await _backToMessages(tester);
    await _backHome(tester);
  });

  testWidgets('Library Share in chat: the thread, then the Chat tab, then '
      'the file', (tester) async {
    final library = FakeLibraryRepository(now: testNow)
      ..filesBySpace[_space] = [
        LibraryFile(
          id: 'f-plan',
          spaceId: _space,
          name: 'Level 3 plan.pdf',
          path: '$_space/library/f-plan/x.pdf',
          mime: 'application/pdf',
          createdAt: testNow,
          bytes: 4800000,
          uploadedById: 'p-omar',
          uploadedByName: 'Omar Haddad',
        ),
      ];
    await _pump(tester, library: library);
    await _push(tester, '/spaces/$_space/library/f-plan');
    await _tapKey(tester, 'preview-share');
    await _tapKey(tester, 'share-to-$_thread');
    // F77: the file waits in the message box.
    expect(find.text('Level 3 plan.pdf'), findsOneWidget);
    await _backToSpaceChat(tester);
    await _back(tester);
    expect(find.byType(SpaceScreen), findsNothing);
    expect(find.byType(FilePreviewScreen), findsOneWidget);
  });

  testWidgets('a Space search hit: the thread at the message, then the Chat '
      'tab, then the search', (tester) async {
    final search = FakeSearchRepository()
      ..hits.add(
        SpaceSearchHit(
          kind: SpaceSearchKind.message,
          id: 'msg-1',
          threadId: _thread,
          snippet: 'Podium slab poured last night.',
          authorName: 'Omar Haddad',
          createdAt: testNow,
        ),
      );
    await _pump(tester, search: search);
    await _push(tester, '/spaces/$_space');
    await _tapKey(tester, 'space-search');
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('search-field')),
        matching: find.byType(TextField),
      ),
      'podium',
    );
    await tester.pump(BvMotion.searchWait);
    await tester.pumpAndSettle();
    await _tapKey(tester, 'search-message-msg-1');
    expect(
      tester.widget<ThreadScreen>(find.byType(ThreadScreen)).atMessage,
      'msg-1',
    );
    await _backToSpaceChat(tester);
    await _back(tester);
    expect(find.byType(SpaceSearchScreen), findsOneWidget);
  });

  testWidgets('Home, Messages, a conversation: Back to Messages, then Home', (
    tester,
  ) async {
    await _pump(tester);
    await _tapKey(tester, 'home-messages');
    await _tapKey(tester, 'messages-row-t-omar');
    await _backToMessages(tester);
    await _backHome(tester);
  });

  testWidgets('a profile\'s Message: the conversation, then Messages, then '
      'the profile', (tester) async {
    final app = await _pump(tester);
    app.profiles.profiles['p-layla'] = const MyProfile(
      id: 'p-layla',
      firstName: 'Layla',
      lastName: 'Haddad',
      locale: 'en',
      tradeId: 'site_engineer',
      homeMarketId: 'kw',
    );
    await _push(tester, '/people/p-layla');
    await _tapKey(tester, 'profile-message');
    await _backToMessages(tester);
    await _back(tester);
    expect(find.byType(MessagesScreen), findsNothing);
    expect(find.byType(PersonProfileScreen), findsOneWidget);
  });
}
