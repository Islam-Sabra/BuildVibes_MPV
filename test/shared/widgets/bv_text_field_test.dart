import 'package:buildvibes/core/design/bv_specs.dart';
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/shared/widgets/bv_choice_card.dart';
import 'package:buildvibes/shared/widgets/bv_search_field.dart';
import 'package:buildvibes/shared/widgets/bv_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

InputDecoration _decoration(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField).first).decoration!;

void main() {
  group('BvTextField', () {
    testBoth('label, field and helper', (tester, lang) async {
      await pumpComponent(
        tester,
        const BvTextField(label: 'Title', placeholder: 'Type', helper: 'Short'),
        lang: lang,
      );
      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Short'), findsOneWidget);
      expect(textStyle(tester, 'Short').color, BvColors.textSecondary);
      expect(tester.getSize(find.byType(TextField)).height, BvFieldSpec.height);
      final d = _decoration(tester);
      expect(d.fillColor, BvColors.surfaceElevated);
      final enabled = d.enabledBorder! as OutlineInputBorder;
      expect(enabled.borderSide.color, BvColors.borderInput);
      expect(enabled.borderSide.width, BvStroke.thin);
      final focused = d.focusedBorder! as OutlineInputBorder;
      expect(focused.borderSide.color, BvColors.borderFocus);
      expect(focused.borderSide.width, BvStroke.thick);
      expect(enabled.borderRadius, BvRadius.controlAll);
    });

    testBoth('error: red border and helper with a warning icon', (
      tester,
      lang,
    ) async {
      await pumpComponent(
        tester,
        const BvTextField(label: 'Title', helper: 'Short', error: 'Needed'),
        lang: lang,
      );
      expect(find.text('Short'), findsNothing);
      expect(textStyle(tester, 'Needed').color, BvColors.textDestructive);
      expect(find.byKey(const Key('field-error-icon')), findsOneWidget);
      final border = _decoration(tester).enabledBorder! as OutlineInputBorder;
      expect(border.borderSide.color, BvColors.borderDestructive);
      expect(border.borderSide.width, BvStroke.thick);

      final icon = tester.getCenter(find.byKey(const Key('field-error-icon')));
      final text = tester.getCenter(find.text('Needed'));
      expect(isRtl(lang) ? icon.dx > text.dx : icon.dx < text.dx, isTrue);
    });

    testBoth('multi-line shows a counter only near the limit', (
      tester,
      lang,
    ) async {
      final controller = TextEditingController(text: 'short');
      addTearDown(controller.dispose);
      await pumpComponent(
        tester,
        BvTextField(controller: controller, maxLines: 3, maxLength: 10),
        lang: lang,
      );
      expect(find.byKey(const Key('field-counter')), findsNothing);
      await tester.enterText(find.byType(TextField), 'eight ch');
      await tester.pump();
      expect(find.text('8 / 10'), findsOneWidget);
    });
  });

  test('Arabic-Indic and Persian digits become Western digits', () {
    final arabic = String.fromCharCodes([0x0661, 0x0662, 0x0663]);
    final persian = String.fromCharCodes([0x06F4, 0x06F5]);
    expect(BvWesternDigitsFormatter.normalise(arabic), '123');
    expect(BvWesternDigitsFormatter.normalise(persian), '45');
    expect(BvWesternDigitsFormatter.normalise('KCT-021'), 'KCT-021');
  });

  testBoth('phone field: dial code before the number, left to right', (
    tester,
    lang,
  ) async {
    await pumpComponent(
      tester,
      const BvPhoneField(label: 'Phone', dialCode: '+000'),
      lang: lang,
    );
    // The dial code shows before the field is focused, before the number.
    expect(find.text('+000'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '5');
    expect(
      tester.getCenter(find.text('+000')).dx,
      lessThan(tester.getCenter(find.text('5')).dx),
    );
    expect(
      Directionality.of(tester.element(find.byType(TextField))),
      TextDirection.ltr,
    );
    final arabicDigits = String.fromCharCodes([0x0669, 0x0668]);
    await tester.enterText(find.byType(TextField), '5x$arabicDigits');
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '598',
    );
  });

  testBoth('code field takes 6 digits and reports when complete', (
    tester,
    lang,
  ) async {
    String? done;
    await pumpComponent(
      tester,
      BvCodeField(onCompleted: (v) => done = v),
      lang: lang,
    );
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.maxLength, BvFieldSpec.codeLength);
    expect(
      field.inputFormatters!.whereType<FilteringTextInputFormatter>(),
      isNotEmpty,
    );
    await tester.enterText(find.byType(TextField), '123456');
    expect(done, '123456');
  });

  testBoth('select opens a sheet with one choice list', (tester, lang) async {
    String? value = 'a';
    await pumpComponent(
      tester,
      StatefulBuilder(
        builder: (context, setState) => BvSelect<String>(
          label: 'Team',
          value: value,
          options: const [
            BvSelectOption(value: 'a', label: 'Structure'),
            BvSelectOption(value: 'b', label: 'Finishes'),
          ],
          onChanged: (v) => setState(() => value = v),
        ),
      ),
      lang: lang,
    );
    expect(find.text('Structure'), findsOneWidget);
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bv-sheet')), findsOneWidget);
    expect(find.byType(BvChoiceCard), findsNWidgets(2));
    await tester.tap(find.text('Finishes').last);
    await tester.pumpAndSettle();
    expect(value, 'b');
    expect(find.byKey(const Key('bv-sheet')), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Finishes',
    );
  });

  group('BvSearchField', () {
    testBoth('subtle without focus, white with a focus border', (
      tester,
      lang,
    ) async {
      await pumpComponent(
        tester,
        const BvSearchField(placeholder: 'Search people'),
        lang: lang,
      );
      expect(_decoration(tester).fillColor, BvColors.surfaceSubtle);
      expect(
        (_decoration(tester).enabledBorder! as OutlineInputBorder).borderSide,
        BorderSide.none,
      );
      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(_decoration(tester).fillColor, BvColors.surfaceElevated);
      final focused = _decoration(tester).focusedBorder! as OutlineInputBorder;
      expect(focused.borderSide.color, BvColors.borderFocus);
      expect(focused.borderSide.width, BvStroke.thick);
      expect(tester.getSize(find.byType(TextField)).height, BvFieldSpec.height);
    });
  });
}
