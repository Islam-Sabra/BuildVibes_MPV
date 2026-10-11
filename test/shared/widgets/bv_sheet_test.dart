import 'package:buildvibes/core/design/bv_specs.dart';
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/shared/widgets/bv_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

Widget _opener({BvSheetFooter? footer}) => Builder(
  builder: (context) => TextButton(
    onPressed: () => showBvSheet(
      context: context,
      title: 'Who can see it?',
      subtitle: 'Choose one.',
      footer: footer,
      builder: (_) => const Text('Body'),
    ),
    child: const Text('open'),
  ),
);

void main() {
  testBoth('sheet: handle, header, body, colours', (tester, lang) async {
    await pumpComponent(tester, _opener(), lang: lang);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Who can see it?'), findsOneWidget);
    expect(textStyle(tester, 'Choose one.').color, BvColors.textSecondary);
    expect(find.text('Body'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('bv-sheet-handle'))),
      const Size(BvSheetSpec.handleWidth, BvSheetSpec.handleHeight),
    );
    final sheet = decorationOf(tester, find.byKey(const Key('bv-sheet')));
    expect(sheet.color, BvColors.surfaceApp);
    expect(sheet.borderRadius, BvRadius.sheetTop);
    expect(sheet.boxShadow, BvShadow.sheet);
    final modal = tester.widget<ModalBarrier>(find.byType(ModalBarrier).last);
    expect(modal.color, BvColors.overlayScrim);
  });

  testBoth('tapping the scrim closes the sheet', (tester, lang) async {
    await pumpComponent(tester, _opener(), lang: lang);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(195, 40));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bv-sheet')), findsNothing);
  });

  testBoth('footer: Cancel and Confirm share the width', (tester, lang) async {
    var confirmed = false;
    await pumpComponent(
      tester,
      _opener(
        footer: BvSheetFooter(
          cancelLabel: 'Cancel',
          confirmLabel: 'Confirm',
          onConfirm: () => confirmed = true,
        ),
      ),
      lang: lang,
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final cancel = tester.getRect(find.byKey(const Key('bv-sheet-cancel')));
    final confirm = tester.getRect(find.byKey(const Key('bv-sheet-confirm')));
    expect(cancel.width, closeTo(confirm.width, 0.5));
    // Cancel comes first in the reading direction.
    expect(
      isRtl(lang) ? cancel.left > confirm.left : cancel.left < confirm.left,
      isTrue,
    );
    await tester.tap(find.text('Confirm'));
    expect(confirmed, isTrue);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bv-sheet')), findsNothing);
  });
}
