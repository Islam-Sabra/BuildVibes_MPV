// Review 100, the bugs from the founder's test of build 640 (B1–B5): the
// keyboard never drops between lines; a saved entry is edited in place;
// "Write in this page" always starts a new entry; a menu never goes under
// the keyboard; ⋯ opens at once, one menu at a time, and Back closes the
// menu first. In English and Arabic.
import 'dart:async';
import 'dart:convert';

import 'package:buildvibes/data/models/note.dart';
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
}) async {
  final app = await pumpApp(
    tester,
    language: lang,
    now: NotebookSamples.now,
    notebook: FakeNotebookRepository(notes: notes),
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
        expect(menu.top, greaterThanOrEqualTo(kToolbarHeight));
      });
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
