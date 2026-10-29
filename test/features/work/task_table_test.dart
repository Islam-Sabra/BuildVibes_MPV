// Review 105C-B (Part 4, SP3, SP4): + inside a work item, and the table
// of tasks. One owner ticks the rows (or a Lead); a tick is not a
// signature, and Sign as done stays once for the whole item.
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/post_page.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/models/work_item.dart';
import 'package:buildvibes/features/work/daybook_page.dart'
    show mayTickTasks;
import 'package:buildvibes/features/work/daybook_page_editor.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
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

const _post = '00000000-0000-4000-8000-000000000601';
const _table = '00000000-0000-4000-8000-0000000006b1';
const _tile = '00000000-0000-4000-8000-0000000006c1';
const _grout = '00000000-0000-4000-8000-0000000006c2';
const _skirting = '00000000-0000-4000-8000-0000000006c3';

/// SP3: "Snags, level 1 lobby", Islam's, for Omar (Crew in MEP).
DaybookPost _item(DaybookSamples s) => DaybookPost(
  id: _post,
  kind: DaybookPost.workItemKind,
  createdAt: DaybookSamples.thursday.subtract(const Duration(hours: 2)),
  title: s.t('Snags, level 1 lobby', 'ملاحظات التشطيب، ردهة الطابق 1'),
  authorId: DaybookSamples.islam,
  authorName: s.islamName,
  item: DaybookItem(
    status: WorkStatus.open,
    ownerId: DaybookSamples.omar,
    ownerName: s.omarName,
    ref: 'KCT-021',
  ),
  hasPage: true,
);

PageTaskTable _tasks(DaybookSamples s) => PageTaskTable(_table, [
  TaskRow(
    _tile,
    s.t('Cracked tile at the stair', 'بلاطة مكسورة عند الدرج'),
    note: s.t('2 tiles', 'بلاطتان'),
    ticked: true,
  ),
  TaskRow(
    _grout,
    s.t('Grout gap at the lift door', 'فراغ الترويب عند باب المصعد'),
    note: s.t('Grey grout', 'ترويب رمادي'),
  ),
  TaskRow(_skirting, s.t('Skirting loose, grid A3', 'وزرة مفكوكة، محور A3')),
]);

PostPage _page(DaybookSamples s) =>
    PostPage(post: _item(s), version: 2, blocks: [_tasks(s)]);

Future<TestApp> _open(
  WidgetTester tester,
  String lang, {
  String me = DaybookSamples.omar,
  SpacePass pass = SpacePass.crew,
  FakePageRepository? pages,
  PostPage? page,
}) async {
  final s = DaybookSamples(lang);
  final p = page ?? _page(s);
  final daybook = FakeDaybookRepository()
    ..posts[DaybookSamples.space] = [
      DaybookCard(
        post: p.post,
        lastActivityAt: p.post.createdAt,
        need: me == DaybookSamples.omar ? DaybookNeed.toSign : null,
      ),
    ];
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
    postPages: (pages ?? FakePageRepository())..pages[_post] ??= p,
    now: DaybookSamples.thursday,
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/${DaybookSamples.space}');
  await tester.pumpAndSettle();
  return app;
}

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

/// The opened item: a tap on its card's title (its middle is the table
/// now). Brought into sight first: in Arabic the card is taller than Work
/// in the test's font, and its title is under the Needs you line.
Future<void> _openItem(WidgetTester tester) async {
  final title = find.descendant(
    of: _key('daybook-card-$_post'),
    matching: find.byType(BvSlipTitle),
  );
  await tester.ensureVisible(title.first);
  await tester.pumpAndSettle();
  await tester.tap(title.first);
  await tester.pumpAndSettle();
}

/// Inside the opened item.
Finder _inPage(Finder f) => find.descendant(of: _key('daybook-page'), matching: f);

