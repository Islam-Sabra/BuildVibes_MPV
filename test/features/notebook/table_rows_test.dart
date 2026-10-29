// Review 104 N8: a table shows collapsed. A saved entry shows the whole
// table, every row and column, on its card on the page and in the editor
// when it is opened again; wider than the card, it scrolls sideways. In
// English and Arabic (the columns mirror).
import 'dart:convert';

import 'package:buildvibes/data/models/note.dart';
import 'package:buildvibes/data/models/post_page.dart';
import 'package:buildvibes/features/notebook/note_draft.dart';
import 'package:flutter/material.dart';
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

const _cells = [
  ['Item', 'Qty', 'Unit'],
  ['Rebar', '12', 't'],
  ['Cement', '40', 'bags'],
];

Note _saved({List<List<String>> rows = _cells}) => Note(
  id: 'entry-t',
  kind: NoteKind.text,
  title: 'Delivery',
  blocks: [PageTable('tbl', rows)],
  body: 'Delivery',
  createdAt: DateTime(2026, 10, 15, 9),
  pageId: FakeNotebookRepository.myNotesId,
);

Future<TestApp> _open(
  WidgetTester tester,
  String lang, {
  List<Note> notes = const [],
  NoteDraft? draft,
}) async {
  final app = await pumpApp(
    tester,
    language: lang,
    now: NotebookSamples.now,
    notebook: FakeNotebookRepository(notes: notes),
    stored: {
      if (draft != null) 'notebook_draft:user-1': jsonEncode(draft.toJson()),
    },
  );
  GoRouter.of(tester.element(find.byType(Navigator).first)).push(_page);
  await tester.pumpAndSettle();
  return app;
}

Finder _inCard(String text) =>
    find.descendant(of: _key('note-entry-t'), matching: find.text(text));

void main() {
  test('N8: a table keeps every row through the server and the phone '
      '(the note and the Draft, to JSON and back)', () {
    final note = Note.fromJson(
      jsonDecode(jsonEncode(_saved().toJson())) as Map<String, dynamic>,
    );
    expect((note.blocks!.single as PageTable).rows, _cells);
    final draft = NoteDraft.fromJson(
      jsonDecode(
            jsonEncode(
              NoteDraft(
                id: 'd-1',
                startedAt: NotebookSamples.now,
                blocks: [PageTable('tbl', _cells)],
              ).toJson(),
            ),
          )
          as Map<String, dynamic>,
    );
    expect((draft.blocks.single as PageTable).rows, _cells);
  });

  for (final lang in ['en', 'ar']) {
    group('N8: a saved table shows every row and column [$lang]', () {
      testWidgets('on its card on the page: 3 rows × 3 columns, the '
          'columns in the reading order', (tester) async {
        await _open(tester, lang, notes: [_saved()]);
        for (final row in _cells) {
          for (final cell in row) {
            expect(_inCard(cell), findsOneWidget, reason: cell);
          }
        }
        // Rows go down; the columns run in the reading direction.
        final first = tester.getCenter(_inCard('Item'));
        final last = tester.getCenter(_inCard('Unit'));
        expect(tester.getCenter(_inCard('Cement')).dy, greaterThan(first.dy));
        expect(lang == 'ar' ? last.dx < first.dx : last.dx > first.dx, isTrue);
        expect(tester.takeException(), isNull);
      });

      testWidgets('wider than the card, it scrolls sideways and nothing '
          'overflows', (tester) async {
        final wide = [
          for (var r = 0; r < 3; r++) [for (var c = 0; c < 8; c++) 'R${r}C$c'],
        ];
        await _open(tester, lang, notes: [_saved(rows: wide)]);
        expect(tester.takeException(), isNull);
        final scroll = find.descendant(
          of: _key('note-entry-t'),
          matching: find.byWidgetPredicate(
            (w) =>
                w is SingleChildScrollView &&
                w.scrollDirection == Axis.horizontal,
          ),
        );
        expect(scroll, findsOneWidget);
        expect(_inCard('R2C0'), findsOneWidget);
      });

      testWidgets('opened again, the editor has every cell', (tester) async {
        await _open(tester, lang, notes: [_saved()]);
        await _tap(tester, _key('note-entry-t'));
        for (final (r, row) in _cells.indexed) {
          for (final (c, cell) in row.indexed) {
            final field = _key('page-field-c:tbl:$r:$c');
            expect(field, findsOneWidget, reason: '$r:$c');
            expect(
              tester.widget<TextField>(field).controller!.text,
              cell,
              reason: '$r:$c',
            );
          }
        }
      });

      testWidgets('made in a new entry: a row and a column added, the cells '
          'typed, Send; the card and the editor show all of it', (
        tester,
      ) async {
        final app = await _open(
          tester,
          lang,
          draft: NoteDraft(
            id: 'd0000000-0000-4000-8000-000000000104',
            startedAt: NotebookSamples.now,
            title: 'Delivery',
            blocks: [
              PageTable('tbl', const [
                ['', ''],
                ['', ''],
              ]),
            ],
            pageId: FakeNotebookRepository.myNotesId,
          ),
        );
        await _tap(tester, _key('note-draft'));
        await _tap(tester, _key('page-add-row-tbl'));
        await _tap(tester, _key('page-add-column-tbl'));
        for (final (r, row) in _cells.indexed) {
          for (final (c, cell) in row.indexed) {
            final field = _key('page-field-c:tbl:$r:$c');
            await _tap(tester, field);
            await tester.enterText(field, cell);
            await tester.pumpAndSettle();
          }
        }
        await _tap(tester, _key('writing-post'));
        final saved = app.notebook.kept.values.single;
        expect((saved.blocks!.single as PageTable).rows, _cells);
        final card = _key('note-${saved.id}');
        for (final row in _cells) {
          for (final cell in row) {
            expect(
              find.descendant(of: card, matching: find.text(cell)),
              findsOneWidget,
              reason: cell,
            );
          }
        }
        await _tap(tester, card);
        for (final (r, row) in _cells.indexed) {
          for (final (c, cell) in row.indexed) {
            expect(
              tester
                  .widget<TextField>(_key('page-field-c:tbl:$r:$c'))
                  .controller!
                  .text,
              cell,
            );
          }
        }
      });
    });
  }
}
