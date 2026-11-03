// Review 115 (1, 2), in English and Arabic at 390 × 844 in the app's fonts:
// a Library file on its way ("Uploading 33%"), waiting for signal, and
// refused (Tap to fix); "Who sees it: Whole Space · Change" before a file
// goes to the top level, and the choice it opens. Run:
//   flutter test test_screens/r115_library_test.dart --update-goldens
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show StorageException;

import '../test/helpers/daybook_fakes.dart';
import '../test/helpers/daybook_samples.dart';
import '../test/helpers/library_fakes.dart';
import '../test/helpers/pump_app.dart';
import '../test/helpers/space_fakes.dart';
import 'shot.dart';

const _space = DaybookSamples.space;

/// Saves the app as it is now to `docs/reviews/shots-115/<name>_<lang>.png`.
Future<void> _snap(WidgetTester tester, String name, String lang) async {
  debugDisableShadows = false;
  try {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byType(MaterialApp).first,
      matchesGoldenFile('../docs/reviews/shots-115/${name}_$lang.png'),
    );
  } finally {
    debugDisableShadows = true;
  }
}

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(_key(key).first);
  await tester.pumpAndSettle();
  await tester.tap(_key(key).first);
  await tester.pumpAndSettle();
}

Future<TestApp> _library(WidgetTester tester, String lang) async {
  final s = DaybookSamples(lang);
  final app = await pumpApp(
    tester,
    language: lang,
    spaces: FakeSpaceRepository()
      ..details[_space] = s.detail(addFiles: true)
      ..spacePeople[_space] = s.people(),
    daybook: FakeDaybookRepository()..posts[_space] = const [],
    library: FakeLibraryRepository(now: DaybookSamples.thursday)
      ..filesBySpace[_space] = [],
    now: DaybookSamples.thursday,
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/$_space');
  await tester.pumpAndSettle();
  await _tap(tester, 'space-library');
  return app;
}

void main() {
  setUpAll(loadAppFonts);

  for (final lang in ['en', 'ar']) {
    testWidgets('L1 uploading [$lang]', (tester) async {
      final app = await _library(tester, lang);
      app.library.holdUpload = Completer<void>();
      await _tap(tester, 'library-add-file');
      await _tap(tester, 'library-who-add');
      await _snap(tester, 'L1-uploading', lang);
      app.library.holdUpload!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('L1 waiting for signal [$lang]', (tester) async {
      final app = await _library(tester, lang);
      app.library.uploadsOffline = true;
      await _tap(tester, 'library-add-file');
      await _tap(tester, 'library-who-add');
      await _snap(tester, 'L1-waiting', lang);
    });

    testWidgets('L1 could not upload, Tap to fix [$lang]', (tester) async {
      final app = await _library(tester, lang);
      app.library.storageRefuses = const StorageException(
        'The object exceeded the maximum allowed size',
        error: 'Payload too large',
        statusCode: '413',
      );
      await _tap(tester, 'library-add-file');
      await _tap(tester, 'library-who-add');
      await _snap(tester, 'L1-could-not-upload', lang);
      await tester.tap(find.textContaining('Level 3 plan.pdf').first);
      await tester.pumpAndSettle();
      await _snap(tester, 'L1-tap-to-fix', lang);
    });

    testWidgets('L2 who sees it [$lang]', (tester) async {
      await _library(tester, lang);
      await _tap(tester, 'library-add-file');
      await _snap(tester, 'L2-who-sees', lang);
      await _tap(tester, 'library-who-change');
      await _snap(tester, 'L2-who-change', lang);
    });
  }
}
