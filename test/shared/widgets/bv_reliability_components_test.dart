import 'package:buildvibes/core/design/bv_icons.dart';
import 'package:buildvibes/core/design/bv_specs.dart';
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/shared/widgets/bv_new_chip.dart';
import 'package:buildvibes/shared/widgets/bv_quiet_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

const _text = "Notifications aren't reaching this phone";

void main() {
  group('BvQuietLine', () {
    testBoth('subtle surface, a 16 icon and secondary text; the action in '
        'action colour at the end, a 48 tap area', (tester, lang) async {
      var taps = 0;
      await pumpComponent(
        tester,
        BvQuietLine(
          icon: BvIcons.notificationsOff,
          text: _text,
          actionLabel: 'Fix it',
          onAction: () => taps++,
        ),
        lang: lang,
        scroll: false,
      );
      expect(
        tester
            .widget<ColoredBox>(
              find.descendant(
                of: find.byType(BvQuietLine),
                matching: find.byType(ColoredBox),
              ),
            )
            .color,
        BvColors.surfaceSubtle,
      );
      final icon = tester.widget<Icon>(find.byIcon(BvIcons.notificationsOff));
      expect(icon.size, BvQuietLineSpec.icon);
      expect(icon.color, BvColors.iconSecondary);
      expect(textStyle(tester, _text).color, BvColors.textSecondary);
      expect(textStyle(tester, 'Fix it').color, BvColors.textAction);

      final line = tester.getRect(find.byType(BvQuietLine));
      final iconRect = tester.getRect(find.byIcon(BvIcons.notificationsOff));
      final action = tester.getRect(find.byType(InkWell));
      expect(action.height, greaterThanOrEqualTo(BvSize.touchMin));
      expect(action.width, greaterThanOrEqualTo(BvSize.touchMin));
      // The icon at the start, the action at the end.
      if (isRtl(lang)) {
        expect(line.right - iconRect.right, BvQuietLineSpec.paddingStart);
        expect(action.left - line.left, BvQuietLineSpec.paddingEnd);
      } else {
        expect(iconRect.left - line.left, BvQuietLineSpec.paddingStart);
        expect(line.right - action.right, BvQuietLineSpec.paddingEnd);
      }
      await tester.tap(find.text('Fix it'));
      expect(taps, 1);
    });
  });

  group('BvNewChip', () {
    testBoth('ink, inverse words and an arrow; down for the Daybook, up for '
        'Home; a 48 tap area', (tester, lang) async {
      var taps = 0;
      await pumpComponent(
        tester,
        Column(
          children: [
            BvNewChip(label: 'New', onTap: () => taps++),
            BvNewChip(label: 'New', below: false, onTap: () => taps++),
          ],
        ),
        lang: lang,
      );
      expect(find.byIcon(BvIcons.newBelow), findsOneWidget);
      expect(find.byIcon(BvIcons.newAbove), findsOneWidget);
      // Up and down never mirror in Arabic.
      expect(BvIcons.newBelow.matchTextDirection, isFalse);
      final chip = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(BvNewChip).first,
              matching: find.byType(Container),
            )
            .first,
      );
      final shape = chip.decoration! as ShapeDecoration;
      expect(shape.color, BvColors.brandInk);
      expect(shape.shadows, BvShadow.popover);
      expect(
        tester.widget<Text>(find.text('New').first).style!.color,
        BvColors.textInverse,
      );
      expect(
        tester.getSize(find.byType(BvNewChip).first).height,
        BvSize.touchMin,
      );
      await tester.tap(find.byType(BvNewChip).first);
      await tester.tap(find.byType(BvNewChip).last);
      expect(taps, 2);
    });
  });
}
