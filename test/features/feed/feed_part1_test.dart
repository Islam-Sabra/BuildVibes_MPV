import 'package:buildvibes/data/models/market.dart';
import 'package:buildvibes/data/models/post.dart';
import 'package:buildvibes/data/models/profile.dart';
import 'package:buildvibes/features/feed/feed_state.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_avatar.dart';
import 'package:buildvibes/shared/widgets/bv_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/post_fakes.dart';
import '../../helpers/pump_app.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

Future<void> _tap(WidgetTester tester, String key) async {
  // Below the fold, a list hasn't built it yet: scroll to it.
  if (find.byKey(Key(key)).evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      find.byKey(Key(key)),
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(find.byKey(Key(key)).first);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)).first);
  await tester.pumpAndSettle();
}

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Navigator).first));

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(Navigator).first));

const _tower = PostProject(
  id: 'pr-1',
  name: 'Kuwait City Tower',
  typeName: LocalizedText(en: 'Commercial', ar: 'تجاري'),
  placeName: LocalizedText(en: 'Kuwait City', ar: 'مدينة الكويت'),
);

Post _post(
  String id,
  String author,
  String name,
  String body, {
  PostProject? project,
  String lang = 'en',
  List<PostPhoto> photos = const [],
  int hoursAgo = 3,
}) => Post(
  id: id,
  authorId: author,
  authorName: name,
  authorHeadline: 'Site Engineer',
  authorCompany: 'Al Hamra Contracting',
  body: body,
  lang: lang,
  project: project,
  createdAt: testNow.subtract(Duration(hours: hoursAgo)),
  photos: photos,
);

FakePostRepository _posts() => FakePostRepository(now: testNow)
  ..posts.addAll([
    _post(
      'p1',
      'p-omar2',
      'Omar Haddad',
      'First pour on the podium transfer slab is done.',
      project: _tower,
      photos: const [
        PostPhoto(path: 'p-omar2/p1/a.jpg', width: 1600, height: 1200),
      ],
    ),
    _post('p2', 'user-1', 'Omar Haddad', 'Morning walk done.', hoursAgo: 4),
    _post('p3', 'p-sara', 'Sara Ali', 'Hello from Cairo.', hoursAgo: 30),
  ])
  ..home.addAll(['p1', 'p2'])
  ..useful['p1'] = ['Mariam Al-Sabah', 'Rakesh Nair'];

CvProjectEntry _cv(String id, String name, {required bool confirmed}) =>
    CvProjectEntry(
      id: 'cv-$id',
      projectId: id,
      projectName: name,
      role: 'Site engineer',
      showOnProfile: true,
      confirmed: confirmed,
      start: DateTime(2023, 3),
    );

