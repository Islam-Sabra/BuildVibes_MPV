// Review 113 RX1 (2730:39887): React · Share on every post; Like · Heart ·
// Bravo, one per person, tapping again removes it; the icons with faces,
// never a number; a tap shows the names; none on a Check-in. The Reactions
// channel is quiet. In English and Arabic.
import 'package:buildvibes/core/push/reaction_channel.dart';
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/settings/push_host.dart';
import 'package:buildvibes/features/work/check_in_card.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_rows.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<FakeDaybookRepository> _open(
  WidgetTester tester,
  String lang,
  List<DaybookCard> posts, {
  SpacePass pass = SpacePass.lead,
}) async {
  final s = DaybookSamples(lang);
  final daybook = FakeDaybookRepository()
    ..posts[DaybookSamples.space] = posts
    ..reactorId = DaybookSamples.islam
    ..reactorName = s.nameOf(DaybookSamples.islam);
  await pumpApp(
    tester,
    language: lang,
    auth: FakeAuthRepository(
      userId: DaybookSamples.islam,
      phone: '+96550000001',
    ),
    spaces: FakeSpaceRepository()
      ..details[DaybookSamples.space] = s.detail(pass: pass, admin: true)
      ..spacePeople[DaybookSamples.space] = s.people(),
    daybook: daybook,
    now: DaybookSamples.thursday,
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/${DaybookSamples.space}');
  await tester.pumpAndSettle();
  return daybook;
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

DaybookCard _reacted(DaybookCard c) => c.copyWith(
  post: c.post.shownAs(
    reactions: const [
      DaybookReactionGroup(
        kind: PostReaction.bravo,
        people: [
          DaybookPerson(id: 'p-omar', name: 'Omar Haddad'),
          // Hidden or blocked: a face, no name.
          DaybookPerson(id: 'p-hidden'),
        ],
      ),
    ],
  ),
);

void main() {
  test('a card reads its reactions, my own and its hold', () {
    final json = <String, dynamic>{
      'id': 'p',
      'kind': 'note',
      'created_at': '2026-10-15T08:00:00Z',
      'reactions': [
        {
          'kind': 'like',
          'people': [
            {'id': 'a', 'name': 'Ali'},
            {'id': 'b', 'name': null},
          ],
        },
        {'kind': 'unknown', 'people': <Object>[]},
      ],
      'my_reaction': 'like',
      'hold': 'archive',
      'voice': {'path': 's/posts/p/v.m4a', 'duration_ms': 4200},
    };
    final p = DaybookPost.fromJson(json);
    expect(p.reactions.single.kind, PostReaction.like);
    expect(p.reactions.single.people.last.name, isNull);
    expect(p.myReaction, PostReaction.like);
    expect(p.hold, PostHold.archive);
    expect(p.voice?.duration, const Duration(milliseconds: 4200));
    final plain = DaybookPost.fromJson({
      'id': 'p',
      'kind': 'note',
      'created_at': '2026-10-15T08:00:00Z',
      'hold': null,
    });
    expect(plain.reactions, isEmpty);
    expect(plain.hold, isNull);
    expect(plain.voice, isNull);
  });

  test('the Reactions channel is low importance, with no sound', () {
    for (final lang in ['en', 'ar']) {
      final l10n = lookupAppLocalizations(Locale(lang));
      final c = reactionsChannel(l10n);
      expect(c.id, 'reactions');
      expect(c.name, lang == 'en' ? 'Reactions' : 'التفاعلات');
      expect(c.importance, Importance.low);
      expect(c.playSound, isFalse);
      expect(c.enableVibration, isFalse);
    }
  });

  test('a reaction\'s push and an archived item\'s open the post', () {
    final route = postPushRoute(const {
      'kind': 'post_reaction',
      'space_id': 's1',
      'post_id': 'p1',
      'reaction': 'like',
    });
    expect(route, contains('/spaces/s1'));
    expect(route, contains('card=p1'));
    expect(
      postPushRoute(const {
        'kind': 'work_item_archived',
        'space_id': 's1',
        'post_id': 'p1',
      }),
      contains('card=p1'),
    );
    expect(postPushRoute(const {'kind': 'other', 'space_id': 's1'}), isNull);
  });

  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    final s = DaybookSamples(lang);

    testWidgets('React and Share on a post; the picker has only Like, Heart '
        'and Bravo; a pick reacts, the same again takes it off [$lang]', (
      tester,
    ) async {
      final daybook = await _open(tester, lang, [s.rebar()]);
      await scrollToRow(tester, _key('daybook-card-post-rebar'));
      expect(_key('card-react-post-rebar'), findsOneWidget);
      expect(_key('card-share-post-rebar'), findsOneWidget);
      await _tap(tester, _key('card-react-post-rebar'));
      expect(_key('react-picker'), findsOneWidget);
      for (final k in ['like', 'heart', 'bravo']) {
        expect(_key('react-$k'), findsOneWidget);
      }
      await _tap(tester, _key('react-heart'));
      expect(daybook.calls, contains('react post-rebar heart'));
      expect(_key('react-picker'), findsNothing);
      expect(_key('card-reaction-post-rebar-heart'), findsOneWidget);
      expect(find.text(l10n.reactHeart), findsOneWidget);
      // Another kind replaces it; the same kind takes it off.
      await _tap(tester, _key('card-react-post-rebar'));
      await _tap(tester, _key('react-like'));
      expect(_key('card-reaction-post-rebar-heart'), findsNothing);
      expect(_key('card-reaction-post-rebar-like'), findsOneWidget);
      await _tap(tester, _key('card-react-post-rebar'));
      await _tap(tester, _key('react-like'));
      expect(_key('card-reaction-post-rebar-like'), findsNothing);
      expect(find.text(l10n.reactReact), findsOneWidget);
    });

    testWidgets('faces, never a number; a tap shows the names, and a hidden '
        'person keeps a plain face [$lang]', (tester) async {
      await _open(tester, lang, [_reacted(s.rebar())]);
      await scrollToRow(tester, _key('daybook-card-post-rebar'));
      final row = _key('card-reaction-post-rebar-bravo');
      expect(row, findsOneWidget);
      expect(
        find.descendant(of: row, matching: find.textContaining('2')),
        findsNothing,
      );
      await _tap(tester, _key('card-reactions-post-rebar'));
      expect(_key('reactors-sheet'), findsOneWidget);
      expect(find.text(l10n.reactWho), findsOneWidget);
      expect(find.textContaining('Omar Haddad'), findsOneWidget);
      expect(_key('reactor-bravo-p-hidden'), findsOneWidget);
    });

    // Review 114 (founder, 3 Nov): React at the start, its faces right
    // after it, Share alone at the end; mirrored in Arabic. The picker
    // opens from the start, above React.
    testWidgets('React at the start, the faces after it, Share at the end; '
        'the picker opens from the start [$lang]', (tester) async {
      await _open(tester, lang, [_reacted(s.rebar())]);
      await scrollToRow(tester, _key('daybook-card-post-rebar'));
      final rtl = lang == 'ar';
      double start(Finder f) =>
          rtl ? tester.getTopRight(f.first).dx : tester.getTopLeft(f.first).dx;
      double end(Finder f) =>
          rtl ? tester.getTopLeft(f.first).dx : tester.getTopRight(f.first).dx;
      bool before(double a, double b) => rtl ? a >= b : a <= b;
      final row = _key('card-react-row-post-rebar');
      final react = _key('card-react-post-rebar');
      final faces = _key('card-reactions-post-rebar');
      final share = _key('card-share-post-rebar');
      // React first, at the row's start; the faces after it; Share last,
      // at the row's end.
      expect(start(react), moreOrLessEquals(start(row), epsilon: 8));
      expect(before(end(react), start(faces)), isTrue);
      expect(before(end(faces), start(share)), isTrue);
      expect(end(share), moreOrLessEquals(end(row), epsilon: 8));
      await _tap(tester, react);
      final picker = _key('react-picker');
      expect(picker, findsOneWidget);
      expect(start(picker), moreOrLessEquals(start(react), epsilon: 1));
      expect(
        tester.getBottomLeft(picker).dy,
        lessThan(tester.getTopLeft(react.first).dy),
      );
    });

    testWidgets('no reactions: React alone at the start, Share at the end '
        '[$lang]', (tester) async {
      await _open(tester, lang, [s.rebar()]);
      await scrollToRow(tester, _key('daybook-card-post-rebar'));
      final rtl = lang == 'ar';
      final row = tester.getRect(_key('card-react-row-post-rebar'));
      final react = tester.getRect(_key('card-react-post-rebar'));
      final share = tester.getRect(_key('card-share-post-rebar'));
      expect(_key('card-reactions-post-rebar'), findsNothing);
      if (rtl) {
        expect(react.right, moreOrLessEquals(row.right, epsilon: 8));
        expect(share.left, moreOrLessEquals(row.left, epsilon: 8));
      } else {
        expect(react.left, moreOrLessEquals(row.left, epsilon: 8));
        expect(share.right, moreOrLessEquals(row.right, epsilon: 8));
      }
    });

    testWidgets('a Viewer may react and share [$lang]', (tester) async {
      await _open(tester, lang, [s.rebar()], pass: SpacePass.viewer);
      await scrollToRow(tester, _key('daybook-card-post-rebar'));
      expect(_key('card-react-post-rebar'), findsOneWidget);
      expect(_key('card-share-post-rebar'), findsOneWidget);
    });

    testWidgets('no reactions on a Check-in: Share only [$lang]', (
      tester,
    ) async {
      final c = s.card(
        DaybookPost(
          id: 'post-in',
          kind: DaybookPost.checkInKind,
          createdAt: DateTime(2026, 10, 15, 7),
          title: s.t('Morning check-in', 'تسجيل الصباح'),
          authorId: DaybookSamples.islam,
          authorName: s.nameOf(DaybookSamples.islam),
        ),
      );
      await _open(tester, lang, [c]);
      await scrollToRow(tester, _key('daybook-card-post-in'));
      expect(find.byType(DaybookCheckInBody), findsWidgets);
      expect(_key('card-react-post-in'), findsNothing);
      expect(_key('card-share-post-in'), findsOneWidget);
    });
  }
}
