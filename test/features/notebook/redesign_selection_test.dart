// Review 100 Part 0 and Part 3 (BH2, BH12): one product language. Holding
// an entry or a line's start selects it; one bar at the bottom acts on what
// is selected (Move · Duplicate · Delete, Delete last in red); the line
// menu keeps only the line's structure. Deleting goes to Deleted items
// (99B B3), with Undo for 5 s. In English and Arabic.
import 'dart:convert';

import 'package:buildvibes/data/models/post_page.dart';
import 'package:buildvibes/features/notebook/note_draft.dart';
import 'package:buildvibes/features/notebook/notebook_page_parts.dart'
    show SelectionBar;
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

Future<void> _hold(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.longPress(f.first);
  await tester.pumpAndSettle();
}

const _siteA = '/notebook/pages/${NotebookPageSamples.siteA}';

Future<FakeNotebookRepository> _open(
  WidgetTester tester,
  String lang, {
  FakeNotebookRepository? notebook,
  NoteDraft? draft,
}) async {
  final repo = notebook ?? NotebookPageSamples(lang).repository();
  await pumpApp(
    tester,
    language: lang,
    now: NotebookPageSamples.now,
    notebook: repo,
    stored: {
      if (draft != null) 'notebook_draft:user-1': jsonEncode(draft.toJson()),
    },
  );
  GoRouter.of(tester.element(find.byType(Navigator).first)).push(_siteA);
  await tester.pumpAndSettle();
  return repo;
}

NotebookData _data(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(Scaffold).first),
).read(notebookProvider).value!;

/// The undo bar closes by itself after its time.
Future<void> _barGoes(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await tester.pumpAndSettle();
}