Future<TestApp> _feed(
  WidgetTester tester,
  String lang, {
  FakePostRepository? posts,
}) async {
  final app = await pumpApp(
    tester,
    language: lang,
    posts: posts ?? _posts(),
    setUp: (pages, _) => pages.cv['user-1'] = [
      _cv('pr-1', 'Kuwait City Tower', confirmed: true),
      _cv('pr-2', 'Gate 3 car park', confirmed: false),
    ],
  );
  await tester.pumpAndSettle();
  return app;
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);

    testWidgets('H1: home market first, the divider, then the rest [$lang]', (
      tester,
    ) async {
      await _feed(tester, lang);
      expect(find.byKey(const Key('post-p1')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('feed-beyond')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      // p2 is a home post: above the divider.
      expect(
        tester.getTopLeft(find.byKey(const Key('post-p2'))).dy,
        lessThan(tester.getTopLeft(find.byKey(const Key('feed-beyond'))).dy),
      );
      expect(
        find.text(l10n.feedBeyond(lang == 'ar' ? 'الكويت' : 'Kuwait')),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('post-p3')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester.getTopLeft(find.byKey(const Key('post-p3'))).dy,
        greaterThan(tester.getTopLeft(find.byKey(const Key('feed-beyond'))).dy),
      );
    });

    testWidgets('the card: project strip with its type, names, no counts '
        '[$lang]', (tester) async {
      await _feed(tester, lang);
      expect(find.byKey(const Key('post-project-pr-1')), findsOneWidget);
      expect(find.text(lang == 'ar' ? 'تجاري' : 'COMMERCIAL'), findsOneWidget);
      expect(
        find.text(l10n.postUsefulTwo('Mariam Al-Sabah', 'Rakesh Nair')),
        findsOneWidget,
      );
      // No Save, Share or numbers.
      expect(
        find.textContaining(RegExp(r'\b\d+ (useful|replies)')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('post-photo-p-omar2/p1/a.jpg')),
        findsOneWidget,
      );
    });

    testWidgets('Useful: on and off; never on your own post [$lang]', (
      tester,
    ) async {
      final app = await _feed(tester, lang);
      await _tap(tester, 'post-useful-p1');
      expect(app.posts.calls, ['useful post p1 true']);
      await _tap(tester, 'post-useful-p1');
      expect(app.posts.calls.last, 'useful post p1 false');
      await _tap(tester, 'post-useful-p2');
      expect(app.posts.calls, hasLength(2));
    });

    testWidgets('H8: Mute takes their posts out, with Undo [$lang]', (
      tester,
    ) async {
      final app = await _feed(tester, lang);
      await _tap(tester, 'post-menu-p1');
      expect(find.byKey(const Key('post-edit')), findsNothing);
      await _tap(tester, 'post-mute');
      expect(app.posts.calls, ['mute p-omar2 true']);
      expect(find.byKey(const Key('post-p1')), findsNothing);
      expect(find.text(l10n.postMuted('Omar Haddad')), findsOneWidget);
      await tester.tap(find.text(l10n.postUndo));
      await tester.pumpAndSettle();
      expect(app.posts.calls.last, 'mute p-omar2 false');
      // And their posts are back.
      expect(find.byKey(const Key('post-p1')), findsOneWidget);
    });

    testWidgets('H8b/H11: your post: Edit and Delete, after asking [$lang]', (
      tester,
    ) async {
      final app = await _feed(tester, lang);
      await _tap(tester, 'post-menu-p2');
      expect(find.byKey(const Key('post-mute')), findsNothing);
      await _tap(tester, 'post-delete');
      expect(find.text(l10n.postDeleteTitle), findsOneWidget);
      await _tap(tester, 'bv-dialog-confirm');
      expect(app.posts.calls, ['delete p2']);
      expect(find.byKey(const Key('post-p2')), findsNothing);
    });

    testWidgets('empty feed: a note and Create [$lang]', (tester) async {
      await _feed(tester, lang, posts: FakePostRepository(now: testNow));
      expect(find.text(l10n.feedEmpty), findsOneWidget);
      await _tap(tester, 'feed-create');
      expect(find.byKey(const Key('composer-text')), findsOneWidget);
    });

    testWidgets('H5 couldn\'t load, then Try again [$lang]', (tester) async {
      final posts = _posts()..feedOffline = true;
      await _feed(tester, lang, posts: posts);
      expect(find.text(l10n.feedCouldntLoad), findsOneWidget);
      expect(find.text(l10n.feedCouldntLoadBody), findsOneWidget);
      posts.feedOffline = false;
      await _tap(tester, 'feed-try-again');
      expect(find.byKey(const Key('post-p1')), findsOneWidget);
    });

    testWidgets('H6 offline: the page kept on the phone [$lang]', (
      tester,
    ) async {
      final posts = _posts();
      final app = await _feed(tester, lang, posts: posts);
      posts.feedOffline = true;
      _container(tester).invalidate(feedProvider);
      await tester.pumpAndSettle();
      expect(find.text(l10n.feedOffline), findsOneWidget);
      expect(find.byKey(const Key('post-p1')), findsOneWidget);
      // Kept for this person only.
      expect(app.prefs.getString('feed_cache_user-1'), isNotNull);
      expect(app.prefs.getString('feed_cache'), isNull);
    });

    testWidgets('C1/C2: a template, the audience, the language, Post '
        '[$lang]', (tester) async {
      final app = await _feed(tester, lang);
      _router(tester).push('/posts/new');
      await tester.pumpAndSettle();
      // Post waits for text or a photo.
      expect(
        tester
            .widget<BvButton>(find.byKey(const Key('composer-post')))
            .onPressed,
        isNull,
      );
      await _tap(tester, 'composer-template-progress');
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('composer-text')))
            .controller!
            .text,
        startsWith(l10n.tplProgressLines),
      );
      expect(find.byKey(const Key('composer-start-from')), findsNothing);
      expect(find.text(l10n.composerAudience), findsOneWidget);
      // Arabic letters: the post is written in Arabic.
      await tester.enterText(
        find.byKey(const Key('composer-text')),
        'تم صب السقف',
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.composerWrittenIn('ar')), findsOneWidget);
      await _tap(tester, 'composer-lang-change');
      // L6: what was detected, in the app's language. The line about
      // Translate waits for Translate (review 28).
      expect(find.text(l10n.composerLangWhy), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('composer-lang-auto')),
          matching: find.text(l10n.langName('ar')),
        ),
        findsOneWidget,
      );
      await _tap(tester, 'composer-lang-en');
      expect(find.text(l10n.composerWrittenIn('en')), findsOneWidget);

      // C10: only the confirmed project.
      await _tap(tester, 'composer-project');
      expect(find.byKey(const Key('composer-tag-pr-1')), findsOneWidget);
      expect(find.byKey(const Key('composer-tag-pr-2')), findsNothing);
      await _tap(tester, 'composer-tag-pr-1');
      expect(find.text(l10n.composerAudienceProject), findsOneWidget);
      expect(
        find.text(l10n.composerPostingToProject('Kuwait City Tower')),
        findsOneWidget,
      );

      await _tap(tester, 'composer-media');
      await _tap(tester, 'composer-post');
      expect(app.posts.uploads, hasLength(1));
      expect(app.posts.calls.single, 'create en pr-1 1 تم صب السقف');
      expect(find.byKey(const Key('composer-text')), findsNothing);
    });

    testWidgets('weak signal: kept as a draft, then Retry [$lang]', (
      tester,
    ) async {
      final posts = _posts()..failNext = 9;
      final app = await _feed(tester, lang, posts: posts);
      _router(tester).push('/posts/new');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('composer-text')),
        'Rebar done.',
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'composer-post');
      expect(find.text(l10n.postFailed), findsOneWidget);
      expect(app.prefs.getString('post_outbox'), contains('Rebar done.'));
      posts.failNext = 0;
      final retry = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('feed-retry-'),
      );
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(app.posts.calls.single, 'create en - 0 Rebar done.');
      expect(find.text(l10n.postFailed), findsNothing);
      expect(app.prefs.getString('post_outbox'), isNot(contains('Rebar')));
    });

    testWidgets('C13: closing with text asks first [$lang]', (tester) async {
      await _feed(tester, lang);
      _router(tester).push('/posts/new');
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('composer-text')), 'Draft');
      await tester.pumpAndSettle();
      await _tap(tester, 'composer-close');
      expect(find.text(l10n.discardTitle), findsOneWidget);
      await _tap(tester, 'bv-dialog-confirm');
      expect(find.byKey(const Key('composer-text')), findsNothing);
    });

    testWidgets('edit: the text and its language only [$lang]', (tester) async {
      final app = await _feed(tester, lang);
      _router(tester).push('/posts/p2/edit');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('composer-media')), findsNothing);
      await tester.enterText(
        find.byKey(const Key('composer-text')),
        'Walk done, all clear.',
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'composer-post');
      expect(app.posts.calls.single, 'edit p2 en Walk done, all clear.');
    });

    testWidgets('H10/H17: replies one level deep, and Replying to '
        '[$lang]', (tester) async {
      final posts = _posts()
        ..repliesByPost['p1'] = [
          PostReply(
            id: 'r1',
            postId: 'p1',
            authorId: 'p-faisal',
            authorName: 'Faisal Al-Rashidi',
            body: 'Good catch on C7.',
            createdAt: testNow.subtract(const Duration(hours: 1)),
          ),
          PostReply(
            id: 'r2',
            postId: 'p1',
            authorId: 'p-mariam',
            authorName: 'Mariam Al-Sabah',
            replyTo: 'r1',
            body: 'Model updated.',
            createdAt: testNow.subtract(const Duration(minutes: 30)),
          ),
        ];
      final app = await _feed(tester, lang, posts: posts);
      _router(tester).push('/posts/p1');
      await tester.pumpAndSettle();
      expect(find.text(l10n.postReplies), findsOneWidget);
      // Mariam's reply sits under Faisal's.
      await tester.scrollUntilVisible(
        find.byKey(const Key('reply-r2')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      // Indented on the start side: the left in English, the right in Arabic.
      final r1 = tester.getRect(find.byKey(const Key('reply-r1')));
      final r2 = tester.getRect(find.byKey(const Key('reply-r2')));
      expect(lang == 'ar' ? r2.right < r1.right : r2.left > r1.left, isTrue);
      // Replying to Mariam answers the top-level reply, named for her.
      await _tap(tester, 'reply-reply-r2');
      expect(find.text(l10n.postReplyingTo('Mariam Al-Sabah')), findsOneWidget);
      // English text stays left to right in Arabic: the quote and the box.
      expect(
        tester
            .widget<Text>(find.byKey(const Key('post-replying-body')))
            .textDirection,
        TextDirection.ltr,
      );
      await tester.enterText(
        find.byKey(const Key('post-reply-input')),
        'Thanks.',
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('post-reply-input')))
            .textDirection,
        TextDirection.ltr,
      );
      await _tap(tester, 'post-reply-send');
      expect(app.posts.calls.single, 'reply p1 r1 Thanks.');
      expect(find.byKey(const Key('post-replying')), findsNothing);
    });

    testWidgets('H13/H14: delete your own reply only [$lang]', (tester) async {
      final posts = _posts()
        ..repliesByPost['p1'] = [
          PostReply(
            id: 'r1',
            postId: 'p1',
            authorId: 'p-faisal',
            authorName: 'Faisal Al-Rashidi',
            body: 'Good catch.',
            createdAt: testNow,
          ),
          PostReply(
            id: 'r3',
            postId: 'p1',
            authorId: 'user-1',
            authorName: 'Omar Haddad',
            body: 'Thanks all.',
            createdAt: testNow,
          ),
        ];
      final app = await _feed(tester, lang, posts: posts);
      _router(tester).push('/posts/p1');
      await tester.pumpAndSettle();
      // Someone else's reply: its menu offers Report, never Delete.
      await _tap(tester, 'reply-menu-r1');
      expect(find.byKey(const Key('reply-delete')), findsNothing);
      expect(find.byKey(const Key('reply-report')), findsOneWidget);
      await tester.tapAt(const Offset(195, 100));
      await tester.pumpAndSettle();
      // Your reply's text is as wide as anyone's: the menu doesn't push it in.
      await tester.scrollUntilVisible(
        find.byKey(const Key('reply-r3')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester.getSize(find.byKey(const Key('reply-body-r3'))).width,
        tester.getSize(find.byKey(const Key('reply-body-r1'))).width,
      );
      await _tap(tester, 'reply-menu-r3');
      await _tap(tester, 'reply-delete');
      expect(find.text(l10n.postDeleteReplyTitle), findsOneWidget);
      // H14: a short "Delete", so the button never cuts off.
      expect(
        tester
            .widget<BvButton>(find.byKey(const Key('bv-dialog-confirm')))
            .label,
        l10n.delete,
      );
      await _tap(tester, 'bv-dialog-confirm');
      expect(app.posts.calls.single, 'delete-reply r3');
      expect(find.byKey(const Key('reply-r3')), findsNothing);
    });

    testWidgets('the reply box rises with the keyboard [$lang]', (
      tester,
    ) async {
      await _feed(tester, lang);
      _router(tester).push('/posts/p1');
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const Key('post-reply-input'))).bottom,
        lessThanOrEqualTo(844 - 300),
      );
    });

    testWidgets('review 18: short times, the feed card on the post page, '
        'Useful on replies [$lang]', (tester) async {
      final posts = _posts()
        ..repliesByPost['p1'] = [
          PostReply(
            id: 'r1',
            postId: 'p1',
            authorId: 'p-faisal',
            authorName: 'Faisal Al-Rashidi',
            authorHeadline: 'Site Engineer',
            body: 'Good catch.',
            createdAt: testNow.subtract(const Duration(minutes: 4)),
          ),
        ];
      final app = await _feed(tester, lang, posts: posts);
      // "3h", not "3h ago".
      expect(find.textContaining(l10n.timeHoursShort(3)), findsWidgets);
      expect(find.textContaining(l10n.timeHoursAgo(3)), findsNothing);
      _router(tester).push('/posts/p1');
      await tester.pumpAndSettle();
      // The project strip, as in the Feed; no avatar on the card.
      expect(find.byKey(const Key('post-project-pr-1')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('post-p1')),
          matching: find.byType(BvAvatar),
        ),
        findsNothing,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('reply-r1')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Site Engineer'), findsOneWidget);
      expect(find.text(l10n.timeMinutesShort(4)), findsOneWidget);
      await _tap(tester, 'reply-useful-r1');
      expect(app.posts.calls.single, 'useful reply r1 true');
    });

    testWidgets('review 18: the network tile, Discard words, Retry [$lang]', (
      tester,
    ) async {
      final posts = _posts()..failNext = 9;
      await _feed(tester, lang, posts: posts);
      _router(tester).push('/posts/new');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('composer-network-tile')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('composer-text')), 'Draft');
      await tester.pumpAndSettle();
      await _tap(tester, 'composer-close');
      expect(find.text(l10n.discardBody), findsOneWidget);
      expect(find.text(l10n.discardKeep), findsOneWidget);
      await _tap(tester, 'bv-dialog-cancel');
      await _tap(tester, 'composer-post');
      expect(find.text(l10n.chatRetry), findsOneWidget);
    });

    testWidgets('P6: a post that is gone [$lang]', (tester) async {
      await _feed(tester, lang);
      _router(tester).push('/posts/nope');
      await tester.pumpAndSettle();
      expect(find.text(l10n.postUnavailable), findsOneWidget);
      // Centred in both directions.
      expect(
        tester.getCenter(find.text(l10n.postUnavailable)).dx,
        closeTo(tester.getSize(find.byType(Scaffold).last).width / 2, 1),
      );
    });

    testWidgets('R12: your posts on your profile [$lang]', (tester) async {
      await _feed(tester, lang);
      _router(tester).push('/profile');
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.profileTabPosts));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('post-p2')), findsOneWidget);
      expect(find.byKey(const Key('post-p1')), findsNothing);
    });
  }

  test('the post language: Arabic when most letters are Arabic', () {
    expect(detectLang('Slab poured'), 'en');
    expect(detectLang('تم صب السقف اليوم'), 'ar');
    expect(detectLang('تم صب السقف KCT-021'), 'ar');
    expect(detectLang('KCT-021 slab ثم'), 'en');
  });
}
