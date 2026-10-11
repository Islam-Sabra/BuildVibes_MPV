import 'package:buildvibes/core/design/bv_icons.dart';
import 'package:buildvibes/core/design/bv_specs.dart';
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/shared/widgets/bv_choice_card.dart';
import 'package:buildvibes/shared/widgets/bv_controls.dart';
import 'package:buildvibes/shared/widgets/bv_list_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

void main() {
  group('BvListRow', () {
    testBoth('chevron row: title, subtitle, leading tile, mirrored chevron', (
      tester,
      lang,
    ) async {
      var taps = 0;
      await pumpComponent(
        tester,
        BvListRow(
          leading: const BvRowIcon(BvIcons.language),
          title: 'Language',
          subtitle: 'English',
          onTap: () => taps++,
        ),
        lang: lang,
      );
      expect(
        tester.getSize(find.byType(BvListRow)).height,
        greaterThanOrEqualTo(BvListRowSpec.minHeight),
      );
      expect(textStyle(tester, 'English').color, BvColors.textSecondary);
      expect(
        tester.getSize(find.byType(BvRowIcon)),
        const Size.square(BvListRowSpec.leadingSize),
      );
      final chevron = tester.widget<Icon>(find.byIcon(BvIcons.caretForward));
      expect(chevron.icon!.matchTextDirection, isTrue);
      expect(chevron.color, BvColors.iconSecondary);

      final tile = tester.getCenter(find.byType(BvRowIcon)).dx;
      final arrow = tester.getCenter(find.byIcon(BvIcons.caretForward)).dx;
      expect(isRtl(lang) ? tile > arrow : tile < arrow, isTrue);

      await tester.tap(find.text('Language'));
      expect(taps, 1);
    });

    testBoth('value, toggle and none trailing', (tester, lang) async {
      var on = false;
      await pumpComponent(
        tester,
        StatefulBuilder(
          builder: (context, setState) => BvListGroup(
            rows: [
              const BvListRow(
                title: 'Language',
                trailing: BvRowTrailing.value('English'),
              ),
              BvListRow(
                title: 'Alerts',
                trailing: BvRowTrailing.toggle(
                  value: on,
                  onChanged: (v) => setState(() => on = v),
                ),
              ),
              const BvListRow(title: 'Help', trailing: BvRowTrailing.none()),
            ],
          ),
        ),
        lang: lang,
      );
      expect(find.text('English'), findsOneWidget);
      expect(find.byIcon(BvIcons.caretForward), findsOneWidget);
      expect(find.byType(BvSwitch), findsOneWidget);
      // Tapping anywhere on a switch row toggles it.
      await tester.tap(find.text('Alerts'));
      await tester.pumpAndSettle();
      expect(on, isTrue);
      expect(find.byType(Divider), findsNWidgets(2));
    });

    testBoth('dividers start after the leading tile', (tester, lang) async {
      await pumpComponent(
        tester,
        const BvListGroup(
          rows: [
            BvListRow(leading: BvRowIcon(BvIcons.lock), title: 'A'),
            BvListRow(title: 'B'),
          ],
        ),
        lang: lang,
      );
      final divider = find.byType(Divider);
      final rect = tester.getRect(divider);
      final group = tester.getRect(find.byType(BvListGroup));
      final inset = isRtl(lang)
          ? group.right - rect.right
          : rect.left - group.left;
      expect(inset, BvListRowSpec.dividerInset);
    });
  });

  group('BvChoiceCard', () {
    testBoth('one choice is selected; tapping picks another', (
      tester,
      lang,
    ) async {
      var value = 'a';
      await pumpComponent(
        tester,
        StatefulBuilder(
          builder: (context, setState) => BvChoiceList<String>(
            value: value,
            options: const [
              BvChoiceOption(value: 'a', title: 'Everyone', description: 'All'),
              BvChoiceOption(value: 'b', title: 'Only me'),
            ],
            onChanged: (v) => setState(() => value = v),
          ),
        ),
        lang: lang,
      );
      RoundedRectangleBorder shape(String title) =>
          tester
                  .widget<Material>(
                    find
                        .ancestor(
                          of: find.text(title),
                          matching: find.byType(Material),
                        )
                        .first,
                  )
                  .shape!
              as RoundedRectangleBorder;

      expect(
        materialColor(tester, find.text('Everyone')),
        BvColors.surfaceBrandSoft,
      );
      expect(shape('Everyone').side.color, BvColors.borderSelected);
      expect(shape('Everyone').side.width, BvStroke.thick);
      expect(
        materialColor(tester, find.text('Only me')),
        BvColors.surfaceElevated,
      );
      expect(shape('Only me').side.width, BvStroke.thin);
      expect(textStyle(tester, 'All').color, BvColors.textSecondary);

      await tester.tap(find.text('Only me'));
      await tester.pumpAndSettle();
      expect(value, 'b');
      expect(shape('Only me').side.color, BvColors.borderSelected);

      // The radio sits at the end.
      final radio = tester.getCenter(find.byType(BvRadio).last).dx;
      final title = tester.getCenter(find.text('Only me')).dx;
      expect(isRtl(lang) ? radio < title : radio > title, isTrue);
    });
  });
}
