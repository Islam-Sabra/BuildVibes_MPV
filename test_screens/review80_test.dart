// Review 80, the fix batch from the build 473 test: every screen it
// touched, English and Arabic, in the app's fonts, for the lead to check
// against review 50's text (most items have no Figma frame of their own).
// Run:
//   flutter test test_screens/review80_test.dart --update-goldens
import 'dart:async';

import 'package:buildvibes/data/models/chat.dart';
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/dm.dart';
import 'package:buildvibes/data/models/library.dart';
import 'package:buildvibes/data/models/post_page.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/models/space_search.dart';
import 'package:buildvibes/data/models/work_item.dart';
import 'package:buildvibes/features/messages/dm_live.dart';
import 'package:buildvibes/features/spaces/space_screen.dart' show SpaceOpen;
import 'package:buildvibes/features/work/daybook_writing.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_slip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../test/helpers/daybook_fakes.dart';
import '../test/helpers/daybook_samples.dart';
import '../test/helpers/dm_fakes.dart';
import '../test/helpers/fakes.dart';
import '../test/helpers/library_fakes.dart';
import '../test/helpers/page_fakes.dart';
import '../test/helpers/people_search_fakes.dart';
import '../test/helpers/pump_app.dart';
import '../test/helpers/push_fakes.dart';
import '../test/helpers/search_fakes.dart';
import '../test/helpers/space_fakes.dart';
import 'shot.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Navigator).first));

/// Saves the app as it is now, at 390 × 844 and twice the pixels, to
/// `docs/screens/review80/<name>_<lang>.png`.
Future<void> _snap(WidgetTester tester, String name, String lang) async {
  tester.view.physicalSize = shotSize * shotPixelRatio;
  tester.view.devicePixelRatio = shotPixelRatio;
  debugDisableShadows = false;
  // A text field's copy-and-paste menu isn't part of the shot.
  ContextMenuController.removeAny();
  try {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byType(MaterialApp).first,
      matchesGoldenFile('../docs/screens/review80/${name}_$lang.png'),
    );
  } finally {
    debugDisableShadows = true;
  }
}

/// The sample Space, as Islam (its admin) unless [me] says otherwise.
Future<TestApp> _space(
  WidgetTester tester,
  String lang, {
  String me = DaybookSamples.islam,
  List<DaybookCard> posts = const [],
  DaybookExtras extras = const DaybookExtras(),
  List<LibraryFile> files = const [],
  FakePageRepository? pages,
  FakeSearchRepository? search,
  Map<String, Object> stored = const {},
  DateTime? now,
  Object? open,
  String? postId,
}) async {
  final s = DaybookSamples(lang);
  final daybook = FakeDaybookRepository()
    ..posts[DaybookSamples.space] = posts
    ..extrasBySpace[DaybookSamples.space] = extras;
  final app = await pumpApp(
    tester,
    language: lang,
    auth: FakeAuthRepository(userId: me, phone: '+96550000001'),
    spaces: FakeSpaceRepository()
      ..details[DaybookSamples.space] = s.detail(
        admin: me == DaybookSamples.islam,
      )
      ..spacePeople[DaybookSamples.space] = s.people(),
    daybook: daybook,
    library: FakeLibraryRepository(now: DaybookSamples.thursday)
      ..filesBySpace[DaybookSamples.space] = files,
    postPages: pages,
    search: search,
    stored: stored,
    now: now ?? DaybookSamples.thursday,
    overrides: [
      pickPinProvider.overrideWithValue(
        (context, {required now, until}) async =>
            (until: DateTime(2026, 10, 17)),
      ),
      pickPinTimeProvider.overrideWithValue(
        (context, {required initial}) async =>
            const TimeOfDay(hour: 14, minute: 0),
      ),
      // A new post's torn edge follows its id: the same on every run.
      if (postId != null) newPostIdProvider.overrideWithValue(() => postId),
    ],
  );
  _router(tester).push('/spaces/${DaybookSamples.space}', extra: open);
  await tester.pumpAndSettle();
  return app;
}

/// Opens a card, picks [kind] from the kind chip's menu and types [title].
Future<void> _write(
  WidgetTester tester,
  String lang,
  String kindName,
  String title,
) async {
  await _tap(tester, _key('post-bar-notepad'));
  await _tap(tester, _key('writing-kind-chip'));
  await _tap(
    tester,
    find.descendant(
      of: _key('writing-kind-menu'),
      matching: find.text(kindName),
    ),
  );
  if (title.isNotEmpty) {
    await tester.enterText(_key('writing-title'), title);
    await tester.pumpAndSettle();
  }
}

