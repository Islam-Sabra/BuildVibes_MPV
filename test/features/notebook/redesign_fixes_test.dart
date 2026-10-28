// Review 100, the lead's check of the redesign (28 Oct): the bugs H3–H8
// and the outbox. H3 Duplicate keeps attachments; H4 the Filter's hits are
// checked against what the phone holds; H5 emptying a saved entry sends it
// to Deleted items; H6 deleted lines on their Undo are kept in the outbox;
// H7 a swipe never takes the screen's edge; H8 Delete forever confirms
// before it moves. In English and Arabic.
import 'dart:convert';

import 'package:buildvibes/data/models/note.dart';
import 'package:buildvibes/data/models/notebook_page.dart';
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

const _siteA = '/notebook/pages/${NotebookPageSamples.siteA}';

Future<TestApp> _open(
  WidgetTester tester,
  String lang, {
  FakeNotebookRepository? notebook,
  String path = _siteA,
  Map<String, Object> stored = const {},
}) async {
  final app = await pumpApp(
    tester,
    language: lang,
    now: NotebookPageSamples.now,
    notebook: notebook ?? NotebookPageSamples(lang).repository(),
    stored: stored,
  );
  GoRouter.of(tester.element(find.byType(Navigator).first)).push(path);
  await tester.pumpAndSettle();
  return app;
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));

