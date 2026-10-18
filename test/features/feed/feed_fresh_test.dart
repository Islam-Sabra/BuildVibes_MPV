// Review 51 Part B: the Home feed is never stale (F11, F18), a post sent
// after no signal is one card without "Waiting to send" (F17), and a
// reply sent again is one reply (F19).
import 'package:buildvibes/data/models/post.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/post_fakes.dart';
import '../../helpers/pump_app.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

Post _post(String id, String body, {int minutesAgo = 60}) => Post(
  id: id,
  authorId: 'p-omar2',
  authorName: 'Omar Haddad',
  body: body,
  lang: 'en',
  createdAt: testNow.subtract(Duration(minutes: minutesAgo)),
);

/// [count] home posts, newest first.
FakePostRepository _posts({int count = 1}) {
  final posts = FakePostRepository(now: testNow);
  for (var i = 0; i < count; i++) {
    posts.posts.add(
      _post('p$i', 'Site note $i: the slab is ready.', minutesAgo: 60 + i),
    );
    posts.home.add('p$i');
  }
  return posts;
}

/// Someone else posts while this phone shows the feed.
void _someonePosts(FakePostRepository posts, String body) {
  posts.posts.insert(0, _post('p-new', body, minutesAgo: 1));
  posts.home.add('p-new');
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)).first);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)).first);
  await tester.pumpAndSettle();
}

