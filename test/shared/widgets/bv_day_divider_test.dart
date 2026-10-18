import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/core/design/daybook_days_specs.dart';
import 'package:buildvibes/shared/widgets/bv_day_divider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

void main() {
  group('BvDayDivider', () {
    testBoth('dashed line above the weekday, date at the end', (
      tester,
      lang,
    ) async {
      await pumpComponent(
        tester,
        const BvDayDivider(weekday: 'Thursday', date: '15 October'),
        lang: lang,
        scroll: false,
      );
      final line = tester.getRect(find.byKey(const Key('day-divider-line')));
      expect(line.height, BvDayDividerSpec.lineWidth);
      expect(line.width, 390 - 2 * BvDayDividerSpec.paddingHorizontal);
      expect(
        tester.getRect(find.text('Thursday')).top,
        greaterThan(line.bottom),
      );
      expect(textStyle(tester, '15 October').color, BvColors.textSecondary);
      final weekday = tester.getCenter(find.text('Thursday')).dx;
      final date = tester.getCenter(find.text('15 October')).dx;
      expect(isRtl(lang) ? weekday > date : weekday < date, isTrue);
    });
  });
}