final _a501 = LibraryFile(
  id: 'lib-a501-2',
  spaceId: DaybookSamples.space,
  name: 'A-501.pdf',
  path: '${DaybookSamples.space}/library/lib-a501-2/A-501.pdf',
  mime: 'application/pdf',
  createdAt: DateTime(2026, 10, 12),
  bytes: 2400000,
  versionNo: 2,
);

final _m201 = LibraryFile(
  id: 'lib-m201-c',
  spaceId: DaybookSamples.space,
  name: 'M-201.pdf',
  path: '${DaybookSamples.space}/library/lib-m201-c/M-201.pdf',
  mime: 'application/pdf',
  createdAt: DateTime(2026, 10, 10),
  bytes: 4800000,
  versionNo: 3,
  revLabel: 'Rev C',
);

const _post = '00000000-0000-4000-8000-000000000801';
const _text = '00000000-0000-4000-8000-0000000008b1';
const _toggle = '00000000-0000-4000-8000-0000000008b2';
const _inside = '00000000-0000-4000-8000-0000000008b3';
const _list = '00000000-0000-4000-8000-0000000008b4';
const _table = '00000000-0000-4000-8000-0000000008b5';
const _sized = '00000000-0000-4000-8000-0000000008c1';
const _photoPoint = '00000000-0000-4000-8000-0000000008c2';

DaybookPost _item(DaybookSamples s) => DaybookPost(
  id: _post,
  kind: DaybookPost.workItemKind,
  createdAt: DaybookSamples.thursday.subtract(const Duration(hours: 2)),
  title: s.t(
    'Sleeves at grid C7 before the pour',
    'الأكمام عند المحور C7 قبل الصب',
  ),
  authorId: DaybookSamples.islam,
  authorName: s.islamName,
  item: DaybookItem(
    status: WorkStatus.open,
    ownerId: DaybookSamples.omar,
    ownerName: s.omarName,
    ref: 'KCT-021',
  ),
  pointsTotal: 2,
  hasPage: true,
);

PostPage _page(DaybookSamples s) => PostPage(
  post: _item(s),
  version: 4,
  blocks: [
    PageText(
      _text,
      s.t('Check the sizes against the drawing.', 'طابق المقاسات مع المخطط.'),
    ),
    PageToggle(_toggle, s.t('Why the sizes matter', 'لماذا تهم المقاسات'), [
      PageText(_inside, s.t('Fire rating.', 'مقاومة الحريق.')),
    ]),
    const PageChecklist(_list, [_sized, _photoPoint]),
    PageTable(_table, [
      [s.t('Grid', 'المحور'), s.t('Size', 'المقاس'), s.t('Done', 'منجز')],
      ['C7', '100 mm', s.t('Yes', 'نعم')],
    ]),
  ],
  points: [
    DaybookPoint(
      id: _sized,
      text: s.t('Sleeves sized as the drawing', 'الأكمام بمقاس المخطط'),
    ),
    DaybookPoint(
      id: _photoPoint,
      text: s.t('Photo of each sleeve', 'صورة لكل كم'),
      tickedAt: DaybookSamples.thursday,
      tickedById: DaybookSamples.omar,
    ),
  ],
);

