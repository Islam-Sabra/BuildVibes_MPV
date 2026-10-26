// Review 100, the bugs from the founder's test of build 640 (B1–B5): the
// keyboard never drops between lines; a saved entry is edited in place;
// "Write in this page" always starts a new entry; a menu never goes under
// the keyboard; ⋯ opens at once, one menu at a time, and Back closes the
// menu first. In English and Arabic.
import 'dart:async';
import 'dart:convert';

import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/core/design/daybook_writing_specs.dart'
    show BvLineMenuSpec;
import 'package:buildvibes/core/l10n/locale_controller.dart';
import 'package:buildvibes/data/models/note.dart';
import 'package:buildvibes/data/models/post_page.dart';
import 'package:buildvibes/data/models/space.dart'
    show SpaceException, SpaceFailure;
import 'package:buildvibes/features/notebook/note_draft.dart';
import 'package:buildvibes/features/notebook/note_page_editor.dart';
import 'package:buildvibes/features/notebook/notebook_state.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_line_popover.dart'
    show visibleTop;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/notebook_fakes.dart';
import '../../helpers/notebook_samples.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

const _page = '/notebook/pages/${FakeNotebookRepository.myNotesId}';

Future<TestApp> _open(
  WidgetTester tester,
  String lang, {
  List<Note> notes = const [],
  NoteDraft? draft,
  FakeSpaceRepository? spaces,
  FakeNotebookRepository? notebook,
}) async {
  final app = await pumpApp(
    tester,
    language: lang,
    now: NotebookSamples.now,
    notebook: notebook ?? FakeNotebookRepository(notes: notes),
    spaces: spaces,
    stored: {
      if (draft != null) 'notebook_draft:user-1': jsonEncode(draft.toJson()),
    },
  );
  GoRouter.of(tester.element(find.byType(Navigator).first)).push(_page);
  await tester.pumpAndSettle();
  return app;
}

NoteDraft _draft(List<PageBlock> blocks, {String title = 'Pour'}) => NoteDraft(
  id: 'draft-1',
  startedAt: NotebookSamples.now,
  title: title,
  blocks: blocks,
  pageId: FakeNotebookRepository.myNotesId,
);

NotePageEditorState _editor(WidgetTester tester) =>
    tester.state<NotePageEditorState>(find.byType(NotePageEditor));

NoteDraft? _drafted(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(Scaffold).first),
).read(noteDraftProvider);

bool _focused(WidgetTester tester, String key) =>
    tester.widget<TextField>(_key('page-field-$key')).focusNode!.hasFocus;

