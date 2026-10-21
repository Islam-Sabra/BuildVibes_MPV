import 'package:buildvibes/core/design/bv_icons.dart';
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/core/design/daybook_days_specs.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_due_today_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

BvDueTodayStrip _docket(
  String lang, {
  int n = 2,
  String oldest = 'Paint Room 3',
  VoidCallback? onTap,
}) {
  final l10n = _l10n(lang);
  return BvDueTodayStrip(
    title: l10n.daybookDocketTitle(n),
    oldest: oldest,
    rest:
        ' · ${l10n.daybookDocketFrom(isRtl(lang) ? 'الأحد' : 'Sun')}'
        '${l10n.daybookDocketRest(n - 1)}',
    onTap: onTap,
  );
}

void main() {
  group('BvDueTodayStrip, the To do docket (review 50 F68b)', () {
    test('the first line names the work, with its number (plurals)', () {
      final en = _l10n('en');
      expect(en.daybookDocketTitle(1), '1 work item for you');
      expect(en.daybookDocketTitle(2), '2 work items for you');
      expect(en.daybookDocketTitle(12), '12 work items for you');
      final ar = _l10n('ar');
      expect(ar.daybookDocketTitle(1), 'بند عمل واحد لك');
      expect(ar.daybookDocketTitle(2), 'بندا عمل لك');
      expect(ar.daybookDocketTitle(3), '3 بنود عمل لك');
      expect(ar.daybookDocketTitle(10), '10 بنود عمل لك');
      expect(ar.daybookDocketTitle(12), '12 بند عمل لك');
    });

    test('the second line ends with how many more', () {
      final en = _l10n('en');
      expect(en.daybookDocketRest(0), '');
      expect(en.daybookDocketRest(1), ', and 1 more');
      expect(en.daybookDocketRest(2), ', and 2 more');
      final ar = _l10n('ar');
      expect(ar.daybookDocketRest(0), '');
      expect(ar.daybookDocketRest(1), '، وبند آخر');
      expect(ar.daybookDocketRest(2), '، و2 بنود أخرى');
    });

    testBoth('a card 62 high, 16 from the edges, radius 8, a subtle border', (
      tester,
      lang,
    ) async {
      await pumpComponent(tester, _docket(lang), lang: lang, scroll: false);
      final card = find.descendant(
        of: find.byType(BvDueTodayStrip),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).color ==
                  BvColors.surfaceElevated,
        ),
      );
      final box = tester.widget<Container>(card).decoration! as BoxDecoration;
      expect(box.borderRadius, BvDueTodaySpec.radius);
      expect((box.border! as Border).top.color, BvColors.borderSubtle);
      final rect = tester.getRect(card);
      expect(rect.height, greaterThanOrEqualTo(BvDueTodaySpec.minHeight));
      final outer = tester.getRect(find.byType(BvDueTodayStrip));
      expect(rect.left - outer.left, BvDueTodaySpec.outer.start);
      expect(outer.right - rect.right, BvDueTodaySpec.outer.end);
    });

    testBoth('the stub: brand-soft, the list-checks icon in the action '
        'colour, then the perforation; the stub at the start', (
      tester,
      lang,
    ) async {
      await pumpComponent(tester, _docket(lang), lang: lang, scroll: false);
      final icon = tester.widget<Icon>(find.byIcon(BvIcons.workItems));
      expect(icon.size, BvDueTodaySpec.icon);
      expect(icon.color, BvColors.iconAction);
      expect(
        tester.getSize(find.byKey(const Key('to-do-stub'))).width,
        BvDueTodaySpec.stubWidth,
      );
      expect(find.byKey(const Key('to-do-perforation')), findsOneWidget);
      final stubRect = tester.getRect(find.byKey(const Key('to-do-stub')));
      final caret = tester.getRect(find.byIcon(BvIcons.caretForward));
      // Start and end swap in right to left.
      expect(
        isRtl(lang) ? stubRect.left > caret.left : stubRect.left < caret.left,
        isTrue,
      );
    });

    testBoth('two lines: what it is in ink, the oldest item in grey; the '
        'caret grey and mirrored', (tester, lang) async {
      await pumpComponent(tester, _docket(lang), lang: lang, scroll: false);
      final l10n = _l10n(lang);
      final title = tester.widget<Text>(find.text(l10n.daybookDocketTitle(2)));
      expect(title.style?.color, BvColors.textPrimary);
      final oldest = tester.widget<Text>(find.byKey(const Key('to-do-oldest')));
      // The test font is wide: the line may be cut as one, the title first.
      expect(oldest.data, startsWith('Paint Room 3'));
      expect(oldest.style?.color, BvColors.textSecondary);
      final caret = tester.widget<Icon>(find.byIcon(BvIcons.caretForward));
      expect(caret.color, BvColors.iconSecondary);
      expect(caret.icon!.matchTextDirection, isTrue);
    });

    testBoth('a long title is cut with …, and "and 1 more" still shows', (
      tester,
      lang,
    ) async {
      final long = List.filled(12, 'Cable tray hangers').join(' ');
      await pumpComponent(
        tester,
        _docket(lang, oldest: long),
        lang: lang,
        scroll: false,
      );
      final oldest = tester.widget<Text>(find.byKey(const Key('to-do-oldest')));
      expect(oldest.maxLines, 1);
      expect(oldest.overflow, TextOverflow.ellipsis);
      final rest = _l10n(lang).daybookDocketRest(1);
      expect(find.textContaining(rest), findsOneWidget);
      final restRect = tester.getRect(find.textContaining(rest));
      final card = tester.getRect(find.byType(BvDueTodayStrip));
      expect(
        restRect.left >= card.left && restRect.right <= card.right,
        isTrue,
      );
    });

    testBoth('the whole docket is tapped', (tester, lang) async {
      var taps = 0;
      await pumpComponent(
        tester,
        _docket(lang, onTap: () => taps++),
        lang: lang,
        scroll: false,
      );
      await tester.tap(find.byIcon(BvIcons.caretForward));
      await tester.tap(find.byKey(const Key('to-do-stub')));
      expect(taps, 2);
    });
  });
}
