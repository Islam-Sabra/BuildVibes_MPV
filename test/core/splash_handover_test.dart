import 'package:buildvibes/core/design/bv_specs.dart';
import 'package:buildvibes/core/design/bv_tokens.dart';
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

  testWidgets('the splash stays while start-up runs, and goes once when the '
      'gate decides', (tester) async {
    final splash = await _pump(tester, AppGate.loading);
    await tester.pump(const Duration(seconds: 5));
    expect(splash.removed, 0);
    expect(_coverOpacity(tester), 1);

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
}