/// Records every moment the focus was on something other than a line's
/// field (nothing, a scope, a button): on a phone the keyboard drops then.
/// Moving from one field straight to another keeps it up.
List<Object?> _watchFocus(WidgetTester tester) {
  final gaps = <Object?>[];
  bool field(FocusNode? f) {
    final ctx = f?.context;
    return ctx != null &&
        ctx.findAncestorWidgetOfExactType<NotePageEditor>() != null &&
        ctx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  void listen() {
    final f = FocusManager.instance.primaryFocus;
    if (!field(f)) gaps.add(f);
  }

  FocusManager.instance.addListener(listen);
  addTearDown(() => FocusManager.instance.removeListener(listen));
  tester.testTextInput.log.clear();
  return gaps;
}

/// The keyboard was told to go away.
bool _hidden(WidgetTester tester) =>
    tester.testTextInput.log.any((c) => c.method == 'TextInput.hide');

Note _saved() => Note(
  id: 'entry-1',
  kind: NoteKind.text,
  title: 'Pour',
  blocks: [PageText('s-1', 'Clean the formwork')],
  body: 'Pour\nClean the formwork',
  createdAt: DateTime(2026, 10, 15, 9),
  pageId: FakeNotebookRepository.myNotesId,
);

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));

    group('B1 the keyboard never drops [$lang]', () {
      testWidgets('Enter in a to-do: the next line has the cursor in the '
          'same pump, and the focus never leaves the fields', (tester) async {
        await _open(tester, lang, draft: _draft([PageTodo('t-1', 'Rebar')]));
        await _tap(tester, _key('note-draft'));
        _editor(tester).focusBlock('t:t-1');
        await tester.pumpAndSettle();
        final gaps = _watchFocus(tester);
        await tester.testTextInput.receiveAction(TextInputAction.next);
        await tester.pump();
        final next = _drafted(tester)!.blocks.last;
        expect(_drafted(tester)!.blocks, hasLength(2));
        expect(next, isA<PageTodo>());
        expect(_focused(tester, 't:${next.id}'), isTrue);
        await tester.pumpAndSettle();
        expect(gaps, isEmpty);
        expect(_hidden(tester), isFalse);
      });

      testWidgets('Backspace on an empty line: the line above has the '
          'cursor in the same pump', (tester) async {
        await _open(
          tester,
          lang,
          draft: _draft([PageText('t-1', 'Rebar'), PageText('t-2', '')]),
        );
        await _tap(tester, _key('note-draft'));
        _editor(tester).focusBlock('t:t-2');
        await tester.pumpAndSettle();
        final gaps = _watchFocus(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
        await tester.pump();
        expect(_focused(tester, 't:t-1'), isTrue);
        await tester.pumpAndSettle();
        expect(_drafted(tester)!.blocks, hasLength(1));
        expect(gaps, isEmpty);
        expect(_hidden(tester), isFalse);
      });
    });

    group('B2 a saved entry is edited in place [$lang]', () {
      testWidgets('changed, then Back: one card with the new words, "Saved '
          '· Undo"; Undo gives the old words back', (tester) async {
        final app = await _open(tester, lang, notes: [_saved()]);
        await _tap(tester, _key('note-entry-1'));
        await tester.enterText(_key('note-title'), 'Pour, level 3');
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(_key('note-draft'), findsNothing);
        expect(_key('note-entry-1'), findsOneWidget);
        expect(app.notebook.kept['entry-1']!.title, 'Pour, level 3');
        expect(find.text(l10n.notebookSavedEdit), findsOneWidget);
        expect(_drafted(tester), isNull);
        await tester.tap(find.text(l10n.daybookUndo));
        await tester.pumpAndSettle();
        expect(app.notebook.kept['entry-1']!.title, 'Pour');
        expect(find.text('Pour'), findsOneWidget);
      });

      testWidgets('no change, then Back: nothing saved, nothing shown', (
        tester,
      ) async {
        final app = await _open(tester, lang, notes: [_saved()]);
        await _tap(tester, _key('note-entry-1'));
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(app.notebook.calls.where((c) => c.startsWith('save:')), isEmpty);
        expect(find.text(l10n.notebookSavedEdit), findsNothing);
        expect(_key('note-draft'), findsNothing);
        expect(_drafted(tester), isNull);
      });

      testWidgets('D1: an edit left open when the app was closed opens '
          'again in the editor; nothing is sent until Back', (tester) async {
        final edit = NoteDraft.of(_saved()).copyWith(title: 'Pour, edited');
        final app = await _open(tester, lang, notes: [_saved()], draft: edit);
        // Back in the editor, where it was, not a Draft card.
        expect(_key('note-draft'), findsNothing);
        expect(_key('note-tools'), findsOneWidget);
        expect(find.text('Pour, edited'), findsOneWidget);
        // Nothing sent without the person.
        expect(app.notebook.calls.where((c) => c.startsWith('save:')), isEmpty);
        expect(app.notebook.kept['entry-1']!.title, 'Pour');
        // Back saves it in place, as any edit (B2), with Undo.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(app.notebook.kept['entry-1']!.title, 'Pour, edited');
        expect(find.text(l10n.notebookSavedEdit), findsOneWidget);
        await tester.tap(find.text(l10n.daybookUndo));
        await tester.pumpAndSettle();
        expect(app.notebook.kept['entry-1']!.title, 'Pour');
      });

      testWidgets('D2: Back with a delete on its Undo bar and a call that '
          'hangs: the edit is in the outbox before the Draft goes', (
        tester,
      ) async {
        final gate = Completer<void>();
        final app = await _open(tester, lang, notes: [_saved()]);
        await _tap(tester, _key('note-entry-1'));
        await tester.enterText(_key('note-title'), 'Pour, level 3');
        await tester.pumpAndSettle();
        // A page delete waits on its Undo bar; its call will hang.
        final c = ProviderScope.containerOf(
          tester.element(find.byType(Scaffold).first),
        );
        await c
            .read(notebookProvider.notifier)
            .hold(const NoteChange.deletePages(['page-x']));
        app.notebook
          ..gate = gate.future
          ..offline = true;
        await tester.binding.handlePopRoute();
        await tester.pump();
        await tester.pump();
        // The app is killed now: what the phone holds must have the edit.
        final prefs = c.read(sharedPreferencesProvider);
        final draft = prefs.getString('notebook_draft:user-1');
        final waiting = prefs.getString('notebook_waiting:user-1') ?? '';
        expect(
          waiting.contains('Pour, level 3') ||
              (draft?.contains('Pour, level 3') ?? false),
          isTrue,
          reason: 'waiting: $waiting, draft: $draft',
        );
        gate.complete();
        await tester.pumpAndSettle();
      });

      testWidgets('D3: emptied, then Back: "Deleted · Undo"; it goes when the '
          'bar closes', (tester) async {
        final app = await _open(tester, lang, notes: [_saved()]);
        await _tap(tester, _key('note-entry-1'));
        await tester.enterText(_key('note-title'), '');
        await tester.enterText(_key('page-field-t:s-1'), '');
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text(l10n.notebookUndoDeleted), findsOneWidget);
        expect(_key('note-entry-1'), findsNothing);
        expect(_drafted(tester), isNull);
        // Sent only once the Undo bar has gone.
        expect(app.notebook.calls, isNot(contains('delete:entry-1')));
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();
        expect(app.notebook.calls, contains('delete:entry-1'));
        expect(app.notebook.kept['entry-1'], isNull);
      });

      testWidgets('D3: emptied, Back, then Undo: the entry is back as it was',
          (tester) async {
        final app = await _open(tester, lang, notes: [_saved()]);
        await _tap(tester, _key('note-entry-1'));
        await tester.enterText(_key('note-title'), '');
        await tester.enterText(_key('page-field-t:s-1'), '');
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.daybookUndo));
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();
        expect(_key('note-entry-1'), findsOneWidget);
        expect(app.notebook.calls, isNot(contains('delete:entry-1')));
        expect(app.notebook.kept['entry-1']!.title, 'Pour');
      });

      testWidgets('D4: a refused edit stays an edit of that entry: one card, '
          'its words back in the editor', (tester) async {
        final app = await _open(
          tester,
          lang,
          notes: [_saved()],
          notebook: _RefusingEdits(notes: [_saved()]),
        );
        await _tap(tester, _key('note-entry-1'));
        await tester.enterText(_key('note-title'), 'Pour, level 3');
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text(l10n.notebookCouldntKeep), findsOneWidget);
        // No Draft card beside the entry: the edit is back in the editor.
        expect(_key('note-draft'), findsNothing);
        expect(_key('note-tools'), findsOneWidget);
        expect(_drafted(tester)!.editing?.id, 'entry-1');
        expect(_drafted(tester)!.title, 'Pour, level 3');
        expect(app.notebook.kept['entry-1']!.title, 'Pour');
        // Back again with no new change leaves: never a loop of refusals.
        final saves = app.notebook.calls.where((c) => c.startsWith('save:'));
        final tries = saves.length;
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(_key('note-tools'), findsNothing);
        expect(_key('note-draft'), findsNothing);
        expect(_key('note-entry-1'), findsOneWidget);
        expect(
          app.notebook.calls.where((c) => c.startsWith('save:')),
          hasLength(tries),
        );
      });

      testWidgets('a Draft\'s ⋯: Discard, with Undo', (tester) async {
        await _open(tester, lang, draft: _draft([PageText('t-1', 'Rebar')]));
        await _tap(tester, _key('note-draft-menu-draft-1'));
        await _tap(tester, _key('note-draft-discard'));
        expect(_key('note-draft'), findsNothing);
        await tester.tap(find.text(l10n.daybookUndo));
        await tester.pumpAndSettle();
        expect(_key('note-draft'), findsOneWidget);
      });
    });

    group('B3 Write in this page always starts a new entry [$lang]', () {
      testWidgets('a Draft stays its own card; a second Draft beside it', (
        tester,
      ) async {
        await _open(
          tester,
          lang,
          draft: _draft([PageText('t-1', 'Rebar')], title: 'Old'),
        );
        await _tap(tester, _key('page-write'));
        expect(_drafted(tester)!.id, isNot('draft-1'));
        expect(_drafted(tester)!.title, isEmpty);
        await tester.enterText(_key('note-title'), 'New');
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(_key('note-draft'), findsNWidgets(2));
        expect(find.text('Old'), findsOneWidget);
        expect(find.text('New'), findsOneWidget);
        // Each goes on where it was left.
        await _tap(tester, _key('note-draft-card-draft-1'));
        expect(_drafted(tester)!.title, 'Old');
      });
    });

    group('B4 a menu never goes under the keyboard [$lang]', () {
      testWidgets('the line at the bottom of the room the keyboard leaves: '
          'the line menu ends above the keyboard', (tester) async {
        await _open(
          tester,
          lang,
          draft: _draft([
            for (var i = 0; i < 12; i++) PageText('t-$i', 'Line $i'),
          ]),
        );
        await _tap(tester, _key('note-draft'));
        tester.view.viewInsets = FakeViewPadding(
          bottom: 300 * tester.view.devicePixelRatio,
        );
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        _editor(tester).focusBlock('t:t-11');
        await tester.pumpAndSettle();
        await tester.tap(_key('page-handle-t-11'));
        await tester.pumpAndSettle();
        final screen =
            tester.view.physicalSize.height / tester.view.devicePixelRatio;
        final keyboardTop =
            screen -
            tester.view.viewInsets.bottom / tester.view.devicePixelRatio;
        final menu = tester.getRect(_key('page-block-menu'));
        expect(menu.bottom, lessThanOrEqualTo(keyboardTop));
        expect(menu.top, greaterThanOrEqualTo(BvSize.topBar));
      });
    });

    group('D5, D6 room for a card, with the keyboard up [$lang]', () {
      /// 30 lines, the keyboard 300 high, and line [n] in the middle of the
      /// room left: a card fits neither under it nor over it.
      Future<double> middle(WidgetTester tester, int n) async {
        await _open(
          tester,
          lang,
          draft: _draft([
            for (var i = 0; i < 30; i++) PageText('t-$i', 'Line $i'),
          ]),
        );
        await _tap(tester, _key('note-draft'));
        tester.view.viewInsets = FakeViewPadding(
          bottom: 300 * tester.view.devicePixelRatio,
        );
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        _editor(tester).focusBlock('t:t-$n');
        await tester.pumpAndSettle();
        await Scrollable.ensureVisible(
          tester.element(_key('page-field-t:t-$n')),
          alignment: 0.5,
        );
        await tester.pumpAndSettle();
        final screen =
            tester.view.physicalSize.height / tester.view.devicePixelRatio;
        return screen - 300;
      }

      void beside(WidgetTester tester, String card, int n, double floor) {
        final line = tester.getRect(_key('page-field-t:t-$n'));
        final rect = tester.getRect(_key(card));
        // Never on the line, never under the keyboard or the top bar.
        expect(
          rect.top >= line.bottom || rect.bottom <= line.top,
          isTrue,
          reason: 'card $rect, line $line',
        );
        expect(rect.bottom, lessThanOrEqualTo(floor));
        expect(rect.top, greaterThanOrEqualTo(BvSize.topBar));
        // Every row shows: the card doesn't scroll inside.
        final inner = tester.state<ScrollableState>(
          find
              .ancestor(of: _key(card), matching: find.byType(Scrollable))
              .first,
        );
        expect(inner.position.maxScrollExtent, 0);
      }

      testWidgets('D5: the line menu: the line scrolls up first, though the '
          'Scaffold takes the keyboard out of its insets', (tester) async {
        final floor = await middle(tester, 14);
        await tester.tap(_key('page-handle-t-14'));
        await tester.pumpAndSettle();
        beside(tester, 'page-block-menu', 14, floor);
      });

      testWidgets('D6: the "/" card makes room for its real height', (
        tester,
      ) async {
        final floor = await middle(tester, 14);
        final c = tester.widget<TextField>(_key('page-field-t:t-14'));
        final words = c.controller!.text;
        tester.testTextInput.enterText('$words ');
        await tester.pumpAndSettle();
        tester.testTextInput.enterText('$words /');
        await tester.pumpAndSettle();
        expect(_key('page-add-menu'), findsOneWidget);
        beside(tester, 'page-add-menu', 14, floor);
      });
    });

    testWidgets('D7: the top bar and the room under it read one BV token '
        '[$lang]', (tester) async {
      await _open(tester, lang);
      final bar = tester.getRect(find.byType(AppBar).first);
      expect(bar.height, BvSize.topBar);
      final media = MediaQuery.of(tester.element(find.byType(AppBar).first));
      expect(
        visibleTop(media),
        media.padding.top + BvSize.topBar + BvLineMenuSpec.screenMargin,
      );
    });

    group('B5 ⋯ opens at once, one menu at a time [$lang]', () {
      testWidgets('⋯ opens before the Spaces have come; a second tap opens '
          'no second menu', (tester) async {
        final gate = Completer<void>();
        await _open(
          tester,
          lang,
          notes: [_saved()],
          spaces: FakeSpaceRepository()..spacesGate = gate.future,
        );
        await tester.tap(_key('note-menu-entry-1'));
        await tester.tap(_key('note-menu-entry-1'), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 400));
        expect(_key('note-menu'), findsOneWidget);
        gate.complete();
        await tester.pumpAndSettle();
        expect(_key('note-menu'), findsOneWidget);
      });

      testWidgets('Back closes the line menu first, and writing goes on', (
        tester,
      ) async {
        await _open(tester, lang, draft: _draft([PageText('t-1', 'Rebar')]));
        await _tap(tester, _key('note-draft'));
        _editor(tester).focusBlock('t:t-1');
        await tester.pumpAndSettle();
        await tester.tap(_key('page-handle-t-1'));
        await tester.pumpAndSettle();
        expect(_key('page-block-menu'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(_key('page-block-menu'), findsNothing);
        expect(_key('note-tools'), findsOneWidget);
      });
    });
  }
}

/// The server refuses every save (D4).
class _RefusingEdits extends FakeNotebookRepository {
  _RefusingEdits({super.notes});

  @override
  Future<bool> save(Note note, {String? newPageTitle}) async {
    calls.add('save:${note.id}');
    throw const SpaceException(SpaceFailure.badInput);
  }
}
