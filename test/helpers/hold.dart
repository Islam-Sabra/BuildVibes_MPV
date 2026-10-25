import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hold to confirm (review 94): a finger down on [f] for [time] (just past
/// the hold by default), then up.
Future<void> hold(WidgetTester tester, Finder f, {Duration? time}) async {
  time ??= BvMotion.hold + const Duration(milliseconds: 50);
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  final finger = await tester.startGesture(holdPoint(tester, f));
  // The first frame starts the fill's clock.
  await tester.pump();
  await tester.pump(time ~/ 2);
  await tester.pump(time - time ~/ 2);
  await finger.up();
  await tester.pumpAndSettle();
}

/// The hold button on a sheet.
Finder get holdOnSheet => find.descendant(
  of: find.byKey(const Key('hold-sheet')),
  matching: find.byKey(const Key('hold-button')),
);

/// The middle of the part of [f] that takes the hold (a pill hugs its
/// words at the start of a wider row).
Offset holdPoint(WidgetTester tester, Finder f) {
  final press = find.descendant(
    of: f.first,
    matching: find.byKey(const Key('hold-press')),
  );
  return tester.getCenter(press.evaluate().isEmpty ? f.first : press.first);
}
