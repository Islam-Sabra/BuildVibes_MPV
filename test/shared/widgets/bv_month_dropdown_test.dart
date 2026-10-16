import 'package:buildvibes/core/design/bv_icons.dart';
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/core/design/daybook_days_specs.dart';
import 'package:buildvibes/shared/widgets/bv_month_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

Future<void> _pump(
  WidgetTester tester,
  String lang, {
  int firstWeekday = 0,
  ValueChanged<DateTime>? onDay,
  VoidCallback? onPrevious,
  VoidCallback? onNext,
}) => pumpComponent(
  tester,
  BvMonthDropdown(
    month: DateTime(2026, 10),
    today: DateTime(2026, 10, 15),
    firstWeekday: firstWeekday,
    postDays: const {4, 15},
    dueDays: const {16},
    postsLabel: 'Posts',
    dueLabel: 'Something due',
    onDay: onDay,
    onPrevious: onPrevious,
    onNext: onNext,
  ),
  lang: lang,
  scroll: false,
);

BoxDecoration _circle(WidgetTester tester, int day) =>
    decorationOf(tester, find.byKey(Key('month-circle-$day')));

void main() {
  group('BvMonthDropdown', () {
    testBoth('month name from intl, legend and day states', (
      tester,
      lang,
    ) async {
      await _pump(tester, lang);
      expect(
        find.text(lang == 'ar' ? 'أكتوبر 2026' : 'October 2026'),
        findsOne,
      );
      expect(find.text('Posts'), findsOneWidget);
      expect(find.text('Something due'), findsOneWidget);

      // Today is filled with a white number.
      expect(_circle(tester, 15).color, BvColors.actionPrimary);
      expect(textStyle(tester, '15').color, BvColors.actionPrimaryForeground);
      // Something due: a ring, a quiet number.
      expect(_circle(tester, 16).border!.top.color, BvColors.actionPrimary);
      expect(_circle(tester, 16).border!.top.width, BvMonthDropdownSpec.ring);
      expect(textStyle(tester, '16').color, BvColors.textSecondary);
      // Past days are primary, later days secondary.
      expect(textStyle(tester, '14').color, BvColors.textPrimary);
      expect(textStyle(tester, '20').color, BvColors.textSecondary);
      // Posts: a dot under the day.
      expect(find.byKey(const Key('month-dot-4')), findsOneWidget);
      expect(find.byKey(const Key('month-dot-5')), findsNothing);
    });

    testBoth('the grid starts on the given weekday, from the start side', (
      tester,
      lang,
    ) async {
      // 1 October 2026 is a Thursday.
      await _pump(tester, lang);
      final grid = tester.getRect(find.byType(BvMonthDropdown));
      final one = tester.getCenter(find.byKey(const Key('month-day-1')));
      final four = tester.getCenter(find.byKey(const Key('month-day-4')));
      // Sunday 4 starts the second row, at the start side.
      expect(four.dy, greaterThan(one.dy));
      final column = (grid.width - 2 * BvMonthDropdownSpec.padding) / 7;
      final startEdge = isRtl(lang)
          ? grid.right - BvMonthDropdownSpec.padding
          : grid.left + BvMonthDropdownSpec.padding;
      expect((four.dx - startEdge).abs(), closeTo(column / 2, 0.5));
      // Thursday is the fifth column.
      expect((one.dx - startEdge).abs(), closeTo(column * 4.5, 0.5));

      // Saturday first: Thursday 1 moves to the sixth column.
      await _pump(tester, lang, firstWeekday: 6);
      final moved = tester.getCenter(find.byKey(const Key('month-day-1')));
      expect((moved.dx - startEdge).abs(), closeTo(column * 5.5, 0.5));
    });

    testBoth('carets mirror; days and carets call back', (tester, lang) async {
      DateTime? picked;
      var previous = 0, next = 0;
      await _pump(
        tester,
        lang,
        onDay: (d) => picked = d,
        onPrevious: () => previous++,
        onNext: () => next++,
      );
      expect(BvIcons.caretBack.matchTextDirection, isTrue);
      expect(BvIcons.caretForward.matchTextDirection, isTrue);
      final back = tester.getCenter(find.byKey(const Key('month-previous')));
      final forward = tester.getCenter(find.byKey(const Key('month-next')));
      expect(isRtl(lang) ? back.dx > forward.dx : back.dx < forward.dx, isTrue);

      await tester.tap(find.byKey(const Key('month-previous')));
      await tester.tap(find.byKey(const Key('month-next')));
      await tester.tap(find.text('18'));
      expect((previous, next), (1, 1));
      expect(picked, DateTime(2026, 10, 18));
    });
  });
}
