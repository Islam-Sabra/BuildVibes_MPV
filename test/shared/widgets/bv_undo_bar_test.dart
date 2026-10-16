import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/core/design/daybook_writing_specs.dart';
import 'package:buildvibes/shared/widgets/bv_undo_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

Future<void> _show(
  WidgetTester tester,
  String lang,
  VoidCallback onUndo,
) async {
  await pumpComponent(
    tester,
    Builder(
      builder: (context) => TextButton(
        onPressed: () => showBvUndoBar(
          context,
          message: 'Checked',
          actionLabel: 'Undo',
          onAction: onUndo,
        ),
        child: const Text('check'),
      ),
    ),
    lang: lang,
  );
  await tester.tap(find.text('check'));
  await tester.pumpAndSettle();
}

void main() {
  testBoth('undo bar: ink, labelMd, an underlined action at the end', (
    tester,
    lang,
  ) async {
    var undone = 0;
    await pumpComponent(
      tester,
      BvUndoBar(
        message: 'Checked',
        actionLabel: 'Undo',
        onAction: () => undone++,
      ),
      lang: lang,
    );
    expect(textStyle(tester, 'Undo').decoration, TextDecoration.underline);
    expect(textStyle(tester, 'Checked').color, BvColors.textInverse);
    final message = tester.getCenter(find.text('Checked')).dx;
    final action = tester.getCenter(find.text('Undo')).dx;
    expect(isRtl(lang) ? action < message : action > message, isTrue);
    await tester.tap(find.text('Undo'));
    expect(undone, 1);
  });

  testBoth('shown 12 above the post bar, gone after 5 seconds', (
    tester,
    lang,
  ) async {
    var undone = 0;
    await _show(tester, lang, () => undone++);
    final bar = tester.getRect(find.byType(BvUndoBar));
    expect(bar.bottom, 844 - BvUndoBarSpec.postBarHeight - BvUndoBarSpec.lift);
    expect(bar.width, 390 - BvUndoBarSpec.side * 2);

    await tester.pump(BvUndoBarSpec.duration);
    await tester.pumpAndSettle();
    expect(find.byType(BvUndoBar), findsNothing);
    expect(undone, 0);
  });

  testBoth('undo closes the bar', (tester, lang) async {
    var undone = 0;
    await _show(tester, lang, () => undone++);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(undone, 1);
    expect(find.byType(BvUndoBar), findsNothing);
  });
}
