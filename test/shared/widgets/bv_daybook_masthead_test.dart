import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/shared/widgets/bv_daybook_masthead.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

void main() {
  group('BvDaybookMasthead', () {
    testBoth('weekday at the start, weather at the end, tappable', (
      tester,
      lang,
    ) async {
      var taps = 0;
      await pumpComponent(
        tester,
        BvDaybookMasthead(
          weekday: 'Thursday',
          dateLine: '15 October, day 41 on site',
          temperature: '34°',
          weather: 'Sunny, light wind',
          onTap: () => taps++,
        ),
        lang: lang,
        scroll: false,
      );
      final type = BvType.of(tester.element(find.text('Thursday')));
      expect(
        textStyle(tester, 'Thursday').fontSize,
        type.displayBrand.fontSize,
      );
      expect(
        textStyle(tester, '15 October, day 41 on site').color,
        BvColors.textSecondary,
      );
      expect(
        textStyle(tester, 'Sunny, light wind').color,
        BvColors.textSecondary,
      );
      final weekday = tester.getCenter(find.text('Thursday')).dx;
      final temp = tester.getCenter(find.text('34°')).dx;
      expect(isRtl(lang) ? weekday > temp : weekday < temp, isTrue);

      await tester.tap(find.text('Thursday'));
      expect(taps, 1);
    });

    testBoth('no weather hides the block', (tester, lang) async {
      await pumpComponent(
        tester,
        const BvDaybookMasthead(weekday: 'Thursday', dateLine: '15 October'),
        lang: lang,
        scroll: false,
      );
      expect(find.byKey(const Key('masthead-weather')), findsNothing);
    });

    testBoth('compact is one line with the temperature', (tester, lang) async {
      await pumpComponent(
        tester,
        const BvDaybookMasthead.compact(
          title: 'Thursday 15 October',
          temperature: '34°',
        ),
        lang: lang,
        scroll: false,
      );
      final type = BvType.of(tester.element(find.text('34°')));
      expect(
        textStyle(tester, 'Thursday 15 October').fontSize,
        type.titleLg.fontSize,
      );
      expect(textStyle(tester, '34°').fontSize, type.titleLg.fontSize);
    });

    testBoth('Home has a subline and no weather', (tester, lang) async {
      await pumpComponent(
        tester,
        const BvDaybookMasthead.home(
          weekday: 'Thursday',
          dateLine: '15 October, from people you follow',
        ),
        lang: lang,
        scroll: false,
      );
      expect(find.text('15 October, from people you follow'), findsOneWidget);
      expect(find.byKey(const Key('masthead-weather')), findsNothing);
    });
  });
}
