// Review 53 Part D on the post page: no Reply and no Useful on your own
// replies (F31); the reply bar rides on the keyboard (F24).
import 'package:buildvibes/data/models/post.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/post_fakes.dart';
import '../../helpers/pump_app.dart';

const _keyboard = 300.0;

FakePostRepository _posts() => FakePostRepository(now: testNow)
  ..posts.add(
    Post(
      id: 'p1',
      authorId: 'p-omar2',
      authorName: 'Omar Haddad',
      authorHeadline: 'Site Engineer',
      body: 'First pour on the podium transfer slab is done.',
      lang: 'en',
      createdAt: testNow.subtract(const Duration(hours: 3)),
    ),
  )
  ..home.add('p1')
  ..repliesByPost['p1'] = [
    PostReply(
      id: 'r1',
      postId: 'p1',
      authorId: 'p-omar2',
      authorName: 'Omar Haddad',
      body: 'Seen it, thanks.',
      createdAt: testNow.subtract(const Duration(minutes: 10)),
    ),
    // Yours (user-1), answering Omar.
    PostReply(
      id: 'r2',
      postId: 'p1',
      authorId: 'user-1',
      authorName: 'Islam Ahmed',
      replyTo: 'r1',
      replyToPerson: 'p-omar2',
      body: 'Good, thanks Omar.',
      createdAt: testNow.subtract(const Duration(minutes: 5)),
    ),
  ];

Future<void> _openPost(WidgetTester tester, String lang) async {
  await pumpApp(tester, language: lang, posts: _posts());
  await tester.pumpAndSettle();
  GoRouter.of(tester.element(find.byType(Navigator).first)).push('/posts/p1');
  await tester.pumpAndSettle();
}

void main() {
  for (final lang in ['en', 'ar']) {
    testWidgets('F31: your own reply has no Reply and no Useful, only ⋯; '
        "someone else's has both [$lang]", (tester) async {
      await _openPost(tester, lang);
      await tester.scrollUntilVisible(
        find.byKey(const Key('reply-r2')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const Key('reply-reply-r2')), findsNothing);
      expect(find.byKey(const Key('reply-useful-r2')), findsNothing);
      expect(find.byKey(const Key('reply-menu-r2')), findsOneWidget);
      // Others can still answer your reply's thread, and Omar's has both.
      expect(find.byKey(const Key('reply-reply-r1')), findsOneWidget);
      expect(find.byKey(const Key('reply-useful-r1')), findsOneWidget);
    });

    testWidgets('F24: the reply bar rides on a 300-point keyboard from the '
        'first frame [$lang]', (tester) async {
      await _openPost(tester, lang);
      await tester.tap(find.byKey(const Key('post-reply-input')));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();
      for (final key in ['post-reply-input', 'post-reply-send']) {
        final r = tester.getRect(find.byKey(Key(key)));
        expect(r.top, greaterThanOrEqualTo(0));
        expect(r.bottom, lessThanOrEqualTo(844 - _keyboard + 0.5), reason: key);
      }
      // Sends at the first tap.
      await tester.enterText(find.byKey(const Key('post-reply-input')), 'Ok');
      await tester.pump();
      await tester.tap(find.byKey(const Key('post-reply-send')));
      await tester.pumpAndSettle();
      expect(find.text('Ok'), findsOneWidget);
    });
  }
}
