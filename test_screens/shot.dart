// Screenshots for review at 390 × 844, English and Arabic, rendered with
// the app's real fonts. Not part of `flutter test`; run:
//   flutter test test_screens --update-goldens
// The PNGs land in docs/screens/slice1/ (committed for the lead, review 43).
import 'dart:async';

import 'package:buildvibes/core/theme/bv_theme.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const shotSize = Size(390, 844);

/// The one site photo the shots use (the Components gallery's).
const samplePhoto = AssetImage('assets/dev/site_sample.jpg');

/// Decodes [samplePhoto] for real, so the shots draw it.
Future<void> warmSamplePhoto(WidgetTester tester) => tester.runAsync(() {
  final done = Completer<void>();
  final stream = samplePhoto.resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  listener = ImageStreamListener((_, _) {
    stream.removeListener(listener);
    done.complete();
  }, onError: (e, _) => done.completeError(e));
  stream.addListener(listener);
  return done.future;
});
const shotPixelRatio = 2.0;

Future<void> loadAppFonts() async {
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final f in files) {
      loader.addFont(rootBundle.load('assets/fonts/$f'));
    }
    await loader.load();
  }

  await family('PlusJakartaSans', [
    'PlusJakartaSans-Regular.ttf',
    'PlusJakartaSans-Medium.ttf',
    'PlusJakartaSans-SemiBold.ttf',
    'PlusJakartaSans-Bold.ttf',
    'PlusJakartaSans-ExtraBold.ttf',
  ]);
  await family('NotoSansArabic', [
    'NotoSansArabic-Regular.ttf',
    'NotoSansArabic-Medium.ttf',
    'NotoSansArabic-SemiBold.ttf',
    'NotoSansArabic-Bold.ttf',
  ]);
  await family('PhosphorRegular', ['Phosphor-Regular.ttf']);
}

/// Renders [child] in a 390 × 844 app frame in [lang] and saves
/// `docs/screens/slice1/<name>_<lang>.png`.
///
/// A whole screen gets its providers from [overrides], and [before] puts it
/// in the state to shoot (a scroll, a tap) once it has settled.
Future<void> shoot(
  WidgetTester tester,
  String name,
  String lang,
  Widget Function(BuildContext context) child, {
  List<Override>? overrides,
  Future<void> Function(WidgetTester tester)? before,
}) async {
  tester.view.physicalSize = shotSize * shotPixelRatio;
  tester.view.devicePixelRatio = shotPixelRatio;
  addTearDown(tester.view.reset);
  final locale = Locale(lang);
  final key = GlobalKey();
  // flutter_test draws shadows solid by default; the paper's soft shadows
  // are part of the look. Restored before the test ends, as it requires.
  debugDisableShadows = false;
  try {
    final app = MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: BvTheme.forLocale(locale),
      home: Builder(builder: child),
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: overrides == null
            ? app
            : ProviderScope(overrides: overrides, child: app),
      ),
    );
    await tester.pumpAndSettle();
    await before?.call(tester);
    await expectLater(
      find.byKey(key),
      matchesGoldenFile('../docs/screens/slice1/${name}_$lang.png'),
    );
  } finally {
    debugDisableShadows = true;
  }
}
