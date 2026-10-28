// Review 100 Part 3b (BH3): swipe an entry. Toward the end: Pin · Reminder
// as round buttons behind the lifted card; toward the start: Archive, at
// once on a full swipe, with Undo. Only from the card, not the screen's
// edge; one card open at a time; off while selecting; a one-time hint;
// screen readers get the same actions. "Archived ›" at the page's end. In
// English and Arabic (the directions mirror).
import 'dart:convert';

import 'package:buildvibes/features/notebook/note_draft.dart';
import 'package:buildvibes/features/notebook/notebook_page_parts.dart'
    show SelectionBar;
import 'package:buildvibes/features/notebook/notebook_state.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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

/// The hint has been seen, unless [hint].
Future<FakeNotebookRepository> _open(
  WidgetTester tester,
  String lang, {
  FakeNotebookRepository? notebook,
  NoteDraft? draft,
  bool hint = false,
  String path = _siteA,
}) async {
  final repo = notebook ?? NotebookPageSamples(lang).repository();
  await pumpApp(
    tester,
    language: lang,
    now: NotebookPageSamples.now,
    notebook: repo,
    swipeHint: hint,
    stored: {
      if (draft != null) 'notebook_draft:user-1': jsonEncode(draft.toJson()),
    },
  );
  GoRouter.of(tester.element(find.byType(Navigator).first)).push(path);
  await tester.pumpAndSettle();
  return repo;
}

NotebookData _data(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(Scaffold).first),
).read(notebookProvider).value!;

/// A swipe on [card] by [logical] toward the end (negative: the start),
/// mirrored in Arabic.
Future<void> _swipe(
  WidgetTester tester,
  String lang,
  Finder card,
  double logical,
) async {
  await tester.ensureVisible(card);
  await tester.pumpAndSettle();
  final dx = lang == 'ar' ? -logical : logical;
  await tester.timedDrag(
    card,
    Offset(dx, 0),
    const Duration(milliseconds: 300),
  );
  await tester.pumpAndSettle();
}

