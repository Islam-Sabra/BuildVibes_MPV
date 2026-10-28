// Review 98: the notebook writes like Notion and AppFlowy, in our own
// editor. Typed shortcuts with Undo; "/" at the start or after a space,
// filtered by English, Arabic and simple words, Enter and Escape; + adds a
// line below; ⇥ ⇤ only when they can act; the line menu next to the line
// from ⋮⋮ or a held marker, its rows that can't act hidden; Move up, Move
// down and Duplicate carry the children; Undo after each line action; no
// drag on a phone; Reduce motion. In English and Arabic.
import 'dart:convert';

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

/// The notebook with a Draft of [blocks], being written.
Future<void> _open(
  WidgetTester tester,
  String lang,
  List<PageBlock> blocks,
) async {
  final draft = NoteDraft(
    id: 'd0000000-0000-4000-8000-000000000098',
    startedAt: NotebookSamples.now,
    title: 'Before the pour',
    blocks: blocks,
  );
  await pumpApp(
    tester,
    language: lang,
    now: NotebookSamples.now,
    notebook: FakeNotebookRepository(),
    stored: {'notebook_draft:user-1': jsonEncode(draft.toJson())},
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/notebook/pages/page-my-notes');
  await tester.pumpAndSettle();
  await _tap(tester, _key('note-draft'));
}

List<PageBlock> _blocks(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(Scaffold).first),
).read(noteDraftProvider)!.blocks;

String _json(WidgetTester tester) =>
    jsonEncode([for (final b in _blocks(tester)) b.toJson()]);

List<String?> _words(WidgetTester tester) => [
  for (final b in _blocks(tester)) lineWords(b),
];

List<int> _levels(WidgetTester tester) => [
  for (final b in _blocks(tester)) b.indent,
];

/// The cursor at the end of line [n].
Future<void> _cursor(WidgetTester tester, int n) async {
  await _tap(tester, _line(n));
  final c = tester.widget<TextField>(_line(n)).controller!;
  c.selection = TextSelection.collapsed(offset: c.text.length);
  await tester.pumpAndSettle();
}

/// The field with the keyboard.
TextEditingController _focused(WidgetTester tester) => tester
    .widgetList<TextField>(find.byType(TextField))
    .firstWhere((t) => t.focusNode?.hasFocus ?? false)
    .controller!;

/// [chars] typed one by one at the end of the line being written.
Future<void> _type(WidgetTester tester, String chars) async {
  for (final ch in chars.characters) {
    tester.testTextInput.enterText(_focused(tester).text + ch);
    await tester.pumpAndSettle();
  }
}

Future<void> _menu(WidgetTester tester, int n) async {
  await _cursor(tester, n);
  await _tap(tester, _key('page-handle-${_id(n)}'));
}

/// A tap beside the line menu closes it.
Future<void> _away(WidgetTester tester) async {
  expect(_key('line-popover-barrier'), findsOneWidget);
  await tester.tapAt(const Offset(195, 100));
  await tester.pumpAndSettle();
}

Future<void> _undo(WidgetTester tester) =>
    _tap(tester, _key('undo-bar-action'));

