import 'package:buildvibes/core/design/bv_icons.dart';
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/core/design/daybook_days_specs.dart';
import 'package:buildvibes/shared/widgets/bv_due_today_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

const _text = 'Due today: Cable tray hangers, level 4';

void main() {
  group('BvDueTodayStrip', () {
    testBoth('brand-soft, a 16 calendar and the words in action colour', (
      tester,
      lang,
    ) async {
      await pumpComponent(
        tester,
        const BvDueTodayStrip(_text),
        lang: lang,
        scroll: false,
      );
      expect(
        tester
            .widget<ColoredBox>(
              find.descendant(
                of: find.byType(BvDueTodayStrip),
                matching: find.byType(ColoredBox),
              ),
            )
            .color,
        BvColors.surfaceBrandSoft,
      );
      final icon = tester.widget<Icon>(find.byIcon(BvIcons.month));
      expect(icon.size, BvDueTodaySpec.icon);
      expect(icon.color, BvColors.textAction);
      expect(textStyle(tester, _text).color, BvColors.textAction);
    });

    testBoth('the calendar sits 20 from the start, the words after it', (
      tester,
      lang,
    ) async {
      await pumpComponent(
        tester,
        const BvDueTodayStrip(_text),
        lang: lang,
        scroll: false,
      );
      final strip = tester.getRect(find.byType(BvDueTodayStrip));
      final icon = tester.getRect(find.byIcon(BvIcons.month));
      final text = tester.getRect(find.text(_text));
      if (isRtl(lang)) {
        expect(strip.right - icon.right, BvDueTodaySpec.paddingStart);
        expect(icon.left - text.right, BvDueTodaySpec.gap);
      } else {
        expect(icon.left - strip.left, BvDueTodaySpec.paddingStart);
        expect(text.left - icon.right, BvDueTodaySpec.gap);
      }
    });

    testBoth('a long list wraps to two lines at most', (tester, lang) async {
      await pumpComponent(
        tester,
        BvDueTodayStrip(List.filled(12, 'Cable tray hangers').join(' · ')),
        lang: lang,
        scroll: false,
      );
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.maxLines, 2);
      expect(text.overflow, TextOverflow.ellipsis);
    });
  });
}
