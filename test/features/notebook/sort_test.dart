// Review 102 N5: SORT, the Filter card's third part, one single choice.
// The pages list: Latest activity (default) · Name A–Z · Newest created,
// pinned pages always on top. Inside a page: Newest first (default) ·
// Oldest first. Remembered on the phone (the pages list once, each page on
// its own); a sort that isn't the default shows as a chip, whose ✕ resets
// it. Name A–Z keeps each alphabet together, the app's own first. In
// English and Arabic.
import 'package:buildvibes/data/models/note.dart';
import 'package:buildvibes/data/models/notebook_page.dart';
import 'package:buildvibes/features/notebook/note_filter.dart';
import 'package:buildvibes/features/notebook/notebook_page_parts.dart'
    show NotebookPageRow;
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/notebook_fakes.dart';
import '../../helpers/notebook_page_samples.dart';
import '../../helpers/pump_app.dart';

Finder _key(String k) => find.byKey(Key(k));

NotebookPage _page(
  String id,
  String title, {
  required int created,
  required int active,
  bool pinned = false,
}) => NotebookPage(
  id: id,
  title: title,
  pinned: pinned,
  createdAt: DateTime(2026, 10, created),
  lastActivityAt: DateTime(2026, 10, active, 9),
);

Note _entry(String id, DateTime at) => Note(
  id: id,
  kind: NoteKind.text,
  title: 'Entry $id',
  body: 'Entry $id',
  createdAt: at,
  pageId: 'p-log',
);

/// Pages of both alphabets, one pinned; a log page of four entries over
/// two days.
FakeNotebookRepository _notebook() => FakeNotebookRepository(
  pages: [
    FakeNotebookRepository.myNotes(),
    _page('p-pin', 'Zulu pinned', created: 1, active: 2, pinned: true),
    _page('p-a', 'Beta', created: 3, active: 14),
    _page('p-b', 'alpha', created: 10, active: 12),
    _page('p-c', 'بيت', created: 5, active: 15),
    _page('p-d', 'أمل', created: 8, active: 9),
    _page('p-log', 'Log', created: 2, active: 3),
  ],
  notes: [
    _entry('e4', DateTime(2026, 10, 15, 11)),
    _entry('e3', DateTime(2026, 10, 15, 8)),
    _entry('e2', DateTime(2026, 10, 14, 15)),
    _entry('e1', DateTime(2026, 10, 14, 9)),
  ],
);

Future<TestApp> _open(
  WidgetTester tester,
  String lang, {
  String path = '/notebook',
  Map<String, Object> stored = const {},
}) async {
  final app = await pumpApp(
    tester,
    language: lang,
    now: NotebookPageSamples.now,
    notebook: _notebook(),
    stored: stored,
  );
  GoRouter.of(tester.element(find.byType(Navigator).first)).push(path);
  await tester.pumpAndSettle();
  return app;
}

/// The pages list's rows, top to bottom (all on screen).
List<String> _pages(WidgetTester tester) => [
  for (final r in tester.widgetList<NotebookPageRow>(
    find.byType(NotebookPageRow),
  ))
    if (r.page.id != 'p-log') r.page.id,
];

/// A page's entries, top to bottom (all on screen).
List<String> _entries(WidgetTester tester) {
  final found = [
    for (final id in ['e1', 'e2', 'e3', 'e4'])
      (id, tester.getTopLeft(find.byKey(ValueKey(('swipe', id)))).dy),
  ]..sort((a, b) => a.$2.compareTo(b.$2));
  return [for (final (id, _) in found) id];
}

Future<void> _sort(WidgetTester tester, String filter, String choice) async {
  await tester.tap(_key(filter));
  await tester.pumpAndSettle();
  await tester.tap(_key('sort-$choice'));
  await tester.pumpAndSettle();
}