/// The selection bar's actions, in their order.
List<String> _actions(WidgetTester tester) => [
  for (final e
      in find
          .descendant(
            of: find.byType(SelectionBar),
            matching: find.byWidgetPredicate(
              (w) => w is InkWell && '${w.key}'.contains('select-'),
            ),
          )
          .evaluate())
    '${(e.widget as InkWell).key}'.replaceAll(RegExp(r"[\[\]<>']"), ''),
];

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    final s = NotebookPageSamples(lang);

    group('BH2 an entry selected [$lang]', () {
      testWidgets('hold: ✕ and "1 selected" on top; Move · Duplicate · '
          'Delete at the bottom; Write in this page hides', (tester) async {
        await _open(tester, lang);
        await _hold(tester, _key('note-entry-pour'));
        expect(_key('selection-close'), findsOneWidget);
        expect(find.text(l10n.notebookSelected(1)), findsOneWidget);
        // Review 106 T4: one entry's actions are its status icons.
        expect(_actions(tester), [
          'select-move',
          'select-duplicate',
          'select-delete',
        ]);
        expect(_key('page-write'), findsNothing);
        // A tap on another adds it; for two or more, Pin (review 106 T4).
        await _tap(tester, _key('note-entry-gate'));
        expect(find.text(l10n.notebookSelected(2)), findsOneWidget);
        expect(_actions(tester), [
          'select-pin',
          'select-move',
          'select-duplicate',
          'select-delete',
        ]);
        // Unselecting the last one leaves selection mode.
        await _tap(tester, _key('note-entry-gate'));
        await _tap(tester, _key('note-entry-pour'));
        expect(find.byType(SelectionBar), findsNothing);
        expect(_key('page-write'), findsOneWidget);
      });

      testWidgets('Delete: asked first (review 104 N6), then gone at once with '
          '"Deleted · Undo"; '
          'it goes to Deleted items when the bar closes', (tester) async {
        final repo = await _open(tester, lang);
        await _hold(tester, _key('note-entry-pour'));
        await _tap(tester, _key('note-entry-gate'));
        await _tap(tester, _key('select-delete'));
        await _tap(tester, _key('bv-dialog-confirm'));
        expect(find.text(l10n.notebookDeleteTitle), findsNothing);
        expect(find.text(l10n.notebookUndoDeleted), findsOneWidget);
        expect(_key('note-entry-pour'), findsNothing);
        expect(_key('note-entry-gate'), findsNothing);
        expect(find.byType(SelectionBar), findsNothing);
        expect(repo.calls.where((c) => c.startsWith('delete')), isEmpty);
        await _barGoes(tester);
        expect(repo.calls, contains('delete-entries:entry-pour,entry-gate'));
        // Kept on the server, in Deleted items: the list still leaves it
        // out after the notebook reads again.
        expect(repo.kept['entry-pour']!.deletedAt, isNotNull);
        ProviderScope.containerOf(
          tester.element(find.byType(Scaffold).first),
        ).invalidate(notebookProvider);
        await tester.pumpAndSettle();
        expect(_key('note-entry-pour'), findsNothing);
      });

      testWidgets('Undo puts them back, and nothing is sent', (tester) async {
        final repo = await _open(tester, lang);
        await _hold(tester, _key('note-entry-pour'));
        await _tap(tester, _key('select-delete'));
        await _tap(tester, _key('bv-dialog-confirm'));
        await tester.tap(find.text(l10n.daybookUndo));
        await tester.pumpAndSettle();
        expect(_key('note-entry-pour'), findsOneWidget);
        await _barGoes(tester);
        expect(repo.calls.where((c) => c.startsWith('delete')), isEmpty);
      });

      testWidgets('Duplicate: a copy right under each, the same time, marked '
          '"Copy", without its reminder; "Duplicated · Undo"', (tester) async {
        final notebook = NotebookPageSamples(lang).repository();
        final pour = notebook.kept['entry-pour']!;
        notebook.kept['entry-pour'] = pour.copyWith(
          remindAt: () => DateTime(2026, 10, 16, 9),
        );
        final repo = await _open(tester, lang, notebook: notebook);
        await _hold(tester, _key('note-entry-pour'));
        await _tap(tester, _key('select-duplicate'));
        expect(find.text(l10n.notebookUndoDuplicated), findsOneWidget);
        expect(find.byType(SelectionBar), findsNothing);
        final copies = _data(tester).notes
            .where((n) => n.id != 'entry-pour' && n.title == s.beforePour)
            .toList();
        expect(copies, hasLength(1));
        final copy = copies.single;
        expect(copy.createdAt, pour.createdAt);
        expect(copy.remindAt, isNull);
        expect(copy.blocks!.length, pour.blocks!.length);
        expect(
          copy.blocks!.map((b) => b.id).toSet().intersection({'b-1', 'b-2'}),
          isEmpty,
        );
        // Right under the one it copies.
        expect(
          tester.getTopLeft(_key('note-${copy.id}')).dy,
          greaterThan(tester.getTopLeft(_key('note-entry-pour')).dy),
        );
        expect(
          tester.getTopLeft(_key('note-${copy.id}')).dy,
          lessThan(tester.getTopLeft(_key('note-entry-gate')).dy),
        );
        await _barGoes(tester);
        expect(repo.calls, contains('save:${copy.id}'));
        expect(repo.kept[copy.id]!.remindAt, isNull);
      });

      testWidgets('Undo after Duplicate: no copy, nothing sent', (
        tester,
      ) async {
        final repo = await _open(tester, lang);
        await _hold(tester, _key('note-entry-pour'));
        await _tap(tester, _key('select-duplicate'));
        await tester.tap(find.text(l10n.daybookUndo));
        await tester.pumpAndSettle();
        await _barGoes(tester);
        expect(
          _data(tester).notes.where((n) => n.title == s.beforePour),
          hasLength(1),
        );
        expect(repo.calls.where((c) => c.startsWith('save:')), isEmpty);
      });

      testWidgets('Move: the page list at once, the current page marked; one '
          'tap moves them all, then "Moved to {page} · Open"', (tester) async {
        final repo = await _open(tester, lang);
        await _hold(tester, _key('note-entry-pour'));
        await _tap(tester, _key('note-entry-gate'));
        await _tap(tester, _key('select-move'));
        await _tap(tester, _key('page-pick-${NotebookPageSamples.level3}'));
        expect(
          repo.calls,
          contains(
            'notes-move:entry-pour,entry-gate:${NotebookPageSamples.level3}',
          ),
        );
        expect(
          find.text(l10n.notebookMovedTo(s.t('Level 3', 'الطابق 3'))),
          findsOneWidget,
        );
        expect(find.byType(SelectionBar), findsNothing);
        await tester.tap(find.text(l10n.notebookOpen));
        await tester.pumpAndSettle();
        expect(_key('note-entry-pour'), findsOneWidget);
        expect(_key('note-entry-gate'), findsOneWidget);
      });

      testWidgets('Back leaves selection mode first', (tester) async {
        await _open(tester, lang);
        await _hold(tester, _key('note-entry-pour'));
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(SelectionBar), findsNothing);
        expect(_key('note-entry-pour'), findsOneWidget);
      });
    });

    group('BH12 a line selected while writing [$lang]', () {
      NoteDraft draft() => NoteDraft(
        id: 'draft-1',
        startedAt: NotebookPageSamples.now,
        title: s.beforePour,
        blocks: [
          PageText('l-0', 'Plain line'),
          PageNumbered('l-1', 'Clean the formwork'),
          PageNumbered('l-2', 'Check the rebar cover'),
          PageNumbered('l-3', 'Under it', indent: 1),
        ],
        pageId: NotebookPageSamples.siteA,
      );

      Future<void> write(WidgetTester tester) async {
        await _tap(tester, _key('note-draft-card-draft-1'));
        await tester.tap(find.text('Check the rebar cover'));
        await tester.pumpAndSettle();
      }

      testWidgets('holding a list line\'s marker selects it with its '
          'children; the keyboard goes down; ✕ · "1 line selected"; the same '
          'bar', (tester) async {
        await _open(tester, lang, draft: draft());
        await write(tester);
        tester.testTextInput.log.clear();
        await _hold(tester, _key('note-marker-l-2'));
        expect(
          FocusManager.instance.primaryFocus?.context?.widget,
          isNot(isA<EditableText>()),
        );
        expect(find.text(l10n.notebookLinesSelected(1)), findsOneWidget);
        expect(_key('line-selected-l-2'), findsOneWidget);
        expect(_key('line-selected-l-3'), findsOneWidget);
        expect(_key('line-selected-l-1'), findsNothing);
        expect(_actions(tester), [
          'select-move',
          'select-duplicate',
          'select-delete',
        ]);
        // The writing bar steps aside while selecting.
        expect(_key('note-tools'), findsNothing);
        // A tap on another line's start adds it.
        await _tap(tester, _key('note-marker-l-1'));
        expect(find.text(l10n.notebookLinesSelected(2)), findsOneWidget);
        // ✕: the keyboard comes back on the line being written.
        await _tap(tester, _key('selection-close'));
        expect(find.byType(SelectionBar), findsNothing);
        expect(_key('note-tools'), findsOneWidget);
        expect(
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<EditableText>(),
          isNotNull,
        );
      });

      testWidgets('a plain line\'s start strip selects it too; holding the '
          'words does not', (tester) async {
        await _open(tester, lang, draft: draft());
        await write(tester);
        await _hold(tester, _key('note-start-l-0'));
        expect(find.text(l10n.notebookLinesSelected(1)), findsOneWidget);
        expect(_key('line-selected-l-0'), findsOneWidget);
        await _tap(tester, _key('selection-close'));
        await _hold(tester, find.text('Clean the formwork'));
        expect(find.byType(SelectionBar), findsNothing);
      });

      testWidgets('Duplicate and Delete act on the selected lines, with '
          'Undo', (tester) async {
        await _open(tester, lang, draft: draft());
        await write(tester);
        await _hold(tester, _key('note-marker-l-2'));
        await _tap(tester, _key('select-duplicate'));
        expect(find.text(l10n.notebookUndoDuplicated), findsOneWidget);
        expect(find.text('Check the rebar cover'), findsNWidgets(2));
        expect(find.text('Under it'), findsNWidgets(2));
        await tester.tap(find.text(l10n.spacesUndo));
        await tester.pumpAndSettle();
        expect(find.text('Check the rebar cover'), findsOneWidget);
        await _hold(tester, _key('note-marker-l-2'));
        await _tap(tester, _key('select-delete'));
        await _tap(tester, _key('bv-dialog-confirm'));
        expect(find.text(l10n.notebookUndoDeleted), findsOneWidget);
        expect(find.text('Check the rebar cover'), findsNothing);
        expect(find.text('Under it'), findsNothing);
        expect(find.byType(SelectionBar), findsNothing);
      });

      testWidgets('BH10: ⋮⋮ keeps the line\'s structure only: no Duplicate, '
          'Delete or Move to page…', (tester) async {
        await _open(tester, lang, draft: draft());
        await write(tester);
        await _tap(tester, _key('page-handle-l-2'));
        expect(_key('page-block-menu'), findsOneWidget);
        expect(_key('page-turn-into'), findsOneWidget);
        expect(_key('page-duplicate'), findsNothing);
        expect(_key('page-block-delete'), findsNothing);
        expect(_key('page-move-to-page'), findsNothing);
      });

      testWidgets('lines deleted from a saved entry go to Deleted items as '
          '"Part of an entry"; its save then starts from the new version', (
        tester,
      ) async {
        final notebook = NotebookPageSamples(lang).repository();
        final repo = await _open(tester, lang, notebook: notebook);
        await _tap(tester, _key('note-entry-pour'));
        await tester.tap(
          find.text(s.t('Check the rebar cover', 'فحص غطاء الحديد')),
        );
        await tester.pumpAndSettle();
        await _hold(tester, _key('note-marker-b-2'));
        await _tap(tester, _key('select-delete'));
        await _tap(tester, _key('bv-dialog-confirm'));
        await _barGoes(tester);
        expect(
          repo.calls.where((c) => c.startsWith('delete-lines:entry-pour:b-2')),
          hasLength(1),
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(repo.bases['entry-pour'], 2);
        expect(repo.kept['entry-pour']!.blocks!.map((b) => b.id), ['b-1']);
      });
    });
  }
}
