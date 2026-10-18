// Review 50 F30 (review 53 Part D): the feed card shows that a post has
// replies: the latest reply's line with up to three faces, never a number;
// a reply to you is bold until you open the post; the line opens the post
// at that reply. H1 v4 2587:35849, AR 2588:412.
import 'package:buildvibes/core/design/bv_icons.dart';
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/core/l10n/locale_controller.dart';
import 'package:buildvibes/data/models/post.dart';
import 'package:buildvibes/features/entry/entry_state.dart';
import 'package:buildvibes/features/feed/feed_state.dart';
import 'package:buildvibes/features/feed/post_screen.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_avatar.dart';
import 'package:buildvibes/shared/widgets/bv_latest_reply.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/post_fakes.dart';
import '../../helpers/pump_app.dart';

final _at = testNow.subtract(const Duration(hours: 2));

LatestReply _latest({bool toMe = false}) => LatestReply(
  id: 'r3',
  body: 'Seen it, thanks Islam',
  authorId: 'p-omar',
  authorName: 'Omar Haddad',
  createdAt: _at,
  toMe: toMe,
);

const _faces = [
  ReplyFace(id: 'p-omar', name: 'Omar Haddad'),
  ReplyFace(id: 'p-sara', name: 'Sara Ali'),
  ReplyFace(id: 'p-lina', name: 'Lina Haddad'),
];

FakePostRepository _posts({bool toMe = false}) =>
    FakePostRepository(now: testNow)
      ..posts.addAll([
        Post(
          id: 'p1',
          authorId: 'user-1',
          authorName: 'Islam Ahmed',
          body: 'Fire stopping on level 4 is finished.',
          lang: 'en',
          createdAt: testNow.subtract(const Duration(hours: 3)),
          latestReply: _latest(toMe: toMe),
          replyFaces: _faces,
        ),
        Post(
          id: 'p2',
          authorId: 'p-sara',
          authorName: 'Sara Ali',
          body: 'No replies yet.',
          lang: 'en',
          createdAt: testNow.subtract(const Duration(hours: 4)),
        ),
      ])
      ..home.addAll(['p1', 'p2'])
      ..repliesByPost['p1'] = [
        for (var i = 1; i <= 3; i++)
          PostReply(
            id: 'r$i',
            postId: 'p1',
            authorId: _faces[3 - i].id,
            authorName: _faces[3 - i].name,
            body: i == 3 ? 'Seen it, thanks Islam' : 'Reply $i',
            createdAt: _at.subtract(Duration(minutes: 10 * (3 - i))),
          ),
      ];

