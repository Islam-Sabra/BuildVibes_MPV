// Review 99A: the notebook becomes pages (A1–A6), in English and Arabic.
import 'dart:convert';

import 'package:buildvibes/core/design/bv_icons.dart';
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

/// The path's carets (they flip in Arabic).
Finder _carets() => find.descendant(
  of: _key('page-path'),
  matching: find.byIcon(BvIcons.caretForward),
);

/// The vertical place of each finder's first widget.
double _top(WidgetTester tester, Finder f) => tester.getTopLeft(f.first).dy;

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    final s = NotebookPageSamples(lang);

    group('A1 the pages list [$lang]', () {
      testWidgets('pinned first, then by latest activity; each row "{n} '
          'entries · {when}" (review 100 Part 7)', (tester) async {
        await _open(tester, lang);
        expect(_key('notebook-new-entry'), findsOneWidget);
        expect(find.text(l10n.notebookNewEntry), findsOneWidget);
        expect(_key('notebook-search'), findsOneWidget);
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
          _top(tester, find.text(l10n.notebookPinnedLabel)),
          lessThan(_top(tester, find.text(l10n.notebookPagesLabel))),
        );
        // Review 100 Part 7: "{n} entries · {when}", no to-dos, no first
        // line (redesign_filter_test.dart has the rest).
        expect(
          find.descendant(
            of: _key('page-${NotebookPageSamples.siteA}'),
            matching: find.text(l10n.notebookRowLine(6, l10n.notebookRowToday)),
          ),
          findsOneWidget,
        );
        expect(_key('page-todos'), findsNothing);
        // A new page: its dot, and its one entry.
        expect(
          find.descendant(
            of: _key('page-${NotebookPageSamples.pump}'),
            matching: _key('page-new-dot'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: _key('page-${NotebookPageSamples.pump}'),
            matching: find.text(l10n.notebookRowLine(1, l10n.notebookRowToday)),
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

      testWidgets("99B: Deleted items at the list's end, under + New page "
          '(ruling 9)', (tester) async {
        await _open(tester, lang);
        expect(_key('notebook-deleted'), findsOneWidget);
        expect(
          _top(tester, _key('notebook-new-page')),
          lessThan(_top(tester, _key('notebook-deleted'))),
        );
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
        // C5: back on the list, the page on top with its mark, and
        // "Saved in … · Open"; nothing opened it.
        expect(_key('notebook-new-entry'), findsOneWidget);
        expect(
          find.descendant(
            of: _key('page-${page.id}'),
            matching: _key('page-new-dot'),
          ),
          findsOneWidget,
        );
        expect(
          app.notebook.calls.where((c) => c.startsWith('page-open')),
          isEmpty,
        );
        expect(
          find.text(l10n.notebookSavedIn('Pump booked 2 pm')),
          findsOneWidget,
        );
        await tester.tap(find.text(l10n.notebookOpen));
        await tester.pumpAndSettle();
        expect(_key('page-title'), findsOneWidget);
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
        // C9: the path's names with a caret after each, no › typed.
        expect(
          find.descendant(
            of: _key('page-path'),
            matching: find.text(l10n.notebookTitle),
          ),
          findsOneWidget,
        );
        expect(_carets(), findsOneWidget);
        expect(find.textContaining('›'), findsNothing);
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
          find.descendant(
            of: _key('page-path'),
            matching: find.text('Tower A'),
          ),
          findsOneWidget,
        );
        expect(_carets(), findsNWidgets(2));
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

      testWidgets('C2: a merge into a new page is one call, and the page '
          'shows its new mark', (tester) async {
        final app = await _open(tester, lang);
        await tester.longPress(_key('page-${NotebookPageSamples.siteB}'));
        await tester.pumpAndSettle();
        await _tap(tester, _key('page-${NotebookPageSamples.meetings}'));
        await _tap(tester, _key('select-merge'));
        await _tap(tester, _key('merge-into-new'));
        await _tap(tester, _key('merge-go'));
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();
        expect(app.notebook.calls.where((c) => c.startsWith('page:')), isEmpty);
        expect(
          app.notebook.calls.where((c) => c.startsWith('merge:')),
          hasLength(1),
        );
        final made = app.notebook.pageKept.values.singleWhere(
          (p) => !s.pages().any((q) => q.id == p.id),
        );
        expect(
          find.descendant(
            of: _key('page-${made.id}'),
            matching: _key('page-new-dot'),
          ),
          findsOneWidget,
        );
        expect(find.text(l10n.notebookUntitled), findsOneWidget);
      });

      testWidgets('C7: a merge waiting for its Undo is kept on the phone; '
          'Undo takes it off', (tester) async {
        final app = await _open(tester, lang);
        await tester.longPress(_key('page-${NotebookPageSamples.siteB}'));
        await tester.pumpAndSettle();
        await _tap(tester, _key('page-${NotebookPageSamples.pump}'));
        await _tap(tester, _key('select-merge'));
        await _tap(tester, _key('merge-go'));
        expect(app.prefs.getString('notebook_held:user-1'), isNotNull);
        await tester.tap(find.text(l10n.daybookUndo));
        await tester.pumpAndSettle();
        expect(app.prefs.getString('notebook_held:user-1'), isNull);
      });

      testWidgets('C7: one held when the app closed goes when it opens '
          'again', (tester) async {
        final held = NoteChange.merge(
          [NotebookPageSamples.siteB, NotebookPageSamples.pump],
          const [],
          NotebookPageSamples.siteB,
        );
        final app = await _open(
          tester,
          lang,
          stored: {'notebook_held:user-1': jsonEncode(held.toJson())},
        );
        expect(
          app.notebook.calls,
          contains(
            'merge:${NotebookPageSamples.siteB},${NotebookPageSamples.pump}:'
            ':${NotebookPageSamples.siteB}',
          ),
        );
        expect(app.prefs.getString('notebook_held:user-1'), isNull);
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
        await _tap(tester, _key('bv-dialog-confirm'));
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

      testWidgets('an entry held, then Move (review 100 Part 3): into a new '
          'page', (tester) async {
        final app = await _open(
          tester,
          lang,
          path: '/notebook/pages/${NotebookPageSamples.siteA}',
        );
        await tester.longPress(_key('note-entry-gate'));
        await tester.pumpAndSettle();
        await _tap(tester, _key('select-move'));
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
        await _tap(tester, _key('select-move'));
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

      testWidgets('C6: a line moved from a saved entry, then discarded: the '
          'part is in the target page only', (tester) async {
        final entry = Note(
          id: 'entry-walk',
          kind: NoteKind.text,
          title: 'Walk',
          blocks: [
            PageText('w-1', 'Keep'),
            PageBullet('w-2', 'Rebar'),
            PageBullet('w-3', 'Cover', indent: 1),
          ],
          body: 'Walk',
          createdAt: DateTime(2026, 10, 15, 8),
          pageId: NotebookPageSamples.siteA,
        );
        final repo = s.repository()..kept[entry.id] = entry;
        final app = await _open(
          tester,
          lang,
          notebook: repo,
          path: '/notebook/pages/${NotebookPageSamples.siteA}',
        );
        await _tap(tester, _key('note-entry-walk'));
        await tester.longPress(_key('note-marker-w-2'));
        await tester.pumpAndSettle();
        await _tap(tester, _key('select-move'));
        await tester.enterText(_key('page-picker-search'), s.siteBTitle);
        await tester.pumpAndSettle();
        await _tap(tester, _key('page-pick-${NotebookPageSamples.siteB}'));
        await ProviderScope.containerOf(
          tester.element(find.byType(Scaffold).first),
        ).read(noteDraftProvider.notifier).discard();
        await tester.pumpAndSettle();
        final withPart = [
          for (final n in app.notebook.kept.values)
            if ((n.blocks ?? const []).any((b) => b.id == 'w-2')) n.pageId,
        ];
        expect(withPart, [NotebookPageSamples.siteB]);
        expect(
          [for (final b in app.notebook.kept['entry-walk']!.blocks!) b.id],
          ['w-1'],
        );
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

    test('C1: merged into a page deeper inside the one that goes', () {
      NotebookPage p(String id, {String? parent}) => NotebookPage(
        id: id,
        parentId: parent,
        createdAt: DateTime(2026, 10, 1),
        lastActivityAt: DateTime(2026, 10, 1),
      );
      final data = NotebookData(
        pages: [
          p('g'),
          p('x', parent: 'g'),
          p('i', parent: 'x'),
        ],
      );
      final merged = const NoteChange.merge(['g'], [], 'i').applyTo(data);
      expect(merged.page('i')!.parentId, isNull);
      expect(merged.page('x')!.parentId, 'i');
      expect(merged.page('g'), isNull);
    });

    test('C4: activity is an entry written, its words or to-dos changed, '
        'or moved in; never a pin or a reminder', () {
      final day = DateTime(2026, 10, 1);
      final later = DateTime(2026, 10, 15, 12);
      NotebookPage p(String id) =>
          NotebookPage(id: id, createdAt: day, lastActivityAt: day);
      final n = Note(
        id: 'n',
        kind: NoteKind.text,
        body: 'Words',
        createdAt: day,
        pageId: 'a',
      );
      final data = NotebookData(notes: [n], pages: [p('a'), p('b')]);
      DateTime at(NotebookData d, String id) => d.page(id)!.lastActivityAt;
      expect(at(NoteChange.pin('n', on: true).applyTo(data), 'a'), day);
      expect(
        at(
          NoteChange.save(
            n.copyWith(remindAt: () => later),
            at: later,
          ).applyTo(data),
          'a',
        ),
        day,
      );
      expect(
        at(
          NoteChange.save(n.copyWith(body: 'New'), at: later).applyTo(data),
          'a',
        ),
        later,
      );
      expect(
        at(NoteChange.done('n', on: true, at: later).applyTo(data), 'a'),
        later,
      );
      final moved = NoteChange.moveNotes(['n'], 'b', at: later).applyTo(data);
      expect(at(moved, 'b'), later);
      expect(at(moved, 'a'), day);
    });

    test('C8: the notebook says page and entry, never note or line', () {
      for (final lang in ['en', 'ar']) {
        final l = lookupAppLocalizations(Locale(lang));
        final words = [
          l.notebookNote,
          l.notebookEmptyBody,
          l.notebookDeleteTitle,
          l.notebookCouldntKeep,
          l.notebookFilesFull,
          l.notebookPhotosFull,
          l.notebookDeleteLines(3),
          l.notebookFoldHide,
          l.notebookFoldShow,
        ];
        for (final w in words) {
          expect(
            w,
            isNot(
              matches(
                RegExp(r'notes?|lines?|ملاحظ|سطر', caseSensitive: false),
              ),
            ),
          );
        }
      }
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

    test('a row counts the entries of the page and every page under it '
        '(review 100 Part 7)', () {
      final data = NotebookPageSamples('en');
      final view = NotebookData(notes: data.notes(), pages: data.pages());
      expect(view.entryCount(NotebookPageSamples.siteA), 6);
      expect(view.entryCount(NotebookPageSamples.meetings), 1);
    });
  });
}

/// The id of the entry just sent (the only save of a new one).
String _draftlessId(TestApp app) {
  final save = app.notebook.calls.lastWhere((c) => c.startsWith('save:'));
  return save.split(':')[1];
}