/// How far [card] moved along the reading direction.
double _moved(WidgetTester tester, String lang, String id, double from) {
  final x = tester.getTopLeft(_key('note-$id')).dx - from;
  return lang == 'ar' ? -x : x;
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));

    group('BH3 swipe an entry [$lang]', () {
      testWidgets('toward the end: Pin · Reminder behind it; it stays open; '
          'a tap on Pin pins it', (tester) async {
        final repo = await _open(tester, lang);
        expect(_key('note-menu-entry-pour'), findsNothing);
        final x = tester.getTopLeft(_key('note-entry-pour')).dx;
        await _swipe(tester, lang, _key('note-entry-pour'), 160);
        expect(_key('swipe-pin-entry-pour'), findsOneWidget);
        expect(_key('swipe-remind-entry-pour'), findsOneWidget);
        expect(find.text(l10n.notebookPin), findsOneWidget);
        expect(find.text(l10n.notebookReminder), findsOneWidget);
        expect(_moved(tester, lang, 'entry-pour', x), greaterThan(0));
        await tester.tap(_key('swipe-pin-entry-pour'));
        await tester.pumpAndSettle();
        expect(repo.calls, contains('pin:entry-pour:true'));
        // Closed again.
        expect(_moved(tester, lang, 'entry-pour', x), 0);
      });

      testWidgets('a short swipe springs back; a tap elsewhere closes an open '
          'one; only one is open at a time', (tester) async {
        await _open(tester, lang);
        final x = tester.getTopLeft(_key('note-entry-pour')).dx;
        await _swipe(tester, lang, _key('note-entry-pour'), 30);
        expect(_moved(tester, lang, 'entry-pour', x), 0);
        await _swipe(tester, lang, _key('note-entry-pour'), 160);
        expect(_moved(tester, lang, 'entry-pour', x), greaterThan(0));
        await _swipe(tester, lang, _key('note-entry-gate'), 160);
        expect(_moved(tester, lang, 'entry-pour', x), 0);
        expect(_moved(tester, lang, 'entry-gate', x), greaterThan(0));
        await tester.tapAt(const Offset(195, 30));
        await tester.pumpAndSettle();
        expect(_moved(tester, lang, 'entry-gate', x), 0);
      });

      testWidgets('toward the start, all the way: archived at once with '
          '"Archived · Undo"; it goes when the bar closes', (tester) async {
        final repo = await _open(tester, lang);
        await _swipe(tester, lang, _key('note-entry-pour'), -330);
        expect(_key('note-entry-pour'), findsNothing);
        expect(
          find.descendant(
            of: find.byType(SnackBar),
            matching: find.text(l10n.notebookArchivedUndo),
          ),
          findsOneWidget,
        );
        expect(repo.calls.where((c) => c.startsWith('archive')), isEmpty);
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();
        expect(repo.calls, contains('archive:entry-pour:true'));
        expect(repo.kept['entry-pour']!.archivedAt, isNotNull);
        // Kept, out of the list and its count, under "Archived ›".
        expect(
          _data(tester).entries(NotebookPageSamples.siteA).map((n) => n.id),
          isNot(contains('entry-pour')),
        );
        expect(_key('page-archived'), findsOneWidget);
      });

      testWidgets('half way toward the start shows Archive; Undo after it '
          'puts the entry back', (tester) async {
        final repo = await _open(tester, lang);
        await _swipe(tester, lang, _key('note-entry-pour'), -120);
        expect(_key('swipe-archive-entry-pour'), findsOneWidget);
        expect(find.text(l10n.notebookArchive), findsOneWidget);
        await tester.tap(_key('swipe-archive-entry-pour'));
        await tester.pumpAndSettle();
        expect(_key('note-entry-pour'), findsNothing);
        await tester.tap(find.text(l10n.daybookUndo));
        await tester.pumpAndSettle();
        expect(_key('note-entry-pour'), findsOneWidget);
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();
        expect(repo.calls.where((c) => c.startsWith('archive')), isEmpty);
      });

      testWidgets('a swipe from the screen\'s edge is the system\'s back, not '
          'the card\'s', (tester) async {
        await _open(tester, lang);
        final card = _key('note-entry-pour');
        final x = tester.getTopLeft(card).dx;
        final y = tester.getCenter(card).dy;
        final width =
            tester.view.physicalSize.width / tester.view.devicePixelRatio;
        final from = lang == 'ar' ? Offset(width - 10, y) : Offset(10, y);
        await tester.timedDragFrom(
          from,
          Offset(lang == 'ar' ? -200 : 200, 0),
          const Duration(milliseconds: 300),
        );
        await tester.pumpAndSettle();
        expect(_moved(tester, lang, 'entry-pour', x), 0);
        expect(_key('swipe-pin-entry-pour'), findsNothing);
      });

      testWidgets('off while selecting', (tester) async {
        await _open(tester, lang);
        await tester.longPress(_key('note-entry-pour'));
        await tester.pumpAndSettle();
        expect(find.byType(SelectionBar), findsOneWidget);
        final x = tester.getTopLeft(_key('note-entry-gate')).dx;
        await _swipe(tester, lang, _key('note-entry-gate'), 160);
        expect(_moved(tester, lang, 'entry-gate', x), 0);
        expect(_key('swipe-pin-entry-gate'), findsNothing);
      });

      testWidgets('screen readers: Pin, Reminder and Archive as the card\'s '
          'own actions', (tester) async {
        final semantics = tester.ensureSemantics();
        await _open(tester, lang);
        final node = tester.getSemantics(_key('swipe-card-entry-pour'));
        final labels = [
          for (final id in node.getSemanticsData().customSemanticsActionIds!)
            CustomSemanticsAction.getAction(id)!.label,
        ];
        expect(
          labels,
          containsAll([
            l10n.notebookPin,
            l10n.notebookReminder,
            l10n.notebookArchive,
          ]),
        );
        semantics.dispose();
      });

      testWidgets('the first time, the top card slides open by a third and '
          'closes after 1 s; once per person', (tester) async {
        await _open(tester, lang, hint: true);
        final card = _key('note-entry-pour');
        // Its place at rest, before the hint starts.
        final rest = tester.getTopLeft(_key('page-title')).dx;
        await tester.pump(const Duration(milliseconds: 600));
        expect(_key('swipe-pin-entry-pour'), findsOneWidget);
        final open = tester.getTopLeft(card).dx;
        expect(open, isNot(rest));
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(_key('swipe-pin-entry-pour'), findsNothing);
        // Opened again: no hint.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        GoRouter.of(tester.element(find.byType(Navigator).first)).push(_siteA);
        await tester.pump(const Duration(milliseconds: 600));
        expect(_key('swipe-pin-entry-pour'), findsNothing);
      });

      testWidgets('a Draft\'s card swipes to Discard, with Undo', (
        tester,
      ) async {
        await _open(
          tester,
          lang,
          draft: NoteDraft(
            id: 'draft-1',
            startedAt: NotebookPageSamples.now,
            title: 'Not sent',
            pageId: NotebookPageSamples.siteA,
          ),
        );
        expect(_key('note-draft-card-draft-1'), findsOneWidget);
        await _swipe(tester, lang, _key('swipe-card-draft-1'), -120);
        expect(find.text(l10n.notebookDiscardDraft), findsOneWidget);
        await tester.tap(_key('swipe-discard-draft-1'));
        await tester.pumpAndSettle();
        expect(_key('note-draft-card-draft-1'), findsNothing);
        expect(find.text(l10n.notebookDraftDiscarded), findsOneWidget);
        await tester.tap(find.text(l10n.daybookUndo));
        await tester.pumpAndSettle();
        expect(_key('note-draft-card-draft-1'), findsOneWidget);
      });
    });

    group('Archived › [$lang]', () {
      testWidgets('a quiet row at the page\'s end when it has any; it lists '
          'them newest first; Unarchive puts one back', (tester) async {
        final notebook = NotebookPageSamples(lang).repository();
        for (final (id, at) in [
          ('entry-lobby', DateTime(2026, 10, 15, 11)),
          ('entry-cubes', DateTime(2026, 10, 15, 11, 30)),
        ]) {
          notebook.kept[id] = notebook.kept[id]!.copyWith(archivedAt: () => at);
        }
        final repo = await _open(tester, lang, notebook: notebook);
        expect(_key('note-entry-lobby'), findsNothing);
        expect(find.text(l10n.notebookArchivedRow), findsOneWidget);
        await _tap(tester, _key('page-archived'));
        expect(_key('note-entry-lobby'), findsOneWidget);
        expect(_key('note-entry-cubes'), findsOneWidget);
        expect(_key('note-entry-pour'), findsNothing);
        expect(
          tester.getTopLeft(_key('note-entry-lobby')).dy,
          lessThan(tester.getTopLeft(_key('note-entry-cubes')).dy),
        );
        await _swipe(tester, lang, _key('note-entry-lobby'), -120);
        expect(find.text(l10n.notebookUnarchive), findsOneWidget);
        await tester.tap(_key('swipe-archive-entry-lobby'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();
        expect(repo.calls, contains('archive:entry-lobby:false'));
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(_key('note-entry-lobby'), findsOneWidget);
      });

      testWidgets('no archived entries: no row', (tester) async {
        await _open(tester, lang);
        expect(_key('page-archived'), findsNothing);
      });
    });
  }
}
