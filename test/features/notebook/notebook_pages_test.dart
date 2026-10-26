// Review 99A: the notebook becomes pages (A1–A6), in English and Arabic.
import 'dart:convert';

import 'package:buildvibes/data/models/note.dart';
import 'package:buildvibes/data/models/notebook_page.dart';
import 'package:buildvibes/data/models/post_page.dart';
import 'package:buildvibes/features/notebook/note_draft.dart';
import 'package:buildvibes/features/notebook/notebook_page_screen.dart';
import 'package:buildvibes/features/notebook/notebook_state.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/notebook_fakes.dart';
import '../../helpers/notebook_page_samples.dart';
import '../../helpers/pump_app.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

Future<void> _go(WidgetTester tester, String path) async {
  GoRouter.of(tester.element(find.byType(Navigator).first)).push(path);
  await tester.pumpAndSettle();
}

Future<TestApp> _open(
  WidgetTester tester,
  String lang, {
  FakeNotebookRepository? notebook,
  String path = '/notebook',
  Map<String, Object> stored = const {},
}) async {
  final app = await pumpApp(
    tester,
    language: lang,
    now: NotebookPageSamples.now,
    notebook: notebook ?? NotebookPageSamples(lang).repository(),
    stored: stored,
  );
  await _go(tester, path);
  return app;
}

NotebookData _data(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(Scaffold).first),
).read(notebookProvider).value!;

NoteDraft? _draft(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(Scaffold).first),
).read(noteDraftProvider);

