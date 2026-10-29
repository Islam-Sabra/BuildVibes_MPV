// Review 104 N6: every delete in the notebook asks first: entries, pages,
// lines selected with the bottom bar and a Draft's Discard. "Delete this
// entry?", "It goes to Deleted items for 30 days." (the person's 7, 30 or
// 90), Cancel · Delete with Delete in red. After Delete the "Deleted ·
// Undo" bar still shows. A swipe's Archive is not a delete: it asks
// nothing. In English and Arabic.
import 'dart:convert';

import 'package:buildvibes/data/models/post_page.dart';
import 'package:buildvibes/features/notebook/note_draft.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_button.dart';
import 'package:flutter/material.dart';
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
  String path = _siteA,
  NoteDraft? draft,
  int keep = 30,
}) async {
  final repo = NotebookPageSamples(lang).repository()..keep = keep;
  await pumpApp(
    tester,
    language: lang,
    now: NotebookPageSamples.now,
    notebook: repo,
    stored: {
      if (draft != null) 'notebook_draft:user-1': jsonEncode(draft.toJson()),
    },
  );
  GoRouter.of(tester.element(find.byType(Navigator).first)).push(path);
  await tester.pumpAndSettle();
  return repo;
}

/// The confirm, as asked: its title and body, Cancel · Delete, Delete red.
void _asks(
  WidgetTester tester,
  AppLocalizations l10n,
  String title,
  String body,
) {
  expect(_key('bv-dialog'), findsOneWidget);
  expect(
    find.descendant(of: _key('bv-dialog'), matching: find.text(title)),
    findsOneWidget,
  );
  expect(
    find.descendant(of: _key('bv-dialog'), matching: find.text(body)),
    findsOneWidget,
  );
  final cancel = tester.widget<BvButton>(_key('bv-dialog-cancel'));
  final delete = tester.widget<BvButton>(_key('bv-dialog-confirm'));
  expect(cancel.label, l10n.commonCancel);
  expect(delete.label, l10n.pageDelete);
  expect(delete.style, BvButtonStyle.destructive);
}