const _byActivity = [
  'p-c',
  'p-a',
  'p-b',
  'p-d',
  FakeNotebookRepository.myNotesId,
];

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));

    testWidgets('the pages list\'s card: SORT, three choices, Latest '
        'activity checked [$lang]', (tester) async {
      await _open(tester, lang);
      await tester.tap(_key('notebook-filter'));
      await tester.pumpAndSettle();
      expect(find.text(l10n.notebookSortLabel), findsOneWidget);
      for (final (key, label) in [
        ('activity', l10n.notebookSortActivity),
        ('name', l10n.notebookSortName),
        ('created', l10n.notebookSortCreated),
      ]) {
        expect(
          find.descendant(of: _key('sort-$key'), matching: find.text(label)),
          findsOneWidget,
        );
      }
      expect(
        find.descendant(
          of: _key('sort-activity'),
          matching: _key('menu-checked'),
        ),
        findsOneWidget,
      );
      expect(_key('sort-newest'), findsNothing);
    });

    testWidgets('each sort of the pages list; pinned always on top; no chip '
        'for the default [$lang]', (tester) async {
      await _open(tester, lang);
      expect(_pages(tester), ['p-pin', ..._byActivity]);
      expect(_key('sort-chip'), findsNothing);

      await _sort(tester, 'notebook-filter', 'name');
      // Each alphabet together, the app's own first.
      expect(
        _pages(tester),
        lang == 'en'
            ? [
                'p-pin',
                'p-b',
                'p-a',
                FakeNotebookRepository.myNotesId,
                'p-d',
                'p-c',
              ]
            : [
                'p-pin',
                'p-d',
                'p-c',
                FakeNotebookRepository.myNotesId,
                'p-b',
                'p-a',
              ],
      );
      expect(
        find.descendant(
          of: _key('sort-chip'),
          matching: find.text(l10n.notebookSortName),
        ),
        findsOneWidget,
      );

      await _sort(tester, 'notebook-filter', 'created');
      expect(_pages(tester), [
        'p-pin',
        'p-b',
        'p-d',
        'p-c',
        'p-a',
        FakeNotebookRepository.myNotesId,
      ]);
      // The Filter itself stays off.
      expect(_key('notebook-filter-on'), findsNothing);
    });

    testWidgets('the chip\'s ✕ puts the default back [$lang]', (tester) async {
      await _open(tester, lang);
      await _sort(tester, 'notebook-filter', 'name');
      await tester.tap(_key('sort-clear'));
      await tester.pumpAndSettle();
      expect(_key('sort-chip'), findsNothing);
      expect(_pages(tester), ['p-pin', ..._byActivity]);
    });

    testWidgets('kept on the phone after a restart [$lang]', (tester) async {
      await _open(tester, lang);
      await _sort(tester, 'notebook-filter', 'created');
      final prefs = await SharedPreferences.getInstance();
      final kept = {
        for (final k in prefs.getKeys())
          if (k.startsWith('notebook_sort')) k: prefs.get(k)!,
      };
      expect(kept, isNotEmpty);
      await tester.pumpWidget(const SizedBox());
      await _open(tester, lang, stored: kept);
      expect(_pages(tester).take(3), ['p-pin', 'p-b', 'p-d']);
      expect(_key('sort-chip'), findsOneWidget);
    });

    testWidgets('inside a page: Newest first, then Oldest first, kept for '
        'that page only [$lang]', (tester) async {
      await _open(tester, lang, path: '/notebook/pages/p-log');
      expect(_entries(tester), ['e4', 'e3', 'e2', 'e1']);
      await tester.tap(_key('page-filter'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: _key('sort-newest'),
          matching: _key('menu-checked'),
        ),
        findsOneWidget,
      );
      expect(_key('sort-name'), findsNothing);
      await tester.tap(_key('sort-oldest'));
      await tester.pumpAndSettle();
      expect(_entries(tester), ['e1', 'e2', 'e3', 'e4']);
      expect(
        find.descendant(
          of: _key('sort-chip'),
          matching: find.text(l10n.notebookSortOldest),
        ),
        findsOneWidget,
      );
      // Another page keeps its own: the default.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('notebook_sort_page:p-log'), 'oldest');
      expect(prefs.getString('notebook_sort_page:p-a'), isNull);
      await tester.tap(_key('sort-clear'));
      await tester.pumpAndSettle();
      expect(_entries(tester), ['e4', 'e3', 'e2', 'e1']);
    });
  }

  test('Name A–Z: each alphabet in its own order, the app\'s first', () {
    final names = ['Zeta', 'بيت', 'alpha', 'أمل', 'ملف', 'Beta'];
    expect([...names]..sort(byName('en')), [
      'alpha',
      'Beta',
      'Zeta',
      'أمل',
      'بيت',
      'ملف',
    ]);
    expect([...names]..sort(byName('ar')), [
      'أمل',
      'بيت',
      'ملف',
      'alpha',
      'Beta',
      'Zeta',
    ]);
  });
}
