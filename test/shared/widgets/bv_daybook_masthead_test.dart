import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/shared/widgets/bv_daybook_masthead.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

void main() {
  group('BvDaybookMasthead', () {
    testBoth('one line: the day in bold, the date in grey, tappable', (
      tester,
      lang,
    ) async {
      var taps = 0;
      await pumpComponent(
        tester,
        BvDaybookMasthead(
          weekday: 'Thursday',
          date: '15 October',
          onTap: () => taps++,
        ),
        lang: lang,
        scroll: false,
      );
      final type = BvType.of(tester.element(find.text('Thursday')));
      expect(textStyle(tester, 'Thursday').fontSize, type.titleLg.fontSize);
      expect(textStyle(tester, 'Thursday').fontWeight, type.titleLg.fontWeight);
      expect(textStyle(tester, '15 October').color, BvColors.textSecondary);
      // One line: the date follows the day.
      final day = tester.getRect(find.text('Thursday'));
      final date = tester.getRect(find.text('15 October'));
      expect(date.top, lessThan(day.bottom));
      expect(
        isRtl(lang) ? date.right <= day.left : date.left >= day.right,
        isTrue,
      );

      await tester.tap(find.text('Thursday'));
      expect(taps, 1);
    });
  });
}
