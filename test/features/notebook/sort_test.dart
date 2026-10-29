// Review 102 N5: SORT, the Filter card's third part, one single choice.
// The pages list: Latest activity (default) · Name A–Z · Newest created,
// pinned pages always on top. Inside a page: Newest first (default) ·
// Oldest first. Remembered on the phone (the pages list once, each page on
// its own); a sort that isn't the default shows as a chip, whose ✕ resets
// it. Name A–Z keeps each alphabet together, the app's own first.
//
// Review 104 N7 completes the lists: the pages list adds Oldest created;
// inside a page, Name A–Z (the title, or the first line) and Type (grouped
// under To-dos · Checklists · Photos · Files · Voice notes · Text, newest
// first in each). Day headers and the hand order only in the date sorts;
// pinned on top in every sort. In English and Arabic.
import 'package:buildvibes/data/models/note.dart';
import 'package:buildvibes/data/models/notebook_page.dart';
import 'package:buildvibes/data/models/post_page.dart';
import 'package:buildvibes/features/notebook/note_filter.dart';
import 'package:buildvibes/features/notebook/notebook_page_parts.dart'
    show NotebookPageRow;
import 'package:buildvibes/features/work/daybook_words.dart';
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

/// N7: a page of one entry of each kind over two days, one pinned; the
/// titles of both alphabets, one with only a first line.
Note _mixed(
  String id,
  DateTime at, {
  NoteKind kind = NoteKind.text,
  String title = '',
  String body = '',
  List<PageBlock>? blocks,
  List<NotePhoto> photos = const [],
  List<NoteFile> files = const [],
  List<NotePoint> points = const [],
  bool pinned = false,
}) => Note(
  id: id,
  kind: kind,
  title: title,
  body: body,
  blocks: blocks,
  photos: photos,
  files: files,
  points: points,
  pinned: pinned,
  createdAt: at,
  pageId: 'p-mix',
);

final _mixedNotes = [
  _mixed('m-text', DateTime(2026, 10, 15, 11), title: 'Delta'),
  _mixed(
    'm-todo',
    DateTime(2026, 10, 15, 10),
    kind: NoteKind.todo,
    body: 'Order rebar',
  ),
  _mixed(
    'm-line',
    DateTime(2026, 10, 15, 8),
    blocks: [PageText('l-1', 'بيت المضخة')],
  ),
  _mixed('m-pin', DateTime(2026, 10, 14, 16), title: 'Zulu', pinned: true),
  _mixed(
    'm-voice',
    DateTime(2026, 10, 14, 15),
    kind: NoteKind.voice,
    title: 'Alpha',
  ),
  _mixed(
    'm-file',
    DateTime(2026, 10, 14, 12),
    title: 'Bravo',
    files: const [NoteFile(path: 'u/spec.pdf', name: 'spec.pdf')],
  ),
  _mixed(
    'm-check',
    DateTime(2026, 10, 14, 10),
    kind: NoteKind.checklist,
    body: 'أعمدة',
    points: const [NotePoint('Column 1')],
  ),
  _mixed(
    'm-page-todo',
    DateTime(2026, 10, 14, 9),
    title: 'Charlie',
    blocks: [PageText('p-1', 'Walk'), PageTodo('p-2', 'Close the gate')],
  ),
];

const _mixedIds = [
  'm-text',
  'm-todo',
  'm-line',
  'm-pin',
  'm-voice',
  'm-file',
  'm-check',
  'm-page-todo',
];

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
    _page('p-mix', 'Mixed', created: 4, active: 4),
  ],
  notes: [
    _entry('e4', DateTime(2026, 10, 15, 11)),
    _entry('e3', DateTime(2026, 10, 15, 8)),
    _entry('e2', DateTime(2026, 10, 14, 15)),
    _entry('e1', DateTime(2026, 10, 14, 9)),
    ..._mixedNotes,
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
    if (r.page.id != 'p-log' && r.page.id != 'p-mix') r.page.id,
];

