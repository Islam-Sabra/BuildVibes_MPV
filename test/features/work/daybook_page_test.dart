// Slice 5 (review 76): a post's page opened in place (N1), edited by its
// author (N2), "/" for a new block (N3) and Turn into (N4).
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/post_page.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/models/work_item.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_popover_menu.dart';
import 'package:buildvibes/shared/widgets/bv_slip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/fakes.dart';
import '../../helpers/page_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

const _post = '00000000-0000-4000-8000-000000000501';
const _text = '00000000-0000-4000-8000-0000000000b1';
const _toggle = '00000000-0000-4000-8000-0000000000b2';
const _inside = '00000000-0000-4000-8000-0000000000b3';
const _list = '00000000-0000-4000-8000-0000000000b4';
const _table = '00000000-0000-4000-8000-0000000000b5';
const _under = '00000000-0000-4000-8000-0000000000b6';
const _sized = '00000000-0000-4000-8000-0000000000c1';
const _photoPoint = '00000000-0000-4000-8000-0000000000c2';
const _core = '00000000-0000-4000-8000-0000000000d1';

DaybookPost _item(DaybookSamples s, {bool page = true}) => DaybookPost(
  id: _post,
  kind: DaybookPost.workItemKind,
  createdAt: DaybookSamples.thursday.subtract(const Duration(hours: 2)),
  title: s.t(
    'Sleeves at grid C7 before the pour',
    'الأكمام عند المحور C7 قبل الصب',
  ),
  body: s.t('Fix them before Thursday’s pour.', 'ثبّتها قبل صب الخميس.'),
  authorId: DaybookSamples.islam,
  authorName: s.islamName,
  item: DaybookItem(
    status: WorkStatus.open,
    ownerId: DaybookSamples.omar,
    ownerName: s.omarName,
    ref: 'KCT-021',
  ),
  pointsTotal: 2,
  hasPage: page,
);

/// N1 as drawn: words, a toggle, two points (one ticked), a table, and a
/// work item under it, checked.
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
    const PageTable(_table, [
      ['Grid', 'Size'],
      ['C7', '100 mm'],
    ]),
    const PageChildItem(_under, _core),
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
  under: [
    PageUnder(
      id: _core,
      title: s.t('Core the slab at C8', 'ثقب البلاطة عند C8'),
      status: WorkStatus.checked,
      ownerId: DaybookSamples.sara,
      ownerName: s.saraName,
    ),
  ],
);

