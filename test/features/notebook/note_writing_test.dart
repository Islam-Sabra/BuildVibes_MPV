// F106 (review 90): My notebook writes in place. A slip at the end of
// today with the keyboard up; the kind chip; Work's point editor; by when
// and Remind me as chips; Send; photos; the Voice tool; a Draft kept on
// leaving. In English and Arabic.
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/data/models/daybook.dart' show dayOf;
import 'package:buildvibes/data/models/note.dart';
import 'package:buildvibes/features/notebook/note_draft.dart';
import 'package:buildvibes/features/work/daybook_words.dart';
import 'package:buildvibes/features/work/daybook_writing.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/gestures.dart' show kLongPressTimeout;
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

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

/// Four o'clock today, from the daybook's day-and-time picker.
final _pickFour = pickDueProvider.overrideWithValue(
  (context, {required now, day, at}) async =>
      (day: DateTime(2026, 10, 15), at: DateTime(2026, 10, 15, 16)),
);

Future<TestApp> _open(
  WidgetTester tester,
  String lang, {
  List<Note> notes = const [],
}) async {
  final app = await pumpApp(
    tester,
    language: lang,
    now: NotebookSamples.now,
    notebook: FakeNotebookRepository(notes: notes),
    overrides: [_pickFour],
  );
  GoRouter.of(tester.element(find.byType(Navigator).first)).push('/notebook');
  await tester.pumpAndSettle();
  return app;
}

Future<void> _note(WidgetTester tester) =>
    _tap(tester, _key('post-bar-notepad'));

NoteDraft? _draft(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(Scaffold).first),
).read(noteDraftProvider);

TextField _field(WidgetTester tester, Finder f) => tester.widget<TextField>(f);

bool _sendOn(WidgetTester tester) =>
    tester.widget<GestureDetector>(_key('writing-post')).onTap != null;

/// The checklist's text lines, the empty "Add a point" one last.
Finder _points() => find.descendant(
  of: _key('writing-points'),
  matching: find.byType(TextField),
);

/// A tool's icon colour: the action colour while it is in use.
Color? _toolColour(WidgetTester tester, String tool) => tester
    .widget<Icon>(find.descendant(of: _key(tool), matching: find.byType(Icon)))
    .color;

