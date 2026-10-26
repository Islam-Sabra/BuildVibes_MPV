// F107 (review 92): the notebook writes like Notion, against NBX1–NBX4
// (EN 2619:36719, 2619:36808, 2619:36951, 2619:37076; AR 2619:37201,
// 2619:37290, 2619:37433, 2619:37558). English and Arabic, at 390 × 844 on
// a 12-hour phone, in the app's fonts. The frames draw a keyboard under
// the bar; a test has none.
// Run:
//   flutter test test_screens/f107_test.dart --update-goldens
import 'dart:convert';

import 'package:buildvibes/data/models/note.dart';
import 'package:buildvibes/data/models/post_page.dart';
import 'package:buildvibes/features/notebook/note_draft.dart';
import 'package:buildvibes/features/notebook/note_location.dart';
import 'package:buildvibes/features/work/daybook_photos.dart'
    show localPhotoProvider;
import 'package:buildvibes/features/work/daybook_writing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../test/helpers/notebook_fakes.dart';
import '../test/helpers/notebook_samples.dart';
import '../test/helpers/pump_app.dart';
import 'shot.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

/// Saves the app as it is now to `docs/screens/f107/<name>_<lang>.png`.
Future<void> _snap(WidgetTester tester, String name, String lang) async {
  debugDisableShadows = false;
  try {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byType(MaterialApp).first,
      matchesGoldenFile('../docs/screens/f107/${name}_$lang.png'),
    );
  } finally {
    debugDisableShadows = true;
  }
}

String Function(String en, String ar) _t(String lang) =>
    (en, ar) => lang == 'ar' ? ar : en;

/// NBX1–NBX2: "Pump booking" and its line, being written.
NoteDraft _pump(String lang) {
  final t = _t(lang);
  return NoteDraft(
    id: 'd0000000-0000-4000-8000-000000000001',
    startedAt: NotebookSamples.now,
    title: t('Pump booking', 'حجز المضخة'),
    blocks: [
      PageText(
        'b0000000-0000-4000-8000-000000000001',
        t(
          'Al Bahar Ready Mix, 2 pm slot.',
          'البحر للخرسانة الجاهزة، موعد 2 ظهرًا.',
        ),
      ),
    ],
  );
}

/// NBX3–NBX4: the to-do list before the pour, with its location, two
/// photos, a PDF and the date (NBX4: the location typed only).
NoteDraft _pour(String lang, {bool all = true}) {
  final t = _t(lang);
  return NoteDraft(
    id: 'd0000000-0000-4000-8000-000000000002',
    startedAt: NotebookSamples.now,
    title: t('Before the pour, level 3', 'قبل الصب، الدور 3'),
    blocks: [
      PageTodo(
        'b0000000-0000-4000-8000-000000000011',
        t('Check the sleeves', 'تحقق من الجلب'),
        done: true,
      ),
      PageTodo(
        'b0000000-0000-4000-8000-000000000012',
        t('Clean the formwork', 'نظّف القوالب'),
      ),
      PageTodo(
        'b0000000-0000-4000-8000-000000000013',
        t('Confirm the pump slot', 'أكّد موعد المضخة'),
      ),
    ],
    location: NoteLocation(
      text: t('Level 3, grid C7', 'الدور 3، المحور C7'),
      lat: all ? 29.37594 : null,
      lng: all ? 47.9774 : null,
      accuracyM: all ? 8 : null,
    ),
    photos: all
        ? [NotePhoto(local: testPhotoPath), NotePhoto(local: testPhotoPath)]
        : const [],
    files: all
        ? [
            NoteFile(
              local: testPdfPath,
              name: 'A-501 Rev D.pdf',
              bytes: (2.3 * 1024 * 1024).round(),
            ),
          ]
        : const [],
    dueAt: all ? DateTime(2026, 10, 15, 14) : null,
  );
}

Future<void> _open(WidgetTester tester, String lang, NoteDraft draft) async {
  await pumpApp(
    tester,
    language: lang,
    now: NotebookSamples.now,
    notebook: FakeNotebookRepository(),
    stored: {'notebook_draft:user-1': jsonEncode(draft.toJson())},
    overrides: [
      localPhotoProvider.overrideWith((ref, path) => samplePhoto),
      // The phone's GPS, as NBX4 draws it.
      findPositionProvider.overrideWithValue(
        () async =>
            (lat: 29.37594, lng: 47.9774, accuracyM: 8.0, failure: null),
      ),
      pickDueProvider.overrideWithValue(
        (context, {required now, day, at}) async =>
            (day: DateTime(2026, 10, 15), at: DateTime(2026, 10, 15, 14)),
      ),
    ],
  );
  tester.view.physicalSize = shotSize * shotPixelRatio;
  tester.view.devicePixelRatio = shotPixelRatio;
  addTearDown(tester.view.reset);
  await warmSamplePhoto(tester);
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/notebook/pages/page-my-notes');
  await tester.pumpAndSettle();
  // The Draft, opened again from the bar's Note (a tap on the slip's
  // text would show the selection handle): being written, the keyboard on
  // its last line.
  await _tap(tester, _key('page-write'));
}

void main() {
  setUpAll(loadAppFonts);

  for (final lang in ['en', 'ar']) {
    testWidgets('NBX1 the + and the additions above the keyboard [$lang]', (
      tester,
    ) async {
      await _open(tester, lang, _pump(lang));
      await _snap(tester, 'NBX1-additions', lang);
    });

    testWidgets('NBX2 categories: a grid, like Notion [$lang]', (tester) async {
      await _open(tester, lang, _pump(lang));
      await _tap(tester, _key('note-tool-categories'));
      await _snap(tester, 'NBX2-categories', lang);
    });

    testWidgets('NBX3 a to-do list with a location, photos and a file '
        '[$lang]', (tester) async {
      await _open(tester, lang, _pour(lang));
      await _snap(tester, 'NBX3-additions', lang);
    });

    testWidgets('NBX4 location: type it, add the GPS, or both [$lang]', (
      tester,
    ) async {
      await _open(tester, lang, _pour(lang, all: false));
      await _tap(tester, _key('note-tool-location'));
      await _tap(tester, _key('note-gps-add'));
      await _snap(tester, 'NBX4-location', lang);
    });
  }
}