/// The vertical place of each finder's first widget.
double _top(WidgetTester tester, Finder f) => tester.getTopLeft(f.first).dy;

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    final s = NotebookPageSamples(lang);

    group('A1 the pages list [$lang]', () {
      testWidgets('New entry on top; pinned first, then by latest activity; '
          'each row its latest entry and open to-dos, never a count', (
        tester,
      ) async {
        await _open(tester, lang);
        expect(_key('notebook-new-entry'), findsOneWidget);
        expect(find.text(l10n.notebookNewEntry), findsOneWidget);
        expect(_key('notebook-search'), findsOneWidget);
        expect(_key('notebook-deleted'), findsOneWidget);
        final order = [
          NotebookPageSamples.siteA,
          NotebookPageSamples.phones,
          NotebookPageSamples.pump,
          NotebookPageSamples.siteB,
          NotebookPageSamples.meetings,
          NotebookPageSamples.myNotes,
        ];
        for (final (i, id) in order.indexed.skip(1)) {
          expect(
            _top(tester, _key('page-${order[i - 1]}')),
            lessThan(_top(tester, _key('page-$id'))),
          );
        }
        // Sub-pages are inside their page, not on the list.
        expect(_key('page-${NotebookPageSamples.level3}'), findsNothing);
        expect(
          _top(tester, find.text(l10n.notebookNewEntry)),
          lessThan(_top(tester, find.text(l10n.notebookPinnedLabel))),
        );
        expect(
          _top(tester, find.text(l10n.notebookPinnedLabel)),
          lessThan(_top(tester, find.text(l10n.notebookPagesLabel))),
        );
        // Site A: today and its latest entry; 3 to-dos open with its
        // sub-pages'.
        expect(
          find.text(l10n.notebookPageLine(l10n.notebookToday, s.beforePour)),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: _key('page-${NotebookPageSamples.siteA}'),
            matching: find.text(l10n.notebookTodosOpen(3)),
          ),
          findsOneWidget,
        );
        // No to-dos: no line for them.
        expect(
          find.descendant(
            of: _key('page-${NotebookPageSamples.meetings}'),
            matching: _key('page-todos'),
          ),
          findsNothing,
        );
        // A new page: its dot and "new page".
        expect(
          find.descendant(
            of: _key('page-${NotebookPageSamples.pump}'),
            matching: _key('page-new-dot'),
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            l10n.notebookPageLine(l10n.notebookToday, l10n.notebookNewPageMark),
          ),
          findsOneWidget,
        );
        // "My notes" in the app's language (A6).
        expect(find.text(l10n.notebookMyNotes), findsOneWidget);
        expect(
          find.text(l10n.notebookYesterday, findRichText: true),
          findsNothing,
        );
      });

      testWidgets('+ New page makes an empty page and opens it', (
        tester,
      ) async {
        final app = await _open(tester, lang);
        await _tap(tester, _key('notebook-new-page'));
        expect(_key('page-title'), findsOneWidget);
        expect(_key('page-write'), findsOneWidget);
        final made = app.notebook.calls.where((c) => c.startsWith('page:'));
        expect(made, hasLength(1));
        expect(find.text(l10n.notebookUntitled), findsOneWidget);
      });

      testWidgets('Deleted items opens, empty until 99B', (tester) async {
        await _open(tester, lang);
        await _tap(tester, _key('notebook-deleted'));
        expect(_key('notebook-deleted-empty'), findsOneWidget);
        expect(find.text(l10n.notebookDeletedEmpty), findsOneWidget);
      });
    });

    group('A2 writing never waits [$lang]', () {
      testWidgets('New entry opens at once, the keyboard on the title, the '
          'chip on the last page used', (tester) async {
        await _open(tester, lang);
        await _tap(tester, _key('notebook-new-entry'));
        expect(_key('note-writing-card'), findsOneWidget);
        final title = tester.widget<TextField>(_key('note-title'));
        expect(title.focusNode?.hasFocus ?? false, isTrue);
        expect(find.text(l10n.notebookPageChip(s.siteATitle)), findsOneWidget);
        expect(find.text(s.siteATitle), findsWidgets);
      });

      testWidgets('a fresh notebook: the chip says New page; Send makes the '
          'page titled from the first line, marked new', (tester) async {
        final app = await _open(
          tester,
          lang,
          notebook: FakeNotebookRepository(pages: const []),
        );
        await _tap(tester, _key('notebook-new-entry'));
        expect(
          find.text(l10n.notebookPageChip(l10n.notebookNewPage)),
          findsOneWidget,
        );
        await tester.enterText(_key('note-title'), 'Pump booked 2 pm');
        await tester.pumpAndSettle();
        await _tap(tester, _key('writing-post'));
        final saved = app.notebook.calls.singleWhere(
          (c) => c.startsWith('save:'),
        );
        expect(saved, endsWith(':new:Pump booked 2 pm'));
        final page = app.notebook.pageKept.values.single;
        expect(page.title, 'Pump booked 2 pm');
        // Send shows the page it went into; opening it takes the mark off.
        expect(_key('page-title'), findsOneWidget);
        expect(app.notebook.calls, contains('page-open:${page.id}'));
      });

      testWidgets('the chip\'s picker: search, recent pages, + New page; a '
          'pick changes where the entry goes', (tester) async {
        final app = await _open(tester, lang);
        await _tap(tester, _key('notebook-new-entry'));
        await tester.enterText(_key('note-title'), 'Formwork');
        await tester.pumpAndSettle();
        await _tap(tester, _key('note-page-chip'));
        expect(_key('page-picker'), findsOneWidget);
        expect(find.text(l10n.notebookRecent), findsOneWidget);
        expect(_key('page-pick-new'), findsOneWidget);
        await tester.enterText(_key('page-picker-search'), s.siteBTitle);
        await tester.pumpAndSettle();
        expect(_key('page-pick-${NotebookPageSamples.siteA}'), findsNothing);
        await tester.enterText(_key('page-picker-search'), s.siteBTitle);
        await tester.pumpAndSettle();
        await _tap(tester, _key('page-pick-${NotebookPageSamples.siteB}'));
        expect(_key('page-picker'), findsNothing);
        expect(find.text(l10n.notebookPageChip(s.siteBTitle)), findsOneWidget);
        await _tap(tester, _key('writing-post'));
        final id = _draftlessId(app);
        expect(app.notebook.kept[id]!.pageId, NotebookPageSamples.siteB);
      });

      testWidgets('writing inside a page: no chip; the entry goes there', (
        tester,
      ) async {
        final app = await _open(
          tester,
          lang,
          path: '/notebook/pages/${NotebookPageSamples.meetings}',
        );
        await _tap(tester, _key('page-write'));
        expect(_key('note-page-chip'), findsNothing);
        await tester.enterText(_key('note-title'), 'Samples on Sunday');
        await tester.pumpAndSettle();
        await _tap(tester, _key('writing-post'));
        final id = _draftlessId(app);
        expect(app.notebook.kept[id]!.pageId, NotebookPageSamples.meetings);
        expect(_key('note-$id'), findsOneWidget);
      });

      testWidgets('a Draft from before pages shows in the latest page and '
          'goes on there', (tester) async {
        final draft = NoteDraft(
          id: 'draft-old',
          startedAt: NotebookPageSamples.now,
          title: 'Old draft',
        );
        await _open(
          tester,
          lang,
          path: '/notebook/pages/${NotebookPageSamples.siteA}',
          stored: {'notebook_draft:user-1': jsonEncode(draft.toJson())},
        );
        expect(_key('note-draft'), findsOneWidget);
        await _tap(tester, _key('note-draft'));
        expect(_draft(tester)!.pageId, NotebookPageSamples.siteA);
        expect(_key('note-page-chip'), findsNothing);
      });
    });

    group('A3 inside a page [$lang]', () {
      testWidgets('the path, the title and icon edited in place, sub-pages '
          'at the top, entries newest first by day', (tester) async {
        final app = await _open(
          tester,
          lang,
          path: '/notebook/pages/${NotebookPageSamples.siteA}',
        );
        expect(
          tester.widget<Text>(_key('page-path')).data,
          '${l10n.notebookTitle} ›',
        );
        expect(
          _top(tester, _key('page-${NotebookPageSamples.level3}')),
          lessThan(_top(tester, _key('note-entry-pour'))),
        );
        expect(
          _top(tester, _key('note-entry-pour')),
          lessThan(_top(tester, _key('note-entry-gate'))),
        );
        expect(
          _top(tester, _key('note-entry-gate')),
          lessThan(_top(tester, _key('note-entry-lobby'))),
        );

        await tester.enterText(_key('page-title'), 'Tower A');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(
          app.notebook.calls,
          contains('page-edit:${NotebookPageSamples.siteA}:Tower A:hard_hat'),
        );

        await _tap(tester, _key('page-icon'));
        for (final icon in PageIcon.values) {
          expect(_key('page-icon-${icon.json}'), findsOneWidget);
        }
        await _tap(tester, _key('page-icon-ruler'));
        expect(
          app.notebook.calls,
          contains('page-edit:${NotebookPageSamples.siteA}:Tower A:ruler'),
        );

        // A sub-page's path.
        await _tap(tester, _key('page-${NotebookPageSamples.level3}'));
        expect(
          tester.widget<Text>(_key('page-path')).data,
          '${l10n.notebookTitle} › Tower A ›',
        );
      });

      testWidgets('opening a new page takes its mark off', (tester) async {
        final app = await _open(
          tester,
          lang,
          path: '/notebook/pages/${NotebookPageSamples.pump}',
        );
        expect(
          app.notebook.calls,
          contains('page-open:${NotebookPageSamples.pump}'),
        );
        expect(_data(tester).page(NotebookPageSamples.pump)!.isNew, isFalse);
      });

      testWidgets('the page\'s menu: a page inside it, and Pin', (
        tester,
      ) async {
        final app = await _open(
          tester,
          lang,
          path: '/notebook/pages/${NotebookPageSamples.siteB}',
        );
        await _tap(tester, _key('page-more'));
        await _tap(tester, _key('page-menu-pin'));
        expect(
          app.notebook.calls,
          contains('page-pin:${NotebookPageSamples.siteB}:true'),
        );
        await _tap(tester, _key('page-more'));
        await _tap(tester, _key('page-menu-sub'));
        final sub = app.notebook.pageKept.values.singleWhere(
          (p) => p.parentId == NotebookPageSamples.siteB,
        );
        expect(_data(tester).path(sub.id).first.id, NotebookPageSamples.siteB);
      });
    });

    group('A4 move and merge [$lang]', () {
      testWidgets('long-press, then tap: the bar; Merge into the page that '
          'stays, Undo for 5 s, then it goes', (tester) async {
        final app = await _open(tester, lang);
        await tester.longPress(_key('page-${NotebookPageSamples.siteB}'));
        await tester.pumpAndSettle();
        await _tap(tester, _key('page-${NotebookPageSamples.pump}'));
        expect(find.text(l10n.notebookSelected(2)), findsOneWidget);
        expect(_key('select-merge'), findsOneWidget);
        expect(_key('select-move'), findsOneWidget);
        expect(_key('select-pin'), findsOneWidget);
        expect(_key('select-delete'), findsOneWidget);
        expect(_key('notebook-new-entry'), findsNothing);

        await _tap(tester, _key('select-merge'));
        expect(find.text(l10n.notebookMergeTitle(2)), findsOneWidget);
        expect(find.text(l10n.notebookMergeBody), findsOneWidget);
        expect(_key('merge-into-new'), findsOneWidget);
        await _tap(tester, _key('merge-go'));
        // Shown at once; nothing sent until the Undo bar is gone.
        expect(_key('page-${NotebookPageSamples.pump}'), findsNothing);
        expect(find.text(l10n.notebookMerged), findsOneWidget);
        expect(
          app.notebook.calls.where((c) => c.startsWith('merge:')),
          isEmpty,
        );
        await tester.tap(find.text(l10n.daybookUndo));
        await tester.pumpAndSettle();
        expect(_key('page-${NotebookPageSamples.pump}'), findsOneWidget);
        expect(
          app.notebook.calls.where((c) => c.startsWith('merge:')),
          isEmpty,
        );

        await tester.longPress(_key('page-${NotebookPageSamples.siteB}'));
        await tester.pumpAndSettle();
        await _tap(tester, _key('page-${NotebookPageSamples.pump}'));
        await _tap(tester, _key('select-merge'));
        await _tap(tester, _key('merge-go'));
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();
        expect(
          app.notebook.calls,
          contains(
            'merge:${NotebookPageSamples.siteB},${NotebookPageSamples.pump}:'
            ':${NotebookPageSamples.siteB}',
          ),
        );
        expect(
          app.notebook.kept['entry-pump-new']!.pageId,
          NotebookPageSamples.siteB,
        );
        expect(app.notebook.pageKept[NotebookPageSamples.pump], isNull);
      });

      testWidgets('Move into… never offers a page under itself; Pin; '
          'Delete with Undo', (tester) async {
        final app = await _open(tester, lang);
        await tester.longPress(_key('page-${NotebookPageSamples.meetings}'));
        await tester.pumpAndSettle();
        await _tap(tester, _key('select-move'));
        expect(_key('page-pick-top'), findsOneWidget);
        expect(_key('page-pick-${NotebookPageSamples.meetings}'), findsNothing);
        expect(_key('page-pick-new'), findsNothing);
        await tester.enterText(_key('page-picker-search'), s.siteBTitle);
        await tester.pumpAndSettle();
        await _tap(tester, _key('page-pick-${NotebookPageSamples.siteB}'));
        expect(
          app.notebook.calls,
          contains(
            'page-move:${NotebookPageSamples.meetings}:'
            '${NotebookPageSamples.siteB}',
          ),
        );
        expect(_key('page-${NotebookPageSamples.meetings}'), findsNothing);

        await tester.longPress(_key('page-${NotebookPageSamples.siteB}'));
        await tester.pumpAndSettle();
        await _tap(tester, _key('select-pin'));
        expect(
          app.notebook.calls,
          contains('page-pin:${NotebookPageSamples.siteB}:true'),
        );

        await tester.longPress(_key('page-${NotebookPageSamples.phones}'));
        await tester.pumpAndSettle();
        await _tap(tester, _key('select-delete'));
        expect(find.text(l10n.notebookPagesDeleted(1)), findsOneWidget);
        expect(_key('page-${NotebookPageSamples.phones}'), findsNothing);
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();
        expect(
          app.notebook.calls,
          contains('page-delete:${NotebookPageSamples.phones}'),
        );
      });

      testWidgets('entries: long-press, tap another, Move to page…', (
        tester,
      ) async {
        final app = await _open(
          tester,
          lang,
          path: '/notebook/pages/${NotebookPageSamples.siteA}',
        );
        await tester.longPress(_key('note-entry-gate'));
        await tester.pumpAndSettle();
        await _tap(tester, _key('note-entry-lobby'));
        expect(find.text(l10n.notebookSelected(2)), findsOneWidget);
        expect(_key('note-selected-entry-gate'), findsOneWidget);
        await _tap(tester, _key('select-move'));
        await tester.enterText(_key('page-picker-search'), s.siteBTitle);
        await tester.pumpAndSettle();
        await _tap(tester, _key('page-pick-${NotebookPageSamples.siteB}'));
        expect(
          app.notebook.calls,
          contains(
            'notes-move:entry-gate,entry-lobby:${NotebookPageSamples.siteB}',
          ),
        );
        expect(_key('note-entry-gate'), findsNothing);
        expect(find.text(l10n.notebookMovedTo(s.siteBTitle)), findsOneWidget);
      });

      testWidgets('an entry\'s ⋯: Move to page…, into a new page', (
        tester,
      ) async {
        final app = await _open(
          tester,
          lang,
          path: '/notebook/pages/${NotebookPageSamples.siteA}',
        );
        await _tap(tester, _key('note-menu-entry-gate'));
        await _tap(tester, _key('note-move'));
        await _tap(tester, _key('page-pick-new'));
        final made = app.notebook.pageKept.values.singleWhere(
          (p) => !s.pages().any((q) => q.id == p.id),
        );
        expect(made.title, s.pumpTitle);
        expect(app.notebook.kept['entry-gate']!.pageId, made.id);
      });

      testWidgets('a line from the line menu: a new entry with its children '
          'in another page; it leaves this one', (tester) async {
        final draft = NoteDraft(
          id: 'draft-walk',
          startedAt: NotebookPageSamples.now,
          title: 'Walk',
          blocks: [
            PageText('l-1', 'Keep'),
            PageBullet('l-2', 'Rebar'),
            PageBullet('l-3', 'Cover', indent: 1),
          ],
          pageId: NotebookPageSamples.siteA,
        );
        final app = await _open(
          tester,
          lang,
          path: '/notebook/pages/${NotebookPageSamples.siteA}',
          stored: {'notebook_draft:user-1': jsonEncode(draft.toJson())},
        );
        await _tap(tester, _key('note-draft'));
        await tester.longPress(_key('note-marker-l-2'));
        await tester.pumpAndSettle();
        await _tap(tester, _key('page-move-to-page'));
        await tester.enterText(_key('page-picker-search'), s.siteBTitle);
        await tester.pumpAndSettle();
        await _tap(tester, _key('page-pick-${NotebookPageSamples.siteB}'));
        final moved = app.notebook.kept.values.singleWhere(
          (n) =>
              n.pageId == NotebookPageSamples.siteB &&
              (n.blocks ?? const []).any((b) => b.id == 'l-2'),
        );
        expect([for (final b in moved.blocks!) b.indent], [0, 1]);
        expect([for (final b in _draft(tester)!.blocks) b.id], ['l-1']);
      });
    });

    group('A5 search [$lang]', () {
      testWidgets('one field over every page; a hit shows its page and day, '
          'and opens the entry in its page', (tester) async {
        final repo = s.repository()
          ..hits = [
            NotebookHit(
              pageId: NotebookPageSamples.siteA,
              noteId: 'entry-lobby',
              title: 'Snags, lobby',
              snippet: 'Cracked tile at the stair',
              at: DateTime(2026, 10, 14, 16, 20),
            ),
          ];
        await _open(tester, lang, notebook: repo);
        await _tap(tester, _key('notebook-search'));
        await tester.enterText(_key('notebook-search-field'), '٢٣');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        expect(repo.searched, '٢٣');
        expect(
          find.text(
            l10n.notebookPageLine(s.siteATitle, l10n.notebookYesterday),
          ),
          findsOneWidget,
        );
        await _tap(tester, _key('notebook-hit-entry-lobby'));
        expect(find.byType(NotebookPageScreen), findsOneWidget);
        expect(_key('note-entry-lobby'), findsOneWidget);
      });

      testWidgets('nothing found says so', (tester) async {
        await _open(tester, lang);
        await _tap(tester, _key('notebook-search'));
        await tester.enterText(_key('notebook-search-field'), 'zz');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        expect(_key('notebook-search-none'), findsOneWidget);
      });
    });

    group('A6 existing notes [$lang]', () {
      testWidgets('older notes are in "My notes", named in the app\'s '
          'language, oldest to newest kept', (tester) async {
        final notes = [
          Note(
            id: 'old-1',
            kind: NoteKind.text,
            body: 'First',
            createdAt: DateTime(2026, 10, 1, 8),
          ),
          Note(
            id: 'old-2',
            kind: NoteKind.text,
            body: 'Second',
            createdAt: DateTime(2026, 10, 2, 8),
          ),
        ];
        await _open(
          tester,
          lang,
          notebook: FakeNotebookRepository(notes: notes),
        );
        expect(find.text(l10n.notebookMyNotes), findsOneWidget);
        await _tap(tester, _key('page-${FakeNotebookRepository.myNotesId}'));
        expect(
          _top(tester, _key('note-old-2')),
          lessThan(_top(tester, _key('note-old-1'))),
        );
      });
    });
  }

  group('the phone keeps page changes until they are sent', () {
    test('each page change goes and comes back the same', () {
      final page = NotebookPage(
        id: 'p',
        title: 'Site',
        icon: PageIcon.wrench,
        createdAt: DateTime.utc(2026, 10, 15),
        lastActivityAt: DateTime.utc(2026, 10, 15),
      );
      final changes = [
        NoteChange.newPage(page),
        NoteChange.editPage(page),
        const NoteChange.openPage('p'),
        const NoteChange.pinPages(['p', 'q'], on: true),
        const NoteChange.movePages(['p'], null),
        const NoteChange.moveNotes(['n'], 'p'),
        NoteChange.merge(['p', 'q'], ['n'], 'r', page: page),
        const NoteChange.deletePages(['p']),
      ];
      for (final c in changes) {
        final back = NoteChange.fromJson(
          jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>,
        );
        expect(back.op, c.op);
        expect(back.ids, c.ids);
        expect(back.noteIds, c.noteIds);
        expect(back.target, c.target);
        expect(back.page?.icon, c.page?.icon);
        expect(back.noteId, isNull);
      }
    });

    test('a merge: entries in date order in the page that stays; sub-pages '
        'under it; the page that stays climbs out of one that goes', () {
      NotebookPage p(String id, {String? parent}) => NotebookPage(
        id: id,
        parentId: parent,
        createdAt: DateTime(2026, 10, 1),
        lastActivityAt: DateTime(2026, 10, 1),
      );
      Note n(String id, String page, int day) => Note(
        id: id,
        kind: NoteKind.text,
        body: id,
        createdAt: DateTime(2026, 10, day),
        pageId: page,
      );
      final data = NotebookData(
        notes: [n('c', 'b', 3), n('b', 'a', 2), n('a', 'b', 1)],
        pages: [
          p('a'),
          p('b', parent: 'a'),
          p('sub', parent: 'a'),
        ],
      );
      final merged = const NoteChange.merge(['a', 'b'], [], 'b').applyTo(data);
      expect([for (final x in merged.entries('b')) x.id], ['c', 'b', 'a']);
      expect(merged.page('a'), isNull);
      expect(merged.page('b')!.parentId, isNull);
      expect(merged.page('sub')!.parentId, 'b');
    });

    test('Move into never puts a page under itself', () {
      NotebookPage p(String id, {String? parent}) => NotebookPage(
        id: id,
        parentId: parent,
        createdAt: DateTime(2026, 10, 1),
        lastActivityAt: DateTime(2026, 10, 1),
      );
      final data = NotebookData(
        pages: [
          p('a'),
          p('b', parent: 'a'),
        ],
      );
      final after = const NoteChange.movePages(['a'], 'b').applyTo(data);
      expect(after.page('a')!.parentId, isNull);
    });

    test('open to-dos count the page and every page under it', () {
      final data = NotebookPageSamples('en');
      final view = NotebookData(notes: data.notes(), pages: data.pages());
      expect(view.openTodos(NotebookPageSamples.siteA), 3);
      expect(view.openTodos(NotebookPageSamples.meetings), 0);
    });
  });
}

/// The id of the entry just sent (the only save of a new one).
String _draftlessId(TestApp app) {
  final save = app.notebook.calls.lastWhere((c) => c.startsWith('save:'));
  return save.split(':')[1];
}
