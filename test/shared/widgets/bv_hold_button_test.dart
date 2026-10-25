// Review 94: Hold to confirm. A hold under 600 ms does nothing, a full one
// acts; the fill runs from the start side (right to left in Arabic); let
// go early, a line says to keep holding, the first two times; a screen
// reader's double-tap asks instead; Reduce motion moves nothing.
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/shared/widgets/bv_hold_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/hold.dart';

class _Probe {
  int confirmed = 0;
  int asked = 0;
  bool answer = true;
}

Future<_Probe> _pump(
  WidgetTester tester, {
  TextDirection direction = TextDirection.ltr,
}) async {
  final probe = _Probe();
  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: direction,
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: BvHoldButton(
                label: 'Hold to check',
                hint: 'Keep holding to confirm',
                expand: true,
                onConfirmed: () => probe.confirmed++,
                confirm: () async {
                  probe.asked++;
                  return probe.answer;
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return probe;
}

final _button = find.byKey(const Key('hold-button'));

/// The fill's reach, 0 to 1: how much of the fill layer is clipped in.
Rect? _fill(WidgetTester tester) {
  final clips = find.descendant(of: _button, matching: find.byType(ClipRect));
  if (clips.evaluate().isEmpty) return null;
  final clip = tester.widget<ClipRect>(clips.first);
  return clip.clipper!.getClip(const Size(300, 48));
}

void main() {
  setUp(() {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
  });

  test('600 ms to hold, 150 ms to run back', () {
    expect(BvMotion.hold, const Duration(milliseconds: 600));
    expect(BvMotion.holdBack, const Duration(milliseconds: 150));
  });

  testWidgets('a tap and a short hold do nothing; a full hold acts once', (
    tester,
  ) async {
    final probe = await _pump(tester);
    await tester.tap(_button);
    await tester.pumpAndSettle();
    await hold(tester, _button, time: const Duration(milliseconds: 500));
    expect(probe.confirmed, 0);
    await hold(tester, _button);
    expect(probe.confirmed, 1);
    expect(probe.asked, 0);
  });

  testWidgets('let go early: the fill runs back in 150 ms', (tester) async {
    await _pump(tester);
    final finger = await tester.startGesture(tester.getCenter(_button));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_fill(tester)!.width, closeTo(150, 2));
    await finger.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 75));
    expect(_fill(tester)!.width, closeTo(75, 3));
    await tester.pump(const Duration(milliseconds: 80));
    expect(_fill(tester), isNull);
  });

  testWidgets('a finger that slides off lets go', (tester) async {
    final probe = await _pump(tester);
    final finger = await tester.startGesture(tester.getCenter(_button));
    await tester.pump(const Duration(milliseconds: 200));
    await finger.moveBy(const Offset(0, 60));
    await tester.pump(const Duration(milliseconds: 600));
    await finger.up();
    await tester.pumpAndSettle();
    expect(probe.confirmed, 0);
  });

  for (final direction in TextDirection.values) {
    testWidgets('the fill starts at the start side ($direction)', (
      tester,
    ) async {
      await _pump(tester, direction: direction);
      final finger = await tester.startGesture(tester.getCenter(_button));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final reach = _fill(tester)!;
      if (direction == TextDirection.rtl) {
        expect(reach.right, 300);
        expect(reach.left, closeTo(150, 2));
      } else {
        expect(reach.left, 0);
        expect(reach.right, closeTo(150, 2));
      }
      await finger.up();
      await tester.pumpAndSettle();
    });
  }

  testWidgets('"Keep holding to confirm" after the first two early lets-go '
      'only', (tester) async {
    await _pump(tester);
    final hint = find.byKey(const Key('hold-hint'));
    for (var i = 0; i < 3; i++) {
      final finger = await tester.startGesture(tester.getCenter(_button));
      await tester.pump();
      // A new hold puts the line away.
      expect(hint, findsNothing);
      await tester.pump(const Duration(milliseconds: 200));
      await finger.up();
      await tester.pumpAndSettle();
      expect(hint, i < 2 ? findsOneWidget : findsNothing, reason: '$i');
    }
  });

  testWidgets('a screen reader: a double-tap asks; Not now does nothing, '
      'yes acts', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final probe = await _pump(tester)
      ..answer = false;
    await tester.tap(_button);
    await tester.pumpAndSettle();
    expect((probe.asked, probe.confirmed), (1, 0));
    probe.answer = true;
    await tester.tap(_button);
    await tester.pumpAndSettle();
    expect((probe.asked, probe.confirmed), (2, 1));
    // Its own button, read out by its words.
    expect(
      tester.getSemantics(find.bySemanticsLabel('Hold to check')),
      matchesSemantics(
        label: 'Hold to check',
        isButton: true,
        hasTapAction: true,
      ),
    );
  });

  testWidgets('Reduce motion: no fill while held; solid at 600 ms, and it '
      'acts', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final probe = await _pump(tester);
    final finger = await tester.startGesture(tester.getCenter(_button));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_fill(tester), isNull);
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pump(const Duration(milliseconds: 320));
    expect(probe.confirmed, 1);
    await finger.up();
    await tester.pumpAndSettle();
    expect(probe.confirmed, 1);
  });
}
