import 'package:buildvibes/core/design/bv_specs.dart';
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/core/splash/splash_cube.dart';
import 'package:buildvibes/core/splash/splash_handover.dart';
import 'package:buildvibes/features/entry/entry_state.dart';
import 'package:buildvibes/features/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

class _FakeSplash implements NativeSplash {
  int removed = 0;

  @override
  void remove() => removed++;
}

class _Gate extends Notifier<AppGate> {
  _Gate(this.initial);

  final AppGate initial;

  @override
  AppGate build() => initial;

  void set(AppGate gate) => state = gate;
}

late NotifierProvider<_Gate, AppGate> _gate;

/// The handover alone, over a first screen, with a gate the test moves.
Future<_FakeSplash> _pump(WidgetTester tester, AppGate start) async {
  final splash = _FakeSplash();
  _gate = NotifierProvider<_Gate, AppGate>(() => _Gate(start));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appGateProvider.overrideWith((ref) => ref.watch(_gate)),
        nativeSplashProvider.overrideWithValue(splash),
      ],
      child: MaterialApp(
        builder: (context, child) => SplashHandover(child: child!),
        home: const Text('first screen'),
      ),
    ),
  );
  return splash;
}

/// One frame at 60 Hz.
const _frame = Duration(microseconds: 16667);

final _cover = find.byKey(const Key('splash-cover'));

double _coverOpacity(WidgetTester tester) =>
    tester.widget<FadeTransition>(_cover).opacity.value;

/// The cube's progress, 0 to 1 (1: the native splash's cube).
double _cube(WidgetTester tester) =>
    (tester.widget<CustomPaint>(find.byKey(const Key('splash-cube'))).painter!
            as SplashCubePainter)
        .progress
        .value;

