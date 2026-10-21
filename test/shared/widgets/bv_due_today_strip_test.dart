import 'package:buildvibes/core/design/bv_icons.dart';
import 'package:buildvibes/core/design/bv_specs.dart';
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/core/design/daybook_days_specs.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_due_today_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

String _label(String lang) => lookupAppLocalizations(Locale(lang)).daybookToDo;

BvDueTodayStrip _strip(String lang, {VoidCallback? onTap}) =>
    BvDueTodayStrip(label: _label(lang), count: 5, onTap: onTap);

/// The colour of each piece of the strip's one line.
Map<String, Color?> _colours(WidgetTester tester) {
  final text = tester.widget<Text>(
    find.descendant(
      of: find.byType(BvDueTodayStrip),
      matching: find.byType(Text),
    ),
  );
  final colours = <String, Color?>{};
  text.textSpan!.visitChildren((span) {
    if (span is TextSpan && span.text != null) {
      colours[span.text!.trim()] = span.style?.color ?? text.style?.color;
    }
    return true;
  });
  return colours;
}

void main() {
  group('BvDueTodayStrip (review 50 F68)', () {
    testBoth('one line: "To do · 5" in Western digits, no titles', (
      tester,
      lang,
    ) async {
      await pumpComponent(tester, _strip(lang), lang: lang, scroll: false);
      final words = isRtl(lang) ? 'مطلوب منك · 5' : 'To do · 5';
      expect(find.text(words), findsOneWidget);
      expect(tester.widget<Text>(find.byType(Text)).maxLines, 1);
      expect(
        tester.getSize(find.byType(BvDueTodayStrip)).height,
        greaterThanOrEqualTo(BvDueTodaySpec.minHeight),
      );
    });

    testBoth('no tinted band: the page, with a hairline under it', (
      tester,
      lang,
    ) async {
      await pumpComponent(tester, _strip(lang), lang: lang, scroll: false);
      final box = decorationOf(
        tester,
        find.descendant(
          of: find.byType(BvDueTodayStrip),
          matching: find.byType(Container),
        ),
      );
      expect(box.color, BvColors.surfaceApp);
      final border = box.border! as Border;
      expect(border.bottom.color, BvColors.borderSubtle);
      expect(border.bottom.width, BvStroke.thin);
      expect(border.top, BorderSide.none);
    });

    testBoth('the calendar and "To do" in the action colour, the count in '
        'ink, › in grey', (tester, lang) async {
      await pumpComponent(tester, _strip(lang), lang: lang, scroll: false);
      final calendar = tester.widget<Icon>(find.byIcon(BvIcons.month));
      expect(calendar.size, BvDueTodaySpec.icon);
      expect(calendar.color, BvColors.iconAction);
      final colours = _colours(tester);
      expect(colours[_label(lang)], BvColors.textAction);
      expect(colours['· 5'], BvColors.textPrimary);
      final caret = tester.widget<Icon>(find.byIcon(BvIcons.caretForward));
      expect(caret.size, BvDueTodaySpec.caret);
      expect(caret.color, BvColors.iconSecondary);
      expect(caret.icon!.matchTextDirection, isTrue);
    });

    testBoth('mirrored: the calendar 20 from the start, › at the end', (
      tester,
      lang,
    ) async {
      await pumpComponent(tester, _strip(lang), lang: lang, scroll: false);
      final strip = tester.getRect(find.byType(BvDueTodayStrip));
      final icon = tester.getRect(find.byIcon(BvIcons.month));
      final caret = tester.getRect(find.byIcon(BvIcons.caretForward));
      if (isRtl(lang)) {
        expect(strip.right - icon.right, BvDueTodaySpec.paddingStart);
        expect(caret.left - strip.left, BvDueTodaySpec.paddingEnd);
      } else {
        expect(icon.left - strip.left, BvDueTodaySpec.paddingStart);
        expect(strip.right - caret.right, BvDueTodaySpec.paddingEnd);
      }
    });

    testBoth('the whole line is tapped', (tester, lang) async {
      var taps = 0;
      await pumpComponent(
        tester,
        _strip(lang, onTap: () => taps++),
        lang: lang,
        scroll: false,
      );
      await tester.tap(find.byIcon(BvIcons.caretForward));
      await tester.tap(find.byType(BvDueTodayStrip));
      expect(taps, 2);
    });
  });
}
