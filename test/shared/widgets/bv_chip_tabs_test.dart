import 'package:buildvibes/core/design/bv_specs.dart';
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/shared/widgets/bv_chip.dart';
import 'package:buildvibes/shared/widgets/bv_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

RoundedRectangleBorder _shape(WidgetTester tester, String label) =>
    tester
            .widget<Material>(
              find
                  .ancestor(
                    of: find.text(label),
                    matching: find.byType(Material),
                  )
                  .first,
            )
            .shape!
        as RoundedRectangleBorder;

void main() {
  group('BvChip', () {
    testBoth('default, selected and ink states', (tester, lang) async {
      await pumpComponent(
        tester,
        const BvChipRow(
          chips: [
            BvChip(label: 'All', ink: true, selected: true),
            BvChip(label: 'Open', selected: true),
            BvChip(label: 'Done'),
          ],
        ),
        lang: lang,
        scroll: false,
      );
      expect(materialColor(tester, find.text('All')), BvColors.brandInk);
      expect(textStyle(tester, 'All').color, BvColors.textInverse);
      expect(
        materialColor(tester, find.text('Open')),
        BvColors.surfaceBrandSoft,
      );
      expect(_shape(tester, 'Open').side.color, BvColors.borderSelected);
      expect(
        materialColor(tester, find.text('Done')),
        BvColors.surfaceElevated,
      );
      expect(_shape(tester, 'Done').side.color, BvColors.borderDefault);
      expect(textStyle(tester, 'Done').color, BvColors.textPrimary);

      final chip = find.ancestor(
        of: find.text('Done'),
        matching: find.byType(Container),
      );
      expect(tester.getSize(chip.first).height, BvChipSpec.height);
    });

    testBoth('a row scrolls sideways from the start', (tester, lang) async {
      await pumpComponent(
        tester,
        const BvChipRow(
          chips: [
            BvChip(label: 'First'),
            BvChip(label: 'Second'),
          ],
        ),
        lang: lang,
        scroll: false,
      );
      final scroll = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(scroll.scrollDirection, Axis.horizontal);
      final first = tester.getCenter(find.text('First')).dx;
      final second = tester.getCenter(find.text('Second')).dx;
      expect(isRtl(lang) ? first > second : first < second, isTrue);
    });
  });

  group('BvTabs', () {
    testBoth('active tab: larger ink label and indicator', (
      tester,
      lang,
    ) async {
      var selected = 0;
      await pumpComponent(
        tester,
        StatefulBuilder(
          builder: (context, setState) => BvTabs(
            labels: const ['Feed', 'Spaces'],
            selectedIndex: selected,
            onSelect: (i) => setState(() => selected = i),
          ),
        ),
        lang: lang,
      );
      final type = isRtl(lang) ? BvType.arabic : BvType.latin;
      expect(textStyle(tester, 'Feed').color, BvColors.textPrimary);
      expect(textStyle(tester, 'Feed').fontSize, type.labelLg.fontSize);
      expect(textStyle(tester, 'Spaces').color, BvColors.textSecondary);
      expect(textStyle(tester, 'Spaces').fontSize, type.labelMd.fontSize);
      expect(
        tester.getSize(find.byKey(const Key('tab-0'))).height,
        BvTabsSpec.height,
      );

      final indicator = find.byKey(const Key('tab-indicator'));
      expect(
        find.descendant(
          of: find.byKey(const Key('tab-0')),
          matching: indicator,
        ),
        findsOneWidget,
      );
      expect(tester.getSize(indicator).height, BvTabsSpec.indicatorHeight);

      await tester.tap(find.text('Spaces'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('tab-1')),
          matching: indicator,
        ),
        findsOneWidget,
      );

      final feed = tester.getCenter(find.text('Feed')).dx;
      final spaces = tester.getCenter(find.text('Spaces')).dx;
      expect(isRtl(lang) ? feed > spaces : feed < spaces, isTrue);
    });
  });
}
