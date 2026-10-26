// Review 99A: the notebook's pages, against PG1–PG5b (EN 2635:37785,
// 2635:37894, 2635:37987, 2635:38121, 2635:38216, 2635:38336; AR
// 2635:38736, 2635:38845, 2635:38938, 2635:39072, 2635:39167, 2635:39287).
// English and Arabic, at 390 × 844 on a 12-hour phone, in the app's fonts;
// PG2 and PG3 draw a keyboard under the bar: the test keeps its room,
// blank. Run:
//   flutter test test_screens/pg_test.dart --update-goldens
import 'dart:convert';

import 'package:buildvibes/data/models/post_page.dart';
import 'package:buildvibes/features/notebook/note_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../test/helpers/notebook_page_samples.dart';
import '../test/helpers/pump_app.dart';
import 'shot.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

/// Saves the app as it is now to `docs/screens/r99/<name>_<lang>.png`.
Future<void> _snap(WidgetTester tester, String name, String lang) async {
  debugDisableShadows = false;
  try {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byType(MaterialApp).first,
      matchesGoldenFile('../docs/screens/r99/${name}_$lang.png'),
    );
  } finally {
    debugDisableShadows = true;
  }
}

/// The app on [path], with PG1's pages; [draft] is the Draft being
/// written; [keyboard] keeps the keyboard's room.
Future<void> _open(
  WidgetTester tester,
  String lang,
  String path, {
  NoteDraft? draft,
  bool keyboard = false,
}) async {
  await pumpApp(
    tester,
    language: lang,
    now: NotebookPageSamples.now,
    notebook: NotebookPageSamples(lang).repository(),
    stored: {
      if (draft != null) 'notebook_draft:user-1': jsonEncode(draft.toJson()),
    },
  );
  tester.view.physicalSize = shotSize * shotPixelRatio;
  tester.view.devicePixelRatio = shotPixelRatio;
  if (keyboard) {
    tester.view.viewInsets = const FakeViewPadding(
      bottom: shotKeyboard * shotPixelRatio,
    );
  }
  addTearDown(tester.view.reset);
  GoRouter.of(tester.element(find.byType(Navigator).first)).push(path);
  await tester.pumpAndSettle();
}

/// PG2's entry: its title and two numbered lines, going into Site A.
NoteDraft _pour(String lang) {
  final s = NotebookPageSamples(lang);
  return NoteDraft(
    id: 'd0000000-0000-4000-8000-000000000099',
    startedAt: NotebookPageSamples.now,
    title: s.beforePour,
    blocks: [
      PageNumbered('pg-1', s.t('Clean the formwork', 'تنظيف القوالب')),
      PageNumbered('pg-2', s.t('Check the rebar cover', 'فحص غطاء الحديد')),
    ],
    pageId: NotebookPageSamples.siteA,
  );
}

/// [chars] typed one by one in the field with the cursor.
Future<void> _type(WidgetTester tester, String chars) async {
  for (final ch in chars.characters) {
    final field = tester
        .widgetList<TextField>(find.byType(TextField))
        .firstWhere((t) => t.focusNode?.hasFocus ?? false);
    tester.testTextInput.enterText(field.controller!.text + ch);
    await tester.pumpAndSettle();
  }
}

/// PG2's entry typed on New entry (review 100 B3: it always starts a new
/// entry): its title, then "1. " and two numbered lines, into Site A (the
/// page the chip starts on).
Future<void> _typePour(WidgetTester tester, String lang) async {
  final pour = _pour(lang);
  await tester.enterText(_key('note-title'), pour.title);
  await tester.testTextInput.receiveAction(TextInputAction.next);
  await tester.pumpAndSettle();
  await _type(tester, '1. ');
  // The shortcut's Undo bar goes before the shot.
  ScaffoldMessenger.of(
    tester.element(find.byType(Scaffold).first),
  ).removeCurrentSnackBar();
  for (final (i, b) in pour.blocks.indexed) {
    final field = tester
        .widgetList<TextField>(find.byType(TextField))
        .firstWhere((t) => t.focusNode?.hasFocus ?? false);
    tester.testTextInput.enterText(
      field.controller!.text + (b as PageNumbered).text,
    );
    await tester.pumpAndSettle();
    if (i < pour.blocks.length - 1) {
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
    }
  }
}

void main() {
  setUpAll(loadAppFonts);

  for (final lang in ['en', 'ar']) {
    testWidgets('PG1 the pages list [$lang]', (tester) async {
      await _open(tester, lang, '/notebook');
      await _snap(tester, 'PG1-pages', lang);
    });

    testWidgets('PG2 writing an entry, the page chip under it [$lang]', (
      tester,
    ) async {
      await _open(tester, lang, '/notebook/write', keyboard: true);
      await _typePour(tester, lang);
      await _snap(tester, 'PG2-writing-chip', lang);
    });

    testWidgets('PG3 the page picker from the chip [$lang]', (tester) async {
      await _open(tester, lang, '/notebook/write', keyboard: true);
      await _typePour(tester, lang);
      await _tap(tester, _key('note-page-chip'));
      await _snap(tester, 'PG3-page-picker', lang);
    });

    testWidgets('PG4 a page: path, sub-pages, entries by day [$lang]', (
      tester,
    ) async {
      await _open(tester, lang, '/notebook/pages/${NotebookPageSamples.siteA}');
      await _snap(tester, 'PG4-page', lang);
    });

    testWidgets('PG5 pages selected [$lang]', (tester) async {
      await _open(tester, lang, '/notebook');
      await tester.longPress(_key('page-${NotebookPageSamples.siteA}'));
      await tester.pumpAndSettle();
      await _tap(tester, _key('page-${NotebookPageSamples.pump}'));
      await _snap(tester, 'PG5-selected', lang);
    });

    testWidgets('PG5b the merge sheet [$lang]', (tester) async {
      await _open(tester, lang, '/notebook');
      await tester.longPress(_key('page-${NotebookPageSamples.siteA}'));
      await tester.pumpAndSettle();
      await _tap(tester, _key('page-${NotebookPageSamples.pump}'));
      await _tap(tester, _key('select-merge'));
      await _snap(tester, 'PG5b-merge', lang);
    });
  }
}
