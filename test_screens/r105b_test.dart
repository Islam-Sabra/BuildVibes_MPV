// Review 105B, the lead's check (L11): the new screens of Pin, Archive and
// Share, in English and Arabic. My pinned lines with "+n more" (L9), the
// Archive swipe, the thread picker for Share, the shared cards in Chat
// (Open and Checked, L8), and "Archived · Undo" (L7). Run:
//   flutter test test_screens/r105b_test.dart --update-goldens
import 'package:buildvibes/core/l10n/locale_controller.dart';
import 'package:buildvibes/data/models/chat.dart';
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/work_item.dart';
import 'package:buildvibes/data/repositories/activity_repository.dart';
import 'package:buildvibes/data/repositories/chat_repository.dart';
import 'package:buildvibes/data/repositories/daybook_live.dart';
import 'package:buildvibes/data/repositories/daybook_repository.dart';
import 'package:buildvibes/data/repositories/page_repository.dart';
import 'package:buildvibes/data/repositories/space_repository.dart';
import 'package:buildvibes/data/repositories/work_repository.dart';
import 'package:buildvibes/features/account/account_parts.dart';
import 'package:buildvibes/features/chat/thread_screen.dart';
import 'package:buildvibes/features/entry/entry_state.dart';
import 'package:buildvibes/features/profile/edit/experience_screens.dart';
import 'package:buildvibes/features/spaces/space_screen.dart';
import 'package:buildvibes/features/work/daybook_photos.dart';
import 'package:buildvibes/features/work/daybook_writing.dart';
import 'package:buildvibes/features/work/work_outbox.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers/activity_fakes.dart';
import '../test/helpers/chat_fakes.dart';
import '../test/helpers/daybook_fakes.dart';
import '../test/helpers/daybook_samples.dart';
import '../test/helpers/fakes.dart';
import '../test/helpers/page_fakes.dart';
import '../test/helpers/space_fakes.dart';
import '../test/helpers/work_fakes.dart';
import 'shot.dart';
import 'work_gestures.dart';

const _folder = 'r105b';
const _everyone = 'th-everyone';
const _mep = 'th-mep';

Future<List<Override>> _overrides(
  DaybookSamples s, {
  required List<DaybookCard> posts,
  DaybookExtras extras = const DaybookExtras(),
  Map<String, List<ChatMessage>> messages = const {},
}) async {
  // test_screens/ is a test folder the analyzer doesn't know.
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues(const {});
  final prefs = await SharedPreferences.getInstance();
  final now = DaybookSamples.thursday;
  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    spaceRepositoryProvider.overrideWithValue(
      FakeSpaceRepository()
        ..details[DaybookSamples.space] = s.detail()
        ..spacePeople[DaybookSamples.space] = s.people(),
    ),
    activityRepositoryProvider.overrideWithValue(FakeActivityRepository()),
    chatRepositoryProvider.overrideWithValue(
      FakeChatRepository(now: now)
        ..threadsBySpace[DaybookSamples.space] = [
          ChatThread(
            id: _everyone,
            lastKind: ChatKind.text,
            lastAt: DateTime(2026, 10, 15, 9, 40),
          ),
          ChatThread(
            id: _mep,
            teamId: 't-mep',
            teamName: s.t('MEP', 'الكهروميكانيك'),
            lastKind: ChatKind.text,
            lastAt: DateTime(2026, 10, 15, 9, 10),
          ),
        ]
        ..messagesByThread.addAll(messages),
    ),
    authUserIdProvider.overrideWithValue(const AsyncData(DaybookSamples.islam)),
    myMarketProvider.overrideWithValue(kuwait),
    clockProvider.overrideWithValue(() => now),
    pageRepositoryProvider.overrideWithValue(FakePageRepository()),
    workRepositoryProvider.overrideWithValue(FakeWorkRepository()),
    daybookLiveProvider.overrideWithValue(FakeDaybookLive()),
    daybookRepositoryProvider.overrideWithValue(
      FakeDaybookRepository()
        ..posts[DaybookSamples.space] = posts
        ..extrasBySpace[DaybookSamples.space] = extras,
    ),
    daybookPhotoProvider.overrideWith((ref, path) => samplePhoto),
    localPhotoProvider.overrideWith((ref, path) => samplePhoto),
    outboxRetryDelaysProvider.overrideWithValue(const []),
    newPostIdProvider.overrideWithValue(() => 'msg-r105b-new'),
  ];
}