Future<void> _barGoes(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await tester.pumpAndSettle();
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    final s = NotebookPageSamples(lang);

    testWidgets('H3: Duplicate keeps the photos; the copy is sent with its '
        'own, and doesn\'t show as waiting [$lang]', (tester) async {
      final notebook = s.repository();
      notebook.kept['entry-pour'] = notebook.kept['entry-pour']!.copyWith(
        photos: [NotePhoto(local: testPhotoPath)],
      );
      await _open(tester, lang, notebook: notebook);
      await tester.longPress(_key('note-entry-pour'));
      await tester.pumpAndSettle();
      await _tap(tester, _key('select-duplicate'));
      await _barGoes(tester);
      final copy = notebook.kept.values.singleWhere(
        (n) => n.id != 'entry-pour' && n.title == s.beforePour,
      );
      expect(notebook.calls, contains('photo:${copy.id}'));
      expect(copy.photos.single.path, startsWith('user-1/${copy.id}/'));
      final shown = _container(
        tester,
      ).read(notebookProvider).value!.all.singleWhere((n) => n.id == copy.id);
      expect(shown.waiting, isFalse);
      // Ruling 6: no "Copy" mark.
      expect(_key('note-copy-${copy.id}'), findsNothing);
    });

    testWidgets('H4: a Filter hit the phone holds as deleted or archived '
        'doesn\'t show; an Archived hit opens the page\'s archived list on '
        'it [$lang]', (tester) async {
      final notebook = s.repository()
        ..hits = [
          NotebookHit(
            pageId: NotebookPageSamples.siteA,
            noteId: 'entry-pour',
            title: s.beforePour,
            at: DateTime(2026, 10, 15, 10, 40),
          ),
          NotebookHit(
            pageId: NotebookPageSamples.siteA,
            noteId: 'entry-gate',
            title: s.pumpTitle,
            at: DateTime(2026, 10, 15, 9, 5),
          ),
        ];
      await _open(tester, lang, notebook: notebook);
      // entry-gate deleted, its Undo still showing (not sent yet).
      await tester.longPress(_key('note-entry-gate'));
      await tester.pumpAndSettle();
      await _tap(tester, _key('select-delete'));
      await _tap(tester, _key('page-filter'));
      await _tap(tester, _key('filter-show-todos_open'));
      expect(_key('filter-hit-entry-pour'), findsOneWidget);
      expect(_key('filter-hit-entry-gate'), findsNothing);
      // Archived: the hit opens Archived on it.
      final lobby = notebook.kept['entry-lobby']!;
      notebook.kept['entry-lobby'] = lobby.copyWith(
        archivedAt: () => DateTime(2026, 10, 15, 11),
      );
      notebook.hits = [
        NotebookHit(
          pageId: NotebookPageSamples.siteA,
          noteId: 'entry-lobby',
          title: lobby.title,
          at: lobby.createdAt,
        ),
      ];
      _container(tester).invalidate(notebookProvider);
      await tester.pumpAndSettle();
      await _tap(tester, _key('filter-chip-page'));
      await _tap(tester, _key('menu-back'));
      await _tap(tester, _key('filter-show-archived'));
      await _tap(tester, _key('filter-hit-entry-lobby'));
      expect(find.text(l10n.notebookArchivedRow), findsWidgets);
      expect(_key('note-entry-lobby'), findsOneWidget);
    });

    testWidgets('H5: an emptied saved entry, then Back, goes to Deleted '
        'items, never deleted for good [$lang]', (tester) async {
      final app = await _open(tester, lang);
      await _tap(tester, _key('note-entry-gate'));
      await tester.enterText(_key('note-title'), '');
      await tester.enterText(find.byKey(const Key('page-field-t:b-3')), '');
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text(l10n.notebookUndoDeleted), findsOneWidget);
      await _barGoes(tester);
      expect(app.notebook.calls, contains('delete-entries:entry-gate'));
      expect(app.notebook.calls, isNot(contains('delete:entry-gate')));
    });

    testWidgets('H6: lines deleted from a saved entry, on their Undo, are '
        'kept in the phone\'s outbox: an app closed then loses nothing '
        '[$lang]', (tester) async {
      final app = await _open(tester, lang);
      await _tap(tester, _key('note-entry-pour'));
      await tester.tap(
        find.text(s.t('Check the rebar cover', 'فحص غطاء الحديد')),
      );
      await tester.pumpAndSettle();
      await tester.longPress(_key('note-marker-b-2'));
      await tester.pumpAndSettle();
      await _tap(tester, _key('select-delete'));
      final held = app.prefs.getString('notebook_held:user-1');
      expect(held, isNotNull);
      final change = jsonDecode(held!) as Map<String, dynamic>;
      expect(change['op'], 'delete_lines');
      expect(change['id'], 'entry-pour');
      expect(change['ids'], ['b-2']);
      // Undo takes it back off the phone.
      await tester.tap(find.text(l10n.spacesUndo));
      await tester.pumpAndSettle();
      expect(app.prefs.getString('notebook_held:user-1'), isNull);
    });

    testWidgets('H7: a drag that starts at the screen\'s edge is the back '
        'gesture\'s, even once it has moved past the edge [$lang]', (
      tester,
    ) async {
      await _open(tester, lang);
      final card = _key('note-entry-pour');
      final x = tester.getTopLeft(card).dx;
      final y = tester.getCenter(card).dy;
      final width =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      // Down 20 from the edge: past the slop it is well inside.
      final from = lang == 'ar' ? Offset(width - 20, y) : Offset(20, y);
      await tester.timedDragFrom(
        from,
        Offset(lang == 'ar' ? -200 : 200, 0),
        const Duration(milliseconds: 300),
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(card).dx, x);
      expect(_key('swipe-pin-entry-pour'), findsNothing);
    });

    testWidgets('H8: Delete forever asks first; Cancel leaves the card where '
        'it was [$lang]', (tester) async {
      final notebook = s.repository()
        ..deletedList = [
          DeletedItem(
            kind: DeletedKind.entry,
            id: 'gone-pump',
            title: s.pumpTitle,
            pageId: NotebookPageSamples.siteA,
            pageTitle: s.siteATitle,
            deletedAt: DateTime(2026, 10, 15, 9),
            purgeAt: DateTime(2026, 11, 14, 9),
          ),
        ];
      await _open(tester, lang, notebook: notebook, path: '/notebook/deleted');
      final row = _key('deleted-gone-pump');
      final x = tester.getTopLeft(row).dx;
      await tester.timedDrag(
        row,
        Offset(lang == 'ar' ? 330 : -330, 0),
        const Duration(milliseconds: 300),
      );
      // The question comes before the card goes anywhere.
      await tester.pump();
      expect(find.text(l10n.notebookDeleteForeverTitle), findsOneWidget);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.commonCancel));
      await tester.pumpAndSettle();
      expect(row, findsOneWidget);
      expect(tester.getTopLeft(row).dx, x);
      expect(notebook.calls.where((c) => c.startsWith('forever')), isEmpty);
    });
  }
}
