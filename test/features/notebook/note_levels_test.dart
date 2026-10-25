// Review 93: a note's lines under each other, in the editor. ⇥ ⇤ on the
// bar, numbering by level, Continue numbering and Restart at 1, folding,
// Return and Backspace on a list line, and Turn into, move and delete
// keeping the children. In English and Arabic.
import 'dart:convert';

import 'package:buildvibes/core/design/bv_icons.dart';
import 'package:buildvibes/data/models/post_page.dart';
import 'package:buildvibes/features/notebook/note_draft.dart';
import 'package:buildvibes/features/notebook/note_page_editor.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/notebook_fakes.dart';
import '../../helpers/notebook_samples.dart';
import '../../helpers/pump_app.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

Finder _key(String k) => find.byKey(Key(k));

String _id(int n) => 'a0000000-0000-4000-8000-${'$n'.padLeft(12, '0')}';

Finder _line(int n) => _key('page-field-t:${_id(n)}');

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

/// The notebook with a Draft of [blocks], opened from the bar's Note: being
/// written, the keyboard on its last line.
Future<void> _open(
  WidgetTester tester,
  String lang,
  List<PageBlock> blocks,
) async {
  final draft = NoteDraft(
    id: 'd0000000-0000-4000-8000-000000000093',
    startedAt: NotebookSamples.now,
    title: 'Level 3 slab',
    blocks: blocks,
  );
  await pumpApp(
    tester,
    language: lang,
    now: NotebookSamples.now,
    notebook: FakeNotebookRepository(),
    stored: {'notebook_draft:user-1': jsonEncode(draft.toJson())},
  );
  GoRouter.of(tester.element(find.byType(Navigator).first)).push('/notebook');
  await tester.pumpAndSettle();
  await _tap(tester, _key('post-bar-notepad'));
}

List<PageBlock> _blocks(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(Scaffold).first),
).read(noteDraftProvider)!.blocks;

List<int> _levels(WidgetTester tester) => [
  for (final b in _blocks(tester)) b.indent,
];

/// The cursor into line [n] (its ⋮⋮ shows), at its start or end.
Future<void> _cursor(WidgetTester tester, int n, {bool start = false}) async {
  await _tap(tester, _line(n));
  final c = tester.widget<TextField>(_line(n)).controller!;
  c.selection = TextSelection.collapsed(offset: start ? 0 : c.text.length);
  await tester.pumpAndSettle();
}

Future<void> _menu(WidgetTester tester, int n) async {
  await _cursor(tester, n);
  await _tap(tester, _key('page-handle-${_id(n)}'));
}

