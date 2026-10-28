// Review 100 Parts 7 and 8 (BH1, BH9, BH11): each page row reads
// "{n} entries · {when}" (no to-dos, no first line); New entry is a round
// button at the bottom end; Filter · Search · Calendar on top. Filter is a
// compact card: Show (one choice) and In (a page); with it on, chips under
// the top bar and the matching entries grouped by page. Search keeps the
// filter. In English and Arabic.
import 'package:buildvibes/data/models/notebook_page.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
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

Future<FakeNotebookRepository> _open(
  WidgetTester tester,
  String lang, {
  FakeNotebookRepository? notebook,
  String path = '/notebook',
}) async {
  final repo = notebook ?? NotebookPageSamples(lang).repository();
  await pumpApp(
    tester,
    language: lang,
    now: NotebookPageSamples.now,
    notebook: repo,
  );
  GoRouter.of(tester.element(find.byType(Navigator).first)).push(path);
  await tester.pumpAndSettle();
  return repo;
}

/// x along the reading direction.
double _along(WidgetTester tester, String lang, Finder f) {
  final x = tester.getCenter(f).dx;
  return lang == 'ar' ? -x : x;
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    final s = NotebookPageSamples(lang);

    List<NotebookHit> hits() => [
      NotebookHit(
        pageId: NotebookPageSamples.siteA,
        noteId: 'entry-pour',
        title: s.beforePour,
        at: DateTime(2026, 10, 15, 10, 40),
      ),
      NotebookHit(
        pageId: NotebookPageSamples.siteB,
        noteId: 'entry-snags',
        title: s.t('Snags, ground floor', 'ملاحظات، الطابق الأرضي'),
        at: DateTime(2026, 10, 14, 16, 20),
      ),
    ];

    group('BH1 the pages list [$lang]', () {
      testWidgets('"{n} entries · {when}" under each title; no to-dos and no '
          'first line', (tester) async {
        await _open(tester, lang);
        Finder inRow(String page, Finder f) =>
            find.descendant(of: _key('page-$page'), matching: f);
        // Site A: its 4 entries and its sub-pages' 2, today.
        expect(
          inRow(
            NotebookPageSamples.siteA,
            find.text(l10n.notebookRowLine(6, l10n.notebookRowToday)),
          ),
          findsOneWidget,
        );
        // Meetings: one entry, its last on Thu 8 Oct.
        expect(
          find.descendant(
            of: _key('page-${NotebookPageSamples.meetings}'),
            matching: find.textContaining(l10n.notebookRowLine(1, '').trim()),
          ),
          findsOneWidget,
        );
        expect(_key('page-todos'), findsNothing);
        expect(find.textContaining(s.beforePour), findsNothing);
      });

      testWidgets('an archived or deleted entry isn\'t counted', (
        tester,
      ) async {
        final notebook = s.repository();
        notebook.kept['entry-lobby'] = notebook.kept['entry-lobby']!.copyWith(
          archivedAt: () => DateTime(2026, 10, 15, 11),
        );
        notebook.kept['entry-cubes'] = notebook.kept['entry-cubes']!.copyWith(
          deletedAt: () => DateTime(2026, 10, 15, 11),
        );
        await _open(tester, lang, notebook: notebook);
        expect(
          find.text(l10n.notebookRowLine(4, l10n.notebookRowToday)),
          findsOneWidget,
        );
      });

      testWidgets('Arabic counts: 1, 2, 3–10, 11+', (tester) async {
        expect(
          [
            for (final n in [1, 2, 3, 11]) l10n.notebookRowLine(n, 'x'),
          ],
          lang == 'ar'
              ? [
                  'تدوينة واحدة · x',
                  'تدوينتان · x',
                  '3 تدوينات · x',
                  '11 تدوينة · x',
                ]
              : [
                  '1 entry · x',
                  '2 entries · x',
                  '3 entries · x',
                  '11 entries · x',
                ],
        );
      });

      testWidgets('New entry is a round button at the bottom end; Filter · '
          'Search · Calendar on top', (tester) async {
        await _open(tester, lang);
        final button = _key('notebook-new-entry');
        expect(button, findsOneWidget);
        expect(tester.getRect(button).bottom, greaterThan(700));
        expect(
          _along(tester, lang, button),
          greaterThan(_along(tester, lang, _key('notebook-new-page'))),
        );
        expect(
          [
            _along(tester, lang, _key('notebook-filter')),
            _along(tester, lang, _key('notebook-search')),
            _along(tester, lang, _key('notebook-calendar')),
          ],
          orderedEquals(
            [
              for (final k in [
                'notebook-filter',
                'notebook-search',
                'notebook-calendar',
              ])
                _along(tester, lang, _key(k)),
            ]..sort(),
          ),
        );
        await _tap(tester, button);
        expect(_key('note-tools'), findsOneWidget);
      });
    });

    group('BH9, BH11 the Filter [$lang]', () {
      testWidgets('the card: Show (one choice) and In; a choice shows the '
          'entries by page under its chips; ✕ turns it off', (tester) async {
        final repo = s.repository()..hits = hits();
        await _open(tester, lang, notebook: repo);
        await _tap(tester, _key('notebook-filter'));
        expect(_key('notebook-filter-menu'), findsOneWidget);
        for (final k in [
          'todos_open',
          'photos',
          'files',
          'voice',
          'reminders',
          'archived',
        ]) {
          expect(_key('filter-show-$k'), findsOneWidget, reason: k);
        }
        expect(find.text(l10n.notebookAllPages), findsOneWidget);
        await _tap(tester, _key('filter-show-todos_open'));
        expect(_key('notebook-filter-menu'), findsNothing);
        expect(repo.calls, contains('search::todos_open:'));
        expect(
          find.descendant(
            of: _key('filter-chip-kind'),
            matching: find.text(l10n.notebookFilterTodos),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: _key('filter-chip-page'),
            matching: find.text(l10n.notebookAllPages),
          ),
          findsOneWidget,
        );
        expect(_key('notebook-filter-on'), findsOneWidget);
        // By page, newest first: Site A, then Site B.
        expect(_key('page-${NotebookPageSamples.siteA}'), findsNothing);
        final a = tester.getTopLeft(_key('filter-hit-entry-pour')).dy;
        final b = tester.getTopLeft(_key('filter-hit-entry-snags')).dy;
        expect(a, lessThan(b));
        expect(
          tester.getTopLeft(find.text(s.siteBTitle)).dy,
          allOf(greaterThan(a), lessThan(b)),
        );
        // ✕: the pages again.
        await _tap(tester, _key('filter-clear'));
        expect(_key('filter-chip-kind'), findsNothing);
        expect(_key('page-${NotebookPageSamples.siteA}'), findsOneWidget);
      });

      testWidgets('In ›: one page, with its sub-pages, picked in the same '
          'card', (tester) async {
        final repo = s.repository()..hits = hits().take(1).toList();
        await _open(tester, lang, notebook: repo);
        await _tap(tester, _key('notebook-filter'));
        await _tap(tester, _key('filter-in'));
        expect(_key('menu-back'), findsOneWidget);
        await _tap(tester, _key('filter-page-${NotebookPageSamples.siteA}'));
        await _tap(tester, _key('filter-show-photos'));
        expect(
          repo.calls,
          contains('search::photos:${NotebookPageSamples.siteA}'),
        );
        expect(
          find.descendant(
            of: _key('filter-chip-page'),
            matching: find.text(s.siteATitle),
          ),
          findsOneWidget,
        );
      });

      testWidgets('inside a page, the filter starts with that page; a hit '
          'opens its entry', (tester) async {
        final repo = s.repository()..hits = hits().take(1).toList();
        await _open(
          tester,
          lang,
          notebook: repo,
          path: '/notebook/pages/${NotebookPageSamples.siteA}',
        );
        await _tap(tester, _key('page-filter'));
        await _tap(tester, _key('filter-show-reminders'));
        expect(
          repo.calls,
          contains('search::reminders:${NotebookPageSamples.siteA}'),
        );
        await _tap(tester, _key('filter-hit-entry-pour'));
        expect(_key('filter-chip-kind'), findsNothing);
        expect(_key('note-entry-pour'), findsOneWidget);
      });

      testWidgets('Search keeps the filter that is on', (tester) async {
        final repo = s.repository()..hits = hits();
        await _open(tester, lang, notebook: repo);
        await _tap(tester, _key('notebook-filter'));
        await _tap(tester, _key('filter-show-todos_open'));
        await _tap(tester, _key('notebook-search'));
        await tester.enterText(find.byType(TextField), 'pour');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
        expect(repo.calls, contains('search:pour:todos_open:'));
      });
    });
  }
}