void main() {
  setUpAll(loadAppFonts);

  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);
    final s = DaybookSamples(lang);

    testWidgets('F81 a direct message banner with the app open [$lang]', (
      tester,
    ) async {
      final push = FakePushMessaging();
      final dm = FakeDmRepository()
        ..inboxValue = DmInbox(
          threads: [
            DmRow(
              threadId: 't-omar',
              person: DmPerson(id: 'p-omar', name: s.omarName),
              lastMessageAt: DaybookSamples.thursday,
              unread: true,
              last: DmPreview(
                fromMe: false,
                kind: ChatKind.text,
                at: DaybookSamples.thursday,
                text: s.t('Gate 2 is blocked', 'البوابة 2 مغلقة'),
              ),
            ),
          ],
        );
      await pumpApp(
        tester,
        language: lang,
        dm: dm,
        push: push,
        now: DaybookSamples.thursday,
      );
      push.arrive({
        'kind': 'dm_message',
        'route': '/messages/t-omar',
        'dm_thread_id': 't-omar',
        pushTitleKey: s.t('Message from Omar Haddad', 'رسالة من ${s.omarName}'),
        pushBodyKey: s.t('Gate 2 is blocked', 'البوابة 2 مغلقة'),
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await _snap(tester, 'F81-dm-banner', lang);
      // The banner goes by itself.
      await tester.pumpAndSettle(const Duration(seconds: 10));
    });

    testWidgets('F78 New message from Messages [$lang]', (tester) async {
      await pumpApp(
        tester,
        language: lang,
        peopleSearch: FakePeopleSearchRepository(
          people: [
            SpacePerson(
              id: 'p-omar',
              firstName: s.t('Omar', 'عمر'),
              lastName: s.t('Haddad', 'حداد'),
              headline: s.t('Site Engineer', 'مهندس موقع'),
              companyLabel: 'Al Hamra Contracting',
            ),
            SpacePerson(
              id: 'p-sara',
              firstName: s.t('Sara', 'سارة'),
              lastName: s.t('Al-Mutairi', 'المطيري'),
              headline: s.t('Foreman', 'مراقب عمال'),
            ),
          ],
          shared: const {'p-omar', 'p-sara'},
        ),
      );
      await _tap(tester, _key('home-messages'));
      await _tap(tester, _key('messages-new'));
      await _snap(tester, 'F78-new-message', lang);
    });

    testWidgets('F79 a person on the People tab, as the admin [$lang]', (
      tester,
    ) async {
      await _space(tester, lang, open: SpaceOpen.people);
      await _tap(tester, _key('member-${DaybookSamples.omar}'));
      await _snap(tester, 'F79-person-sheet', lang);
    });

    testWidgets('F89 F90 F92 the page editor: table lines, a toggle, a '
        "point's own handle [$lang]", (tester) async {
      await _space(
        tester,
        lang,
        posts: [
          DaybookCard(post: _item(s), lastActivityAt: _item(s).createdAt),
        ],
        pages: FakePageRepository()..pages[_post] = _page(s),
      );
      final card = find.descendant(
        of: _key('daybook-card-$_post'),
        matching: find.byType(BvSlip),
      );
      await tester.longPress(card.first);
      await tester.pumpAndSettle();
      await _tap(
        tester,
        find.descendant(
          of: _key('slip-menu'),
          matching: find.text(l10n.pageEdit),
        ),
      );
      await _snap(tester, 'F89-F90-page-editor', lang);
      await _tap(tester, _key('page-point-handle-$_sized'));
      await _snap(tester, 'F92-point-menu', lang);
    });

    testWidgets('F72 the paper clip, the one way to add [$lang]', (
      tester,
    ) async {
      await _space(tester, lang, files: [_m201, _a501]);
      await _write(tester, lang, l10n.daybookKindNote, s.handoverTitle);
      await _tap(tester, find.bySemanticsLabel(l10n.daybookAttachTitle));
      await _snap(tester, 'F72-attach', lang);
    });

    testWidgets('F71 a file from the phone: new file or a new version '
        '[$lang]', (tester) async {
      await _space(tester, lang, files: [_m201, _a501]);
      await _write(tester, lang, l10n.daybookKindNote, s.handoverTitle);
      await _tap(tester, find.bySemanticsLabel(l10n.daybookAttachTitle));
      await _tap(tester, _key('attach-file'));
      await _snap(tester, 'F71-replaces-choice', lang);
      await _tap(tester, _key('replaces-version'));
      await _snap(tester, 'F71-version-picker', lang);
      await _tap(tester, _key('version-${_m201.id}'));
      await _snap(tester, 'F71-replaces-picked', lang);
      await _tap(tester, _key('replaces-done'));
      await _snap(tester, 'F71-writing-replaces', lang);
    });

    testWidgets('F73 a large file sending [$lang]', (tester) async {
      final app = await _space(
        tester,
        lang,
        files: [_m201],
        postId: 'post-review80-sending',
      );
      app.library.holdUpload = Completer<void>();
      await _write(tester, lang, l10n.daybookKindDocument, 'M-201 Rev D');
      await _tap(tester, _key('file-from-phone'));
      await _tap(tester, _key('replaces-none'));
      await _tap(tester, _key('replaces-done'));
      await _tap(tester, _key('writing-post'));
      await _snap(tester, 'F73-sending', lang);
    });

    testWidgets('F75 F76 F74 a new version and the one it replaced [$lang]', (
      tester,
    ) async {
      const v1 = '00000000-0000-4000-8000-0000000008a1';
      const v2 = '00000000-0000-4000-8000-0000000008a2';
      DaybookPost post(String id, DaybookFile file, Duration ago) =>
          DaybookPost(
            id: id,
            kind: DaybookPost.fileKind,
            createdAt: DaybookSamples.thursday.subtract(ago),
            title: 'A-501',
            authorId: DaybookSamples.sara,
            authorName: s.saraName,
            file: file,
            newVersion: id == v2,
          );
      final old = post(
        v1,
        DaybookFile(
          id: 'f1',
          name: 'A-501.pdf',
          mime: 'application/pdf',
          bytes: 2400000,
          versionNo: 1,
          hasNewer: true,
          newerVersionNo: 2,
          newerAt: DaybookSamples.thursday.subtract(const Duration(hours: 1)),
          newerPostId: v2,
        ),
        const Duration(hours: 3),
      );
      final now = post(
        v2,
        const DaybookFile(
          id: 'f2',
          name: 'A-501.pdf',
          mime: 'application/pdf',
          bytes: 2500000,
          versionNo: 2,
          replacesVersionNo: 1,
        ),
        const Duration(hours: 1),
      );
      await _space(
        tester,
        lang,
        posts: [
          DaybookCard(post: now, lastActivityAt: now.createdAt),
          DaybookCard(post: old, lastActivityAt: old.createdAt),
        ],
      );
      await _snap(tester, 'F75-F76-versions', lang);
    });

    testWidgets('F70 an empty Library [$lang]', (tester) async {
      await _space(tester, lang);
      await _tap(tester, _key('space-tab-library'));
      await _snap(tester, 'F70-library-empty', lang);
    });

    testWidgets('F82 F85 a pinned announcement until a time [$lang]', (
      tester,
    ) async {
      final pinned = DaybookPost(
        id: DaybookSamples.halfDayId,
        kind: DaybookPost.announcementKind,
        createdAt: DateTime(2026, 10, 15, 8),
        title: s.t('Gate 2 closed for the crane.', 'البوابة 2 مغلقة للرافعة.'),
        authorId: DaybookSamples.sara,
        authorName: s.saraName,
        pinnedUntil: DateTime(2026, 10, 15, 14),
        quote: DaybookQuote(
          text: s.t('Crane lift at gate 2 till 2 pm', 'رفع بالرافعة حتى 2'),
          authorName: s.omarName,
          at: DateTime(2026, 10, 15, 7, 40),
        ),
      );
      final later = DaybookPost(
        id: '00000000-0000-4000-8000-0000000008e1',
        kind: DaybookPost.announcementKind,
        createdAt: DateTime(2026, 10, 15, 9),
        title: s.t('Friday is a half day.', 'الجمعة نصف يوم.'),
        authorId: DaybookSamples.islam,
        authorName: s.islamName,
        pinnedUntil: DateTime(2026, 10, 17),
      );
      await _space(
        tester,
        lang,
        posts: [
          s.rebar(),
          DaybookCard(post: pinned, lastActivityAt: pinned.createdAt),
          DaybookCard(post: later, lastActivityAt: later.createdAt),
        ],
        extras: DaybookExtras(pinned: [pinned, later]),
      );
      await _snap(tester, 'F82-F85-pinned', lang);
    });

    testWidgets('F82 the writing card: pinned until a time [$lang]', (
      tester,
    ) async {
      await _space(tester, lang);
      await _write(tester, lang, l10n.daybookKindAnnouncement, s.halfDay);
      await _tap(tester, find.bySemanticsLabel(l10n.daybookMore));
      await _tap(tester, find.text(l10n.daybookPinUntil));
      await _snap(tester, 'F82-pin-add-time', lang);
      await _tap(tester, find.text(l10n.daybookPinAddTime));
      await _snap(tester, 'F82-pin-with-time', lang);
    });

    testWidgets('F95 a new walk starts at the last place [$lang]', (
      tester,
    ) async {
      await _space(
        tester,
        lang,
        stored: {
          'walk_last_place:${DaybookSamples.islam}:${DaybookSamples.space}': s
              .t('Level 2', 'الدور 2'),
        },
      );
      await _tap(tester, _key('space-more'));
      await _tap(tester, find.text(l10n.walkMenu));
      await _snap(tester, 'F95-walk-place', lang);
    });

    testWidgets('Search says You for my own message [$lang]', (tester) async {
      final search = FakeSearchRepository()
        ..matchAll = true
        ..hits.addAll([
          SpaceSearchHit(
            kind: SpaceSearchKind.post,
            id: 'post-c7',
            postId: 'post-c7',
            postKind: 'work_item',
            ref: 'KCT-021',
            title: s.t(
              'Sleeves at grid C7 before the pour',
              'الأكمام عند المحور C7 قبل الصب',
            ),
            authorName: s.omarName,
            createdAt: DaybookSamples.thursday,
          ),
          SpaceSearchHit(
            kind: SpaceSearchKind.message,
            id: 'msg-1',
            threadId: 'thread-1',
            snippet: s.t(
              'Sleeves arrive tomorrow morning',
              'الأكمام تصل صباح الغد',
            ),
            authorName: s.islamName,
            mine: true,
            createdAt: DaybookSamples.thursday,
          ),
        ]);
      await _space(tester, lang, search: search);
      await _tap(tester, _key('space-more'));
      await _tap(tester, find.text(l10n.searchMenu));
      await tester.enterText(
        find.descendant(
          of: _key('search-field'),
          matching: find.byType(TextField),
        ),
        s.t('sleeves', 'الأكمام'),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await _snap(tester, 'search-you', lang);
    });
  }
}