/// A page's entries, top to bottom (all on screen).
List<String> _entries(
  WidgetTester tester, [
  List<String> ids = const ['e1', 'e2', 'e3', 'e4'],
]) {
  final found = [
    for (final id in ids)
      (id, tester.getTopLeft(find.byKey(ValueKey(('swipe', id)))).dy),
  ]..sort((a, b) => a.$2.compareTo(b.$2));
  return [for (final (id, _) in found) id];
}

/// What shows top to bottom on a page: its labels and its entries.
List<String> _rows(WidgetTester tester, List<String> labels) {
  final found = [
    for (final id in _mixedIds)
      (id, tester.getTopLeft(find.byKey(ValueKey(('swipe', id)))).dy),
    for (final label in labels)
      for (final e in find.text(label).evaluate())
        (label, (e.renderObject! as RenderBox).localToGlobal(Offset.zero).dy),
  ]..sort((a, b) => a.$2.compareTo(b.$2));
  return [for (final (id, _) in found) id];
}

/// The mixed page, on a screen tall enough for all of it (the list is
/// built as it scrolls).
Future<TestApp> _openMixed(WidgetTester tester, String lang) async {
  final app = await _open(tester, lang, path: '/notebook/pages/p-mix');
  tester.view.physicalSize = const Size(390, 3200);
  await tester.pumpAndSettle();
  return app;
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

    testWidgets('the pages list\'s card: SORT, four choices (N7), Latest '
        'activity checked [$lang]', (tester) async {
      await _open(tester, lang);
      await tester.tap(_key('notebook-filter'));
      await tester.pumpAndSettle();
      expect(find.text(l10n.notebookSortLabel), findsOneWidget);
      for (final (key, label) in [
        ('activity', l10n.notebookSortActivity),
        ('name', l10n.notebookSortName),
        ('created', l10n.notebookSortCreated),
        ('oldest_created', l10n.notebookSortOldestCreated),
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
      // N7: Oldest created, pinned still on top.
      await _sort(tester, 'notebook-filter', 'oldest_created');
      expect(_pages(tester), [
        'p-pin',
        FakeNotebookRepository.myNotesId,
        'p-a',
        'p-c',
        'p-d',
        'p-b',
      ]);
      expect(
        find.descendant(
          of: _key('sort-chip'),
          matching: find.text(l10n.notebookSortOldestCreated),
        ),
        findsOneWidget,
      );
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
      // N7: four choices.
      for (final (key, label) in [
        ('newest', l10n.notebookSortNewest),
        ('oldest', l10n.notebookSortOldest),
        ('name', l10n.notebookSortName),
        ('type', l10n.notebookSortType),
      ]) {
        expect(
          find.descendant(of: _key('sort-$key'), matching: find.text(label)),
          findsOneWidget,
        );
      }
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

  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    // The day headers, read once the app (and its date words) is up.
    List<String> dayLabels() => [
      for (final d in [DateTime(2026, 10, 15), DateTime(2026, 10, 14)])
        DaybookWords(l10n, lang, use24: false).compactDate(d),
    ];

    group('N7 inside a page [$lang]', () {
      testWidgets('Newest first: pinned on top, then a day at a time', (
        tester,
      ) async {
        await _openMixed(tester, lang);
        final days = dayLabels();
        expect(_rows(tester, [l10n.notebookPinnedLabel, ...days]), [
          l10n.notebookPinnedLabel,
          'm-pin',
          days[0],
          'm-text',
          'm-todo',
          'm-line',
          days[1],
          'm-voice',
          'm-file',
          'm-check',
          'm-page-todo',
        ]);
      });

      testWidgets('Name A–Z: the title or the first line, each alphabet '
          'together, the app\'s own first; no day headers; pinned on top', (
        tester,
      ) async {
        await _openMixed(tester, lang);
        await _sort(tester, 'page-filter', 'name');
        final days = dayLabels();
        // Alpha, Bravo, Charlie, Delta, then "Order rebar" (a to-do
        // with no title: its words); أعمدة and بيت by their letters.
        const latin = ['m-voice', 'm-file', 'm-page-todo', 'm-text', 'm-todo'];
        const arabic = ['m-check', 'm-line'];
        expect(_rows(tester, [l10n.notebookPinnedLabel, ...days]), [
          l10n.notebookPinnedLabel,
          'm-pin',
          ...(lang == 'en' ? [...latin, ...arabic] : [...arabic, ...latin]),
        ]);
        expect(
          find.descendant(
            of: _key('sort-chip'),
            matching: find.text(l10n.notebookSortName),
          ),
          findsOneWidget,
        );
      });

      testWidgets('Type: To-dos · Checklists · Photos · Files · Voice notes '
          '· Text, newest first in each; no day headers; pinned on top', (
        tester,
      ) async {
        await _openMixed(tester, lang);
        await _sort(tester, 'page-filter', 'type');
        final days = dayLabels();
        final groups = [
          l10n.notebookTypeTodos,
          l10n.notebookTypeChecklists,
          l10n.notebookTypePhotos,
          l10n.notebookTypeFiles,
          l10n.notebookTypeVoice,
          l10n.notebookTypeText,
        ];
        expect(_rows(tester, [l10n.notebookPinnedLabel, ...days, ...groups]), [
          l10n.notebookPinnedLabel,
          'm-pin',
          groups[0],
          'm-todo',
          'm-page-todo',
          groups[1],
          'm-check',
          // No photo here: an empty group shows no label (Photos is in
          // the unit test below).
          groups[3],
          'm-file',
          groups[4],
          'm-voice',
          groups[5],
          'm-text',
          'm-line',
        ]);
      });

      for (final sort in ['name', 'type']) {
        testWidgets('$sort: no hand order; holding an entry selects it', (
          tester,
        ) async {
          final app = await _openMixed(tester, lang);
          await _sort(tester, 'page-filter', sort);
          final before = _rows(tester, const []);
          final from = tester.getCenter(find.byKey(const Key('note-m-text')));
          final hold = await tester.startGesture(from);
          await tester.pump(const Duration(milliseconds: 600));
          await hold.moveBy(const Offset(0, 160));
          await tester.pump(const Duration(milliseconds: 100));
          await hold.up();
          await tester.pumpAndSettle();
          expect(_rows(tester, const []), before);
          expect(find.byKey(const Key('note-selected-m-text')), findsOneWidget);
          expect(
            app.notebook.calls.where((c) => c.startsWith('day-arrange')),
            isEmpty,
          );
        });
      }
    });
  }

  test('N7 Type: an entry goes under the first kind it has, in the '
      'groups\' order', () {
    Note n({
      NoteKind kind = NoteKind.text,
      List<PageBlock>? blocks,
      List<NotePhoto> photos = const [],
      List<NoteFile> files = const [],
    }) => Note(
      id: 'x',
      kind: kind,
      createdAt: DateTime(2026, 10, 15),
      blocks: blocks,
      photos: photos,
      files: files,
    );
    const photo = NotePhoto(path: 'p.jpg');
    const file = NoteFile(path: 'f.pdf', name: 'f.pdf');
    expect(EntryType.of(n(kind: NoteKind.todo)), EntryType.todos);
    // A to-do inside a toggle, with a photo: To-dos come first.
    expect(
      EntryType.of(
        n(
          blocks: [
            PageToggle('t', 'Walk', [PageTodo('t-1', 'Gate')]),
          ],
          photos: [photo],
        ),
      ),
      EntryType.todos,
    );
    expect(EntryType.of(n(kind: NoteKind.checklist)), EntryType.checklists);
    expect(EntryType.of(n(photos: [photo], files: [file])), EntryType.photos);
    expect(
      EntryType.of(n(blocks: [PagePhoto('p', 'p.jpg')])),
      EntryType.photos,
    );
    expect(EntryType.of(n(files: [file])), EntryType.files);
    expect(EntryType.of(n(kind: NoteKind.voice)), EntryType.voice);
    expect(EntryType.of(n(blocks: [PageVoice('v')])), EntryType.voice);
    expect(EntryType.of(n(blocks: [PageText('l', 'Hi')])), EntryType.text);
  });

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
