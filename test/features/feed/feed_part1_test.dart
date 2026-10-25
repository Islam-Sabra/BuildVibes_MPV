import 'package:buildvibes/core/design/around_specs.dart';
import 'package:buildvibes/core/design/bv_specs.dart';
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/core/design/daybook_paper_specs.dart';
import 'package:buildvibes/core/l10n/bidi.dart';
import 'package:buildvibes/core/l10n/bv_time.dart';
import 'package:buildvibes/data/models/market.dart';
import 'package:buildvibes/data/models/post.dart';
import 'package:buildvibes/data/models/profile.dart';
import 'package:buildvibes/features/feed/feed_state.dart';
import 'package:buildvibes/features/feed/post_draft.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_avatar.dart';
import 'package:buildvibes/shared/widgets/bv_button.dart';
import 'package:buildvibes/shared/widgets/bv_writing_toolbar.dart';
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

/// Post (or Save) on the writing toolbar is on.
bool _postOn(WidgetTester tester) =>
    tester.widget<BvWritingToolbar>(find.byType(BvWritingToolbar)).onPost !=
    null;

Future<void> _more(WidgetTester tester, AppLocalizations l10n) async {
  await tester.tap(find.bySemanticsLabel(l10n.daybookMore));
  await tester.pumpAndSettle();
}

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

    testWidgets('the card (H1 v3): the project tag, names, no counts '
        '[$lang]', (tester) async {
      await _feed(tester, lang);
      expect(find.byKey(const Key('post-project-pr-1')), findsOneWidget);
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

    testWidgets('H1 v4: the card: the avatar, the name in main semibold '
        'with the headline under it, the time and ⋯ at the end, level with '
        'the author; the text right under; actions with a 48 touch area '
        '[$lang]', (tester) async {
      final posts = _posts()
        ..posts.add(
          Post(
            id: 'p4',
            authorId: 'p-lina',
            authorName: 'Lina Haddad',
            body: 'Ok.',
            lang: 'en',
            createdAt: testNow.subtract(const Duration(hours: 5)),
          ),
        )
        ..home.add('p4');
      final app = await _feed(tester, lang, posts: posts);
      Rect at(String key) => tester.getRect(find.byKey(Key(key)));
      Rect avatarOf(String id) => tester.getRect(
        find.descendant(
          of: find.byKey(Key('post-$id')),
          matching: find.byType(BvAvatar),
        ),
      );
      final avatar = avatarOf('p1');
      expect(avatar.size, const Size.square(BvAvatarSpec.post));
      final menu = at('post-menu-p1');
      final time = at('post-time-p1');
      expect(menu.center.dy, closeTo(avatar.center.dy, 1));
      expect(time.center.dy, closeTo(avatar.center.dy, 1));
      expect(menu.size, const Size.square(BvHomeSpec.menuIcon));
      // The time, then ⋯ at the card's end, inside the paper.
      final card = at('post-p1');
      if (lang == 'ar') {
        expect(menu.right, lessThan(time.left));
        expect(menu.left - card.left, closeTo(BvSlipSpec.paddingSide, 1));
      } else {
        expect(menu.left, greaterThan(time.right));
        expect(card.right - menu.right, closeTo(BvSlipSpec.paddingSide, 1));
      }
      // The card is full width, 16 from each edge: no hour spine.
      expect(card.left, closeTo(BvSpace.gutter, 0.5));
      expect(card.right, closeTo(390 - BvSpace.gutter, 0.5));
      expect(
        tester
            .widget<Text>(find.byKey(const Key('post-name-p1')))
            .style!
            .fontWeight,
        (lang == 'ar' ? BvType.arabic : BvType.latin).titleMd.fontWeight,
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('post-byline-p1'))).data,
        contains('Site Engineer, Al Hamra Contracting'),
      );
      // The text directly under the author block: the slip's 10 gap.
      final byline = at('post-byline-p1');
      final body = tester.getRect(
        find.text('First pour on the podium transfer slab is done.'),
      );
      expect(body.top - byline.bottom, closeTo(10, 1));
      // Useful takes a touch 20 above its middle (48 high, centred).
      await tester.ensureVisible(find.byKey(const Key('post-useful-p1')));
      await tester.pumpAndSettle();
      final useful = at('post-useful-p1');
      await tester.tapAt(useful.center.translate(0, -20));
      await tester.pumpAndSettle();
      expect(app.posts.calls, ['useful post p1 true']);
      await tester.tapAt(useful.center.translate(0, 20));
      await tester.pumpAndSettle();
      expect(app.posts.calls.last, 'useful post p1 false');

      // No headline: the name sits centred with the avatar, no empty line,
      // and ⋯ stays level with it.
      await tester.scrollUntilVisible(
        find.byKey(const Key('post-p4')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const Key('post-byline-p4')), findsNothing);
      final alone = at('post-name-p4');
      expect(alone.center.dy, closeTo(avatarOf('p4').center.dy, 1));
      expect(at('post-menu-p4').center.dy, closeTo(alone.center.dy, 1));
      // ⋯ answers a touch beside it (48 × 48).
      await tester.tapAt(at('post-menu-p4').center.translate(0, 14));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('post-report')), findsOneWidget);
      // The card hugs a short post: the text, then the actions.
      final short = at('post-p4');
      final actions = at('post-useful-p4');
      expect(short.bottom - actions.bottom, lessThan(20));
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
      expect(find.byKey(const Key('post-writing-card')), findsOneWidget);
    });

    testWidgets('H5 couldn\'t load, then Try again [$lang]', (tester) async {
      final posts = _posts()..feedOffline = true;
      await _feed(tester, lang, posts: posts);
      expect(find.text(l10n.feedCouldntLoad), findsOneWidget);
      expect(find.text(l10n.feedCouldntLoadBody), findsOneWidget);
      // The signal comes back only at the tap: Riverpod's own retry of the
      // failed load may land while the test scrolls (review 91).
      const tryAgain = Key('feed-try-again');
      await tester.ensureVisible(find.byKey(tryAgain));
      await tester.pumpAndSettle();
      posts.feedOffline = false;
      await tester.tap(find.byKey(tryAgain));
      await tester.pumpAndSettle();
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

    testWidgets('H2: Create writes a post in place at Now [$lang]', (
      tester,
    ) async {
      final app = await _feed(tester, lang);
      await tester.tap(find.byKey(const Key('nav-create')));
      await tester.pumpAndSettle();
      // Create's choice (F1): Post to everyone.
      await tester.tap(find.byKey(const Key('create-post')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('post-writing-card')), findsOneWidget);
      expect(find.text(l10n.postWritingAuthor), findsOneWidget);
      // Post waits for text or a photo.
      expect(_postOn(tester), isFalse);

      // Arabic letters: the post is written in Arabic.
      await tester.enterText(
        find.byKey(const Key('writing-body')),
        'تم صب السقف',
      );
      await tester.pumpAndSettle();
      expect(_postOn(tester), isTrue);
      await _more(tester, l10n);
      expect(find.text(l10n.postWritingLang('ar')), findsOneWidget);
      await tester.tap(find.text(l10n.postWritingLang('ar')));
      await tester.pumpAndSettle();
      // L6: what was found, chosen by default; one single choice.
      expect(find.text(l10n.postLangAuto('ar')), findsOneWidget);
      await tester.tap(find.text(l10n.langEnglish));
      await tester.pumpAndSettle();
      await _more(tester, l10n);
      expect(find.text(l10n.postWritingLang('en')), findsOneWidget);

      // C10: only the confirmed project on the profile.
      await tester.tap(find.text(l10n.postWritingProject));
      await tester.pumpAndSettle();
      expect(find.text('Kuwait City Tower'), findsOneWidget);
      expect(find.text('Gate 3 car park'), findsNothing);
      await tester.tap(find.text('Kuwait City Tower'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('post-writing-tag')), findsOneWidget);

      await tester.tap(find.bySemanticsLabel(l10n.daybookCamera));
      await tester.pumpAndSettle();
      expect(app.cameraAsks, [true]);
      await tester.tap(find.byKey(const Key('writing-post')));
      await tester.pumpAndSettle();
      expect(app.posts.uploads, hasLength(1));
      expect(app.posts.calls.single, 'create en pr-1 1 تم صب السقف');
      expect(find.byKey(const Key('post-writing-card')), findsNothing);
      // The app chose its id; it is on top of the feed.
      expect(
        find.byKey(Key('post-${app.posts.posts.first.id}')),
        findsOneWidget,
      );
      expect(app.prefs.getString('post_draft:user-1'), isNull);
    });

    testWidgets('H2: up to four photos, from the camera or the phone '
        '[$lang]', (tester) async {
      final app = await _feed(tester, lang);
      await tester.tap(find.byKey(const Key('nav-create')));
      await tester.pumpAndSettle();
      // Create's choice (F1): Post to everyone.
      await tester.tap(find.byKey(const Key('create-post')));
      await tester.pumpAndSettle();
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.bySemanticsLabel(l10n.daybookAddPhoto));
        await tester.pumpAndSettle();
      }
      expect(app.cameraAsks, [false, false, false, false]);
      // A photo alone can be posted.
      expect(_postOn(tester), isTrue);
      await tester.tap(find.bySemanticsLabel(l10n.daybookCamera));
      await tester.pumpAndSettle();
      expect(app.cameraAsks, hasLength(4));
      expect(find.text(l10n.postWritingPhotosMax), findsOneWidget);
      await tester.tap(find.byKey(const Key('writing-photo-remove-3')).first);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('writing-photo-remove-3')), findsNothing);
      await tester.tap(find.byKey(const Key('writing-post')));
      await tester.pumpAndSettle();
      expect(app.posts.calls.single, startsWith('create en - 3'));
    });

    testWidgets('H4: a draft is kept as soon as anything is entered '
        '[$lang]', (tester) async {
      final app = await _feed(tester, lang);
      await tester.tap(find.byKey(const Key('nav-create')));
      await tester.pumpAndSettle();
      // Create's choice (F1): Post to everyone.
      await tester.tap(find.byKey(const Key('create-post')));
      await tester.pumpAndSettle();
      // The photo often comes first (review 46).
      await tester.tap(find.bySemanticsLabel(l10n.daybookCamera));
      await tester.pumpAndSettle();
      expect(app.prefs.getString('post_draft:user-1'), contains('kept.png'));
      await tester.enterText(
        find.byKey(const Key('writing-body')),
        'Slab poured',
      );
      await tester.pumpAndSettle();
      // A tap off the card puts it down: it stays as the Draft.
      await tester.tapAt(const Offset(195, 120));
      await tester.pumpAndSettle();
      expect(find.text(l10n.daybookDraft), findsOneWidget);
      expect(find.byKey(const Key('writing-post')), findsNothing);
      expect(app.posts.calls, isEmpty);

      // The app is closed and opened again: the Draft comes back.
      _container(tester).invalidate(postDraftProvider);
      await tester.pumpAndSettle();
      expect(_container(tester).read(postDraftProvider)?.body, 'Slab poured');
      await tester.tap(find.byKey(const Key('post-draft')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('writing-post')), findsOneWidget);

      // Emptied, it goes.
      await tester.enterText(find.byKey(const Key('writing-body')), '');
      await tester.tap(find.byKey(const Key('writing-photo-remove-0')).first);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(195, 120));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('post-writing-card')), findsNothing);
      expect(app.prefs.getString('post_draft:user-1'), isNull);
    });

    testWidgets('H5: no signal: it waits on the phone, then sends, with the '
        'sound (F5) [$lang]', (tester) async {
      final posts = _posts()..failNext = 9;
      final app = await _feed(tester, lang, posts: posts);
      await tester.tap(find.byKey(const Key('nav-create')));
      await tester.pumpAndSettle();
      // Create's choice (F1): Post to everyone.
      await tester.tap(find.byKey(const Key('create-post')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('writing-body')),
        'Rebar done.',
      );
      await tester.tap(find.bySemanticsLabel(l10n.daybookCamera));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('writing-post')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.daybookWaitingToSend), findsOneWidget);
      expect(find.text('Rebar done.'), findsOneWidget);
      // Each account has its own outbox.
      expect(app.prefs.getString('post_outbox:user-1'), contains('Rebar'));
      expect(app.prefs.getString('post_outbox'), isNull);
      expect(app.posts.calls, isEmpty);
      // F5: no sound while it only waits.
      expect(app.chimes, isEmpty);

      // The signal is back: photos first, then the post, once.
      posts.failNext = 0;
      await _container(tester).read(postOutboxProvider.notifier).flushAll();
      await tester.pumpAndSettle();
      expect(app.posts.uploads, hasLength(1));
      expect(app.posts.calls.single, 'create en - 1 Rebar done.');
      // F5: the sound and haptic when the server took it.
      expect(app.chimes, ['haptic', 'sound']);
      expect(find.text(l10n.daybookWaitingToSend), findsNothing);
      expect(app.prefs.getString('post_outbox:user-1'), isNot(contains('R')));
    });

    testWidgets('H6: refused: back to a Draft, "Couldn\'t send" [$lang]', (
      tester,
    ) async {
      final posts = _posts()..refuseNext = 1;
      final app = await _feed(tester, lang, posts: posts);
      await tester.tap(find.byKey(const Key('nav-create')));
      await tester.pumpAndSettle();
      // Create's choice (F1): Post to everyone.
      await tester.tap(find.byKey(const Key('create-post')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('writing-body')),
        'Rebar done.',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('writing-post')));
      await tester.pumpAndSettle();
      // Nothing is lost: the card is back at Now, with the red line.
      expect(find.text(l10n.daybookCouldNotSend), findsOneWidget);
      expect(find.text(l10n.daybookWaitingToSend), findsNothing);
      expect(app.prefs.getString('post_draft:user-1'), contains('Rebar'));
      expect(app.prefs.getString('post_outbox:user-1'), isNot(contains('R')));
      // Tap to fix, then send again.
      await tester.tap(find.byKey(const Key('post-draft')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('writing-post')));
      await tester.pumpAndSettle();
      expect(app.posts.calls.single, 'create en - 0 Rebar done.');
      expect(find.text(l10n.daybookCouldNotSend), findsNothing);
    });

    testWidgets('edit: in place at Now, the text and its language only '
        '[$lang]', (tester) async {
      final app = await _feed(tester, lang);
      await _tap(tester, 'post-menu-p2');
      await _tap(tester, 'post-edit');
      expect(find.byKey(const Key('post-writing-card')), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('writing-body')))
            .controller!
            .text,
        'Morning walk done.',
      );
      // Photos and the tag stay as posted (edit_post).
      expect(
        tester.widget<BvWritingToolbar>(find.byType(BvWritingToolbar)).onCamera,
        isNull,
      );
      await _more(tester, l10n);
      expect(find.text(l10n.postWritingProject), findsNothing);
      await tester.tapAt(const Offset(195, 120));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('writing-body')),
        'Walk done, all clear.',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('writing-post')));
      await tester.pumpAndSettle();
      expect(app.posts.calls.single, 'edit p2 en Walk done, all clear.');
      expect(find.byKey(const Key('post-writing-card')), findsNothing);
      expect(find.text('Walk done, all clear.'), findsOneWidget);
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
      // An answer reads "Replying to" its top-level reply's author, when
      // the server doesn't name the person (before migration 25).
      expect(
        tester.widget<Text>(find.byKey(const Key('reply-to-r2'))).data,
        l10n.postReplyingTo(inOwnDirection('Faisal Al-Rashidi')),
      );
      expect(find.byKey(const Key('reply-to-r1')), findsNothing);
      // Replying to Mariam answers her reply (review 50 F2): the server
      // files it under Faisal's.
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
      expect(app.posts.calls.single, 'reply p1 r2 Thanks.');
      expect(find.byKey(const Key('post-replying')), findsNothing);
      // Filed under Faisal's, "Replying to Mariam Al-Sabah".
      final mine = app.posts.repliesByPost['p1']!.last;
      expect(mine.replyTo, 'r1');
      expect(
        tester.widget<Text>(find.byKey(Key('reply-to-${mine.id}'))).data,
        l10n.postReplyingTo(inOwnDirection('Mariam Al-Sabah')),
      );
    });

    testWidgets('F2: before migration 25 an answer to an answer goes to the '
        'top-level reply [$lang]', (tester) async {
      final posts = _posts()
        ..oneLevelReplies = true
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
      await _tap(tester, 'reply-reply-r2');
      await tester.enterText(
        find.byKey(const Key('post-reply-input')),
        'Thanks.',
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'post-reply-send');
      // Refused for r2, then sent to r1 with the same id: one reply, and
      // no error.
      expect(app.posts.calls, ['reply p1 r2 Thanks.', 'reply p1 r1 Thanks.']);
      expect(app.posts.repliesByPost['p1'], hasLength(3));
      expect(app.posts.repliesByPost['p1']!.last.replyTo, 'r1');
      expect(find.byKey(const Key('post-replying')), findsNothing);
      expect(find.text(l10n.errorGeneric), findsNothing);
    });

    testWidgets('F19: a reply slip: name and time on one line, the text and '
        'its actions under the name, the menu level with the name [$lang]', (
      tester,
    ) async {
      final posts = _posts()
        ..repliesByPost['p1'] = [
          PostReply(
            id: 'r1',
            postId: 'p1',
            authorId: 'p-faisal',
            authorName: 'Faisal Al-Rashidi',
            authorHeadline: 'Site Engineer',
            body: 'Good catch on C7.',
            createdAt: testNow.subtract(const Duration(minutes: 4)),
          ),
          PostReply(
            id: 'r2',
            postId: 'p1',
            authorId: 'p-mariam',
            authorName: 'Mariam Al-Sabah',
            replyTo: 'r1',
            replyToPerson: 'p-faisal',
            body: 'Model updated.',
            createdAt: testNow.subtract(const Duration(minutes: 2)),
          ),
        ];
      await _feed(tester, lang, posts: posts);
      _router(tester).push('/posts/p1');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('reply-r2')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      Rect at(String key) => tester.getRect(find.byKey(Key(key)));
      for (final id in ['r1', 'r2']) {
        final name = at('reply-name-$id');
        final time = at('reply-time-$id');
        final body = at('reply-body-$id');
        final useful = at('reply-useful-$id');
        final menu = at('reply-menu-$id');
        // One line.
        expect(time.center.dy, closeTo(name.center.dy, 1));
        // The text and the actions start under the name.
        if (lang == 'ar') {
          expect(body.right, closeTo(name.right, 1));
          expect(useful.right, closeTo(name.right, 1));
        } else {
          expect(body.left, closeTo(name.left, 1));
          expect(useful.left, closeTo(name.left, 1));
        }
        expect(useful.top, greaterThan(body.bottom));
        // ⋯ level with the name, 48 × 48.
        expect(menu.center.dy, closeTo(name.center.dy, 1));
        expect(menu.size, const Size(48, 48));
      }
      // Under the name, not the headline (replies show who and when).
      expect(find.text('Site Engineer'), findsNothing);
      // Every top-level slip as wide as the others; an answer starts under
      // the name above it.
      final r1 = at('reply-r1');
      final r2 = at('reply-r2');
      expect(r2.width, lessThan(r1.width));
      if (lang == 'ar') {
        expect(r2.right, closeTo(at('reply-name-r1').right, 1));
      } else {
        expect(r2.left, closeTo(at('reply-name-r1').left, 1));
      }
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
      // The card's time (H1 v4), on the Feed and on the post page alike.
      final time = tester
          .widget<Text>(find.byKey(const Key('post-time-p1')))
          .data;
      _router(tester).push('/posts/p1');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(const Key('post-p1')),
                matching: find.byKey(const Key('post-time-p1')),
              ),
            )
            .data,
        time,
      );
      // The project tag and the author's face, as in the Feed.
      expect(find.byKey(const Key('post-project-pr-1')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('post-p1')),
          matching: find.byType(BvAvatar),
        ),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('reply-r1')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      // The reply's time in the app's one format (review 54 A1).
      expect(
        tester.widget<Text>(find.byKey(const Key('reply-time-r1'))).data,
        BvTime(
          l10n,
          lang,
          use24: false,
        ).moment(testNow.subtract(const Duration(minutes: 4)), testNow),
      );
      await _tap(tester, 'reply-useful-r1');
      expect(app.posts.calls.single, 'useful reply r1 true');
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