void main() {
  group('the table of tasks block', () {
    test('reads and writes the server\'s shape', () {
      const t = PageTaskTable(_table, [
        TaskRow(_tile, 'Tile', note: '2 tiles', ticked: true),
        TaskRow(_grout, 'Grout'),
      ]);
      final json = t.toJson();
      expect(json, {
        'id': _table,
        'type': 'task_table',
        'rows': [
          {'id': _tile, 'text': 'Tile', 'note': '2 tiles', 'ticked': true},
          {'id': _grout, 'text': 'Grout', 'ticked': false},
        ],
      });
      final back = PageBlock.fromJson(json) as PageTaskTable;
      expect(back.rows.map((r) => r.ticked), [true, false]);
      expect(back.rows.first.note, '2 tiles');
      expect(back.ticked, 1);
    });

    test('"1 of 3 ticked" counts every table of tasks; none, no count', () {
      final s = DaybookSamples('en');
      expect(taskCount([_tasks(s)]), (ticked: 1, total: 3));
      expect(taskCount(const [PageText(_tile, 'words')]), isNull);
    });

    test('a save keeps the server\'s ticks and a ticked row\'s words; an '
        'empty new row goes', () {
      final s = DaybookSamples('en');
      final page = _page(s);
      final edited = PageTaskTable(_table, [
        // The editor can't change a tick or a ticked row's words.
        const TaskRow(_tile, 'Something else'),
        TaskRow(_grout, '  Grout gap, lift door ', note: ' grey '),
        const TaskRow(_skirting, 'Skirting loose, grid A3'),
        const TaskRow('00000000-0000-4000-8000-0000000006c9', '  '),
      ]);
      final plan = planPageSave(
        page,
        blocks: [edited],
        points: const {},
        title: page.post.title,
        body: '',
      );
      final saved = plan.blocks.single as PageTaskTable;
      expect(saved.rows.map((r) => r.id), [_tile, _grout, _skirting]);
      expect(saved.rows.first.ticked, isTrue);
      expect(saved.rows.first.text, 'Cracked tile at the stair');
      expect(saved.rows[1].text, 'Grout gap, lift door');
      expect(saved.rows[1].note, 'grey');
      expect(saved.rows[1].ticked, isFalse);
    });

    test('+ in a work item: SP4\'s seven in order; a table of tasks only on '
        'a work item', () {
      DaybookPost post(String kind) =>
          DaybookPost(id: 'p', kind: kind, createdAt: DateTime(2026), title: 't');
      expect(pageAdds(post(DaybookPost.workItemKind)).take(7), [
        PageAdd.text,
        PageAdd.bullets,
        PageAdd.checklist,
        PageAdd.table,
        PageAdd.taskTable,
        PageAdd.photo,
        PageAdd.file,
      ]);
      expect(
        pageAdds(post(DaybookPost.announcementKind)),
        isNot(contains(PageAdd.taskTable)),
      );
      expect(
        pageAdds(post(DaybookPost.checklistKind)),
        isNot(contains(PageAdd.taskTable)),
      );
    });
  });

  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);
    final s = DaybookSamples(lang);

    testWidgets('SP4: + in a work item lists Text · Bullet points · '
        'Checklist · Table · Table of tasks · Photo · File or scan, with '
        'their lines [$lang]', (tester) async {
      await _open(tester, lang, me: DaybookSamples.islam, pass: SpacePass.lead);
      await _openItem(tester);
      await _tap(tester, _key('page-edit'));
      await _tap(tester, _key('page-add-button'));
      expect(find.text(l10n.pageAddToItem), findsOneWidget);
      final names = [
        ('text', l10n.pageText),
        ('bullets', l10n.pageBulletPoints),
        ('checklist', l10n.pageChecklist),
        ('table', l10n.pageTable),
        ('taskTable', l10n.pageTaskTable),
        ('photo', l10n.pagePhoto),
        ('file', l10n.pageFileOrScan),
      ];
      double? above;
      for (final (key, name) in names) {
        final row = _key('page-add-$key');
        expect(row, findsOneWidget);
        expect(
          find.descendant(of: row, matching: find.text(name)),
          findsOneWidget,
        );
        final y = tester.getTopLeft(row).dy;
        if (above != null) expect(y, greaterThan(above));
        above = y;
      }
      expect(
        find.descendant(
          of: _key('page-add-table'),
          matching: find.text(l10n.pageTableHint),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _key('page-add-taskTable'),
          matching: find.text(l10n.pageTaskTableHint),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the writing card\'s hint names + [$lang]', (tester) async {
      expect(
        l10n.daybookWritingDetails,
        s.t(
          'Add details. + for bullet points, a table or a table of tasks.',
          'أضف التفاصيل. + للنقاط أو جدول أو جدول مهام.',
        ),
      );
    });

    testWidgets('SP4: Table of tasks adds a table; its first task is typed '
        'and saved with the page; Bullet points starts a line with a bullet '
        '[$lang]', (tester) async {
      final pages = FakePageRepository();
      final s = DaybookSamples(lang);
      await _open(
        tester,
        lang,
        me: DaybookSamples.islam,
        pass: SpacePass.lead,
        pages: pages,
        page: PostPage(post: _item(s), version: 2),
      );
      await _openItem(tester);
      await _tap(tester, _key('page-edit'));
      await _tap(tester, _key('page-add-button'));
      await _tap(tester, _key('page-add-taskTable'));
      final table = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('page-task-table-'),
      );
      expect(table, findsOneWidget);
      // Its header: the tick's column, Task, Note.
      expect(
        find.descendant(of: table, matching: find.text(l10n.taskTableTask)),
        findsWidgets,
      );
      final task = find.descendant(
        of: table,
        matching: find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith('page-field-tt:') &&
              (w.key! as ValueKey<String>).value.endsWith(':t'),
        ),
      );
      expect(task, findsOneWidget);
      await tester.enterText(
        find.descendant(of: task, matching: find.byType(EditableText)),
        s.t('Seal the joint', 'اختم الفاصل'),
      );
      await tester.pumpAndSettle();
      // Add a row: a second task field.
      await _tap(
        tester,
        find.descendant(of: table, matching: _key('task-add-row')),
      );
      expect(
        find.descendant(
          of: table,
          matching: find.byWidgetPredicate(
            (w) =>
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith('page-field-tt:') &&
                (w.key! as ValueKey<String>).value.endsWith(':t'),
          ),
        ),
        findsNWidgets(2),
      );
      await _tap(tester, _key('page-add-button'));
      await _tap(tester, _key('page-add-bullets'));
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.controller?.text == pageBulletStart,
        ),
        findsOneWidget,
      );
      await _tap(tester, _key('page-done'));
      // The empty second row went; the bullet line is a text block.
      expect(pages.calls.last, startsWith('save $_post v2 [task_table'));
      final saved = pages.pages[_post]!.blocks.whereType<PageTaskTable>().single;
      expect(saved.rows.map((r) => r.text), [s.t('Seal the joint', 'اختم الفاصل')]);
      expect(saved.rows.single.ticked, isFalse);
    });

    testWidgets('SP3: the owner reads Task · Note, "1 of 3 ticked" on the '
        'For line, the ticked row crossed out; a tick is his, at once '
        '[$lang]', (tester) async {
      final pages = FakePageRepository();
      await _open(tester, lang, pages: pages);
      // On the card in Work.
      final card = _key('daybook-card-$_post');
      expect(
        find.descendant(
          of: card,
          matching: find.textContaining(l10n.taskTableTicked(1, 3)),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text(l10n.taskTableNote)),
        findsOneWidget,
      );
      final ticked = tester.widget<Text>(
        find.descendant(
          of: card,
          matching: find.text(s.t('Cracked tile at the stair', 'بلاطة مكسورة عند الدرج')),
        ),
      );
      expect(ticked.style?.decoration, TextDecoration.lineThrough);
      // The opened item reads the same.
      await _openItem(tester);
      expect(
        _inPage(find.textContaining(l10n.taskTableTicked(1, 3))),
        findsOneWidget,
      );
      await _tap(tester, _inPage(_key('task-tick-$_grout')));
      expect(pages.calls.last, 'tick $_grout on');
      expect(
        _inPage(find.textContaining(l10n.taskTableTicked(2, 3))),
        findsOneWidget,
      );
      // A tick is not a signature: the item is still Open.
      expect(pages.pages[_post]!.post.item!.status, WorkStatus.open);
    });

    testWidgets('a Lead ticks too, and takes a tick back [$lang]', (
      tester,
    ) async {
      final pages = FakePageRepository();
      await _open(
        tester,
        lang,
        me: DaybookSamples.sara,
        pass: SpacePass.lead,
        pages: pages,
      );
      await _openItem(tester);
      await _tap(tester, _inPage(_key('task-tick-$_tile')));
      expect(pages.calls.last, 'tick $_tile off');
    });

    testWidgets('Crew who don\'t own the item can\'t tick or add [$lang]', (
      tester,
    ) async {
      final pages = FakePageRepository();
      await _open(
        tester,
        lang,
        me: DaybookSamples.rakesh,
        pass: SpacePass.crew,
        pages: pages,
      );
      await _openItem(tester);
      await tester.tap(_inPage(_key('task-tick-$_grout')), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(pages.calls, isEmpty);
      expect(_inPage(_key('task-add-row')), findsNothing);
    });

    testWidgets('a tick the server refuses is taken back [$lang]', (
      tester,
    ) async {
      final pages = FakePageRepository()..mayTick = false;
      await _open(tester, lang, pages: pages);
      await _openItem(tester);
      await _tap(tester, _inPage(_key('task-tick-$_grout')));
      expect(
        _inPage(find.textContaining(l10n.taskTableTicked(1, 3))),
        findsOneWidget,
      );
      expect(find.text(l10n.spacesNotAllowed), findsOneWidget);
    });

    testWidgets('Add a row: the task and a note, at the end [$lang]', (
      tester,
    ) async {
      final pages = FakePageRepository();
      await _open(tester, lang, pages: pages);
      await _openItem(tester);
      await _tap(tester, _inPage(_key('task-add-row')));
      await tester.enterText(
        _key('task-add-text'),
        s.t('Clean the lift sill', 'نظّف عتبة المصعد'),
      );
      await tester.enterText(_key('task-add-note'), s.t('Today', 'اليوم'));
      await tester.pumpAndSettle();
      await _tap(tester, _key('task-add-send'));
      expect(
        pages.calls.last,
        'add row ${s.t('Clean the lift sill', 'نظّف عتبة المصعد')} · '
        '${s.t('Today', 'اليوم')}',
      );
      expect(
        _inPage(find.text(s.t('Clean the lift sill', 'نظّف عتبة المصعد'))),
        findsOneWidget,
      );
      expect(
        _inPage(find.textContaining(l10n.taskTableTicked(1, 4))),
        findsOneWidget,
      );
    });

    testWidgets('Sign as done stays once for the whole item, with rows still '
        'unticked [$lang]', (tester) async {
      await _open(tester, lang);
      final card = _key('daybook-card-$_post');
      expect(
        find.descendant(of: card, matching: find.text(l10n.daybookSignAsDone)),
        findsOneWidget,
      );
      // Not one per row.
      expect(
        find.descendant(of: card, matching: find.text(l10n.daybookSignAsDone)),
        findsNWidgets(1),
      );
    });

    testWidgets('the columns follow the reading direction: the tick at the '
        '${lang == 'ar' ? 'right' : 'left'} [$lang]', (tester) async {
      await _open(tester, lang);
      await _openItem(tester);
      final tick = tester.getCenter(_inPage(_key('task-tick-$_grout')));
      final task = tester.getCenter(
        _inPage(find.text(s.t('Grout gap at the lift door', 'فراغ الترويب عند باب المصعد'))),
      );
      final note = tester.getCenter(
        _inPage(find.text(s.t('Grey grout', 'ترويب رمادي'))),
      );
      if (lang == 'ar') {
        expect(tick.dx, greaterThan(task.dx));
        expect(task.dx, greaterThan(note.dx));
      } else {
        expect(tick.dx, lessThan(task.dx));
        expect(task.dx, lessThan(note.dx));
      }
    });

    test('the lead\'s check N1: a tick is not Done: "1 of 3 ticked" '
        '[$lang]', () {
      expect(
        l10n.taskTableTicked(1, 3),
        s.t('1 of 3 ticked', '1 من 3 معلَّمة'),
      );
    });

    test('the lead\'s check N2: ticks are the owner\'s or a Lead\'s; an '
        'admin with a Crew pass who doesn\'t own it can\'t [$lang]', () {
      final post = _item(s);
      expect(
        mayTickTasks(
          s.detail(pass: SpacePass.crew, admin: true),
          post,
          DaybookSamples.islam,
        ),
        isFalse,
      );
      expect(
        mayTickTasks(s.detail(pass: SpacePass.lead), post, DaybookSamples.sara),
        isTrue,
      );
      expect(
        mayTickTasks(s.detail(), post, DaybookSamples.omar),
        isTrue,
      );
    });

    testWidgets('the lead\'s check N2: the admin on a Crew pass taps a tick '
        'and nothing goes [$lang]', (tester) async {
      final pages = FakePageRepository();
      await _open(
        tester,
        lang,
        me: DaybookSamples.islam,
        pass: SpacePass.crew,
        pages: pages,
      );
      await _openItem(tester);
      await tester.tap(_inPage(_key('task-tick-$_grout')), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(pages.calls, isEmpty);
    });

    testWidgets('the lead\'s check N4: each tick names its row\'s task to a '
        'screen reader; an empty note reads the ARB\'s "—" [$lang]', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _open(tester, lang);
      await _openItem(tester);
      final grout = s.t('Grout gap at the lift door', 'فراغ الترويب عند باب المصعد');
      expect(
        find.bySemanticsLabel(l10n.taskTableTick(grout)),
        findsWidgets,
      );
      expect(
        find.descendant(
          of: _inPage(_key('task-row-$_skirting')),
          matching: find.text(l10n.taskTableNoNote),
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });
  }
}
