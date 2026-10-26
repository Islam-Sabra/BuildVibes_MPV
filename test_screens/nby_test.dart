// Review 98: the notebook writes like Notion, against NBY1–NBY5 (EN
// 2629:37317, 2629:37448, 2629:37610, 2629:37729, 2629:37841; AR
// 2629:37961, 2629:38092, 2629:38254, 2629:38373, 2629:38485). English
// and Arabic, at 390 × 844 on a 12-hour phone, in the app's fonts; the
// frames draw a keyboard under the bar, a test has none.
// Run:
//   flutter test test_screens/nby_test.dart --update-goldens
import 'dart:convert';

import 'package:buildvibes/data/models/post_page.dart';
import 'package:buildvibes/features/notebook/note_draft.dart';
import 'package:buildvibes/features/notebook/note_page_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../test/helpers/notebook_fakes.dart';
import '../test/helpers/notebook_samples.dart';
import '../test/helpers/pump_app.dart';
import 'shot.dart';

Finder _key(String k) => find.byKey(Key(k));

String _id(int n) => 'b0000000-0000-4000-8000-${'$n'.padLeft(12, '0')}';

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

/// Saves the app as it is now to `docs/screens/r98/<name>_<lang>.png`.
Future<void> _snap(WidgetTester tester, String name, String lang) async {
  debugDisableShadows = false;
  try {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byType(MaterialApp).first,
      matchesGoldenFile('../docs/screens/r98/${name}_$lang.png'),
    );
  } finally {
    debugDisableShadows = true;
  }
}

String Function(String en, String ar) _t(String lang) =>
    (en, ar) => lang == 'ar' ? ar : en;

/// The frames' list: 1. Clean; 2. Check, with two to-dos under it; 3.
/// Confirm. [typing]: an empty line after it, for "/".
List<PageBlock> _pour(String lang, {bool typing = false}) {
  final t = _t(lang);
  return [
    PageNumbered(_id(1), t('Clean the formwork', 'نظّف القوالب')),
    PageNumbered(_id(2), t('Check the rebar', 'افحص حديد التسليح')),
    PageTodo(_id(3), t('Cover at the edges', 'الغطاء عند الأطراف'), indent: 1),
    PageTodo(_id(4), t('Spacers every 1 m', 'فواصل كل 1 م'), indent: 1),
    PageNumbered(_id(5), t('Confirm the pump slot', 'أكّد موعد المضخة')),
    if (typing) PageText(_id(6), ''),
  ];
}

Future<void> _open(
  WidgetTester tester,
  String lang,
  List<PageBlock> blocks,
) async {
  final draft = NoteDraft(
    id: 'd0000000-0000-4000-8000-000000000098',
    startedAt: NotebookSamples.now,
    title: _t(lang)('Before the pour, level 3', 'قبل الصب، الدور 3'),
    blocks: blocks,
  );
  await pumpApp(
    tester,
    language: lang,
    now: NotebookSamples.now,
    notebook: FakeNotebookRepository(),
    stored: {'notebook_draft:user-1': jsonEncode(draft.toJson())},
  );
  tester.view.physicalSize = shotSize * shotPixelRatio;
  tester.view.devicePixelRatio = shotPixelRatio;
  addTearDown(tester.view.reset);
  GoRouter.of(tester.element(find.byType(Navigator).first)).push('/notebook');
  await tester.pumpAndSettle();
  await _tap(tester, _key('post-bar-notepad'));
}

NotePageEditorState _editor(WidgetTester tester) =>
    tester.state<NotePageEditorState>(find.byType(NotePageEditor));

/// The cursor at the end of line [n], as the keyboard puts it there (a tap
/// would show the selection handle).
Future<void> _cursor(WidgetTester tester, int n) async {
  _editor(tester).focusBlock('t:${_id(n)}');
  await tester.pumpAndSettle();
}

/// [chars] typed one by one on the line being written.
Future<void> _type(WidgetTester tester, String chars) async {
  for (final ch in chars.characters) {
    final field = tester
        .widgetList<TextField>(find.byType(TextField))
        .firstWhere((t) => t.focusNode?.hasFocus ?? false);
    tester.testTextInput.enterText(field.controller!.text + ch);
    await tester.pumpAndSettle();
  }
}

void main() {
  setUpAll(loadAppFonts);

  for (final lang in ['en', 'ar']) {
    testWidgets('NBY1 "/" next to the line, filtered to "num" [$lang]', (
      tester,
    ) async {
      await _open(tester, lang, _pour(lang, typing: true));
      await _cursor(tester, 6);
      await _type(tester, '/num');
      await _snap(tester, 'NBY1-slash-num', lang);
    });

    testWidgets('NBY2 the line menu on a numbered line with children '
        '[$lang]', (tester) async {
      await _open(tester, lang, _pour(lang));
      await _cursor(tester, 2);
      await _tap(tester, _key('page-handle-${_id(2)}'));
      await _snap(tester, 'NBY2-line-menu', lang);
    });

    testWidgets('NBY3 the bar on the 2nd to-do: ⇥ ⇤ [$lang]', (tester) async {
      await _open(tester, lang, _pour(lang));
      await _cursor(tester, 4);
      await _snap(tester, 'NBY3-bar-todo', lang);
    });

    testWidgets('NBY4 the bar on the title: no ⇥ ⇤ [$lang]', (tester) async {
      await _open(tester, lang, _pour(lang));
      final title = tester.widget<TextField>(_key('note-title'));
      title.controller!.selection = TextSelection.collapsed(
        offset: title.controller!.text.length,
      );
      title.focusNode!.requestFocus();
      await tester.pumpAndSettle();
      await _snap(tester, 'NBY4-bar-title', lang);
    });

    testWidgets('NBY5 Move down, then Moved · Undo [$lang]', (tester) async {
      await _open(tester, lang, _pour(lang));
      await _cursor(tester, 2);
      await _tap(tester, _key('page-handle-${_id(2)}'));
      await _tap(tester, _key('page-move-down'));
      await _snap(tester, 'NBY5-moved-undo', lang);
      // The undo bar's 5 seconds.
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    });
  }
}
