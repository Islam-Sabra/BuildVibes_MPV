// Review 105B: what the off flag held, now on (migration 52). Pin is mine
// only: my pinned posts show as slim lines at the top of Work, and the
// swipe then reads Unpin. Archive is a Lead's, on a Checked item: it
// leaves Work. Share, in the hold bar, picks one of this Space's threads
// (a Team's post only its Team's) and posts the card there; in Chat the
// card shows the kind, the title, For and the status, and a tap opens the
// item in Work. A new announcement is pinned until midnight in the
// Space's time zone. With the lead's check (L1, L2, L5-L10): Leave and
// Remove go through the handover, Send back to someone who has left asks
// Give to first, Share keeps going and tries again with the same ids,
// "Archived · Undo" and Unarchive, the card's status and why it can't be
// read, at most 3 of my pins, the midnight worked out on Post. In English
// and Arabic.
import 'package:buildvibes/data/models/chat.dart';
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/models/work_item.dart';
import 'package:buildvibes/core/l10n/bidi.dart';
import 'package:buildvibes/core/routing/app_routes.dart';
import 'package:buildvibes/data/repositories/daybook_repository.dart';
import 'package:buildvibes/data/repositories/space_repository.dart';
import 'package:buildvibes/features/spaces/space_errors.dart';
import 'package:buildvibes/features/spaces/space_screen.dart';
import 'package:buildvibes/features/work/daybook_draft.dart';
import 'package:buildvibes/features/work/daybook_loop.dart';
import 'package:buildvibes/features/work/work_outbox.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_slip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../helpers/chat_fakes.dart';
import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_rows.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';
import '../../helpers/work_fakes.dart';

Finder _key(String k) => find.byKey(Key(k));
Finder _entry(String id) => _key('daybook-card-$id');

const _everyone = 'thread-all';
const _mep = 'thread-mep';

Future<TestApp> _open(
  WidgetTester tester,
  String lang, {
  required List<DaybookCard> posts,
  String me = DaybookSamples.islam,
  SpacePass pass = SpacePass.lead,
  String? timeZone,
  String path = '/spaces/${DaybookSamples.space}',
  List<ChatMessage> messages = const [],
  FakeDaybookRepository? daybook,
  FakeWorkRepository? work,
  SpacePeople? people,
  DaybookExtras extras = const DaybookExtras(),
}) async {
  final s = DaybookSamples(lang);
  final spaces = FakeSpaceRepository()
    ..details[DaybookSamples.space] = s.detail(
      pass: pass,
      admin: me == DaybookSamples.islam,
      timeZone: timeZone,
    )
    ..spacePeople[DaybookSamples.space] = people ?? s.people();
  daybook ??= FakeDaybookRepository();
  daybook.posts[DaybookSamples.space] = posts;
  daybook.extrasBySpace[DaybookSamples.space] = extras;
  final chat = FakeChatRepository(now: DaybookSamples.thursday)
    ..threadsBySpace[DaybookSamples.space] = [
      const ChatThread(id: _everyone),
      ChatThread(
        id: _mep,
        teamId: 'team-mep',
        teamName: s.t('MEP', 'الكهروميكانيك'),
      ),
    ]
    ..messagesByThread[_everyone] = messages;
  final app = await pumpApp(
    tester,
    language: lang,
    auth: FakeAuthRepository(userId: me, phone: '+96550000001'),
    spaces: spaces,
    daybook: daybook,
    work: work,
    chat: chat,
    now: DaybookSamples.thursday,
  );
  GoRouter.of(tester.element(find.byType(Navigator).first)).push(path);
  await tester.pumpAndSettle();
  return app;
}

Future<void> _show(WidgetTester tester, String id) async {
  await scrollToRow(tester, _entry(id));
  await tester.ensureVisible(_entry(id));
  await tester.pumpAndSettle();
}

Finder _slip(String id) =>
    find.descendant(of: _entry(id), matching: find.byType(BvSlip)).first;

Future<void> _swipe(
  WidgetTester tester,
  String id,
  String lang, {
  required bool toEnd,
}) async {
  await _show(tester, id);
  final dx = (toEnd == (lang != 'ar')) ? 160.0 : -160.0;
  await tester.drag(_slip(id), Offset(dx, 0));
  await tester.pumpAndSettle();
}