PageNumbered _n(int id, String text, {int indent = 0}) =>
    PageNumbered(_id(id), text, indent: indent);

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);

    testWidgets("the founder's case: 1, 2, a callout, then 1; the menu's "
        'Continue numbering (3) gives 3 [$lang]', (tester) async {
      await _open(tester, lang, [
        _n(1, 'Pour'),
        _n(2, 'Cure'),
        PageCallout(_id(3), 'Rain expected'),
        _n(4, 'Strip'),
      ]);
      // Western digits in Arabic too.
      expect(find.text('1.'), findsNWidgets(2));
      expect(find.text('2.'), findsOneWidget);
      await _menu(tester, 4);
      final goOn = l10n.notebookContinueNumbering(3);
      expect(goOn, contains('3'));
      expect(find.text(goOn), findsOneWidget);
      expect(_key('page-restart-numbering'), findsOneWidget);
      await _tap(tester, _key('page-continue-numbering'));
      expect(find.text('3.'), findsOneWidget);
      expect((_blocks(tester)[3] as PageNumbered).start, 3);
      // Restart at 1 puts it back to a count of its own.
      await _menu(tester, 4);
      await _tap(tester, _key('page-restart-numbering'));
      expect(find.text('3.'), findsNothing);
      expect((_blocks(tester)[3] as PageNumbered).start, 1);
    });

    testWidgets('the callout under 2 is a child: the next item is 3 by '
        'itself, with no Continue [$lang]', (tester) async {
      await _open(tester, lang, [
        _n(1, 'Pour'),
        _n(2, 'Cure'),
        PageCallout(_id(3), 'Rain expected', indent: 1),
        _n(4, 'Strip'),
      ]);
      expect(find.text('3.'), findsOneWidget);
      await _menu(tester, 4);
      expect(_key('page-continue-numbering'), findsNothing);
    });

    testWidgets('⇥ and ⇤ on the bar move the line; 1. → a. → i.; in Arabic '
        'in is to the left [$lang]', (tester) async {
      await _open(tester, lang, [_n(1, 'Pour'), _n(2, 'Cure'), _n(3, 'Strip')]);
      // On the first line nothing can move: no ⇥ ⇤.
      await _cursor(tester, 1);
      expect(_key('note-tool-indent'), findsNothing);
      await _cursor(tester, 3);
      expect(_key('note-tool-indent'), findsOneWidget);
      expect(_key('note-tool-outdent'), findsOneWidget);
      expect(BvIcons.indent.matchTextDirection, isTrue);
      // Right after the +, before the thin line and the additions.
      final plus = tester.getCenter(_key('note-tool-categories')).dx;
      final tab = tester.getCenter(_key('note-tool-indent')).dx;
      final place = tester.getCenter(_key('note-tool-location')).dx;
      expect(lang == 'ar' ? plus > tab && tab > place : plus < tab, isTrue);
      expect(lang == 'ar' ? true : tab < place, isTrue);
      final before = tester.getRect(_line(3));
      await _tap(tester, _key('note-tool-indent'));
      expect(_levels(tester), [0, 0, 1]);
      expect(find.text('a.'), findsOneWidget);
      final after = tester.getRect(_line(3));
      if (lang == 'ar') {
        expect(after.right, lessThan(before.right));
      } else {
        expect(after.left, greaterThan(before.left));
      }
      // The first child can't go deeper; Cure can take Strip in.
      await _tap(tester, _key('note-tool-indent'));
      expect(_levels(tester), [0, 0, 1]);
      await _cursor(tester, 2);
      await _tap(tester, _key('note-tool-indent'));
      expect(_levels(tester), [0, 1, 2]);
      expect(find.text('a.'), findsOneWidget);
      expect(find.text('i.'), findsOneWidget);
      await _tap(tester, _key('note-tool-outdent'));
      expect(_levels(tester), [0, 0, 1]);
      expect(find.text('2.'), findsOneWidget);
    });

    testWidgets('Return on an empty item steps out a level, then ends the '
        'list [$lang]', (tester) async {
      await _open(tester, lang, [
        _n(1, 'Pour'),
        PageNumbered(_id(2), '', indent: 1),
      ]);
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      expect(_blocks(tester)[1], isA<PageNumbered>());
      expect(_levels(tester), [0, 0]);
      expect(find.text('2.'), findsOneWidget);
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      expect(_blocks(tester)[1], isA<PageText>());
    });

    testWidgets('Backspace at the start turns an item into text at its '
        'level, then joins it to the line above [$lang]', (tester) async {
      await _open(tester, lang, [_n(1, 'Pour'), _n(2, ' level 3', indent: 1)]);
      await _cursor(tester, 2, start: true);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();
      final text = _blocks(tester)[1];
      expect(text, isA<PageText>());
      expect((text.indent, (text as PageText).text), (1, ' level 3'));
      await _cursor(tester, 2, start: true);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();
      final joined = _blocks(tester).single as PageNumbered;
      expect(joined.text, 'Pour level 3');
      expect(
        tester.widget<TextField>(_line(1)).controller!.selection.baseOffset,
        'Pour'.length,
      );
    });

    testWidgets('Turn into a heading: the children come out one level, and '
        'nothing is lost [$lang]', (tester) async {
      await _open(tester, lang, [
        _n(1, 'Pour'),
        _n(2, 'Rebar', indent: 1),
        _n(3, 'Ties', indent: 2),
      ]);
      await _menu(tester, 1);
      await _tap(tester, _key('page-turn-heading'));
      final blocks = _blocks(tester);
      expect(blocks.first, isA<PageHeading>());
      expect([for (final b in blocks) lineWords(b)], ['Pour', 'Rebar', 'Ties']);
      expect(_levels(tester), [0, 0, 1]);
    });

    testWidgets('moving a parent takes its children; both lists count again '
        '[$lang]', (tester) async {
      await _open(tester, lang, [
        _n(1, 'Pour'),
        _n(2, 'Rebar', indent: 1),
        _n(3, 'Cure'),
        PageText(_id(4), 'End'),
      ]);
      // A drag on Pour's ⋮⋮ to just before End.
      tester
          .state<NotePageEditorState>(find.byType(NotePageEditor))
          .moveBlock(0, 2);
      await tester.pumpAndSettle();
      expect(
        [for (final b in _blocks(tester)) lineWords(b)],
        ['Cure', 'Pour', 'Rebar', 'End'],
      );
      expect(_levels(tester), [0, 0, 1, 0]);
      expect(find.text('1.'), findsOneWidget);
      expect(find.text('2.'), findsOneWidget);
      expect(find.text('a.'), findsOneWidget);
    });

    testWidgets('deleting a parent lifts its children; a folded one asks, '
        'then goes with them; Undo puts it back [$lang]', (tester) async {
      await _open(tester, lang, [
        _n(1, 'Pour'),
        _n(2, 'Rebar', indent: 1),
        _n(3, 'Ties', indent: 2),
        _n(4, 'Cure'),
      ]);
      await _menu(tester, 1);
      await _tap(tester, _key('page-block-delete'));
      expect(
        [for (final b in _blocks(tester)) lineWords(b)],
        ['Rebar', 'Ties', 'Cure'],
      );
      expect(_levels(tester), [0, 1, 0]);
      await _tap(tester, _key('page-undo'));
      expect(_levels(tester), [0, 1, 2, 0]);
      // Folded: asked first, then the three go together.
      await _tap(tester, _key('note-fold-${_id(1)}'));
      expect(_line(2), findsNothing);
      await _menu(tester, 1);
      await _tap(tester, _key('page-block-delete'));
      expect(find.text(l10n.notebookDeleteLines(2)), findsOneWidget);
      await _tap(tester, find.text(l10n.pageDelete).last);
      expect([for (final b in _blocks(tester)) lineWords(b)], ['Cure']);
    });

    testWidgets('a folded item hides the lines under it; the count goes on '
        'unchanged [$lang]', (tester) async {
      await _open(tester, lang, [
        _n(1, 'Pour'),
        _n(2, 'Rebar', indent: 1),
        _n(3, 'Cure'),
      ]);
      expect(_key('note-fold-${_id(1)}'), findsOneWidget);
      expect(_key('note-fold-${_id(3)}'), findsNothing);
      await _tap(tester, _key('note-fold-${_id(1)}'));
      expect(_line(2), findsNothing);
      expect(find.text('2.'), findsOneWidget);
      expect(_levels(tester), [0, 1, 0], reason: 'nothing changes');
      await _tap(tester, _key('note-fold-${_id(1)}'));
      expect(_line(2), findsOneWidget);
      expect(find.text('a.'), findsOneWidget);
    });

    testWidgets('a numbered line from the grid right under a list goes on '
        'with its count [$lang]', (tester) async {
      await _open(tester, lang, [_n(1, 'Pour'), _n(2, 'Cure')]);
      await _cursor(tester, 2);
      await _tap(tester, _key('note-tool-categories'));
      await _tap(tester, _key('note-category-numbers'));
      expect(find.text('3.'), findsOneWidget);
    });
  }
}