void main() {
  test('post_cards: latest_reply and reply_faces, absent before migration '
      '26', () {
    final base = {
      'id': 'p1',
      'author_id': 'a',
      'author_first_name': 'Islam',
      'author_last_name': 'Ahmed',
      'lang': 'en',
      'created_at': '2026-10-15T10:44:00Z',
    };
    final post = Post.fromJson({
      ...base,
      'latest_reply': {
        'id': 'r1',
        'body': 'Seen it',
        'author_id': 'o',
        'author_name': 'Omar Haddad',
        'created_at': '2026-10-15T10:46:00Z',
        'to_me': true,
      },
      'reply_faces': [
        {'id': 'o', 'name': 'Omar Haddad'},
      ],
    });
    expect(post.latestReply!.authorName, 'Omar Haddad');
    expect(post.latestReply!.toMe, isTrue);
    expect(post.replyFaces.single.id, 'o');
    // The offline copy keeps them.
    final kept = Post.fromCache(post.toCache());
    expect(kept.latestReply!.id, 'r1');
    expect(kept.replyFaces.single.name, 'Omar Haddad');
    final old = Post.fromJson(base);
    expect(old.latestReply, isNull);
    expect(old.replyFaces, isEmpty);
  });

  for (final lang in ['en', 'ar']) {
    testWidgets('F30: the latest reply under the text, up to three faces, '
        'never a number; none without replies [$lang]', (tester) async {
      await pumpApp(tester, language: lang, posts: _posts());
      await tester.pumpAndSettle();
      final line = find.byKey(const Key('post-latest-reply-p1'));
      expect(line, findsOneWidget);
      expect(
        find.descendant(of: line, matching: find.byType(BvAvatar)),
        findsNWidgets(3),
      );
      final text = tester
          .widget<RichText>(
            find.descendant(
              of: find.byKey(const Key('latest-reply-text')).first,
              matching: find.byType(RichText),
            ),
          )
          .text
          .toPlainText();
      expect(text, contains('Omar Haddad'));
      expect(text, contains('Seen it, thanks Islam'));
      expect(text, isNot(contains(RegExp('[0-9]'))));
      // Above Useful and Reply.
      expect(
        tester.getTopLeft(line).dy,
        lessThan(tester.getTopLeft(find.byKey(const Key('post-useful-p1'))).dy),
      );
      expect(find.byKey(const Key('post-latest-reply-p2')), findsNothing);
    });

    testWidgets('F30: a reply to you is bold until the post is opened; the '
        'line opens the post at that reply [$lang]', (tester) async {
      await pumpApp(tester, language: lang, posts: _posts(toMe: true));
      await tester.pumpAndSettle();
      bool bold() =>
          tester.widget<BvLatestReply>(find.byType(BvLatestReply).first).unseen;
      expect(bold(), isTrue);
      final type = lang == 'ar' ? BvType.arabic : BvType.latin;
      TextSpan span(String part) {
        final rich = tester.widget<RichText>(
          find.descendant(
            of: find.byKey(const Key('latest-reply-text')).first,
            matching: find.byType(RichText),
          ),
        );
        late TextSpan found;
        rich.text.visitChildren((s) {
          if (s is TextSpan && (s.text ?? '').contains(part)) found = s;
          return true;
        });
        return found;
      }

      expect(span('Omar').style!.fontWeight, type.headingMd.fontWeight);
      expect(span('Seen').style!.color, BvColors.textPrimary);

      await tester.tap(find.byKey(const Key('post-latest-reply-p1')));
      await tester.pumpAndSettle();
      final page = tester.widget<PostScreen>(find.byType(PostScreen));
      expect(page.postId, 'p1');
      expect(page.replyId, 'r3');
      // The reply is on screen.
      final reply = tester.getRect(find.byKey(const Key('reply-r3')));
      expect(reply.top, greaterThanOrEqualTo(0));
      expect(reply.bottom, lessThanOrEqualTo(844));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PostScreen)),
      );
      expect(container.read(seenRepliesProvider), contains('r3'));
      Navigator.of(tester.element(find.byType(PostScreen))).pop();
      await tester.pumpAndSettle();
      expect(bold(), isFalse);
      expect(span('Omar').style!.fontWeight, type.labelMd.fontWeight);
      expect(span('Seen').style!.color, BvColors.textSecondary);
    });
  }

  for (final lang in ['en', 'ar']) {
    testWidgets('review 54 A2: the post page: no reply line on the post; '
        'each reply at the two sizes with 48-point Useful and Reply; "Write '
        'a reply"; Useful is the seal-check [$lang]', (tester) async {
      final l10n = lookupAppLocalizations(Locale(lang));
      final type = lang == 'ar' ? BvType.arabic : BvType.latin;
      final posts = _posts();
      await pumpApp(tester, language: lang, posts: posts);
      await tester.pumpAndSettle();
      // The feed card: Useful with the seal-check, never a thumbs-up.
      Icon iconIn(String key) => tester.widget<Icon>(
        find.descendant(of: find.byKey(Key(key)), matching: find.byType(Icon)),
      );
      expect(iconIn('post-useful-p1').icon, BvIcons.useful);
      expect(BvIcons.useful.codePoint, 0xe606);
      expect(find.byKey(const Key('post-latest-reply-p1')), findsOneWidget);

      await tester.tap(find.byKey(const Key('post-latest-reply-p1')));
      await tester.pumpAndSettle();
      final page = find.byType(PostScreen);
      expect(page, findsOneWidget);
      // The replies are listed under the post: its card has no reply line.
      expect(find.byKey(const Key('post-latest-reply-p1')), findsNothing);
      expect(find.byType(BvLatestReply), findsNothing);
      expect(iconIn('post-useful-p1').icon, BvIcons.useful);
      expect(find.text(l10n.postReplies), findsOneWidget);
      // The field asks for a reply, not a comment.
      final field = tester.widget<TextField>(
        find.byKey(const Key('post-reply-input')),
      );
      expect(field.decoration!.hintText, l10n.postWriteReply);
      expect(l10n.postWriteReply, lang == 'ar' ? 'اكتب ردًا' : 'Write a reply');

      TextStyle styleOf(Finder f) => tester
          .widget<Text>(
            find.descendant(of: f, matching: find.byType(Text)).first,
          )
          .style!;
      for (final id in ['r1', 'r2']) {
        await tester.ensureVisible(find.byKey(Key('reply-$id')));
        await tester.pumpAndSettle();
        final name = tester.widget<Text>(find.byKey(Key('reply-name-$id')));
        expect(name.style!.fontSize, type.labelMd.fontSize);
        expect(name.style!.fontWeight, type.labelMd.fontWeight);
        final time = tester.widget<Text>(find.byKey(Key('reply-time-$id')));
        expect(time.style!.fontSize, type.metadata.fontSize);
        for (final action in ['useful', 'reply']) {
          final key = find.byKey(Key('reply-$action-$id'));
          expect(styleOf(key).fontSize, type.labelMd.fontSize);
          final size = tester.getSize(key);
          expect(size.width, greaterThanOrEqualTo(48));
          expect(size.height, greaterThanOrEqualTo(48));
        }
      }
      // A tap at the edge of the 48-point area still counts.
      final useful = find.byKey(const Key('reply-useful-r1'));
      final rect = tester.getRect(useful);
      await tester.tapAt(Offset(rect.center.dx, rect.bottom - 2));
      await tester.pumpAndSettle();
      expect(posts.calls, contains('useful reply r1 true'));
    });
  }

  test('seen replies are kept per account, the newest only', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    ProviderContainer phone(String user) {
      final c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authUserIdProvider.overrideWithValue(AsyncData(user)),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    final container = phone('user-omar');
    final seen = container.read(seenRepliesProvider.notifier);
    for (var i = 0; i < SeenReplies.keep + 5; i++) {
      seen.seen('r$i');
    }
    final ids = container.read(seenRepliesProvider);
    expect(ids, hasLength(SeenReplies.keep));
    expect(ids, isNot(contains('r0')));
    expect(ids, contains('r${SeenReplies.keep + 4}'));
    // Kept on the phone for this account; another account has its own.
    expect(phone('user-omar').read(seenRepliesProvider), ids);
    expect(phone('user-sara').read(seenRepliesProvider), isEmpty);
  });
}