/// NBY2's list: 1. Clean; 2. Check, with two to-dos under it; 3. Confirm.
List<PageBlock> _pour() => [
  PageNumbered(_id(1), 'Clean the formwork'),
  PageNumbered(_id(2), 'Check the rebar'),
  PageTodo(_id(3), 'Cover at the edges', indent: 1),
  PageTodo(_id(4), 'Spacers every 1 m', indent: 1),
  PageNumbered(_id(5), 'Confirm the pump slot'),
];

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);

    group('typed shortcuts [$lang]', () {
      const shortcuts = {
        '1.': PageNumbered,
        '1)': PageNumbered,
        '١.': PageNumbered,
        '-': PageBullet,
        '*': PageBullet,
        '[]': PageTodo,
        '[ ]': PageTodo,
        '#': PageHeading,
        '##': PageHeading,
        '>': PageToggle,
        '"': PageQuote,
      };
      for (final MapEntry(key: typed, value: kind) in shortcuts.entries) {
        testWidgets('"$typed " turns a text line into $kind; Undo gives the '
            'characters back', (tester) async {
          final clicks = <String>[];
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            (call) async {
              if (call.method == 'HapticFeedback.vibrate') {
                clicks.add('${call.arguments}');
              }
              return null;
            },
          );
          await _open(tester, lang, [PageText(_id(1), '')]);
          await _cursor(tester, 1);
          await _type(tester, '$typed Pour');
          final b = _blocks(tester).single;
          expect(b.runtimeType, kind);
          expect(lineWords(b) ?? (b as PageToggle).text, 'Pour');
          if (typed == '##') expect((b as PageHeading).level, 2);
          if (typed == '#') expect((b as PageHeading).level, 1);
          // A light click when the line changed kind.
          expect(clicks, ['HapticFeedbackType.selectionClick']);
          final kindName = NoteBlockKind.of(b).label(l10n);
          expect(find.text(l10n.notebookUndoTurned(kindName)), findsOneWidget);
          expect(find.text(l10n.spacesUndo), findsOneWidget);
          await _undo(tester);
          final back = _blocks(tester).single;
          expect(back, isA<PageText>());
          // The typed characters are back, as text.
          expect((back as PageText).text, startsWith('$typed '));
        });
      }

      testWidgets('"--- " is a divider, then a new text line with the cursor', (
        tester,
      ) async {
        await _open(tester, lang, [PageText(_id(1), '')]);
        await _cursor(tester, 1);
        await _type(tester, '--- Next');
        final blocks = _blocks(tester);
        expect(blocks.first, isA<PageDivider>());
        expect(blocks.last, isA<PageText>());
        expect((blocks.last as PageText).text, 'Next');
        await _undo(tester);
        expect(_words(tester), ['--- ']);
      });

      testWidgets("1. shows Western digits in Arabic too; mid-line, or in a "
          "to-do, it stays as typed", (tester) async {
        await _open(tester, lang, [
          PageText(_id(1), 'Buy'),
          PageTodo(_id(2), ''),
          PageText(_id(3), ''),
        ]);
        await _cursor(tester, 1);
        await _type(tester, ' 1. ');
        expect(_blocks(tester)[0], isA<PageText>());
        expect(_words(tester)[0], 'Buy 1. ');
        await _cursor(tester, 2);
        await _type(tester, '1. ');
        expect(_blocks(tester)[1], isA<PageTodo>());
        expect(_words(tester)[1], '1. ');
        await _cursor(tester, 3);
        await _type(tester, '١. ');
        expect(_blocks(tester)[2], isA<PageNumbered>());
        expect(find.text('1.'), findsOneWidget);
        expect(find.text('١.'), findsNothing);
      });
    });

    group('the "/" card [$lang]', () {
      testWidgets('opens after a space next to the line, not inside a word; '
          'each kind shows its shortcut', (tester) async {
        await _open(tester, lang, [PageText(_id(1), 'Pour')]);
        await _cursor(tester, 1);
        await _type(tester, '/');
        expect(_key('page-add-menu'), findsNothing);
        await _type(tester, ' /');
        expect(_key('page-add-menu'), findsOneWidget);
        // A card next to the line, not a sheet: the line stays in sight.
        expect(find.byType(BottomSheet), findsNothing);
        final line = tester.getRect(_line(1));
        final card = tester.getRect(_key('page-add-menu'));
        // Under the line, or over it when the line is low on the screen.
        expect(card.top >= line.bottom || card.bottom <= line.top, isTrue);
        expect(
          lang == 'ar'
              ? (card.right - line.right).abs()
              : (card.left - line.left).abs(),
          lessThan(1),
        );
        expect(find.text(l10n.pageSlashTitle), findsOneWidget);
        expect(find.text(l10n.pageSlashEnter), findsOneWidget);
        for (final (kind, s) in [
          ('numbers', '1.'),
          ('bullets', '-'),
          ('todo', '[]'),
          ('heading', '#'),
          ('toggle', '>'),
          ('quote', '"'),
          ('divider', '---'),
        ]) {
          await tester.ensureVisible(_key('page-add-$kind'));
          expect(
            find.descendant(of: _key('page-add-$kind'), matching: find.text(s)),
            findsOneWidget,
            reason: s,
          );
        }
      });

      for (final (typed, kind) in [
        ('num', NoteBlockKind.numbers),
        ('todo', NoteBlockKind.todo),
        ('مهام', NoteBlockKind.todo), // مهام
        ('مرق', NoteBlockKind.numbers), // مرق(مة)
        ('Numb', NoteBlockKind.numbers),
      ]) {
        testWidgets('"/$typed" finds ${kind.name} by English, Arabic or a '
            'simple word; Enter picks it', (tester) async {
          await _open(tester, lang, [PageText(_id(1), '')]);
          await _cursor(tester, 1);
          await _type(tester, '/$typed');
          expect(_key('page-add-${kind.name}'), findsOneWidget);
          expect(
            find.descendant(
              of: _key('page-add-menu'),
              matching: find.byType(InkWell),
            ),
            findsOneWidget,
          );
          await tester.testTextInput.receiveAction(TextInputAction.next);
          await tester.pumpAndSettle();
          expect(_key('page-add-menu'), findsNothing);
          expect(NoteBlockKind.of(_blocks(tester).single), kind);
        });
      }

      testWidgets('after words, the line turns and keeps them', (tester) async {
        await _open(tester, lang, [PageText(_id(1), 'Pour')]);
        await _cursor(tester, 1);
        await _type(tester, ' /num');
        await tester.testTextInput.receiveAction(TextInputAction.next);
        await tester.pumpAndSettle();
        final b = _blocks(tester).single;
        expect(b, isA<PageNumbered>());
        expect((b as PageNumbered).text, 'Pour ');
      });

      testWidgets('Escape closes it and leaves the "/"; so does a space with '
          'no match', (tester) async {
        await _open(tester, lang, [PageText(_id(1), '')]);
        await _cursor(tester, 1);
        await _type(tester, '/nu');
        expect(_key('page-add-menu'), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(_key('page-add-menu'), findsNothing);
        expect(_words(tester), ['/nu']);
        expect(_blocks(tester).single, isA<PageText>());
        // Typing on doesn't open it again.
        await _type(tester, 'm');
        expect(_key('page-add-menu'), findsNothing);
        await _type(tester, ' /zz');
        expect(_key('page-add-menu'), findsNothing);
        await _type(tester, ' ');
        await _type(tester, 'x');
        expect(_key('page-add-menu'), findsNothing);
        expect(_words(tester), ['/num /zz x']);
      });
    });

    group('+ and the bar [$lang]', () {
      testWidgets('+ adds a line below the line and its children, at its '
          'level; an empty text line is turned instead', (tester) async {
        await _open(tester, lang, [
          PageNumbered(_id(1), 'Pour'),
          PageTodo(_id(2), 'Slump', indent: 1),
          PageText(_id(3), 'End'),
        ]);
        await _cursor(tester, 1);
        await _tap(tester, _key('note-tool-categories'));
        expect(_key('page-add-menu'), findsOneWidget);
        await _tap(tester, _key('page-add-bullets'));
        expect(_blocks(tester).map((b) => b.runtimeType), [
          PageNumbered,
          PageTodo,
          PageBullet,
          PageText,
        ]);
        expect(_levels(tester), [0, 1, 0, 0]);
        expect(_words(tester), ['Pour', 'Slump', '', 'End']);
        // Each tile says what to type for it.
        await _tap(tester, _key('note-tool-categories'));
        // Its shortcut at the row's end, left to right in Arabic too.
        final quote = find.descendant(
          of: _key('page-add-quote'),
          matching: find.text('"'),
        );
        expect(tester.widget<Text>(quote).textDirection, TextDirection.ltr);
        // On the empty bullet + adds a line; on an empty text line it turns.
        await _tap(tester, _key('page-add-text'));
        expect(_blocks(tester), hasLength(5));
        await _tap(tester, _key('note-tool-categories'));
        await _tap(tester, _key('page-add-todo'));
        expect(_blocks(tester), hasLength(5));
        expect(_blocks(tester)[3], isA<PageTodo>());
      });

      testWidgets('NBY3, NBY4: ⇥ ⇤ show only when they can act', (
        tester,
      ) async {
        await _open(tester, lang, [
          PageHeading(_id(9), 'Before the pour, level 3'),
          ..._pour(),
        ]);
        // A heading: neither.
        await _cursor(tester, 9);
        expect(_key('note-tool-indent'), findsNothing);
        expect(_key('note-tool-outdent'), findsNothing);
        // The second to-do: both.
        await _cursor(tester, 4);
        expect(_key('note-tool-indent'), findsOneWidget);
        expect(_key('note-tool-outdent'), findsOneWidget);
        // The first to-do: only ⇤.
        await _cursor(tester, 3);
        expect(_key('note-tool-indent'), findsNothing);
        expect(_key('note-tool-outdent'), findsOneWidget);
        // Location and the others stay where they are.
        expect(_key('note-tool-add'), findsOneWidget);
        expect(_key('writing-post'), findsOneWidget);
      });
    });

    group('the line menu [$lang]', () {
      testWidgets('NBY2: from ⋮⋮, next to the line, the line tinted; rows '
          'in order, those that cannot act hidden', (tester) async {
        await _open(tester, lang, _pour());
        await _menu(tester, 2);
        expect(_key('page-block-menu'), findsOneWidget);
        expect(find.byType(BottomSheet), findsNothing);
        expect(_key('page-marked-${_id(2)}'), findsOneWidget);
        final rows = [
          'page-turn-into',
          'page-move-up',
          'page-move-down',
          'page-indent',
          'page-restart-numbering',
        ];
        var top = 0.0;
        for (final row in rows) {
          expect(_key(row), findsOneWidget, reason: row);
          final y = tester.getRect(_key(row)).top;
          expect(y, greaterThan(top), reason: row);
          top = y;
        }
        // Level 0 can't come out; no list before it to continue.
        expect(_key('page-outdent'), findsNothing);
        expect(_key('page-continue-numbering'), findsNothing);
        // Review 100 BH10: the line's structure only.
        expect(_key('page-duplicate'), findsNothing);
        expect(_key('page-block-delete'), findsNothing);
        expect(find.text(l10n.pageTurnInto), findsOneWidget);
        // Its end lined up with the line's, under it.
        final line = tester.getRect(_key('page-marked-${_id(2)}'));
        final menu = tester.getRect(_key('page-block-menu'));
        expect(menu.top > line.bottom || menu.bottom < line.top, isTrue);
        expect(
          lang == 'ar'
              ? (menu.left - line.left).abs()
              : (menu.right - line.right).abs(),
          lessThan(1),
        );
        // A tap elsewhere closes it.
        await _away(tester);
        expect(_key('page-block-menu'), findsNothing);
        expect(_key('page-marked-${_id(2)}'), findsNothing);
      });

      testWidgets('the first line has no Move up; the last no Move down; a '
          'heading no Indent', (tester) async {
        await _open(tester, lang, [PageHeading(_id(9), 'Level 3'), ..._pour()]);
        await _menu(tester, 9);
        expect(_key('page-move-up'), findsNothing);
        expect(_key('page-move-down'), findsOneWidget);
        expect(_key('page-indent'), findsNothing);
        expect(_key('page-restart-numbering'), findsNothing);
        await _away(tester);
        await _menu(tester, 5);
        expect(_key('page-move-down'), findsNothing);
        expect(_key('page-move-up'), findsOneWidget);
        await _away(tester);
        // The first to-do under Check: nothing before it under its parent.
        await _menu(tester, 3);
        expect(_key('page-move-up'), findsNothing);
        expect(_key('page-indent'), findsNothing);
        expect(_key('page-outdent'), findsOneWidget);
      });

      testWidgets('holding the marker selects the line (review 100 BH12); '
          'holding the words selects them', (tester) async {
        await _open(tester, lang, _pour());
        await _cursor(tester, 1);
        await tester.longPress(_key('note-marker-${_id(4)}'));
        await tester.pumpAndSettle();
        expect(_key('page-block-menu'), findsNothing);
        expect(_key('line-selected-${_id(4)}'), findsOneWidget);
        await _tap(tester, _key('selection-close'));
        await tester.longPress(_key('note-marker-${_id(2)}'));
        await tester.pumpAndSettle();
        expect(_key('line-selected-${_id(2)}'), findsOneWidget);
        await _tap(tester, _key('selection-close'));
        // The words: a selection, no menu.
        final words = tester.getRect(_line(5));
        await tester.longPressAt(
          lang == 'ar'
              ? words.topRight + const Offset(-24, 10)
              : words.topLeft + const Offset(24, 10),
        );
        await tester.pumpAndSettle();
        expect(_key('page-block-menu'), findsNothing);
        final c = tester.widget<TextField>(_line(5)).controller!;
        expect(c.selection.isCollapsed, isFalse);
      });

      testWidgets('NBY5: Move down jumps the next group with the children; '
          'Moved · Undo; Undo puts it back', (tester) async {
        await _open(tester, lang, _pour());
        final before = _json(tester);
        await _menu(tester, 2);
        await _tap(tester, _key('page-move-down'));
        expect(_words(tester), [
          'Clean the formwork',
          'Confirm the pump slot',
          'Check the rebar',
          'Cover at the edges',
          'Spacers every 1 m',
        ]);
        expect(_levels(tester), [0, 0, 0, 1, 1]);
        expect(find.text('3.'), findsOneWidget);
        expect(find.text(l10n.notebookUndoMoved), findsOneWidget);
        // The moved line stays tinted while its Undo shows.
        expect(_key('page-marked-${_id(2)}'), findsOneWidget);
        await _undo(tester);
        expect(_json(tester), before);
        // Move up over a whole group: Confirm goes above Check and its
        // to-dos.
        await _menu(tester, 5);
        await _tap(tester, _key('page-move-up'));
        expect(_words(tester), [
          'Clean the formwork',
          'Confirm the pump slot',
          'Check the rebar',
          'Cover at the edges',
          'Spacers every 1 m',
        ]);
      });

      testWidgets('Duplicate (the selection bar, review 100 BH12) copies the '
          'line with its children, right after them', (tester) async {
        await _open(tester, lang, _pour());
        await _cursor(tester, 1);
        await tester.longPress(_key('note-marker-${_id(2)}'));
        await tester.pumpAndSettle();
        await _tap(tester, _key('select-duplicate'));
        expect(_words(tester), [
          'Clean the formwork',
          'Check the rebar',
          'Cover at the edges',
          'Spacers every 1 m',
          'Check the rebar',
          'Cover at the edges',
          'Spacers every 1 m',
          'Confirm the pump slot',
        ]);
        expect(_levels(tester), [0, 0, 1, 1, 0, 1, 1, 0]);
        expect(_blocks(tester).map((b) => b.id).toSet(), hasLength(8));
        expect(find.text(l10n.notebookUndoDuplicated), findsOneWidget);
      });

      for (final (row, n, message) in [
        ('page-turn-into', 2, l10n.notebookUndoTurned(l10n.notebookBullets)),
        ('page-move-up', 5, l10n.notebookUndoMoved),
        ('page-move-down', 1, l10n.notebookUndoMoved),
        ('page-indent', 5, l10n.notebookUndoIndented),
        ('page-outdent', 4, l10n.notebookUndoOutdented),
        // The selection bar's (review 100 BH12).
        ('select-duplicate', 2, l10n.notebookUndoDuplicated),
        ('select-delete', 2, l10n.notebookUndoDeleted),
      ]) {
        testWidgets('Undo after $row restores the note exactly', (
          tester,
        ) async {
          await _open(tester, lang, _pour());
          final before = _json(tester);
          if (row.startsWith('select-')) {
            await _cursor(tester, 1);
            await tester.longPress(_key('note-marker-${_id(n)}'));
            await tester.pumpAndSettle();
          } else {
            await _menu(tester, n);
          }
          await _tap(tester, _key(row));
          if (row == 'page-turn-into') {
            await _tap(tester, _key('page-turn-bullets'));
          }
          expect(_json(tester), isNot(before));
          expect(find.text(message), findsOneWidget);
          await _undo(tester);
          expect(_json(tester), before);
          expect(find.text(message), findsNothing);
        });
      }

      testWidgets('no drag on ⋮⋮ on a phone; a tablet keeps it', (
        tester,
      ) async {
        await _open(tester, lang, _pour());
        await _cursor(tester, 2);
        Finder drag() => find.ancestor(
          of: _key('page-handle-${_id(2)}'),
          matching: find.byType(ReorderableDelayedDragStartListener),
        );
        expect(_key('page-handle-${_id(2)}'), findsOneWidget);
        expect(drag(), findsNothing);
        tester.view.physicalSize = const Size(820, 1180);
        await tester.pumpAndSettle();
        expect(drag(), findsOneWidget);
      });
    });

    group('motion [$lang]', () {
      testWidgets('menus open in 150 ms; Move down and a fold slide in '
          '180 ms', (tester) async {
        await _open(tester, lang, _pour());
        await _cursor(tester, 2);
        await tester.tap(_key('page-handle-${_id(2)}'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.binding.hasScheduledFrame, isTrue);
        await tester.pump(const Duration(milliseconds: 60));
        expect(tester.binding.hasScheduledFrame, isFalse);
        await tester.tap(_key('page-move-down'));
        await tester.pump();
        // Sliding: Check is still near where it was.
        final from = tester.getTopLeft(_line(2)).dy;
        await tester.pump(const Duration(milliseconds: 200));
        final to = tester.getTopLeft(_line(2)).dy;
        expect(to, greaterThan(from));
        await tester.pumpAndSettle();
        // The fold slides shut, then its lines go.
        await _undo(tester);
        await tester.tap(_key('note-fold-${_id(2)}'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 90));
        expect(_line(3), findsOneWidget);
        await tester.pumpAndSettle();
        expect(_line(3), findsNothing);
      });

      testWidgets('Reduce motion: nothing moves', (tester) async {
        await _open(tester, lang, _pour());
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        await tester.pumpAndSettle();
        await _cursor(tester, 2);
        await tester.tap(_key('page-handle-${_id(2)}'));
        await tester.pump();
        // The menu is there at once, fully.
        expect(_key('page-block-menu'), findsOneWidget);
        final fades = find.ancestor(
          of: _key('page-block-menu'),
          matching: find.byType(FadeTransition),
        );
        expect(tester.widget<FadeTransition>(fades.first).opacity.value, 1);
        await tester.tap(_key('page-move-down'));
        await tester.pump();
        // In its place at once.
        final at = tester.getTopLeft(_line(2)).dy;
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(_line(2)).dy, at);
        expect(
          tester.getTopLeft(_line(2)).dy,
          greaterThan(tester.getTopLeft(_line(5)).dy),
        );
        // A fold shuts at once.
        await _undo(tester);
        await tester.tap(_key('note-fold-${_id(2)}'));
        await tester.pump();
        expect(_line(3), findsNothing);
      });
    });

    // Lead, 26 Oct: the cards open under the line (over the bar and the
    // keyboard), over it only when there is no room; the line menu is
    // never cut; the title has no ⇥ ⇤ and no ⋮⋮.
    group('where the cards open [$lang]', () {
      /// A phone of [height]: 390 wide.
      void phone(WidgetTester tester, double height) {
        tester.view.physicalSize = Size(390, height) * 3;
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
      }

      /// Twelve lines: the first stands high on the screen, the last low.
      List<PageBlock> long() => [
        for (var n = 1; n <= 12; n++) PageNumbered(_id(n), 'Line $n'),
      ];

      Rect menu(WidgetTester tester) => tester.getRect(_key('page-block-menu'));

      void everyRowShows(WidgetTester tester) {
        expect(
          find.descendant(
            of: _key('page-block-menu'),
            matching: find.byType(Scrollable),
          ),
          findsNothing,
        );
        final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
        final rows = find.descendant(
          of: _key('page-block-menu'),
          matching: find.byType(InkWell),
        );
        expect(rows, findsAtLeastNWidgets(3));
        for (final e in rows.evaluate()) {
          final r = tester.getRect(find.byWidget(e.widget));
          expect(r.top >= 0 && r.bottom <= screen.height, isTrue);
        }
      }

      testWidgets('the line menu opens under a line with room under it, every '
          'row in sight', (tester) async {
        await _open(tester, lang, long());
        phone(tester, 844);
        await tester.pumpAndSettle();
        await _menu(tester, 1);
        expect(menu(tester).top, greaterThan(tester.getRect(_line(1)).bottom));
        everyRowShows(tester);
      });

      testWidgets('near the bottom, over the line, every row in sight', (
        tester,
      ) async {
        await _open(tester, lang, long());
        phone(tester, 844);
        await tester.pumpAndSettle();
        await _menu(tester, 12);
        expect(menu(tester).bottom, lessThan(tester.getRect(_line(12)).top));
        everyRowShows(tester);
      });

      testWidgets('no room either way: the note scrolls first, and the menu '
          'is never cut', (tester) async {
        // Long enough to scroll.
        await _open(tester, lang, [
          for (var n = 1; n <= 30; n++) PageNumbered(_id(n), 'Line $n'),
        ]);
        phone(tester, 420);
        await tester.pumpAndSettle();
        // A line in the middle: room for the menu (its five rows) neither
        // under it nor over it.
        const need = 5 * 44 + 2 * 6 + 4;
        final n = [
          for (var n = 1; n <= 20; n++)
            if (_line(n).evaluate().isNotEmpty &&
                tester.getRect(_line(n)).top - 16 < need &&
                420 - 16 - tester.getRect(_line(n)).bottom < need)
              n,
        ].first;
        await _cursor(tester, n);
        final before = tester.getRect(_line(n)).top;
        await _tap(tester, _key('page-handle-${_id(n)}'));
        expect(tester.getRect(_line(n)).top, isNot(before));
        everyRowShows(tester);
        final line = tester.getRect(_line(n));
        final card = menu(tester);
        expect(card.top >= line.bottom || card.bottom <= line.top, isTrue);
      });

      testWidgets('the "/" card opens under the line when it fits', (
        tester,
      ) async {
        await _open(tester, lang, [
          PageText(_id(1), ''),
          for (var n = 2; n <= 8; n++) PageNumbered(_id(n), 'Line $n'),
        ]);
        phone(tester, 844);
        await tester.pumpAndSettle();
        await _cursor(tester, 1);
        await _type(tester, '/num');
        // Under the line's words (the card lines up with the text, not the
        // field's padding).
        expect(
          tester.getRect(_key('page-add-menu')).top,
          greaterThan(tester.getRect(_line(1)).center.dy),
        );
      });

      testWidgets('the cursor in the title: no ⇥ ⇤, no ⋮⋮ (NBY4)', (
        tester,
      ) async {
        await _open(tester, lang, [
          PageNumbered(_id(1), 'Clean the formwork'),
          PageNumbered(_id(2), 'Check the rebar'),
        ]);
        await _cursor(tester, 2);
        expect(_key('note-tool-indent'), findsOneWidget);
        expect(_key('page-handle-${_id(2)}'), findsOneWidget);
        await _tap(tester, _key('note-title'));
        expect(_key('note-tool-indent'), findsNothing);
        expect(_key('note-tool-outdent'), findsNothing);
        expect(find.byKey(Key('page-handle-${_id(2)}')), findsNothing);
        // Back on the line, they come back.
        await _cursor(tester, 2);
        expect(_key('note-tool-indent'), findsOneWidget);
        expect(_key('page-handle-${_id(2)}'), findsOneWidget);
      });
    });
  }
}
