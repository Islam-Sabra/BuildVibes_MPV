// Review 91 addendum: three frames of the cube tracing itself on the
// splash, at 390 × 844 (no text, so English only).
// Run:
//   flutter test test_screens/splash_trace_test.dart --update-goldens
import 'package:buildvibes/core/design/bv_specs.dart';
import 'package:buildvibes/core/splash/splash_handover.dart';
import 'package:buildvibes/features/entry/entry_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shot.dart';

class _NoSplash implements NativeSplash {
  @override
  void remove() {}
}

void main() {
  testWidgets('the cube traces itself, fills, and the letters come in', (
    tester,
  ) async {
    tester.view.physicalSize = shotSize * shotPixelRatio;
    tester.view.devicePixelRatio = shotPixelRatio;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: [
            // Start-up never ends here: the loader plays to the end.
            appGateProvider.overrideWithValue(AppGate.loading),
            nativeSplashProvider.overrideWithValue(_NoSplash()),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            builder: (context, child) => SplashHandover(child: child!),
            home: const SizedBox.shrink(),
          ),
        ),
      ),
    );
    Future<void> shot(String name) => expectLater(
      find.byKey(key),
      matchesGoldenFile('../docs/screens/app-icon/$name.png'),
    );

    await tester.pump(BvSplashSpec.traceAfter);
    await tester.pump(); // the trace's first frame
    await tester.pump(BvSplashSpec.trace ~/ 2);
    await shot('splash-trace-half');
    await tester.pump(BvSplashSpec.trace ~/ 2 + BvSplashSpec.fill);
    await shot('splash-filled');
    await tester.pump(BvSplashSpec.letters);
    await shot('splash-letters');
    // The cap fades it out; nothing is left running.
    await tester.pump(BvSplashSpec.loaderMax);
    await tester.pump(BvSplashSpec.fade);
    await tester.pump(BvSplashSpec.fade);
  });
}