Future<void> _writeOffline(
  WidgetTester tester,
  FakePostRepository posts,
  String body,
) async {
  // Each send tries three times before it waits.
  posts.failNext = 3;
  await tester.tap(find.byKey(const Key('nav-create')));
  await tester.pumpAndSettle();
  // Create's choice (F1): Post to everyone.
  await tester.tap(find.byKey(const Key('create-post')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('writing-body')), body);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('writing-post')));
  await tester.pumpAndSettle();
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);
    const fresh = 'Crane inspection passed.';

    testWidgets('F18: pull to refresh works on a feed shorter than the page '
        '[$lang]', (tester) async {
      final posts = _posts();
      await pumpApp(tester, language: lang, posts: posts);
      expect(find.text(fresh), findsNothing);
      _someonePosts(posts, fresh);
      await tester.fling(
        find.byKey(const Key('feed-list')),
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();
      expect(find.text(fresh), findsOneWidget);
    });

    testWidgets('F11: the feed reads again when the app comes back to the '
        'front [$lang]', (tester) async {
      final posts = _posts();
      await pumpApp(tester, language: lang, posts: posts);
      _someonePosts(posts, fresh);
      await backToTheApp(tester);
      expect(find.text(fresh), findsOneWidget);
    });

    testWidgets('F11: the feed reads again when Home is shown again '
        '[$lang]', (tester) async {
      final posts = _posts();
      await pumpApp(tester, language: lang, posts: posts);
      await _tap(tester, 'nav-profile');
      _someonePosts(posts, fresh);
      await _tap(tester, 'nav-home');
      expect(find.text(fresh), findsOneWidget);
      // And after a page on top of it closes.
      posts.posts.insert(0, _post('p-next', 'Scaffold tagged.'));
      posts.home.add('p-next');
      final router = GoRouter.of(tester.element(find.byType(Navigator).first));
      router.push('/posts/p0');
      await tester.pumpAndSettle();
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Scaffold tagged.'), findsOneWidget);
    });

    testWidgets('F11: a push with Home open reads the feed again [$lang]', (
      tester,
    ) async {
      final posts = _posts();
      final app = await pumpApp(tester, language: lang, posts: posts);
      _someonePosts(posts, fresh);
      app.push.arrive({'kind': 'post_reply', 'route': '/posts/p0'});
      await tester.pumpAndSettle();
      expect(find.text(fresh), findsOneWidget);
    });

    testWidgets('F11: reading further down, new posts don\'t move the page; '
        '"New" takes them to the top [$lang]', (tester) async {
      final posts = _posts(count: 12);
      await pumpApp(tester, language: lang, posts: posts);
      await tester.drag(
        find.byKey(const Key('feed-list')),
        const Offset(0, -700),
      );
      await tester.pumpAndSettle();
      // The post being read.
      final read = [
        for (var i = 0; i < 12; i++) 'post-p$i',
      ].firstWhere((k) => find.byKey(Key(k)).evaluate().isNotEmpty);
      final before = tester.getTopLeft(find.byKey(Key(read)));
      expect(find.byKey(const Key('feed-new')), findsNothing);

      _someonePosts(posts, fresh);
      await backToTheApp(tester);
      expect(tester.getTopLeft(find.byKey(Key(read))), before);
      expect(find.byKey(const Key('feed-new')), findsOneWidget);
      expect(find.text(l10n.feedNew), findsOneWidget);

      await tester.tap(find.byKey(const Key('feed-new')));
      await tester.pumpAndSettle();
      expect(find.text(fresh), findsOneWidget);
      expect(find.byKey(const Key('feed-new')), findsNothing);
    });

    testWidgets('F11: at the top, new posts just come in, with no chip '
        '[$lang]', (tester) async {
      final posts = _posts(count: 12);
      await pumpApp(tester, language: lang, posts: posts);
      _someonePosts(posts, fresh);
      await backToTheApp(tester);
      expect(find.text(fresh), findsOneWidget);
      expect(find.byKey(const Key('feed-new')), findsNothing);
    });

    testWidgets('F17: made with no signal, then the signal is back: one card, '
        'without "Waiting to send", within seconds [$lang]', (tester) async {
      final posts = _posts();
      final app = await pumpApp(
        tester,
        language: lang,
        posts: posts,
        retryLater: const [Duration(seconds: 2)],
      );
      await _writeOffline(tester, posts, 'Rebar done.');
      expect(find.text(l10n.daybookWaitingToSend), findsOneWidget);
      expect(posts.calls, isEmpty);

      // The signal is back: the outbox tries again by itself.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(posts.calls.single, 'create en - 0 Rebar done.');
      expect(find.text('Rebar done.'), findsOneWidget);
      expect(find.text(l10n.daybookWaitingToSend), findsNothing);
      expect(app.prefs.getString('post_outbox:user-1'), '[]');
    });

    testWidgets('F17: sent, but not read back yet: the label '
        'goes at once, still one card [$lang]', (tester) async {
      final posts = _posts();
      final app = await pumpApp(tester, language: lang, posts: posts);
      await _writeOffline(tester, posts, 'Rebar done.');
      // The post gets through; the signal drops before the feed reads it.
      posts.readsOffline = true;
      await backToTheApp(tester);
      expect(posts.calls.single, 'create en - 0 Rebar done.');
      expect(find.text('Rebar done.'), findsOneWidget);
      expect(find.text(l10n.daybookWaitingToSend), findsNothing);
      expect(
        app.prefs.getString('post_outbox:user-1'),
        contains('"sent":true'),
      );

      // The next read has it: the server's card, once.
      posts.readsOffline = false;
      await backToTheApp(tester);
      expect(find.text('Rebar done.'), findsOneWidget);
      expect(find.text(l10n.daybookWaitingToSend), findsNothing);
      expect(app.prefs.getString('post_outbox:user-1'), '[]');
      expect(posts.calls, hasLength(1));
    });

    for (final onServer in [false, true]) {
      testWidgets('F17: after the app is opened again, one card without the '
          'label (${onServer ? 'it had reached the server' : 'sent on '
                    'opening'}) [$lang]', (tester) async {
        final posts = _posts();
        final app = await pumpApp(tester, language: lang, posts: posts);
        await _writeOffline(tester, posts, 'Rebar done.');
        final kept = app.prefs.getString('post_outbox:user-1')!;
        expect(kept, contains('Rebar done.'));
        if (onServer) {
          // It reached the server, but the answer was lost.
          posts.posts.insert(
            0,
            _post(
              RegExp(r'"id":"([^"]+)"').firstMatch(kept)!.group(1)!,
              'Rebar done.',
              minutesAgo: 0,
            ),
          );
          posts.home.add(posts.posts.first.id);
        }

        // Closed, then opened again.
        await tester.pumpWidget(const SizedBox());
        final again = await pumpApp(
          tester,
          language: lang,
          posts: posts,
          stored: {'post_outbox:user-1': kept},
        );
        expect(find.text('Rebar done.'), findsOneWidget);
        expect(find.text(l10n.daybookWaitingToSend), findsNothing);
        expect(again.prefs.getString('post_outbox:user-1'), '[]');
        expect(posts.posts.where((p) => p.body == 'Rebar done.'), hasLength(1));
      });
    }

    testWidgets('F19: a reply sent again after the answer was lost is one '
        'reply [$lang]', (tester) async {
      final posts = _posts()..replyAnswerLost = 1;
      await pumpApp(tester, language: lang, posts: posts);
      GoRouter.of(
        tester.element(find.byType(Navigator).first),
      ).push('/posts/p0');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('post-reply-input')),
        'hello islam',
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'post-reply-send');
      // The answer was lost: the text stays to send again.
      expect(find.text('hello islam'), findsOneWidget);
      await _tap(tester, 'post-reply-send');
      expect(posts.calls.where((c) => c.startsWith('reply')), hasLength(2));
      expect(posts.repliesByPost['p0'], hasLength(1));
      expect(
        find.descendant(
          of: find.byType(ListView),
          matching: find.text('hello islam'),
        ),
        findsOneWidget,
      );
    });
  }
}
