import 'package:buildvibes/core/design/bv_icons.dart';
import 'package:buildvibes/core/design/bv_specs.dart';
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/shared/widgets/bv_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

ButtonStyle _style(WidgetTester tester) =>
    tester.widget<TextButton>(find.byType(TextButton)).style!;

void main() {
  testBoth('primary: colours, large height, tap', (tester, lang) async {
    var taps = 0;
    await pumpComponent(
      tester,
      BvButton(label: 'Go', onPressed: () => taps++),
      lang: lang,
    );
    final style = _style(tester);
    expect(style.backgroundColor!.resolve({}), BvColors.actionPrimary);
    expect(
      style.backgroundColor!.resolve({WidgetState.pressed}),
      BvColors.actionPrimaryPressed,
    );
    expect(
      style.foregroundColor!.resolve({}),
      BvColors.actionPrimaryForeground,
    );
    expect(
      tester.getSize(find.byType(TextButton)).height,
      greaterThanOrEqualTo(BvButtonSpec.heightLarge),
    );
    await tester.tap(find.text('Go'));
    expect(taps, 1);
  });

  testBoth('medium size is 44 high (48 tap area)', (tester, lang) async {
    await pumpComponent(
      tester,
      BvButton(label: 'Go', size: BvButtonSize.medium, onPressed: () {}),
      lang: lang,
    );
    final style = _style(tester);
    expect(style.maximumSize!.resolve({})!.height, BvButtonSpec.heightMedium);
    expect(
      tester.getSize(find.byType(TextButton)).height,
      greaterThanOrEqualTo(BvSize.touchMin),
    );
  });

  testBoth('disabled when there is no action', (tester, lang) async {
    await pumpComponent(
      tester,
      const Column(
        children: [
          BvButton(label: 'A', onPressed: null),
          BvButton(label: 'B', style: BvButtonStyle.secondary, onPressed: null),
        ],
      ),
      lang: lang,
    );
    final styles = tester
        .widgetList<TextButton>(find.byType(TextButton))
        .map((b) => b.style!)
        .toList();
    for (final s in styles) {
      expect(
        s.backgroundColor!.resolve({WidgetState.disabled}),
        BvColors.actionDisabled,
      );
      expect(
        s.foregroundColor!.resolve({WidgetState.disabled}),
        BvColors.actionDisabledForeground,
      );
      expect(s.side!.resolve({WidgetState.disabled}), BorderSide.none);
    }
  });

  testBoth('secondary, tertiary and destructive colours', (tester, lang) async {
    for (final (style, text, border) in [
      (BvButtonStyle.secondary, BvColors.textPrimary, BvColors.borderInput),
      (BvButtonStyle.tertiary, BvColors.textAction, null),
      (
        BvButtonStyle.destructive,
        BvColors.textDestructive,
        BvColors.borderDestructive,
      ),
    ]) {
      await pumpComponent(
        tester,
        BvButton(label: 'X', style: style, onPressed: () {}),
        lang: lang,
      );
      final s = _style(tester);
      expect(s.foregroundColor!.resolve({}), text);
      expect(
        s.backgroundColor!.resolve({WidgetState.pressed}),
        BvColors.surfaceSubtle,
      );
      final side = s.side!.resolve({})!;
      if (border == null) {
        expect(side, BorderSide.none);
      } else {
        expect(side.color, border);
        expect(side.width, BvStroke.thin);
      }
    }
  });

  testBoth('focused shows a 2 px focus border', (tester, lang) async {
    await pumpComponent(
      tester,
      BvButton(label: 'X', onPressed: () {}),
      lang: lang,
    );
    final side = _style(tester).side!.resolve({WidgetState.focused})!;
    expect(side.color, BvColors.borderFocus);
    expect(side.width, BvStroke.thick);
  });

  testBoth('icon sits at the start', (tester, lang) async {
    await pumpComponent(
      tester,
      BvButton(label: 'Sign', icon: BvIcons.check, onPressed: () {}),
      lang: lang,
    );
    final icon = tester.getCenter(find.byIcon(BvIcons.check)).dx;
    final text = tester.getCenter(find.text('Sign')).dx;
    expect(isRtl(lang) ? icon > text : icon < text, isTrue);
  });

  testBoth('expand fills the width', (tester, lang) async {
    await pumpComponent(
      tester,
      BvButton(label: 'Go', expand: true, onPressed: () {}),
      lang: lang,
    );
    expect(
      tester.getSize(find.byType(TextButton)).width,
      390 - 2 * BvSpace.gutter,
    );
  });
}
