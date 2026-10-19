import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/core/design/daybook_days_specs.dart';
import 'package:buildvibes/shared/widgets/bv_day_divider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

void main() {
  group('BvDayDivider', () {
    testBoth('the day between two thin rules, in grey', (tester, lang) async {
      await pumpComponent(
        tester,
        const BvDayDivider(label: 'Wednesday 14 October'),
        lang: lang,
        scroll: false,
      );
      final lines = find.byKey(const Key('day-divider-line'));
      expect(lines, findsNWidgets(2));
      final label = tester.getRect(find.text('Wednesday 14 October'));
      final first = tester.getRect(lines.first);
      final last = tester.getRect(lines.last);
      expect(first.height, BvDayDividerSpec.lineWidth);
      // One rule on each side, the same length: the label is centred.
      expect(first.width, moreOrLessEquals(last.width, epsilon: 0.5));
      final left = first.left < last.left ? first : last;
      final right = first.left < last.left ? last : first;
      expect(left.right, lessThanOrEqualTo(label.left));
      expect(right.left, greaterThanOrEqualTo(label.right));
      expect(
        textStyle(tester, 'Wednesday 14 October').color,
        BvColors.textSecondary,
      );
    });
  });
}