/// The phone's Back.
Future<void> _back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);
    final n = NotebookSamples(lang);

    testWidgets('Note opens a slip at the end of today with the keyboard up '
        '(NBW1) [$lang]', (tester) async {
      await _open(tester, lang, notes: [n.todo()]);
      await _note(tester);
      expect(_key('note-writing-card'), findsOneWidget);
      // No sheet, no tabs, no Save: the tools above the keyboard.
      expect(_key('note-tools'), findsOneWidget);
      expect(_key('post-bar-notepad'), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text(l10n.notebookNow), findsOneWidget);
      expect(
        find.descendant(
          of: _key('writing-kind-chip'),
          matching: find.text(l10n.notebookNote),
        ),
        findsOneWidget,
      );
      expect(_field(tester, _key('writing-title')).focusNode!.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      // At the end of today: under today's to-do.
      expect(
        tester.getTopLeft(_key('note-writing-card')).dy,
        greaterThan(tester.getTopLeft(_key('note-note-sleeves')).dy),
      );
      // Send is grey until there is something to keep.
      expect(_sendOn(tester), isFalse);
    });

    testWidgets('the kind chip changes the kind and keeps the words: a '
        'note\'s lines become points, points become lines, a to-do takes '
        'the first line (NBW2) [$lang]', (tester) async {
      await _open(tester, lang);
      await _note(tester);
      await tester.enterText(_key('writing-title'), n.walkTitle);
      await tester.enterText(
        _key('writing-body'),
        '${n.walkPoints[0]}\n${n.walkPoints[1]}',
      );
      await tester.pumpAndSettle();

      await _tap(tester, _key('writing-kind-chip'));
      expect(_key('note-kind-menu'), findsOneWidget);
      await _tap(tester, find.text(l10n.daybookKindChecklist).last);
      expect(_key('note-kind-menu'), findsNothing);
      expect(_draft(tester)!.kind, NoteKind.checklist);
      expect(
        [
          for (final f in tester.widgetList<TextField>(_points()))
            f.controller!.text,
        ],
        [...n.walkPoints.take(2), ''],
      );
      expect(
        _field(tester, _key('writing-title')).controller!.text,
        n.walkTitle,
      );
      // The Checklist tool is tinted while the kind is Checklist.
      expect(_toolColour(tester, 'note-tool-checklist'), BvColors.iconAction);

      await _tap(tester, _key('writing-kind-chip'));
      await _tap(tester, find.text(l10n.notebookNote).last);
      expect(_points(), findsNothing);
      expect(
        _field(tester, _key('writing-body')).controller!.text,
        '${n.walkPoints[0]}\n${n.walkPoints[1]}',
      );
      expect(_toolColour(tester, 'note-tool-checklist'), BvColors.iconPrimary);

      await _tap(tester, _key('writing-kind-chip'));
      await _tap(tester, find.text(l10n.notebookTodo).last);
      expect(
        _field(tester, _key('note-todo-line')).controller!.text,
        n.walkTitle,
      );
      expect(
        _field(tester, _key('note-todo-line')).focusNode!.hasFocus,
        isTrue,
      );
    });

    testWidgets('a checklist: Enter adds the next point, Backspace on an '
        'empty point takes it out (NBW4, F40) [$lang]', (tester) async {
      await _open(tester, lang);
      await _note(tester);
      await _tap(tester, _key('note-tool-checklist'));
      await tester.enterText(_key('writing-title'), n.walkTitle);
      await tester.tap(_points().last);
      await tester.pumpAndSettle();
      tester.testTextInput.enterText(n.walkPoints[0]);
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      TextField at(int i) => tester.widget<TextField>(_points().at(i));
      expect(at(1).focusNode!.hasFocus, isTrue);
      expect(find.text(l10n.daybookPointHint), findsWidgets);
      tester.testTextInput.enterText(n.walkPoints[1]);
      await tester.pump();
      tester.testTextInput.enterText('');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();
      expect(
        [for (final p in _draft(tester)!.points) p.text],
        [n.walkPoints[0]],
      );
      expect(at(0).focusNode!.hasFocus, isTrue);
    });

    testWidgets('a to-do: by when and Remind me show as chips in the slip, '
        'the tools tinted, and × takes each off (NBW3) [$lang]', (
      tester,
    ) async {
      await _open(tester, lang);
      await _note(tester);
      await _tap(tester, _key('writing-kind-chip'));
      await _tap(tester, find.text(l10n.notebookTodo).last);
      await tester.enterText(_key('note-todo-line'), n.sleevesTodo);
      await _tap(tester, _key('note-tool-due'));
      await _tap(tester, _key('note-tool-remind'));
      final words = DaybookWords(l10n, lang, use24: false);
      final four = DateTime(2026, 10, 15, 16);
      expect(
        find.descendant(
          of: _key('note-by-when'),
          matching: find.text(
            words.due(dayOf(four), four, now: NotebookSamples.now, late: false),
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _key('note-remind-chip'),
          matching: find.text(words.time.clock(four)),
        ),
        findsOneWidget,
      );
      expect(_toolColour(tester, 'note-tool-due'), BvColors.iconAction);
      expect(_toolColour(tester, 'note-tool-remind'), BvColors.iconAction);

      await _tap(
        tester,
        find.descendant(
          of: _key('note-by-when'),
          matching: _key('note-chip-remove'),
        ),
      );
      expect(_key('note-by-when'), findsNothing);
      expect(_draft(tester)!.dueAt, isNull);
      await _tap(
        tester,
        find.descendant(
          of: _key('note-remind-chip'),
          matching: _key('note-chip-remove'),
        ),
      );
      expect(_key('note-remind-chip'), findsNothing);
      expect(_draft(tester)!.remindAt, isNull);
      expect(_toolColour(tester, 'note-tool-remind'), BvColors.iconPrimary);
    });

    testWidgets('By when on a note makes it a to-do of its first line '
        '[$lang]', (tester) async {
      await _open(tester, lang);
      await _note(tester);
      await tester.enterText(_key('writing-title'), n.sleevesTodo);
      await _tap(tester, _key('note-tool-due'));
      expect(_draft(tester)!.kind, NoteKind.todo);
      expect(_key('note-by-when'), findsOneWidget);
    });

    testWidgets('Send is off while empty; on, it saves the note, kept with '
        'its reminder, and the slip is gone [$lang]', (tester) async {
      final app = await _open(tester, lang);
      await _note(tester);
      expect(_sendOn(tester), isFalse);
      await _tap(tester, _key('writing-post'));
      expect(app.notebook.calls, isEmpty);
      await tester.enterText(_key('writing-title'), n.walkTitle);
      await tester.enterText(_key('writing-body'), n.walkPoints[0]);
      await tester.pumpAndSettle();
      await _tap(tester, _key('note-tool-remind'));
      expect(_sendOn(tester), isTrue);
      await _tap(tester, _key('writing-post'));
      final note = app.notebook.kept.values.single;
      expect(note.kind, NoteKind.text);
      expect(note.body, '${n.walkTitle}\n${n.walkPoints[0]}');
      expect(note.remindAt, DateTime(2026, 10, 15, 16));
      expect(_key('note-writing-card'), findsNothing);
      expect(_key('post-bar-notepad'), findsOneWidget);
      expect(_key('note-${note.id}'), findsOneWidget);
      expect(app.prefs.getString('notebook_draft:user-1'), isNull);
    });

    testWidgets('Back keeps the slip as a Draft at the end of today; a tap '
        'goes on writing with the keyboard (NBW5) [$lang]', (tester) async {
      final app = await _open(tester, lang);
      await _note(tester);
      await tester.enterText(_key('writing-title'), n.sleevesTodo);
      await tester.pumpAndSettle();
      await _back(tester);
      // Still My notebook: the slip is put down, not the screen.
      expect(find.text(l10n.notebookTitle), findsOneWidget);
      expect(_key('note-draft'), findsOneWidget);
      expect(
        find.descendant(
          of: _key('note-draft-pill'),
          matching: find.text(l10n.daybookDraft),
        ),
        findsOneWidget,
      );
      expect(find.text(l10n.notebookDraftKept), findsOneWidget);
      expect(_key('post-bar-notepad'), findsOneWidget);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(app.prefs.getString('notebook_draft:user-1'), isNotNull);
      expect(app.notebook.calls, isEmpty);

      await _tap(tester, _key('note-draft'));
      expect(_key('note-draft'), findsNothing);
      expect(_field(tester, _key('writing-title')).focusNode!.hasFocus, isTrue);
      expect(
        _field(tester, _key('writing-title')).controller!.text,
        n.sleevesTodo,
      );
    });

    testWidgets('the app going behind keeps the slip as the Draft [$lang]', (
      tester,
    ) async {
      final app = await _open(tester, lang);
      await _note(tester);
      await tester.enterText(_key('writing-title'), n.sleevesTodo);
      await tester.pumpAndSettle();
      for (final state in const [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();
      expect(app.prefs.getString('notebook_draft:user-1'), contains('"title"'));
      // Back to the front: no frames are drawn while it is hidden.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(_key('note-draft'), findsOneWidget);
    });

    testWidgets('one draft at a time: Note goes on with it, and Edit on '
        'another note asks to finish it first [$lang]', (tester) async {
      await _open(tester, lang, notes: [n.yesterday()]);
      await _note(tester);
      await tester.enterText(_key('writing-title'), n.sleevesTodo);
      await tester.pumpAndSettle();
      await _back(tester);

      await _note(tester);
      expect(_key('note-writing-card'), findsOneWidget);
      expect(
        _field(tester, _key('writing-title')).controller!.text,
        n.sleevesTodo,
      );
      await _back(tester);

      await _tap(tester, _key('note-note-yesterday'));
      expect(find.text(l10n.notebookDraftFirst), findsOneWidget);
      expect(_key('note-writing-card'), findsOneWidget);
      expect(
        _field(tester, _key('writing-title')).controller!.text,
        n.sleevesTodo,
      );
      // The other note is still on its slip.
      expect(_key('note-note-yesterday'), findsOneWidget);
    });

    testWidgets('an empty slip leaves no draft [$lang]', (tester) async {
      final app = await _open(tester, lang);
      await _note(tester);
      await _back(tester);
      expect(_key('note-writing-card'), findsNothing);
      expect(_key('note-draft'), findsNothing);
      expect(_key('notebook-empty'), findsOneWidget);
      expect(app.prefs.getString('notebook_draft:user-1'), isNull);

      // Typed, then wiped: no draft either.
      await _note(tester);
      await tester.enterText(_key('writing-title'), 'x');
      await tester.enterText(_key('writing-title'), '');
      await tester.pumpAndSettle();
      await _back(tester);
      expect(_key('note-draft'), findsNothing);
      expect(app.prefs.getString('notebook_draft:user-1'), isNull);
    });

    testWidgets('Edit writes the note in its place, and Send saves the '
        'change [$lang]', (tester) async {
      final app = await _open(tester, lang, notes: [n.checklist()]);
      // On the slip's paper, above its points.
      await tester.tapAt(
        tester.getTopLeft(_key('note-note-walk')) +
            Offset(tester.getSize(_key('note-note-walk')).width / 2, 24),
      );
      await tester.pumpAndSettle();
      expect(_key('note-note-walk'), findsNothing);
      expect(_key('note-writing-card'), findsOneWidget);
      expect(
        _field(tester, _key('writing-title')).controller!.text,
        n.walkTitle,
      );
      expect(_points(), findsNWidgets(n.walkPoints.length + 1));
      await tester.enterText(_points().last, 'Torch');
      await tester.pumpAndSettle();
      await _tap(tester, _key('writing-post'));
      final note = app.notebook.kept['note-walk']!;
      expect([for (final p in note.points) p.text], [...n.walkPoints, 'Torch']);
      // The ticks stay on the points that were ticked.
      expect(
        [for (final p in note.points) p.done],
        [for (final p in n.checklist().points) p.done, false],
      );
      expect(_key('note-note-walk'), findsOneWidget);
    });

    testWidgets('Photo: the camera adds a photo to the slip, × takes one '
        'off, and Send uploads it and sends it in p_files [$lang]', (
      tester,
    ) async {
      final app = await _open(tester, lang);
      await _note(tester);
      await tester.enterText(_key('writing-title'), n.walkTitle);
      await _tap(tester, _key('note-tool-photo'));
      await _tap(tester, _key('note-tool-photo'));
      expect(app.cameraAsks, [true, true]);
      expect(_draft(tester)!.photos, hasLength(2));
      expect(_key('writing-photo-remove-1'), findsOneWidget);
      await _tap(tester, _key('writing-photo-remove-target-0'));
      expect(_draft(tester)!.photos, hasLength(1));
      expect(_key('writing-photo-remove-1'), findsNothing);

      await _tap(tester, _key('writing-post'));
      final id = app.notebook.kept.keys.single;
      expect(app.notebook.calls, ['photo:$id', 'save:$id']);
      expect(app.notebook.files[id], ['user-1/$id/photo-0.jpg']);
      expect(_key('note-photos-$id'), findsOneWidget);
    });

    testWidgets('a photo alone is enough to keep a note [$lang]', (
      tester,
    ) async {
      final app = await _open(tester, lang);
      await _note(tester);
      await _tap(tester, _key('note-tool-photo'));
      expect(_sendOn(tester), isTrue);
      await _tap(tester, _key('writing-post'));
      expect(app.notebook.kept.values.single.photos, hasLength(1));
    });

    testWidgets('Voice note: hold the tool for a voice note of its own, '
        'after the slip; the words stay on the slip [$lang]', (tester) async {
      final app = await _open(tester, lang);
      await _note(tester);
      await tester.enterText(_key('writing-title'), n.walkTitle);
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(
        tester.getCenter(_key('note-tool-voice')),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await tester.pump(const Duration(seconds: 3));
      expect(_key('chat-recording'), findsOneWidget);
      await gesture.up();
      await tester.pumpAndSettle();
      final voice = app.notebook.kept.values.single;
      expect(voice.kind, NoteKind.voice);
      expect(_key('note-writing-card'), findsOneWidget);
      expect(
        _field(tester, _key('writing-title')).controller!.text,
        n.walkTitle,
      );
      expect(
        tester.getTopLeft(_key('note-${voice.id}')).dy,
        greaterThan(tester.getTopLeft(_key('note-writing-card')).dy),
      );
    });

    testWidgets('in Arabic the Send arrow mirrors, and in English it does '
        'not [$lang]', (tester) async {
      await _open(tester, lang);
      await _note(tester);
      final icon = tester.widget<Icon>(
        find.descendant(of: _key('writing-post'), matching: find.byType(Icon)),
      );
      expect(icon.icon!.matchTextDirection, isTrue);
      expect(
        Directionality.of(tester.element(_key('writing-post'))),
        lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      );
    });
  }
}