/// A swipe's button, tapped as it is: a scroll would close the swipe.
Future<void> _tapSwiped(WidgetTester tester, String key) async {
  await tester.tap(_key(key));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

/// A shared card in the Everyone thread, of [postId].
ChatMessage _shared(String postId) => ChatMessage(
  id: 'msg-$postId',
  threadId: _everyone,
  kind: ChatKind.post,
  postId: postId,
  createdAt: DaybookSamples.thursday,
  authorId: DaybookSamples.omar,
  authorName: 'Omar Haddad',
);

const _chatPath = '/spaces/${DaybookSamples.space}/chat/$_everyone';

/// Writes an announcement and posts it: what went to the server.
Future<NewSpacePost> _postAnnouncement(WidgetTester tester, TestApp app) async {
  await _tap(tester, _key('post-bar-notepad'));
  await tester.enterText(_key('writing-title'), 'Pour at 10:00');
  await tester.pumpAndSettle();
  await _tap(tester, _key('kind-chip-${DaybookKind.announcement}'));
  await _tap(tester, _key('writing-post'));
  return app.daybook.createdPosts.single;
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    final s = DaybookSamples(lang);

    group('105B Pin [$lang]', () {
      testWidgets('the swipe pins it for me; it shows at the top of Work; '
          'the swipe then unpins it', (tester) async {
        final app = await _open(tester, lang, posts: [s.rebar(), s.gate()]);
        await _swipe(tester, 'post-rebar', lang, toEnd: true);
        await _tapSwiped(tester, 'swipe-pin-post-rebar');
        expect(app.daybook.calls, contains('pin post-rebar true'));
        expect(_key('my-pin-post-rebar'), findsOneWidget);
        expect(
          find.descendant(
            of: _key('my-pin-post-rebar'),
            matching: find.text(s.rebar().post.title),
          ),
          findsOneWidget,
        );
        await _swipe(tester, 'post-rebar', lang, toEnd: true);
        expect(
          find.descendant(
            of: _key('swipe-pin-post-rebar'),
            matching: find.text(l10n.workUnpin),
          ),
          findsOneWidget,
        );
        await _tapSwiped(tester, 'swipe-pin-post-rebar');
        expect(app.daybook.calls, contains('pin post-rebar false'));
        expect(_key('my-pin-post-rebar'), findsNothing);
      });

      testWidgets('a tap on my pinned line opens the item', (tester) async {
        await _open(tester, lang, posts: [s.rebar(), s.gate()]);
        await _swipe(tester, 'post-rebar', lang, toEnd: true);
        await _tapSwiped(tester, 'swipe-pin-post-rebar');
        await _tap(tester, _key('my-pin-post-rebar'));
        expect(_key('daybook-page'), findsOneWidget);
      });
    });

    group('105B Archive [$lang]', () {
      testWidgets('a Lead archives a Checked item: it leaves Work', (
        tester,
      ) async {
        final app = await _open(tester, lang, posts: [s.gate(), s.rebar()]);
        await _swipe(tester, 'post-gate', lang, toEnd: false);
        await _tapSwiped(tester, 'swipe-archive-post-gate');
        expect(app.daybook.calls, contains('archive post-gate'));
        expect(find.text(l10n.workArchived), findsOneWidget);
        expect(_entry('post-gate'), findsNothing);
      });

      testWidgets('not for Crew', (tester) async {
        await _open(
          tester,
          lang,
          posts: [s.gate()],
          me: DaybookSamples.omar,
          pass: SpacePass.crew,
        );
        await _swipe(tester, 'post-gate', lang, toEnd: false);
        expect(_key('swipe-archive-post-gate'), findsNothing);
      });
    });

    group('105B Share [$lang]', () {
      testWidgets('held: Share picks one of this Space\'s threads and posts '
          'the card there', (tester) async {
        final app = await _open(tester, lang, posts: [s.rebar(), s.gate()]);
        await _show(tester, 'post-rebar');
        await tester.longPress(_slip('post-rebar'));
        await tester.pumpAndSettle();
        await _tap(tester, _key('select-share'));
        expect(_key('share-threads'), findsOneWidget);
        expect(find.text(l10n.workShareIn), findsOneWidget);
        expect(_key('share-thread-$_everyone'), findsOneWidget);
        expect(_key('share-thread-$_mep'), findsOneWidget);
        await _tap(tester, _key('share-thread-$_everyone'));
        expect(app.daybook.calls, contains('share post-rebar $_everyone'));
        expect(find.text(l10n.workSharedIn(l10n.chatEveryone)), findsOneWidget);
        expect(_key('selection-bar'), findsNothing);
      });

      testWidgets('a Team\'s post: only its Team\'s thread', (tester) async {
        final post = s.card(
          DaybookPost(
            id: 'post-mep',
            kind: DaybookPost.workItemKind,
            createdAt: DateTime(2026, 10, 15, 9),
            title: s.t('Duct riser, level 4', 'صاعد الدكت، الدور 4'),
            authorId: DaybookSamples.islam,
            authorName: s.nameOf(DaybookSamples.islam),
            teamId: 'team-mep',
            item: const DaybookItem(
              status: WorkStatus.open,
              ownerId: DaybookSamples.islam,
            ),
          ),
        );
        await _open(tester, lang, posts: [post, s.gate()]);
        await _show(tester, 'post-mep');
        await tester.longPress(_slip('post-mep'));
        await tester.pumpAndSettle();
        await _tap(tester, _key('select-share'));
        expect(_key('share-thread-$_mep'), findsOneWidget);
        expect(_key('share-thread-$_everyone'), findsNothing);
      });
    });

    group('105B the card in Chat [$lang]', () {
      testWidgets('kind, title, For and status; a tap opens the item', (
        tester,
      ) async {
        await _open(
          tester,
          lang,
          posts: [s.rebar(), s.gate()],
          path: '/spaces/${DaybookSamples.space}/chat/$_everyone',
          messages: [
            ChatMessage(
              id: 'msg-share',
              threadId: _everyone,
              kind: ChatKind.post,
              postId: 'post-gate',
              createdAt: DaybookSamples.thursday,
              authorId: DaybookSamples.omar,
              authorName: 'Omar Haddad',
            ),
          ],
        );
        final card = _key('chat-shared-post');
        expect(card, findsOneWidget);
        expect(
          find.descendant(of: card, matching: find.text(s.gate().post.title)),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: card,
            matching: find.text(l10n.daybookStampChecked),
          ),
          findsOneWidget,
        );
        await _tap(tester, card);
        // The Space, opened on that card.
        expect(
          tester
              .widget<SpaceScreen>(find.byType(SpaceScreen).last)
              .target
              ?.postId,
          'post-gate',
        );
      });
    });

    group('105B the Space\'s midnight (L6) [$lang]', () {
      testWidgets('a new announcement is pinned until midnight in the Space\'s '
          'time zone, worked out when it is posted', (tester) async {
        tz_data.initializeTimeZones();
        const zone = 'Asia/Tokyo';
        final app = await _open(
          tester,
          lang,
          posts: [s.gate()],
          timeZone: zone,
        );
        final posted = await _postAnnouncement(tester, app);
        final there = tz.TZDateTime.from(
          DaybookSamples.thursday,
          tz.getLocation(zone),
        );
        final midnight = tz.TZDateTime(
          tz.getLocation(zone),
          there.year,
          there.month,
          there.day + 1,
        );
        expect(
          posted.pinnedUntil?.millisecondsSinceEpoch,
          midnight.millisecondsSinceEpoch,
        );
      });

      testWidgets('with none known: the phone\'s midnight', (tester) async {
        final app = await _open(tester, lang, posts: [s.gate()]);
        final posted = await _postAnnouncement(tester, app);
        expect(posted.pinnedUntil, pinToEndOf(dayOf(DaybookSamples.thursday)));
      });
    });

    group('105B L1 the handover first [$lang]', () {
      test('BV001 is open work: Leave and Remove say it goes first', () {
        expect(spaceFailureFor('BV001'), SpaceFailure.openWork);
        const e = SpaceException(SpaceFailure.openWork);
        expect(spaceErrorText(l10n, e), l10n.spacesHandOverFirst);
        expect(RefusalWhy.of(e), RefusalWhy.openWork);
        expect(
          DaybookLoop.refusalText(
            l10n,
            const DaybookRefusal(
              action: RefusedAction.remove,
              spaceId: DaybookSamples.space,
              postId: DaybookSamples.omar,
              why: RefusalWhy.openWork,
            ),
            const [],
          ),
          l10n.daybookRefusedBecause(
            l10n.spacesCouldNotRemove,
            l10n.daybookWhyOpenWork,
          ),
        );
      });
    });

    group('105B L2 Send back to someone who has left [$lang]', () {
      testWidgets('Give to comes first; it goes back to the one chosen', (
        tester,
      ) async {
        final card = s.sleevesCard();
        final item = card.post.item!;
        final all = s.people();
        final work = FakeWorkRepository();
        await _open(
          tester,
          lang,
          posts: [card],
          work: work,
          people: SpacePeople(
            members: [
              for (final m in all.members)
                if (m.person.id != item.ownerId) m,
            ],
            teams: all.teams,
          ),
        );
        await _show(tester, card.id);
        await tester.tap(_slip(card.id));
        await tester.pumpAndSettle();
        await _tap(tester, _key('page-send-back'));
        expect(_key('give-to'), findsOneWidget);
        expect(
          find.text(l10n.daybookSendBackWhoNow(item.ownerName!)),
          findsOneWidget,
        );
        await tester.tap(
          find.descendant(of: _key('give-to'), matching: find.text(s.saraName)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.daybookReasonNotFinished));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: _key('send-back-card'),
            matching: find.text(l10n.daybookSendBack),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          work.calls.single,
          'back ${card.id} not_finished  due none to ${DaybookSamples.sara}',
        );
      });

      testWidgets('its owner still here: Send back as before', (tester) async {
        final card = s.sleevesCard();
        await _open(tester, lang, posts: [card]);
        await _show(tester, card.id);
        await tester.tap(_slip(card.id));
        await tester.pumpAndSettle();
        await _tap(tester, _key('page-send-back'));
        expect(_key('give-to'), findsNothing);
        expect(_key('send-back-card'), findsOneWidget);
      });
    });

    group('105B L5, L10 Share of several [$lang]', () {
      testWidgets('one that fails is said at the end; Try again sends it with '
          'the same id', (tester) async {
        final daybook = FakeDaybookRepository()..shareFails.add('post-rebar');
        await _open(
          tester,
          lang,
          posts: [s.rebar(), s.gate()],
          daybook: daybook,
        );
        await _show(tester, 'post-rebar');
        await tester.longPress(_slip('post-rebar'));
        await tester.pumpAndSettle();
        await _show(tester, 'post-gate');
        await tester.tap(_slip('post-gate'));
        await tester.pumpAndSettle();
        await _tap(tester, _key('select-share'));
        await _tap(tester, _key('share-thread-$_everyone'));
        expect(daybook.calls, contains('share post-gate $_everyone'));
        expect(
          find.text(l10n.workShareFailed(joinMeta([s.rebar().post.title]))),
          findsOneWidget,
        );
        daybook.shareFails.clear();
        await tester.tap(find.text(l10n.commonRetry));
        await tester.pumpAndSettle();
        expect(daybook.calls, contains('share post-rebar $_everyone'));
        final tries = [
          for (final t in daybook.shareTries)
            if (t.postId == 'post-rebar') t.messageId,
        ];
        expect(tries, hasLength(2));
        expect(tries.toSet(), hasLength(1));
        expect(find.text(l10n.workSharedIn(l10n.chatEveryone)), findsOneWidget);
      });
    });

    group('105B L7 Undo and Unarchive [$lang]', () {
      testWidgets('"Archived · Undo": Undo brings it back', (tester) async {
        final app = await _open(tester, lang, posts: [s.gate(), s.rebar()]);
        await _swipe(tester, 'post-gate', lang, toEnd: false);
        await _tapSwiped(tester, 'swipe-archive-post-gate');
        expect(find.text(l10n.workArchived), findsOneWidget);
        await tester.tap(find.text(l10n.daybookUndo));
        await tester.pumpAndSettle();
        expect(app.daybook.calls, contains('unarchive post-gate'));
        expect(_entry('post-gate'), findsOneWidget);
      });

      DaybookCard archived() => s.card(
        DaybookPost(
          id: 'post-old',
          kind: DaybookPost.workItemKind,
          createdAt: DateTime(2026, 10, 1, 9),
          title: s.t('Old handrail', 'درابزين قديم'),
          authorId: DaybookSamples.islam,
          authorName: s.nameOf(DaybookSamples.islam),
          archivedAt: DateTime(2026, 10, 10, 9),
          item: const DaybookItem(
            status: WorkStatus.checked,
            ownerId: DaybookSamples.omar,
          ),
        ),
      );

      testWidgets('opened from Search, a Lead\'s ⋯ has Unarchive', (
        tester,
      ) async {
        final daybook = FakeDaybookRepository();
        daybook.cardsById['post-old'] = archived();
        await _open(
          tester,
          lang,
          posts: [s.gate()],
          daybook: daybook,
          path: AppRoutes.spaceCard(DaybookSamples.space, 'post-old'),
        );
        expect(_key('daybook-page'), findsOneWidget);
        await _tap(tester, _key('page-more'));
        await _tap(tester, _key('page-more-unarchive'));
        expect(daybook.calls, contains('unarchive post-old'));
        expect(find.text(l10n.workUnarchived), findsOneWidget);
      });

      testWidgets('not for Crew', (tester) async {
        final daybook = FakeDaybookRepository();
        daybook.cardsById['post-old'] = archived();
        await _open(
          tester,
          lang,
          posts: [s.gate()],
          daybook: daybook,
          me: DaybookSamples.omar,
          pass: SpacePass.crew,
          path: AppRoutes.spaceCard(DaybookSamples.space, 'post-old'),
        );
        expect(_key('daybook-page'), findsOneWidget);
        expect(_key('page-more-unarchive'), findsNothing);
      });
    });

    group('105B L8 the shared card [$lang]', () {
      testWidgets('an Open item\'s status shows too', (tester) async {
        await _open(
          tester,
          lang,
          posts: [s.rebar(), s.gate()],
          path: _chatPath,
          messages: [_shared('post-rebar')],
        );
        expect(
          find.descendant(
            of: _key('chat-shared-post'),
            matching: find.text(l10n.daybookStampOpen),
          ),
          findsOneWidget,
        );
      });

      testWidgets('hidden from me, or really gone, says which', (tester) async {
        final daybook = FakeDaybookRepository()..goneIds.add('post-deleted');
        await _open(
          tester,
          lang,
          posts: [s.gate()],
          daybook: daybook,
          path: _chatPath,
          messages: [_shared('post-hidden'), _shared('post-deleted')],
        );
        expect(find.text(l10n.chatPostHidden), findsOneWidget);
        expect(find.text(l10n.chatPostGone), findsOneWidget);
      });

      testWidgets('no signal: the usual error, and Try again reads it', (
        tester,
      ) async {
        final daybook = FakeDaybookRepository()..cardFails = true;
        await _open(
          tester,
          lang,
          posts: [s.gate()],
          daybook: daybook,
          path: _chatPath,
          messages: [_shared('post-gate')],
        );
        expect(find.text(l10n.errorNetwork), findsOneWidget);
        expect(find.text(l10n.chatPostGone), findsNothing);
        daybook.cardFails = false;
        await _tap(tester, _key('chat-shared-post-retry'));
        expect(_key('chat-shared-post'), findsOneWidget);
      });
    });

    group('105B L9 my pins [$lang]', () {
      final mine = [
        for (var i = 1; i <= 4; i++)
          DaybookPost(
            id: 'pin-$i',
            kind: DaybookPost.workItemKind,
            createdAt: DateTime(2026, 10, 14, 8 + i),
            title: s.t('Pinned $i', 'مثبّت $i'),
            authorId: DaybookSamples.islam,
            item: const DaybookItem(
              status: WorkStatus.open,
              ownerId: DaybookSamples.islam,
            ),
          ),
      ];

      testWidgets('at most 3 lines, then "+n more", which opens the rest', (
        tester,
      ) async {
        await _open(
          tester,
          lang,
          posts: [s.gate()],
          extras: DaybookExtras(mine: mine),
        );
        for (final id in ['pin-1', 'pin-2', 'pin-3']) {
          expect(_key('my-pin-$id'), findsOneWidget);
        }
        expect(_key('my-pin-pin-4'), findsNothing);
        expect(find.text(l10n.workPinsMore(1)), findsOneWidget);
        await _tap(tester, _key('my-pins-more'));
        expect(_key('my-pins-sheet'), findsOneWidget);
        expect(
          find.descendant(
            of: _key('my-pins-sheet'),
            matching: _key('my-pin-pin-4'),
          ),
          findsOneWidget,
        );
      });

      testWidgets('held, a pinned item has Unpin in the hold bar', (
        tester,
      ) async {
        final app = await _open(tester, lang, posts: [s.rebar(), s.gate()]);
        await _swipe(tester, 'post-rebar', lang, toEnd: true);
        await _tapSwiped(tester, 'swipe-pin-post-rebar');
        await tester.longPress(_key('my-pin-post-rebar'));
        await tester.pumpAndSettle();
        await _tap(tester, _key('select-unpin'));
        expect(app.daybook.calls, contains('pin post-rebar false'));
        expect(_key('my-pin-post-rebar'), findsNothing);
      });

      testWidgets('held, one not pinned: no Unpin', (tester) async {
        await _open(tester, lang, posts: [s.rebar(), s.gate()]);
        await _show(tester, 'post-rebar');
        await tester.longPress(_slip('post-rebar'));
        await tester.pumpAndSettle();
        expect(_key('select-unpin'), findsNothing);
      });
    });
  }
}
