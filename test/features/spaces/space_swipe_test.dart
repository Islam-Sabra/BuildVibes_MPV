// Review 115 (3): in a Space a sideways swipe moves between Work and Chat,
// mirrored in Arabic, and the switch at the top follows. A swipe on a
// photo strip stays the photos', and nothing swipes while writing.
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/features/chat/chat_tab.dart';
import 'package:buildvibes/features/spaces/space_screen.dart';
import 'package:buildvibes/features/work/daybook_tab.dart';
import 'package:buildvibes/shared/widgets/bv_segmented.dart';
import 'package:buildvibes/shared/widgets/bv_swipe_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

const _far = 220.0;

Future<void> _open(
  WidgetTester tester,
  String lang, {
  List<DaybookCard>? posts,
  Map<String, List<DaybookPostFile>> files = const {},
}) async {
  final s = DaybookSamples(lang);
  await pumpApp(
    tester,
    language: lang,
    spaces: FakeSpaceRepository()
      ..details[DaybookSamples.space] = s.detail()
      ..spacePeople[DaybookSamples.space] = s.people(),
    daybook: FakeDaybookRepository()
      ..posts[DaybookSamples.space] = posts ?? s.d1()
      ..filesByPost.addAll(files),
    now: DaybookSamples.thursday,
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/${DaybookSamples.space}');
  await tester.pumpAndSettle();
}

/// A point on [card] that shows on the screen (a tall card's middle may be
/// above the page's top).
Offset _on(WidgetTester tester, Finder card) {
  final r = tester.getRect(card);
  return Offset(r.center.dx, r.bottom - _inside);
}

const _inside = 40.0;

int _switch(WidgetTester tester) => tester
    .widget<BvSegmented<int>>(find.byKey(const Key('space-switch')))
    .value;

/// Toward the end of reading (Work → Chat): left in English, right in
/// Arabic.
Offset _toNext(String lang) => Offset(lang == 'ar' ? _far : -_far, 0);
Offset _toPrevious(String lang) => Offset(lang == 'ar' ? -_far : _far, 0);

void main() {
  for (final lang in ['en', 'ar']) {
    testWidgets('a swipe moves between Work and Chat, and the switch follows '
        '[$lang]', (tester) async {
      await _open(tester, lang);
      expect(find.byType(DaybookTab), findsOneWidget);

      // Anywhere on the page, cards too: they have no swipe of their own.
      await tester.dragFrom(const Offset(195, 300), _toNext(lang));
      await tester.pumpAndSettle();
      expect(find.byType(ChatTab), findsOneWidget);
      expect(_switch(tester), SpaceScreen.chatTab);

      // Chat is the last.
      await tester.dragFrom(const Offset(195, 300), _toNext(lang));
      await tester.pumpAndSettle();
      expect(_switch(tester), SpaceScreen.chatTab);

      await tester.dragFrom(const Offset(195, 300), _toPrevious(lang));
      await tester.pumpAndSettle();
      expect(find.byType(DaybookTab), findsOneWidget);
      expect(_switch(tester), SpaceScreen.workTab);
    });

    // The lead's check of 115: one gesture model. A card has no sideways
    // swipe of its own, so a swipe on a Lead's Checked card (once its
    // Archive) changes the page, and never opens Archive by surprise.
    testWidgets('a swipe on a card changes the page, never its Archive or '
        'its Pin · Reminder [$lang]', (tester) async {
      final s = DaybookSamples(lang);
      await _open(tester, lang, posts: [s.gate(), s.rebar()]);
      final card = find.byKey(const Key('daybook-card-post-gate'));
      expect(card, findsOneWidget);
      expect(find.byType(BvSwipeCard), findsNothing);

      // Toward the start of the card: where its Archive was.
      await tester.dragFrom(_on(tester, card), _toNext(lang));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('swipe-archive-post-gate')), findsNothing);
      expect(find.byType(ChatTab), findsOneWidget);
      expect(_switch(tester), SpaceScreen.chatTab);

      await tester.dragFrom(const Offset(195, 300), _toPrevious(lang));
      await tester.pumpAndSettle();
      expect(_switch(tester), SpaceScreen.workTab);

      // Toward the end of the card: where its Pin · Reminder were. Work is
      // the first page, so it stays, with nothing opened.
      await tester.dragFrom(_on(tester, card), _toPrevious(lang));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('swipe-remind-post-gate')), findsNothing);
      expect(find.byKey(const Key('swipe-pin-post-gate')), findsNothing);
      expect(_switch(tester), SpaceScreen.workTab);
    });

    testWidgets('a swipe on a photo strip doesn\'t change the page [$lang]', (
      tester,
    ) async {
      const id = DaybookSamples.handoverId;
      final h = DaybookSamples(lang).handover().post;
      await _open(
        tester,
        lang,
        posts: [
          DaybookCard(
            post: DaybookPost(
              id: id,
              kind: DaybookPost.checklistKind,
              createdAt: h.createdAt,
              title: h.title,
              authorId: h.authorId,
              authorName: h.authorName,
              people: h.people,
              coverPath: '${DaybookSamples.space}/posts/$id/0.jpg',
            ),
            lastActivityAt: h.createdAt,
          ),
        ],
        files: {
          id: [
            for (var i = 0; i < 2; i++)
              DaybookPostFile(
                mime: 'image/jpeg',
                path: '${DaybookSamples.space}/posts/$id/$i.jpg',
              ),
          ],
        },
      );
      final photo = find.byKey(const Key('photo-strip-0'));
      expect(photo, findsOneWidget);

      await tester.dragFrom(tester.getCenter(photo), _toNext(lang));
      await tester.pumpAndSettle();
      expect(find.byType(DaybookTab), findsOneWidget);
      expect(_switch(tester), SpaceScreen.workTab);
    });

    testWidgets('nothing swipes while the composer is open [$lang]', (
      tester,
    ) async {
      await _open(tester, lang);
      await tester.tap(find.byKey(const Key('post-bar-notepad')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('writing-title')), findsOneWidget);

      await tester.dragFrom(const Offset(195, 420), _toNext(lang));
      await tester.pumpAndSettle();
      expect(find.byType(ChatTab), findsNothing);
      expect(find.byKey(const Key('writing-title')), findsOneWidget);
    });
  }
}
