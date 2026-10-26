// F108 (review 93): a note's lines under each other. English and Arabic,
// at 390 × 844 on a 12-hour phone, in the app's fonts; a test has no
// keyboard under the bar.
// Run:
//   flutter test test_screens/f108_test.dart --update-goldens
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

/// Saves the app as it is now to `docs/screens/f108/<name>_<lang>.png`.
Future<void> _snap(WidgetTester tester, String name, String lang) async {
  debugDisableShadows = false;
  try {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byType(MaterialApp).first,
      matchesGoldenFile('../docs/screens/f108/${name}_$lang.png'),
    );
  } finally {
    debugDisableShadows = true;
  }
}

String Function(String en, String ar) _t(String lang) =>
    (en, ar) => lang == 'ar' ? ar : en;

/// The pour sequence: 1–3 at the first level, Rebar's checks under 2 as
/// a. b. with a roman sub-point, and a note under 3.
List<PageBlock> _pour(String lang) {
  final t = _t(lang);
  return [
    PageNumbered(_id(1), t('Clean the formwork', 'نظّف القوالب')),
    PageNumbered(_id(2), t('Check the rebar', 'افحص حديد التسليح')),
    PageNumbered(
      _id(3),
      t('Cover at the edges', 'الغطاء عند الأطراف'),
      indent: 1,
    ),
    PageNumbered(_id(4), t('Spacers every 1 m', 'فواصل كل 1 م'), indent: 2),
    PageNumbered(
      _id(5),
      t('Spacers at the beams', 'فواصل عند الجسور'),
      indent: 2,
    ),
    PageNumbered(_id(6), t('Laps and ties', 'الوصلات والربط'), indent: 1),
    PageNumbered(_id(7), t('Confirm the pump slot', 'أكّد موعد المضخة')),
    PageCallout(
      _id(8),
      t('Al Bahar Ready Mix, 2 pm', 'البحر للخرسانة الجاهزة، 2 ظهرًا'),
      indent: 1,
    ),
  ];
}

/// The founder's case: 1, 2, a heading between two parts, then a list
/// that starts at 1.
List<PageBlock> _parts(String lang) {
  final t = _t(lang);
  return [
    PageNumbered(_id(11), t('Clean the formwork', 'نظّف القوالب')),
    PageNumbered(_id(12), t('Check the rebar', 'افحص حديد التسليح')),
    PageCallout(_id(13), t('Rain after 4 pm', 'مطر بعد 4 عصرًا')),
    PageNumbered(_id(14), t('Confirm the pump slot', 'أكّد موعد المضخة')),
  ];
}

Future<void> _open(
  WidgetTester tester,
  String lang,
  List<PageBlock> blocks,
) async {
  final draft = NoteDraft(
    id: 'd0000000-0000-4000-8000-000000000108',
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
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/notebook/pages/page-my-notes');
  await tester.pumpAndSettle();
  await _tap(tester, _key('note-draft'));
}

/// The cursor at the end of line [n] (as the keyboard puts it there; a
/// tap would show the selection handle).
Future<void> _cursor(WidgetTester tester, int n) async {
  tester
      .state<NotePageEditorState>(find.byType(NotePageEditor))
      .focusBlock('t:${_id(n)}');
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  for (final lang in ['en', 'ar']) {
    testWidgets('L1 a nested list: 1. → a. → i., and ⇥ ⇤ on the bar '
        '[$lang]', (tester) async {
      await _open(tester, lang, _pour(lang));
      await _cursor(tester, 6);
      await _snap(tester, 'L1-nested-bar', lang);
    });

    testWidgets('L2 a numbered list with a folded item [$lang]', (
      tester,
    ) async {
      await _open(tester, lang, _pour(lang));
      await _tap(tester, _key('note-fold-${_id(2)}'));
      await _cursor(tester, 7);
      await _snap(tester, 'L2-folded', lang);
    });

    testWidgets('L3 the ⋮⋮ menu: Continue numbering (3) [$lang]', (
      tester,
    ) async {
      await _open(tester, lang, _parts(lang));
      await _cursor(tester, 14);
      await _tap(tester, _key('page-handle-${_id(14)}'));
      await _snap(tester, 'L3-continue', lang);
    });
  }
}
