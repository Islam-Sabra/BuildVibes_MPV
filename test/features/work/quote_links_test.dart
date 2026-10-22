// Review 80 F83, F87, F91: a quote shows on every kind (the pinned
// announcement too), opens its Space chat message, and shows on the page.
import 'package:buildvibes/data/models/chat.dart';
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/post_page.dart';
import 'package:buildvibes/data/models/work_item.dart';
import 'package:buildvibes/features/chat/thread_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/chat_fakes.dart';
import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/fakes.dart';
import '../../helpers/page_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

const _thread = '00000000-0000-4000-8000-0000000007a1';
const _item = '00000000-0000-4000-8000-0000000007b1';
const _note = '00000000-0000-4000-8000-0000000007b2';

final _quote = DaybookQuote(
  text: 'Gate 2 is blocked by the crane.',
  authorName: 'Rakesh Nair',
  at: DateTime(2026, 10, 15, 8, 38),
);

FakeChatRepository _chat({bool deleted = false}) =>
    FakeChatRepository(now: DaybookSamples.thursday)
      ..threadsBySpace[DaybookSamples.space] = [
        ChatThread(
          id: _thread,
          lastKind: ChatKind.text,
          lastBody: 'Gate 2 is blocked by the crane.',
          lastAuthorId: DaybookSamples.omar,
          lastAt: DateTime(2026, 10, 15, 8, 38),
        ),
      ]
      ..messagesByThread[_thread] = [
        ChatMessage(
          id: 'm-gate',
          threadId: _thread,
          kind: ChatKind.text,
          createdAt: DateTime(2026, 10, 15, 8, 38),
          authorId: DaybookSamples.omar,
          authorName: 'Omar Haddad',
          body: deleted ? null : 'Gate 2 is blocked by the crane.',
          deletedAt: deleted ? DateTime(2026, 10, 15, 9) : null,
        ),
      ];

DaybookPost _workItem(DaybookSamples s) => DaybookPost(
  id: _item,
  kind: DaybookPost.workItemKind,
  createdAt: DaybookSamples.thursday.subtract(const Duration(hours: 1)),
  title: s.t('Clear gate 2', 'أخلِ البوابة 2'),
  authorId: DaybookSamples.islam,
  authorName: s.islamName,
  item: DaybookItem(
    status: WorkStatus.open,
    ownerId: DaybookSamples.omar,
    ownerName: s.omarName,
    ref: 'KCT-040',
  ),
  quote: _quote,
  sourceMessageId: 'm-gate',
  hasPage: true,
);

Future<void> _open(
  WidgetTester tester,
  String lang, {
  required List<DaybookPost> posts,
  DaybookExtras extras = const DaybookExtras(),
  FakeChatRepository? chat,
  FakePageRepository? pages,
}) async {
  final s = DaybookSamples(lang);
  await pumpApp(
    tester,
    language: lang,
    auth: FakeAuthRepository(
      userId: DaybookSamples.islam,
      phone: '+96550000001',
    ),
    spaces: FakeSpaceRepository()
      ..details[DaybookSamples.space] = s.detail()
      ..spacePeople[DaybookSamples.space] = s.people(),
    daybook: FakeDaybookRepository()
      ..posts[DaybookSamples.space] = [
        for (final p in posts)
          DaybookCard(post: p, lastActivityAt: p.createdAt),
      ]
      ..extrasBySpace[DaybookSamples.space] = extras,
    chat: chat ?? _chat(),
    postPages: pages,
    now: DaybookSamples.thursday,
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/${DaybookSamples.space}');
  await tester.pumpAndSettle();
}

void main() {
  for (final lang in ['en', 'ar']) {
    final s = DaybookSamples(lang);

    testWidgets('F87: a tap on a work item\'s quote opens its chat message '
        '[$lang]', (tester) async {
      await _open(tester, lang, posts: [_workItem(s)]);
      await tester.tap(find.byKey(const Key('quote-open')).first);
      await tester.pumpAndSettle();
      expect(find.byType(ThreadScreen), findsOneWidget);
      expect(
        tester.widget<ThreadScreen>(find.byType(ThreadScreen)).atMessage,
        'm-gate',
      );
    });

    testWidgets('F87: a deleted message\'s quote opens nothing [$lang]', (
      tester,
    ) async {
      await _open(
        tester,
        lang,
        posts: [_workItem(s)],
        chat: _chat(deleted: true),
      );
      await tester.tap(find.byKey(const Key('quote-open')).first);
      await tester.pumpAndSettle();
      expect(find.byType(ThreadScreen), findsNothing);
    });

    testWidgets('F83: a note and a pinned announcement made from a message '
        'show its quote [$lang]', (tester) async {
      final note = DaybookPost(
        id: _note,
        kind: DaybookPost.noteKind,
        createdAt: DaybookSamples.thursday.subtract(const Duration(hours: 2)),
        title: s.t('Crane at gate 2', 'رافعة عند البوابة 2'),
        authorId: DaybookSamples.islam,
        authorName: s.islamName,
        quote: _quote,
      );
      final pinned = DaybookPost(
        id: DaybookSamples.halfDayId,
        kind: DaybookPost.announcementKind,
        createdAt: DaybookSamples.thursday.subtract(const Duration(hours: 3)),
        title: s.halfDay,
        authorId: DaybookSamples.sara,
        authorName: s.saraName,
        pinnedUntil: DateTime(2026, 10, 17),
        quote: _quote,
        sourceMessageId: 'm-gate',
      );
      await _open(
        tester,
        lang,
        posts: [note, pinned],
        extras: DaybookExtras(pinned: [pinned]),
      );
      expect(find.byKey(const Key('pinned-quote')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(Key('daybook-card-$_note')),
          matching: find.byKey(const Key('card-quote')),
        ),
        findsOneWidget,
      );
    });

    testWidgets('F91: the page shows the quote under the facts [$lang]', (
      tester,
    ) async {
      final post = _workItem(s);
      await _open(
        tester,
        lang,
        posts: [post],
        pages: FakePageRepository()..pages[_item] = PostPage(post: post),
      );
      await tester.tap(find.byKey(const Key('card-open-page')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('page-quote')), findsOneWidget);
    });
  }
}
