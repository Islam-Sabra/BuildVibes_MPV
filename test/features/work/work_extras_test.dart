// Review 105B: what the off flag held, now on (migration 52). Pin is mine
// only: my pinned posts show as slim lines at the top of Work, and the
// swipe then reads Unpin. Archive is a Lead's, on a Checked item: it
// leaves Work. Share, in the hold bar, picks one of this Space's threads
// (a Team's post only its Team's) and posts the card there; in Chat the
// card shows the kind, the title, For and the status, and a tap opens the
// item in Work. A new announcement is pinned until midnight in the
// Space's time zone. In English and Arabic.
import 'package:buildvibes/data/models/chat.dart';
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/models/work_item.dart';
import 'package:buildvibes/features/spaces/space_screen.dart';
import 'package:buildvibes/features/work/daybook_draft.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_slip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
}) async {
  final s = DaybookSamples(lang);
  final spaces = FakeSpaceRepository()
    ..details[DaybookSamples.space] = s.detail(
      pass: pass,
      admin: me == DaybookSamples.islam,
      timeZone: timeZone,
    )
    ..spacePeople[DaybookSamples.space] = s.people();
  final daybook = FakeDaybookRepository();
  daybook.posts[DaybookSamples.space] = posts;
  daybook.extrasBySpace[DaybookSamples.space] = const DaybookExtras();
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

    group('105B the Space\'s midnight [$lang]', () {
      testWidgets('a new announcement is pinned until midnight in the Space\'s '
          'time zone', (tester) async {
        tz_data.initializeTimeZones();
        const zone = 'Asia/Tokyo';
        await _open(tester, lang, posts: [s.gate()], timeZone: zone);
        await _tap(tester, _key('post-bar-notepad'));
        await tester.enterText(_key('writing-title'), 'Pour at 10:00');
        await tester.pumpAndSettle();
        await _tap(tester, _key('kind-chip-${DaybookKind.announcement}'));
        final draft = ProviderScope.containerOf(
          tester.element(find.byType(Scaffold).first),
        ).read(daybookDraftProvider(DaybookSamples.space));
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
          draft?.pinnedUntil?.millisecondsSinceEpoch,
          midnight.millisecondsSinceEpoch,
        );
      });
    });
  }
}