Future<void> _swipe(
  WidgetTester tester,
  String lang,
  Finder card,
  double logical,
) async {
  await tester.ensureVisible(card);
  await tester.pumpAndSettle();
  await tester.timedDrag(
    card,
    Offset(lang == 'ar' ? -logical : logical, 0),
    const Duration(milliseconds: 300),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    final s = NotebookPageSamples(lang);

    group('N6 confirm before delete [$lang]', () {
      testWidgets('entries: "Delete these entries?" with the days kept; '
          'Cancel keeps them; Delete, then "Deleted · Undo"', (tester) async {
        final repo = await _open(tester, lang, keep: 7);
        await _hold(tester, _key('note-entry-pour'));
        await _tap(tester, _key('select-delete'));
        _asks(
          tester,
          l10n,
          l10n.notebookConfirmDeleteEntries(1),
          l10n.notebookConfirmDeleteKeptFor(7),
        );
        await _tap(tester, _key('bv-dialog-cancel'));
        expect(_key('bv-dialog'), findsNothing);
        expect(_key('note-entry-pour'), findsOneWidget);
        expect(find.text(l10n.notebookUndoDeleted), findsNothing);
        // Cancel keeps them selected.
        expect(_key('select-delete'), findsOneWidget);
        await _tap(tester, _key('note-entry-gate'));
        await _tap(tester, _key('select-delete'));
        expect(find.text(l10n.notebookConfirmDeleteEntries(2)), findsOneWidget);
        await _tap(tester, _key('bv-dialog-confirm'));
        expect(_key('note-entry-pour'), findsNothing);
        expect(_key('note-entry-gate'), findsNothing);
        expect(find.text(l10n.notebookUndoDeleted), findsOneWidget);
        await tester.tap(find.text(l10n.daybookUndo));
        await tester.pumpAndSettle();
        expect(_key('note-entry-pour'), findsOneWidget);
        expect(repo.calls.where((c) => c.startsWith('delete')), isEmpty);
      });

      testWidgets('a page from its menu: "Delete this page and everything '
          'in it?"; Cancel keeps it', (tester) async {
        final repo = await _open(
          tester,
          lang,
          path: '/notebook/pages/${NotebookPageSamples.siteB}',
          keep: 90,
        );
        await _tap(tester, _key('page-more'));
        await _tap(tester, _key('page-menu-delete'));
        _asks(
          tester,
          l10n,
          l10n.notebookConfirmDeletePages(1),
          l10n.notebookConfirmDeleteKeptFor(90),
        );
        await _tap(tester, _key('bv-dialog-cancel'));
        expect(find.text(l10n.notebookPagesDeleted(1)), findsNothing);
        await _tap(tester, _key('page-more'));
        await _tap(tester, _key('page-menu-delete'));
        await _tap(tester, _key('bv-dialog-confirm'));
        expect(find.text(l10n.notebookPagesDeleted(1)), findsOneWidget);
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();
        expect(
          repo.calls,
          contains('page-delete:${NotebookPageSamples.siteB}'),
        );
      });

      testWidgets('pages selected in the list: the same confirm', (
        tester,
      ) async {
        await _open(tester, lang, path: '/notebook');
        await _hold(tester, _key('page-${NotebookPageSamples.phones}'));
        await _tap(tester, _key('select-delete'));
        _asks(
          tester,
          l10n,
          l10n.notebookConfirmDeletePages(1),
          l10n.notebookConfirmDeleteKeptFor(30),
        );
        await _tap(tester, _key('bv-dialog-cancel'));
        expect(_key('page-${NotebookPageSamples.phones}'), findsOneWidget);
        await _tap(tester, _key('select-delete'));
        await _tap(tester, _key('bv-dialog-confirm'));
        expect(_key('page-${NotebookPageSamples.phones}'), findsNothing);
        expect(find.text(l10n.notebookPagesDeleted(1)), findsOneWidget);
      });

      testWidgets('lines of a saved entry: "Delete these lines?", kept in '
          'Deleted items; Cancel keeps them', (tester) async {
        await _open(tester, lang);
        await _tap(tester, _key('note-entry-pour'));
        await tester.tap(
          find.text(s.t('Check the rebar cover', 'فحص غطاء الحديد')),
        );
        await tester.pumpAndSettle();
        await _hold(tester, _key('note-marker-b-2'));
        await _tap(tester, _key('select-delete'));
        _asks(
          tester,
          l10n,
          l10n.notebookConfirmDeleteLines(1),
          l10n.notebookConfirmDeleteKeptFor(30),
        );
        await _tap(tester, _key('bv-dialog-cancel'));
        expect(
          find.text(s.t('Check the rebar cover', 'فحص غطاء الحديد')),
          findsOneWidget,
        );
        expect(find.text(l10n.notebookUndoDeleted), findsNothing);
        await _tap(tester, _key('select-delete'));
        await _tap(tester, _key('bv-dialog-confirm'));
        expect(
          find.text(s.t('Check the rebar cover', 'فحص غطاء الحديد')),
          findsNothing,
        );
        expect(find.text(l10n.notebookUndoDeleted), findsOneWidget);
      });

      testWidgets('lines never saved: the confirm says they aren\'t kept', (
        tester,
      ) async {
        await _open(
          tester,
          lang,
          draft: NoteDraft(
            id: 'draft-1',
            startedAt: NotebookPageSamples.now,
            title: s.beforePour,
            blocks: [
              PageNumbered('l-1', 'Clean the formwork'),
              PageNumbered('l-2', 'Check the rebar cover'),
            ],
            pageId: NotebookPageSamples.siteA,
          ),
        );
        await _tap(tester, _key('note-draft-card-draft-1'));
        await tester.tap(find.text('Check the rebar cover'));
        await tester.pumpAndSettle();
        await _hold(tester, _key('note-marker-l-2'));
        await _tap(tester, _key('note-marker-l-1'));
        await _tap(tester, _key('select-delete'));
        _asks(
          tester,
          l10n,
          l10n.notebookConfirmDeleteLines(2),
          l10n.notebookConfirmDeleteNotKept,
        );
        await _tap(tester, _key('bv-dialog-confirm'));
        expect(find.text('Clean the formwork'), findsNothing);
        expect(find.text(l10n.notebookUndoDeleted), findsOneWidget);
      });

      final draft = NoteDraft(
        id: 'draft-1',
        startedAt: NotebookPageSamples.now,
        title: 'Not sent',
        pageId: NotebookPageSamples.siteA,
      );

      testWidgets('a Draft swiped to Discard: "Delete this draft?"; Cancel '
          'keeps it; Delete, then "Draft discarded · Undo"', (tester) async {
        await _open(tester, lang, draft: draft);
        await _swipe(tester, lang, _key('swipe-card-draft-1'), -120);
        await tester.tap(_key('swipe-discard-draft-1'));
        await tester.pumpAndSettle();
        _asks(
          tester,
          l10n,
          l10n.notebookConfirmDeleteDraft,
          l10n.notebookConfirmDeleteNotKept,
        );
        await _tap(tester, _key('bv-dialog-cancel'));
        expect(_key('note-draft-card-draft-1'), findsOneWidget);
        await _swipe(tester, lang, _key('swipe-card-draft-1'), -120);
        await tester.tap(_key('swipe-discard-draft-1'));
        await tester.pumpAndSettle();
        await _tap(tester, _key('bv-dialog-confirm'));
        expect(_key('note-draft-card-draft-1'), findsNothing);
        expect(find.text(l10n.notebookDraftDiscarded), findsOneWidget);
        await tester.tap(find.text(l10n.daybookUndo));
        await tester.pumpAndSettle();
        expect(_key('note-draft-card-draft-1'), findsOneWidget);
      });

      testWidgets('the entry being written, Discard at the top: the same '
          'confirm; Cancel goes back to writing', (tester) async {
        await _open(tester, lang, draft: draft);
        await _tap(tester, _key('note-draft-card-draft-1'));
        await _tap(tester, _key('writing-discard'));
        _asks(
          tester,
          l10n,
          l10n.notebookConfirmDeleteDraft,
          l10n.notebookConfirmDeleteNotKept,
        );
        await _tap(tester, _key('bv-dialog-cancel'));
        expect(_key('note-tools'), findsOneWidget);
        await _tap(tester, _key('writing-discard'));
        await _tap(tester, _key('bv-dialog-confirm'));
        expect(_key('note-tools'), findsNothing);
        expect(_key('note-draft-card-draft-1'), findsNothing);
        expect(find.text(l10n.notebookDiscarded), findsOneWidget);
      });

      testWidgets('Archive on the swipe is not a delete: it asks nothing', (
        tester,
      ) async {
        await _open(tester, lang);
        await _swipe(tester, lang, _key('note-entry-pour'), -160);
        await tester.tap(_key('swipe-archive-entry-pour'));
        await tester.pumpAndSettle();
        expect(_key('bv-dialog'), findsNothing);
        expect(_key('note-entry-pour'), findsNothing);
        expect(_key('undo-bar-action'), findsOneWidget);
      });
    });
  }
}
