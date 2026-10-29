// Review 104, the lead's check, F1 (an N6 gap): a saved entry left empty
// after editing is a delete, so it asks first, like every other one:
// "Delete this empty entry?", Cancel · Delete. Cancel brings the editor
// back with the empty entry; Delete goes on as before, with "Deleted ·
// Undo". The app going behind asks nothing and keeps the edit. In English
// and Arabic.
import 'package:buildvibes/data/models/note.dart';
import 'package:buildvibes/data/models/post_page.dart';
import 'package:buildvibes/features/notebook/note_draft.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/notebook_fakes.dart';
import '../../helpers/notebook_samples.dart';
import '../../helpers/pump_app.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

const _page = '/notebook/pages/${FakeNotebookRepository.myNotesId}';

Note _saved() => Note(
  id: 'entry-1',
  kind: NoteKind.text,
  title: 'Pour',
  blocks: [PageText('s-1', 'Clean the formwork')],
  body: 'Pour\nClean the formwork',
  createdAt: DateTime(2026, 10, 15, 9),
  pageId: FakeNotebookRepository.myNotesId,
);

/// The saved entry opened and emptied.
Future<TestApp> _emptied(WidgetTester tester, String lang) async {
  final app = await pumpApp(
    tester,
    language: lang,
    now: NotebookSamples.now,
    notebook: FakeNotebookRepository(notes: [_saved()]),
  );
  GoRouter.of(tester.element(find.byType(Navigator).first)).push(_page);
  await tester.pumpAndSettle();
  await _tap(tester, _key('note-entry-1'));
  await tester.enterText(_key('note-title'), '');
  await tester.enterText(_key('page-field-t:s-1'), '');
  await tester.pumpAndSettle();
  return app;
}

NoteDraft? _drafted(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(Scaffold).first),
).read(noteDraftProvider);

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));

    group('F1 an emptied entry asks first [$lang]', () {
      testWidgets('Done: "Delete this empty entry?" with Cancel · Delete; '
          'Cancel brings the editor back with the empty entry', (tester) async {
        final app = await _emptied(tester, lang);
        await _tap(tester, _key('writing-post'));
        expect(_key('bv-dialog'), findsOneWidget);
        expect(
          find.descendant(
            of: _key('bv-dialog'),
            matching: find.text(l10n.notebookConfirmDeleteEmpty),
          ),
          findsOneWidget,
        );
        expect(
          tester.widget<BvButton>(_key('bv-dialog-cancel')).label,
          l10n.commonCancel,
        );
        final delete = tester.widget<BvButton>(_key('bv-dialog-confirm'));
        expect(delete.label, l10n.pageDelete);
        expect(delete.style, BvButtonStyle.destructive);
        // Nothing has gone yet.
        expect(find.text(l10n.notebookUndoDeleted), findsNothing);

        await _tap(tester, _key('bv-dialog-cancel'));
        expect(_key('bv-dialog'), findsNothing);
        expect(_key('note-tools'), findsOneWidget);
        expect(
          tester.widget<TextField>(_key('note-title')).controller!.text,
          isEmpty,
        );
        expect(_drafted(tester)?.editing?.id, 'entry-1');
        expect(find.text(l10n.notebookUndoDeleted), findsNothing);
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();
        expect(
          app.notebook.calls.where((c) => c.startsWith('delete')),
          isEmpty,
        );
        expect(app.notebook.kept['entry-1']!.deletedAt, isNull);
      });

      testWidgets('Back, then Delete: gone with "Deleted · Undo", to '
          'Deleted items when the bar closes', (tester) async {
        final app = await _emptied(tester, lang);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: _key('bv-dialog'),
            matching: find.text(l10n.notebookConfirmDeleteEmpty),
          ),
          findsOneWidget,
        );
        await _tap(tester, _key('bv-dialog-confirm'));
        expect(find.text(l10n.notebookUndoDeleted), findsOneWidget);
        expect(_key('note-entry-1'), findsNothing);
        expect(_drafted(tester), isNull);
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();
        expect(app.notebook.calls, contains('delete-entries:entry-1'));
      });

      testWidgets('the app going behind asks nothing and keeps the edit', (
        tester,
      ) async {
        final app = await _emptied(tester, lang);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        await tester.pumpAndSettle();
        expect(_key('bv-dialog'), findsNothing);
        expect(_drafted(tester)?.editing?.id, 'entry-1');
        expect(
          app.notebook.calls.where((c) => c.startsWith('delete')),
          isEmpty,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
      });
    });
  }
}
