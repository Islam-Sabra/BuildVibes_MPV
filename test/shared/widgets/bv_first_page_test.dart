import 'package:buildvibes/core/design/bv_icons.dart';
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/shared/widgets/bv_first_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

void main() {
  group('BvFirstPage', () {
    testBoth('title, body and actions; the first one is primary', (
      tester,
      lang,
    ) async {
      final taps = <String>[];
      await pumpComponent(
        tester,
        BvFirstPage(
          title: 'The first page of your daybook',
          body: 'Everything your team posts will hang here, day by day.',
          actions: [
            BvFirstPageAction(
              icon: BvIcons.confirmed,
              label: 'Post the first work item',
              primary: true,
              onTap: () => taps.add('post'),
            ),
            BvFirstPageAction(
              icon: BvIcons.info,
              label: 'Pin an announcement',
              onTap: () => taps.add('pin'),
            ),
          ],
        ),
        lang: lang,
      );
      final title = tester.widget<Text>(
        find.text('The first page of your daybook'),
      );
      expect(title.textAlign, TextAlign.center);
      expect(
        textStyle(
          tester,
          'Everything your team posts will hang here, day by day.',
        ).color,
        BvColors.textSecondary,
      );

      expect(
        materialColor(tester, find.text('Post the first work item')),
        BvColors.actionPrimary,
      );
      expect(
        textStyle(tester, 'Post the first work item').color,
        BvColors.actionPrimaryForeground,
      );
      expect(
        materialColor(tester, find.text('Pin an announcement')),
        BvColors.surfaceSubtle,
      );
      expect(
        textStyle(tester, 'Pin an announcement').color,
        BvColors.textPrimary,
      );

      // The icon leads, at the start.
      final icon = tester.getCenter(find.byIcon(BvIcons.info)).dx;
      final label = tester.getCenter(find.text('Pin an announcement')).dx;
      expect(isRtl(lang) ? icon > label : icon < label, isTrue);

      await tester.tap(find.text('Post the first work item'));
      await tester.tap(find.text('Pin an announcement'));
      expect(taps, ['post', 'pin']);
    });
  });
}