Future<TestApp> _open(
  WidgetTester tester,
  String lang, {
  String me = DaybookSamples.islam,
  SpacePass pass = SpacePass.lead,
  FakePageRepository? pages,
}) async {
  final s = DaybookSamples(lang);
  final page = _page(s);
  final daybook = FakeDaybookRepository()
    ..posts[DaybookSamples.space] = [
      DaybookCard(post: _item(s), lastActivityAt: page.post.createdAt),
    ]
    ..pointsByPost[_post] = page.points;
  final app = await pumpApp(
    tester,
    language: lang,
    auth: FakeAuthRepository(userId: me, phone: '+96550000001'),
    spaces: FakeSpaceRepository()
      ..details[DaybookSamples.space] = s.detail(
        pass: pass,
        admin: me == DaybookSamples.islam,
      )
      ..spacePeople[DaybookSamples.space] = s.people(),
    daybook: daybook,
    postPages: (pages ?? FakePageRepository())..pages[_post] ??= page,
    now: DaybookSamples.thursday,
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/${DaybookSamples.space}');
  await tester.pumpAndSettle();
  return app;
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

Finder _key(String k) => find.byKey(Key(k));

/// The author's way in: the card's menu → Edit page.
Future<void> _edit(WidgetTester tester, AppLocalizations l10n) async {
  final card = find.descendant(
    of: _key('daybook-card-$_post'),
    matching: find.byType(BvSlip),
  );
  await tester.longPress(card.first);
  await tester.pumpAndSettle();
  final menu = tester.widget<BvSlipMenu<Object>>(_key('slip-menu'));
  expect([for (final i in menu.items) i.label], contains(l10n.pageEdit));
  await _tap(
    tester,
    find.descendant(of: _key('slip-menu'), matching: find.text(l10n.pageEdit)),
  );
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  // The page builds what's on screen: scroll to it first.
  if (_key(key).evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      _key(key),
      200,
      scrollable: find
          .descendant(
            of: _key('page-editor'),
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  await tester.ensureVisible(_key(key));
  await tester.pumpAndSettle();
  final f = find.descendant(of: _key(key), matching: find.byType(EditableText));
  await tester.enterText(f.first, text);
  await tester.pumpAndSettle();
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);
    final s = DaybookSamples(lang);

    testWidgets('N1: Open the page shows every block; Omar reads it [$lang]', (
      tester,
    ) async {
      await _open(tester, lang, me: DaybookSamples.omar, pass: SpacePass.crew);
      expect(_key('card-open-page'), findsOneWidget);
      await _tap(tester, _key('card-open-page'));
      expect(_key('daybook-page'), findsOneWidget);
      // Not his: no Edit page.
      expect(_key('page-edit'), findsNothing);
      expect(
        find.text(
          s.t(
            'Check the sizes against the drawing.',
            'طابق المقاسات مع المخطط.',
          ),
        ),
        findsOneWidget,
      );
      // The toggle is closed until tapped.
      expect(find.text(s.t('Fire rating.', 'مقاومة الحريق.')), findsNothing);
      await _tap(tester, _key('page-toggle-$_toggle'));
      expect(find.text(s.t('Fire rating.', 'مقاومة الحريق.')), findsOneWidget);
      expect(_key('checklist-point-$_sized'), findsOneWidget);
      expect(find.text('100 mm'), findsOneWidget);
      // Its own work items, "1 of 1 checked": a fact about this item.
      expect(find.text(l10n.pageUnder), findsOneWidget);
      expect(find.text(l10n.pageUnderChecked(1, 1)), findsOneWidget);
      expect(_key('page-under-$_core'), findsOneWidget);
      await _tap(tester, _key('page-close'));
      expect(_key('daybook-page'), findsNothing);
    });

    testWidgets('N1: a card without a page has no Open the page [$lang]', (
      tester,
    ) async {
      final pages = FakePageRepository()
        ..pages[_post] = PostPage(post: _item(s, page: false));
      final daybook = FakeDaybookRepository()
        ..posts[DaybookSamples.space] = [
          DaybookCard(
            post: _item(s, page: false),
            lastActivityAt: DaybookSamples.thursday,
          ),
        ];
      await pumpApp(
        tester,
        language: lang,
        auth: FakeAuthRepository(
          userId: DaybookSamples.omar,
          phone: '+96550000001',
        ),
        spaces: FakeSpaceRepository()
          ..details[DaybookSamples.space] = s.detail(
            pass: SpacePass.crew,
            admin: false,
          )
          ..spacePeople[DaybookSamples.space] = s.people(),
        daybook: daybook,
        postPages: pages,
        now: DaybookSamples.thursday,
      );
      GoRouter.of(
        tester.element(find.byType(Navigator).first),
      ).push('/spaces/${DaybookSamples.space}');
      await tester.pumpAndSettle();
      expect(_key('card-open-page'), findsNothing);
    });

    testWidgets('N2: the author edits words in place; Done saves the blocks '
        'at the version read [$lang]', (tester) async {
      final app = await _open(tester, lang);
      await _edit(tester, l10n);
      expect(_key('page-editor'), findsOneWidget);
      expect(_key('page-handle-$_text'), findsOneWidget);
      await _type(tester, 'page-field-t:$_text', 'Check every sleeve.');
      await _tap(tester, _key('page-done'));
      expect(app.postPages.calls, [
        'save $_post v4 [text, toggle, checklist_ref, table, child_item]',
      ]);
      expect(
        (app.postPages.pages[_post]!.blocks.first as PageText).text,
        'Check every sleeve.',
      );
      // Back to reading.
      expect(_key('page-editor'), findsNothing);
      expect(_key('page-edit'), findsOneWidget);
    });

    testWidgets('N2: Done with nothing changed sends nothing [$lang]', (
      tester,
    ) async {
      final app = await _open(tester, lang);
      await _edit(tester, l10n);
      await _tap(tester, _key('page-done'));
      expect(app.postPages.calls, isEmpty);
    });

    testWidgets('N3: "/" picks a heading; a new point goes on the post '
        'before the page [$lang]', (tester) async {
      final app = await _open(tester, lang);
      await _edit(tester, l10n);
      await _type(tester, 'page-add-field', '/');
      expect(_key('page-add-menu'), findsOneWidget);
      // Every block the frame lists, on a work item.
      for (final a in [
        'text',
        'heading',
        'checklist',
        'toggle',
        'table',
        'photo',
        'file',
        'item',
      ]) {
        expect(_key('page-add-$a'), findsOneWidget);
      }
      await _tap(tester, _key('page-add-heading'));
      final heading = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('page-field-t:') &&
            (w as TextField).controller!.text.isEmpty &&
            // Not a toggle's line ready to type inside (F90).
            w.decoration?.hintText != l10n.pageTypeInside,
      );
      expect(heading, findsOneWidget);
      await tester.enterText(heading, 'Sizes');
      await tester.pumpAndSettle();

      // Typing after "/" filters the menu, in the app's language.
      await _type(
        tester,
        'page-add-field',
        '/${l10n.pageChecklist.substring(0, 3)}',
      );
      expect(_key('page-add-heading'), findsNothing);
      await _tap(tester, _key('page-add-checklist'));
      final point = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('page-field-pt:') &&
            (w as TextField).controller!.text.isEmpty,
      );
      await tester.enterText(point, 'Fire collars at C7');
      await tester.pumpAndSettle();
      await _tap(tester, _key('page-done'));
      expect(app.postPages.calls, [
        'edit $_post points',
        'save $_post v4 '
            '[text, toggle, checklist_ref, table, child_item, heading, checklist_ref]',
      ]);
      expect(
        app.postPages.pages[_post]!.points.map((p) => p.text),
        contains('Fire collars at C7'),
      );
    });

    testWidgets('N3: an empty heading and an empty point are dropped [$lang]', (
      tester,
    ) async {
      final app = await _open(tester, lang);
      await _edit(tester, l10n);
      await _type(tester, 'page-add-field', '/');
      await _tap(tester, _key('page-add-heading'));
      await _type(tester, 'page-add-field', '/');
      await _tap(tester, _key('page-add-checklist'));
      await _tap(tester, _key('page-done'));
      expect(app.postPages.calls, isEmpty);
    });

    testWidgets('review 79 P2: an empty point left on the page is dropped '
        'at Done, never sent; the words around it are saved [$lang]', (
      tester,
    ) async {
      final app = await _open(tester, lang);
      await _edit(tester, l10n);
      // Next on a point makes a new, empty one under it: left empty.
      await _type(tester, 'page-field-pt:$_sized', 'Sleeves sized');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      final empty = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('page-field-pt:') &&
            (w as TextField).controller!.text.isEmpty,
      );
      expect(empty, findsOneWidget);
      await tester.enterText(empty, '   ');
      await tester.pumpAndSettle();
      await _tap(tester, _key('page-done'));
      expect(app.postPages.calls, ['edit $_post points']);
      final page = app.postPages.pages[_post]!;
      expect(
        [for (final p in page.points) p.text],
        ['Sleeves sized', s.t('Photo of each sleeve', 'صورة لكل كم')],
      );
      expect(page.blocks.whereType<PageChecklist>().single.pointIds, [
        _sized,
        _photoPoint,
      ]);
    });

    testWidgets('N4: text turns into a checklist point [$lang]', (
      tester,
    ) async {
      final app = await _open(tester, lang);
      await _edit(tester, l10n);
      await _tap(tester, _key('page-handle-$_text'));
      expect(_key('page-block-menu'), findsOneWidget);
      await _tap(tester, _key('page-turn-point'));
      await _tap(tester, _key('page-done'));
      expect(app.postPages.calls.first, 'edit $_post points');
      expect(
        app.postPages.calls[1],
        startsWith('save $_post v4 [checklist_ref,'),
      );
    });

    testWidgets('N4: a ticked point stays as it is [$lang]', (tester) async {
      await _open(tester, lang);
      await _edit(tester, l10n);
      await _tap(tester, _key('page-point-menu-$_photoPoint'));
      expect(find.text(l10n.pageTickedStays), findsOneWidget);
      expect(_key('page-point-menu'), findsNothing);
    });

    testWidgets('F92: each point has its own ⋮⋮: Turn into and Delete; a '
        'ticked point stays as it is [$lang]', (tester) async {
      await _open(tester, lang);
      await _edit(tester, l10n);
      expect(_key('page-point-handle-$_sized'), findsOneWidget);
      expect(_key('page-point-handle-$_photoPoint'), findsOneWidget);
      await _tap(tester, _key('page-point-handle-$_sized'));
      expect(_key('page-point-menu'), findsOneWidget);
      expect(_key('page-turn-text'), findsOneWidget);
      expect(_key('page-turn-item'), findsOneWidget);
      expect(_key('page-point-delete'), findsOneWidget);
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      await _tap(tester, _key('page-point-handle-$_photoPoint'));
      expect(_key('page-point-menu'), findsNothing);
      expect(find.text(l10n.pageTickedStays), findsOneWidget);
    });

    testWidgets('F92: Delete takes one point out; Undo puts it back; Done '
        'removes it from the post after the page [$lang]', (tester) async {
      final app = await _open(tester, lang);
      await _edit(tester, l10n);
      await _tap(tester, _key('page-point-handle-$_sized'));
      await _tap(tester, _key('page-point-delete'));
      expect(_key('page-point-$_sized'), findsNothing);
      expect(_key('page-point-$_photoPoint'), findsOneWidget);
      await _tap(tester, _key('page-undo'));
      expect(_key('page-point-$_sized'), findsOneWidget);
      await _tap(tester, _key('page-point-handle-$_sized'));
      await _tap(tester, _key('page-point-delete'));
      await _tap(tester, _key('page-done'));
      expect(app.postPages.calls, [
        'save $_post v4 [text, toggle, checklist_ref, table, child_item]',
        'edit $_post points',
      ]);
      expect(app.postPages.pages[_post]!.points.map((p) => p.id), [
        _photoPoint,
      ]);
    });

    testWidgets('N4: a point turns into a work item under this one, in one '
        'step [$lang]', (tester) async {
      final app = await _open(tester, lang);
      await _edit(tester, l10n);
      await _tap(tester, _key('page-point-menu-$_sized'));
      await _tap(tester, _key('page-turn-item'));
      expect(_key('page-item-sheet'), findsOneWidget);
      await _tap(
        tester,
        find.descendant(
          of: _key('page-item-owner'),
          matching: find.text(s.omarName),
        ),
      );
      // One call, with the sheet's words as the title (review 79 C1).
      expect(app.postPages.calls.single, startsWith('turn $_sized into '));
      expect(
        app.postPages.calls.single,
        endsWith(
          'for ${DaybookSamples.omar}: '
          '${s.t('Sleeves sized as the drawing', 'الأكمام بمقاس المخطط')}',
        ),
      );
      // The editor shows the page as the server has it now.
      expect(_key('page-point-$_sized'), findsNothing);
      expect(
        find.text(s.t('Sleeves sized as the drawing', 'الأكمام بمقاس المخطط')),
        findsOneWidget,
      );
    });

    testWidgets("review 79 C1: the sheet's own words are the title, in one "
        'call; the point is never edited on the way [$lang]', (tester) async {
      final app = await _open(tester, lang);
      await _edit(tester, l10n);
      await _tap(tester, _key('page-point-menu-$_sized'));
      await _tap(tester, _key('page-turn-item'));
      await tester.enterText(_key('page-item-title'), 'Size the sleeves at C7');
      await tester.pumpAndSettle();
      await _tap(
        tester,
        find.descendant(
          of: _key('page-item-owner'),
          matching: find.text(s.omarName),
        ),
      );
      expect(app.postPages.calls, hasLength(1));
      expect(
        app.postPages.calls.single,
        endsWith('for ${DaybookSamples.omar}: Size the sleeves at C7'),
      );
      expect(
        app.postPages.pages[_post]!.under.map((u) => u.title),
        contains('Size the sleeves at C7'),
      );
    });

    testWidgets('review 79 C1: a retry after a lost answer is the same work '
        'item, not a second one [$lang]', (tester) async {
      final app = await _open(tester, lang);
      app.postPages.loseTurnAnswerOnce = true;
      await _edit(tester, l10n);
      Future<void> turn() async {
        await _tap(tester, _key('page-point-menu-$_sized'));
        await _tap(tester, _key('page-turn-item'));
        await _tap(
          tester,
          find.descendant(
            of: _key('page-item-owner'),
            matching: find.text(s.omarName),
          ),
        );
      }

      await turn();
      // The answer was lost: the point is still on the editor.
      expect(_key('page-point-$_sized'), findsOneWidget);
      final first = app.postPages.calls.single;
      final id = RegExp(r'into (\S+) for').firstMatch(first)!.group(1)!;
      await turn();
      expect(app.postPages.calls, [first, 'turn again $id']);
      expect(
        app.postPages.pages[_post]!.under.where((u) => u.id == id),
        hasLength(1),
      );
      expect(_key('page-point-$_sized'), findsNothing);
    });

    testWidgets('N2: a block is deleted, and Undo puts it back [$lang]', (
      tester,
    ) async {
      final app = await _open(tester, lang);
      await _edit(tester, l10n);
      await _tap(tester, _key('page-handle-$_table'));
      await _tap(tester, _key('page-block-delete'));
      expect(find.text('100 mm'), findsNothing);
      await _tap(tester, _key('page-undo'));
      expect(find.text('100 mm'), findsOneWidget);
      await _tap(tester, _key('page-done'));
      expect(app.postPages.calls, isEmpty);
    });

    testWidgets('N2: a table gets a row and a column [$lang]', (tester) async {
      final app = await _open(tester, lang);
      await _edit(tester, l10n);
      await _tap(tester, _key('page-add-row-$_table'));
      await _tap(tester, _key('page-add-column-$_table'));
      await _tap(tester, _key('page-done'));
      final t = app.postPages.pages[_post]!.blocks
          .whereType<PageTable>()
          .single;
      expect(t.rows.length, 3);
      expect(t.columns, 3);
    });

    testWidgets('F90: three lines inside a toggle with Enter; Enter on the '
        'empty last line leaves it; no + Add text [$lang]', (tester) async {
      final app = await _open(tester, lang);
      await _edit(tester, l10n);
      await _type(tester, 'page-add-field', '/');
      await _tap(tester, _key('page-add-toggle'));
      expect(
        find.byWidgetPredicate((w) => '${w.key}'.contains('page-toggle-add')),
        findsNothing,
      );
      Finder ready() => find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.hintText == l10n.pageTypeInside &&
            w.controller!.text.isEmpty,
      );
      // The toggle's own line, then its lines inside.
      final title = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.hintText == l10n.pageToggle &&
            w.controller!.text.isEmpty,
      );
      await tester.enterText(title.last, 'Why');
      await tester.pumpAndSettle();
      for (final line in ['One', 'Two', 'Three']) {
        await tester.ensureVisible(ready().last);
        await tester.enterText(ready().last, line);
        await tester.testTextInput.receiveAction(TextInputAction.next);
        await tester.pumpAndSettle();
      }
      // Enter on the empty last line: out, with a line after the toggle.
      await tester.ensureVisible(ready().last);
      await tester.showKeyboard(ready().last);
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      await _tap(tester, _key('page-done'));
      final toggle = app.postPages.pages[_post]!.blocks
          .whereType<PageToggle>()
          .where((t) => t.id != _toggle)
          .single;
      expect(toggle.text, 'Why');
      expect(
        [for (final c in toggle.children) (c as PageText).text],
        ['One', 'Two', 'Three'],
      );
    });

    testWidgets('F89: a new table starts 2 × 2; + column adds one up to 8, '
        'then goes [$lang]', (tester) async {
      final app = await _open(tester, lang);
      await _edit(tester, l10n);
      await _type(tester, 'page-add-field', '/');
      await _tap(tester, _key('page-add-table'));
      final add = find.byWidgetPredicate(
        (w) =>
            '${w.key}'.contains('page-add-column-') &&
            !'${w.key}'.contains(_table),
      );
      for (var n = 3; n <= 8; n++) {
        await _tap(tester, add);
      }
      expect(add, findsNothing);
      await _tap(tester, _key('page-done'));
      final made = app.postPages.pages[_post]!.blocks
          .whereType<PageTable>()
          .where((t) => t.id != _table)
          .single;
      expect(made.rows.length, 2);
      expect(made.columns, 8);
    });

    testWidgets('N2: saved first on another phone: Use mine saves over it '
        '[$lang]', (tester) async {
      final pages = FakePageRepository()..staleOnce = true;
      final app = await _open(tester, lang, pages: pages);
      await _edit(tester, l10n);
      await _type(tester, 'page-field-t:$_text', 'Check every sleeve.');
      await _tap(tester, _key('page-done'));
      expect(find.text(l10n.pageStale), findsOneWidget);
      await _tap(tester, _key('bv-dialog-confirm'));
      expect(app.postPages.calls, [
        'save $_post v5 [text, toggle, checklist_ref, table, child_item]',
      ]);
    });

    testWidgets('N2: a "page changed" dialog dismissed keeps the edit '
        'open, nothing thrown away [$lang]', (tester) async {
      final pages = FakePageRepository()..staleOnce = true;
      final app = await _open(tester, lang, pages: pages);
      await _edit(tester, l10n);
      await _type(tester, 'page-field-t:$_text', 'Check every sleeve.');
      await _tap(tester, _key('page-done'));
      expect(find.text(l10n.pageStale), findsOneWidget);
      // A tap outside: neither choice.
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.text(l10n.pageStale), findsNothing);
      expect(_key('page-editor'), findsOneWidget);
      expect(app.postPages.calls, isEmpty);
      await _tap(tester, _key('page-done'));
      await _tap(tester, _key('bv-dialog-confirm'));
      expect(app.postPages.calls, [
        'save $_post v5 [text, toggle, checklist_ref, table, child_item]',
      ]);
    });

    testWidgets('N2: the signal went after the points were saved: Done '
        'again sends them only once [$lang]', (tester) async {
      final pages = FakePageRepository()..failSaveOnce = true;
      final app = await _open(tester, lang, pages: pages);
      await _edit(tester, l10n);
      await _type(tester, 'page-field-t:$_text', 'Check every sleeve.');
      await _type(tester, 'page-field-pt:$_sized', 'Sized and sealed');
      await _tap(tester, _key('page-done'));
      expect(_key('page-editor'), findsOneWidget);
      await _tap(tester, _key('page-done'));
      expect(app.postPages.calls, [
        'edit $_post points',
        'save $_post v4 [text, toggle, checklist_ref, table, child_item]',
      ]);
      expect(_key('page-editor'), findsNothing);
    });

    testWidgets('N3: "/" typed before words already on a line is just a '
        'character [$lang]', (tester) async {
      await _open(tester, lang);
      await _edit(tester, l10n);
      final before = s.t(
        'Check the sizes against the drawing.',
        'طابق المقاسات مع المخطط.',
      );
      await _type(tester, 'page-field-t:$_text', '/$before');
      expect(_key('page-add-menu'), findsNothing);
      expect(
        find.descendant(
          of: _key('page-field-t:$_text'),
          matching: find.text('/$before'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('review 98: "/" after a space opens the card next to the '
        'line; the words stay and the kind goes after them [$lang]', (
      tester,
    ) async {
      final app = await _open(tester, lang);
      await _edit(tester, l10n);
      final field = _key('page-field-t:$_text');
      final c = tester.widget<TextField>(field).controller!;
      final words = c.text;
      final sheets = find.byType(BottomSheet).evaluate().length;
      // One character at a time, as typed.
      await _type(tester, 'page-field-t:$_text', '$words ');
      await _type(tester, 'page-field-t:$_text', '$words /');
      expect(_key('page-add-menu'), findsOneWidget);
      // A card, not another sheet over the page.
      expect(find.byType(BottomSheet).evaluate(), hasLength(sheets));
      await _type(tester, 'page-field-t:$_text', '$words /h');
      expect(_key('page-add-heading'), findsOneWidget);
      expect(_key('page-add-table'), findsNothing);
      await _tap(tester, _key('page-add-heading'));
      expect(_key('page-add-menu'), findsNothing);
      expect(c.text, '$words ');
      // The new heading has the keyboard (an empty one is dropped at Done).
      tester.testTextInput.enterText(s.t('Cover', 'الغطاء'));
      await tester.pumpAndSettle();
      await _tap(tester, _key('page-done'));
      expect(
        app.postPages.calls.last,
        startsWith('save $_post v4 [text, heading, toggle,'),
      );
    });

    testWidgets('review 98: no drag on a phone; ⋮⋮ moves a block down and '
        'up [$lang]', (tester) async {
      final app = await _open(tester, lang);
      await _edit(tester, l10n);
      expect(
        find.ancestor(
          of: _key('page-handle-$_text'),
          matching: find.byType(ReorderableDelayedDragStartListener),
        ),
        findsNothing,
      );
      await _tap(tester, _key('page-handle-$_text'));
      // The first block: no Move up.
      expect(_key('page-move-up'), findsNothing);
      await _tap(tester, _key('page-move-down'));
      await _tap(tester, _key('page-handle-$_text'));
      expect(_key('page-move-up'), findsOneWidget);
      await _tap(tester, _key('page-move-up'));
      await _tap(tester, _key('page-handle-$_text'));
      await _tap(tester, _key('page-move-down'));
      await _tap(tester, _key('page-done'));
      expect(
        app.postPages.calls.last,
        startsWith('save $_post v4 [toggle, text, checklist_ref,'),
      );
    });

    testWidgets('N2: no signal: the edit stays open to send again [$lang]', (
      tester,
    ) async {
      final pages = FakePageRepository();
      final app = await _open(tester, lang, pages: pages);
      await _edit(tester, l10n);
      await _type(tester, 'page-field-t:$_text', 'Check every sleeve.');
      pages.offline = true;
      await _tap(tester, _key('page-done'));
      expect(_key('page-editor'), findsOneWidget);
      pages.offline = false;
      await _tap(tester, _key('page-done'));
      expect(app.postPages.calls, hasLength(1));
      expect(_key('page-editor'), findsNothing);
    });

    testWidgets('slice 10: no signal: Done says the changes stay here; the '
        'next Done sends them [$lang]', (tester) async {
      final pages = FakePageRepository();
      final app = await _open(tester, lang, pages: pages);
      await _edit(tester, l10n);
      await _type(tester, 'page-field-t:$_text', 'Check every sleeve.');
      pages.offline = true;
      await _tap(tester, _key('page-done'));
      expect(find.text(l10n.pageNoSignal), findsOneWidget);
      expect(_key('page-editor'), findsOneWidget);
      pages.offline = false;
      await tester.pump(const Duration(seconds: 5));
      await _tap(tester, _key('page-done'));
      expect(app.postPages.calls, hasLength(1));
    });

    testWidgets('slice 10: leaving with changes asks first; Keep editing '
        'keeps them, Leave closes [$lang]', (tester) async {
      final app = await _open(tester, lang);
      await _edit(tester, l10n);
      await _type(tester, 'page-field-t:$_text', 'Check every sleeve.');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text(l10n.pageLeaveTitle), findsOneWidget);
      await _tap(tester, find.text(l10n.pageLeaveStay));
      expect(_key('page-editor'), findsOneWidget);
      expect(find.text('Check every sleeve.'), findsOneWidget);
      // Dragged down, the sheet stays while editing.
      await tester.drag(
        find.text(l10n.pageDone),
        const Offset(0, 500),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(_key('page-editor'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await _tap(tester, find.text(l10n.pageLeaveGo));
      expect(_key('daybook-page'), findsNothing);
      expect(app.postPages.calls, isEmpty);
    });

    testWidgets('slice 10: with nothing changed, leaving asks nothing '
        '[$lang]', (tester) async {
      await _open(tester, lang);
      await _edit(tester, l10n);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text(l10n.pageLeaveTitle), findsNothing);
      expect(_key('daybook-page'), findsNothing);
    });

    testWidgets('a Viewer opens the page and reads it [$lang]', (tester) async {
      await _open(
        tester,
        lang,
        me: DaybookSamples.mona,
        pass: SpacePass.viewer,
      );
      await _tap(tester, _key('card-open-page'));
      expect(_key('daybook-page'), findsOneWidget);
      expect(_key('page-edit'), findsNothing);
    });
  }
}