/// The phone's Reduce motion (Remove animations) on.
void _reduceMotion(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

void _set(WidgetTester tester, AppGate gate) => ProviderScope.containerOf(
  tester.element(find.text('first screen')),
).read(_gate.notifier).set(gate);

/// Pumps the fade and one more frame: the cover is gone.
Future<void> _fadeOut(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(BvSplashSpec.fade);
  await tester.pump(_frame);
  expect(_cover, findsNothing);
}

void main() {
  test('the fade is the splash terracotta over 350 ms', () {
    expect(BvSplashSpec.colour, BvColors.brandSplash);
    expect(BvSplashSpec.colour, BvPrimitive.energyStrong);
    expect(BvSplashSpec.colour, const Color(0xFFC24417));
    expect(BvSplashSpec.fade, const Duration(milliseconds: 350));
  });

  testWidgets('start-up already done: the splash goes at once and the first '
      'screen is there after the fade, with no other wait', (tester) async {
    final splash = await _pump(tester, AppGate.ready);
    expect(splash.removed, 1);
    expect(find.text('first screen'), findsOneWidget);

    // The cover is the token colour, fully on at the start of the fade.
    final box = tester.widget<ColoredBox>(
      find.descendant(of: _cover, matching: find.byType(ColoredBox)),
    );
    expect(box.color, BvSplashSpec.colour);
    expect(_coverOpacity(tester), 1);

    // The next frame starts the fade; from there it takes the fade alone.
    await tester.pump();
    await tester.pump(BvSplashSpec.fade ~/ 2);
    expect(_coverOpacity(tester), closeTo(0.5, 0.01));

    // At 350 ms the first screen is fully there; the cover leaves the tree
    // on the next frame.
    await tester.pump(BvSplashSpec.fade ~/ 2);
    expect(_coverOpacity(tester), 0);
    await tester.pump(_frame);
    expect(_cover, findsNothing);
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.text('first screen'), findsOneWidget);
    expect(splash.removed, 1);
  });

  testWidgets('reduce motion: the splash stays while start-up runs, with no '
      'trace, and goes once when the gate decides', (tester) async {
    _reduceMotion(tester);
    final splash = await _pump(tester, AppGate.loading);
    await tester.pump(const Duration(seconds: 5));
    expect(splash.removed, 0);
    expect(_coverOpacity(tester), 1);
    expect(_cube(tester), 1);

    final container = ProviderScope.containerOf(
      tester.element(find.text('first screen')),
    );
    container.read(_gate.notifier).set(AppGate.signedOut);
    await tester.pump();
    expect(splash.removed, 1);

    await tester.pump();
    await tester.pump(BvSplashSpec.fade);
    expect(_coverOpacity(tester), 0);
    await tester.pump(_frame);
    expect(_cover, findsNothing);

    // Later gate changes (signing in, signing out) never fade again.
    container.read(_gate.notifier).set(AppGate.ready);
    container.read(_gate.notifier).set(AppGate.loading);
    container.read(_gate.notifier).set(AppGate.signedOut);
    await tester.pump();
    expect(splash.removed, 1);
    expect(_cover, findsNothing);
  });

  testWidgets('offline at start: the retry screen counts as decided', (
    tester,
  ) async {
    final splash = await _pump(tester, AppGate.profileError);
    expect(splash.removed, 1);
  });

  testWidgets('the whole app: Home after the fade, the splash removed once', (
    tester,
  ) async {
    final splash = _FakeSplash();
    await pumpApp(
      tester,
      overrides: [nativeSplashProvider.overrideWithValue(splash)],
    );
    expect(splash.removed, 1);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(_cover, findsNothing);
  });

  group('the cube traces itself while loading (addendum)', () {
    test('its timings and pen', () {
      expect(BvSplashSpec.traceAfter, const Duration(milliseconds: 300));
      expect(
        BvSplashSpec.trace + BvSplashSpec.fill + BvSplashSpec.letters,
        BvSplashSpec.loader,
      );
      expect(BvSplashSpec.finishIn, const Duration(milliseconds: 150));
      expect(BvSplashSpec.loaderMax, const Duration(milliseconds: 1200));
      expect(BvSplashSpec.stroke, 2.5);
      expect(BvSplashSpec.traceCurve, Curves.easeInOutCubic);
      // Trace, then fill, then letters, one after the other.
      const trace = 600 / 950, fill = 800 / 950;
      expect(SplashCubePainter.traceAt(trace / 2), closeTo(0.5, 0.03));
      expect(SplashCubePainter.traceAt(trace), 1);
      expect(SplashCubePainter.fillAt(trace), 0);
      expect(SplashCubePainter.fillAt(fill), 1);
      expect(SplashCubePainter.lettersAt(fill), 0);
      expect(SplashCubePainter.lettersAt(1), 1);
      expect(BvColors.brandCubeLeft, const Color(0xFFF8F1E8));
      expect(BvColors.brandCubeRight, const Color(0xFFE6DACA));
      expect(BvColors.brandCubeLetters, BvPrimitive.energyStrong);
    });

    testWidgets('fast start-up (under 300 ms): no trace, straight to the '
        'fade from the full cube', (tester) async {
      final splash = await _pump(tester, AppGate.loading);
      await tester.pump(BvSplashSpec.traceAfter - _frame * 2);
      expect(splash.removed, 0);
      _set(tester, AppGate.ready);
      await tester.pump();
      expect(splash.removed, 1);
      expect(_cube(tester), 1);
      await tester.pump(BvSplashSpec.fade ~/ 2);
      expect(_coverOpacity(tester), lessThan(1));
      expect(_cube(tester), 1);
      await _fadeOut(tester);
      expect(splash.removed, 1);
    });

    testWidgets('reduce motion: never a trace, even after 300 ms', (
      tester,
    ) async {
      _reduceMotion(tester);
      final splash = await _pump(tester, AppGate.loading);
      await tester.pump(BvSplashSpec.traceAfter * 2);
      expect(splash.removed, 0);
      expect(_cube(tester), 1);
      expect(tester.hasRunningAnimations, isFalse);
      _set(tester, AppGate.ready);
      await tester.pump();
      expect(splash.removed, 1);
      expect(_cube(tester), 1);
      await _fadeOut(tester);
    });

    testWidgets('still loading at 300 ms: the native splash goes and the '
        'trace plays', (tester) async {
      final splash = await _pump(tester, AppGate.loading);
      await tester.pump(BvSplashSpec.traceAfter);
      expect(splash.removed, 1);
      await tester.pump();
      expect(_cube(tester), 0);
      await tester.pump(BvSplashSpec.trace ~/ 2);
      expect(SplashCubePainter.traceAt(_cube(tester)), closeTo(0.5, 0.03));
      expect(_coverOpacity(tester), 1);
    });

    testWidgets('loading never ends: the loader stops at 1.2 s and the '
        'fade starts anyway', (tester) async {
      final splash = await _pump(tester, AppGate.loading);
      await tester.pump(BvSplashSpec.traceAfter);
      expect(splash.removed, 1);
      // The cube is complete, then waits; the fade has not begun.
      await tester.pump(BvSplashSpec.loaderMax - _frame);
      expect(_cube(tester), 1);
      expect(_coverOpacity(tester), 1);
      // At 1.2 s after the native splash went, it fades, still loading.
      await tester.pump(_frame);
      await tester.pump(_frame);
      expect(_coverOpacity(tester), lessThan(1));
      await tester.pump(BvSplashSpec.fade);
      await tester.pump(_frame);
      expect(_cover, findsNothing);
      expect(splash.removed, 1);
      _set(tester, AppGate.ready);
      await tester.pump();
      expect(_cover, findsNothing);
    });

    testWidgets('loading ends mid-trace: the cube finishes within 150 ms, '
        'then the fade', (tester) async {
      final splash = await _pump(tester, AppGate.loading);
      await tester.pump(BvSplashSpec.traceAfter);
      await tester.pump();
      await tester.pump(BvSplashSpec.trace ~/ 3);
      expect(_cube(tester), lessThan(0.3));
      _set(tester, AppGate.ready);
      await tester.pump();
      await tester.pump(BvSplashSpec.finishIn);
      expect(_cube(tester), 1);
      // It completes on the next frame, and the fade starts on the one after.
      await tester.pump(_frame);
      await tester.pump(_frame);
      expect(_coverOpacity(tester), lessThan(1));
      await tester.pump(BvSplashSpec.fade);
      await tester.pump(_frame);
      expect(_cover, findsNothing);
      expect(splash.removed, 1);
    });
  });
}
