// Screenshots for review at 390 × 844, English and Arabic, rendered with
// the app's real fonts. Not part of `flutter test`; run:
//   flutter test test_screens --update-goldens
// The PNGs land in docs/screens/slice1/ (committed for the lead, review 43),
// or a later slice's folder ([shoot]'s folder).
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
  await family('Almarai', ['Almarai-Regular.ttf', 'Almarai-Bold.ttf']);
  await family('PhosphorRegular', ['Phosphor-Regular.ttf']);
}

/// Renders [child] in a 390 × 844 app frame in [lang] and saves
/// `docs/screens/<folder>/<name>_<lang>.png` (slice1 by default).
///
/// A whole screen gets its providers from [overrides], and [before] puts it
/// in the state to shoot (a scroll, a tap) once it has settled. With
/// [keyboard], the phone's keyboard then comes up: a 300-point inset,
/// drawn as Figma draws it (F24, 2582:77206).
Future<void> shoot(
  WidgetTester tester,
  String name,
  String lang,
  Widget Function(BuildContext context) child, {
  List<Override>? overrides,
  Future<void> Function(WidgetTester tester)? before,
  bool keyboard = false,
  String folder = 'slice1',
}) async {
  tester.view.physicalSize = shotSize * shotPixelRatio;
  tester.view.devicePixelRatio = shotPixelRatio;
  addTearDown(tester.view.reset);
  final keyboardUp = ValueNotifier(false);
  addTearDown(keyboardUp.dispose);
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
      builder: keyboard
          ? (context, app) => Stack(
              children: [
                app!,
                ValueListenableBuilder(
                  valueListenable: keyboardUp,
                  builder: (_, up, _) => up
                      ? const Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: _Keyboard(),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            )
          : null,
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
    if (keyboard) {
      tester.view.viewInsets = const FakeViewPadding(
        bottom: shotKeyboard * shotPixelRatio,
      );
      keyboardUp.value = true;
      await tester.pumpAndSettle();
    }
    await expectLater(
      find.byKey(key),
      matchesGoldenFile('../docs/screens/$folder/${name}_$lang.png'),
    );
  } finally {
    debugDisableShadows = true;
  }
}

/// [child] pushed over an empty page, so its app bar has Back as in the
/// app.
class Pushed extends StatefulWidget {
  const Pushed(this.child, {super.key});

  final Widget child;

  @override
  State<Pushed> createState() => _PushedState();
}

class _PushedState extends State<Pushed> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => Navigator.of(context).push(
        PageRouteBuilder<void>(
          transitionDuration: Duration.zero,
          pageBuilder: (_, _, _) => widget.child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const ColoredBox(color: Colors.white);
}

/// The keyboard's height in the shots (F24's tests use the same).
const shotKeyboard = 300.0;

/// A stand-in for the phone's keyboard, as the Figma frame draws it.
class _Keyboard extends StatelessWidget {
  const _Keyboard();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: shotKeyboard,
    child: ColoredBox(
      color: Color(0xFFD1D4DB),
      child: Center(
        child: Text(
          'Phone keyboard',
          textDirection: TextDirection.ltr,
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 12,
            color: Color(0xFF6B6578),
          ),
        ),
      ),
    ),
  );
}

/// The text cursor drawn the same way on every run, never caught mid-blink
/// (review 100, the lead's third check), for this test only.
void steadyCursor() {
  EditableText.debugDeterministicCursor = true;
  addTearDown(() => EditableText.debugDeterministicCursor = false);
}