Widget _space(BuildContext _) =>
    const SpaceScreen(spaceId: DaybookSamples.space);

Widget _thread(BuildContext _) =>
    const ThreadScreen(spaceId: DaybookSamples.space, threadId: _everyone);

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

/// Swipes post [id]'s card toward the start (Archive's side).
Future<void> _swipeToStart(WidgetTester tester, String id, String lang) async {
  final slip = cardSlip(id);
  await tester.ensureVisible(slip.first);
  await tester.pumpAndSettle();
  await tester.drag(slip.first, Offset(lang == 'ar' ? 160 : -160, 0));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  for (final lang in ['en', 'ar']) {
    final s = DaybookSamples(lang);

    /// Four of my pins: two of the Space's cards, and two more.
    List<DaybookPost> mine() => [
      s.rebar().post,
      s.gate().post,
      for (final (i, t) in [
        s.t('Sleeves at grid C7', 'جلبات عند المحور C7'),
        s.t('Fire stopping, riser 2', 'سد الحريق، الصاعد 2'),
      ].indexed)
        DaybookPost(
          id: 'pin-$i',
          kind: DaybookPost.workItemKind,
          createdAt: DateTime(2026, 10, 14, 9 + i),
          title: t,
          authorId: DaybookSamples.islam,
          item: const DaybookItem(
            status: WorkStatus.open,
            ownerId: DaybookSamples.omar,
          ),
        ),
    ];

    ChatMessage shared(String postId, DateTime at) => ChatMessage(
      id: 'msg-$postId',
      threadId: _everyone,
      kind: ChatKind.post,
      postId: postId,
      createdAt: at,
      authorId: DaybookSamples.omar,
      authorName: s.omarName,
    );

    testWidgets('W1 my pinned lines, then "+n more" [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'W1-my-pins',
        lang,
        _space,
        folder: _folder,
        overrides: await _overrides(
          s,
          posts: [s.rebar(), s.gate()],
          extras: DaybookExtras(mine: mine()),
        ),
      );
    });

    testWidgets('W2 the Archive swipe on a Checked item [$lang]', (
      tester,
    ) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'W2-archive-swipe',
        lang,
        _space,
        folder: _folder,
        overrides: await _overrides(s, posts: [s.rebar(), s.gate()]),
        before: (tester) => _swipeToStart(tester, 'post-gate', lang),
      );
    });

    testWidgets('W3 "Archived · Undo" [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'W3-archived-undo',
        lang,
        _space,
        folder: _folder,
        overrides: await _overrides(s, posts: [s.rebar(), s.gate()]),
        before: (tester) async {
          await _swipeToStart(tester, 'post-gate', lang);
          await tester.tap(find.byKey(const Key('swipe-archive-post-gate')));
          await tester.pumpAndSettle();
        },
      );
    });

    testWidgets('W4 Share: the thread picker [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'W4-share-threads',
        lang,
        _space,
        folder: _folder,
        overrides: await _overrides(s, posts: [s.rebar(), s.gate()]),
        before: (tester) async {
          await selectCard(tester, 'post-rebar');
          await _tap(tester, find.byKey(const Key('select-share')));
        },
      );
    });

    testWidgets('C1 shared cards in Chat: Open and Checked [$lang]', (
      tester,
    ) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'C1-shared-cards',
        lang,
        _thread,
        folder: _folder,
        overrides: await _overrides(
          s,
          posts: [s.rebar(), s.gate()],
          messages: {
            // Newest first, as the thread reads them.
            _everyone: [
              shared('post-rebar', DateTime(2026, 10, 15, 9, 40)),
              shared('post-gate', DateTime(2026, 10, 15, 9, 30)),
            ],
          },
        ),
      );
    });
  }
}
