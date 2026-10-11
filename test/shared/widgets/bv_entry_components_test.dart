import 'package:buildvibes/core/design/bv_specs.dart';
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/shared/widgets/bv_choice_card.dart';
import 'package:buildvibes/shared/widgets/bv_code_field.dart';
import 'package:buildvibes/shared/widgets/bv_list_row.dart';
import 'package:buildvibes/shared/widgets/bv_step_progress.dart';
import 'package:buildvibes/shared/widgets/bv_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

void main() {
  group('BvCodeField', () {
    testBoth('six boxes, filled left to right, then completes', (
      tester,
      lang,
    ) async {
      String? done;
      await pumpComponent(
        tester,
        BvCodeField(onCompleted: (v) => done = v),
        lang: lang,
      );
      for (var i = 0; i < BvFieldSpec.codeLength; i++) {
        expect(
          tester.getSize(find.byKey(Key('code-box-$i'))).height,
          BvFieldSpec.codeBoxHeight,
        );
      }
      // Always left to right, also in Arabic.
      expect(
        tester.getCenter(find.byKey(const Key('code-box-0'))).dx,
        lessThan(tester.getCenter(find.byKey(const Key('code-box-5'))).dx),
      );
      final arabicFive = String.fromCharCode(0x0665);
      await tester.enterText(
        find.byKey(const Key('code-input')),
        '47$arabicFive',
      );
      await tester.pump();
      expect(
        find.descendant(
          of: find.byKey(const Key('code-box-2')),
          matching: find.text('5'),
        ),
        findsOneWidget,
      );
      expect(done, isNull);
      await tester.enterText(find.byKey(const Key('code-input')), '472123');
      expect(done, '472123');
      final input = tester.widget<TextField>(
        find.byKey(const Key('code-input')),
      );
      expect(input.autofillHints, contains(AutofillHints.oneTimeCode));
    });

    testBoth('error turns the boxes red', (tester, lang) async {
      await pumpComponent(
        tester,
        const BvCodeField(error: 'Wrong code'),
        lang: lang,
      );
      expect(find.text('Wrong code'), findsOneWidget);
      final border =
          decorationOf(tester, find.byKey(const Key('code-box-0'))).border!
              as Border;
      expect(border.top.color, BvColors.borderDestructive);
    });
  });

  group('BvPhoneField with a dial code box', () {
    testBoth('the code box sits before the number, in both languages', (
      tester,
      lang,
    ) async {
      var taps = 0;
      await pumpComponent(
        tester,
        BvPhoneField(
          label: 'Mobile number',
          dialCode: '+965',
          onDialCodeTap: () => taps++,
          helper: 'We send a code',
        ),
        lang: lang,
      );
      final box = tester.getRect(find.byKey(const Key('dial-code-box')));
      final field = tester.getRect(find.byType(TextField));
      expect(box.right, lessThan(field.left));
      expect(box.width, BvFieldSpec.dialBoxWidth);
      await tester.tap(find.byKey(const Key('dial-code-box')));
      expect(taps, 1);
      expect(find.text('We send a code'), findsOneWidget);
    });

    testBoth('an error marks both boxes and shows once', (tester, lang) async {
      await pumpComponent(
        tester,
        BvPhoneField(dialCode: '+965', onDialCodeTap: () {}, error: 'Check it'),
        lang: lang,
      );
      expect(find.text('Check it'), findsOneWidget);
      expect(find.byKey(const Key('field-error-icon')), findsOneWidget);
    });
  });

  group('BvStepProgress', () {
    testBoth('done steps are ink, later steps are the border colour', (
      tester,
      lang,
    ) async {
      await pumpComponent(
        tester,
        const BvStepProgress(total: 2, current: 1),
        lang: lang,
      );
      expect(
        decorationOf(tester, find.byKey(const Key('step-1'))).color,
        BvColors.brandInk,
      );
      expect(
        decorationOf(tester, find.byKey(const Key('step-2'))).color,
        BvColors.borderDefault,
      );
      expect(
        tester.getSize(find.byKey(const Key('step-1'))).height,
        BvStepProgressSpec.height,
      );
    });
  });

  testBoth('list row check mark only when selected', (tester, lang) async {
    await pumpComponent(
      tester,
      const BvListGroup(
        rows: [
          BvListRow(title: 'A', trailing: BvRowTrailing.check(selected: true)),
          BvListRow(title: 'B', trailing: BvRowTrailing.check(selected: false)),
        ],
      ),
      lang: lang,
    );
    expect(find.byKey(const Key('row-check')), findsOneWidget);
  });

  testBoth('a choice that is not available shows its badge and ignores taps', (
    tester,
    lang,
  ) async {
    String? value;
    await pumpComponent(
      tester,
      StatefulBuilder(
        builder: (context, setState) => BvChoiceList<String>(
          value: value,
          options: const [
            BvChoiceOption(value: 'kw', title: 'Kuwait'),
            BvChoiceOption(
              value: 'eg',
              title: 'Egypt',
              enabled: false,
              badge: 'Coming soon',
            ),
          ],
          onChanged: (v) => setState(() => value = v),
        ),
      ),
      lang: lang,
    );
    expect(find.text('Coming soon'), findsOneWidget);
    await tester.tap(find.text('Egypt'));
    await tester.pump();
    expect(value, isNull);
    expect(materialColor(tester, find.text('Egypt')), BvColors.surfaceSubtle);
    await tester.tap(find.text('Kuwait'));
    await tester.pump();
    expect(value, 'kw');
  });
}
