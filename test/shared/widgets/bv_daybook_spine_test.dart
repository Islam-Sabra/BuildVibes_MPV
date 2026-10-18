import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/core/design/daybook_days_specs.dart';
import 'package:buildvibes/shared/widgets/bv_daybook_spine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

const _slip = SizedBox(key: Key('slip'), height: 80);

Future<void> _pump(
  WidgetTester tester,
  String lang, {
  BvSpineDot dot = BvSpineDot.quiet,
  String time = '08:14',
}) => pumpComponent(
  tester,
  BvDaybookSpine(
    children: [
      BvSpineEntry(time: time, dot: dot, child: _slip),
      const BvSpineEntry(time: '10:05', child: SizedBox(height: 40)),
    ],
  ),
  lang: lang,
  scroll: false,
);

/// The spine's distance from the start edge of the screen.
double _fromStart(WidgetTester tester, String lang) {
  final line = tester.getRect(find.byKey(const Key('daybook-spine-line')));
  final screen = tester.getRect(find.byType(BvDaybookSpine));
  return isRtl(lang)
      ? screen.right - line.center.dx
      : line.center.dx - screen.left;
}

void main() {
  group('BvDaybookSpine', () {
    testBoth('the line sits at the start, the slip to its end', (
      tester,
      lang,
    ) async {
      await _pump(tester, lang);
      final line = tester.getRect(find.byKey(const Key('daybook-spine-line')));
      final slip = tester.getRect(find.byKey(const Key('slip')));
      expect(line.width, BvSpineSpec.lineWidth);
      expect(_fromStart(tester, lang), BvSpineSpec.timeColumn);
      expect(
        isRtl(lang) ? slip.right < line.left : slip.left > line.right,
        isTrue,
      );

      // The time label ends 12 before the spine; the dot is centred on it.
      final label = tester.getRect(find.text('08:14'));
      final dot = tester.getRect(find.byKey(const Key('spine-dot')).first);
      expect(dot.center.dx, closeTo(line.center.dx, 0.01));
      final labelEnd = isRtl(lang) ? label.left : label.right;
      final spineSide = isRtl(lang) ? 1 : -1;
      expect(
        labelEnd,
        closeTo(line.center.dx + spineSide * BvSpineSpec.labelToSpine, 0.5),
      );
      expect(dot.top - slip.top, BvSpineSpec.dotTop);
      expect(dot.width, BvSpineSpec.dotSize);
    });

    testBoth('entries are 22 apart', (tester, lang) async {
      await _pump(tester, lang);
      final entries = find.byType(BvSpineEntry);
      final a = tester.getRect(entries.at(0));
      final b = tester.getRect(entries.at(1));
      expect(b.top - a.bottom, BvSpineSpec.entryGap);
    });

    testBoth('F15: a 12-hour time puts its part of the day on a smaller '
        'line under it, inside the column', (tester, lang) async {
      await pumpComponent(
        tester,
        BvDaybookSpine(
          children: [
            BvSpineEntry(
              time: '11:58',
              period: isRtl(lang) ? 'مساءً' : 'pm',
              child: _slip,
            ),
          ],
        ),
        lang: lang,
        scroll: false,
      );
      final time = tester.getRect(find.byKey(const Key('spine-time')));
      final period = tester.getRect(find.byKey(const Key('spine-period')));
      expect(period.top, greaterThanOrEqualTo(time.bottom));
      double size(Key k) => tester.widget<Text>(find.byKey(k)).style!.fontSize!;
      expect(
        size(const Key('spine-period')),
        lessThan(size(const Key('spine-time'))),
      );
      // Both end at the label's end, and neither is wider than the column
      // before the spine.
      const column = BvSpineSpec.timeColumn - BvSpineSpec.labelToSpine;
      final screen = tester.getRect(find.byType(BvDaybookSpine));
      for (final r in [time, period]) {
        final fromStart = isRtl(lang)
            ? screen.right - r.left
            : r.right - screen.left;
        expect(fromStart, lessThanOrEqualTo(column + 0.5));
        expect(r.width, lessThanOrEqualTo(column));
      }
    });

    testBoth('"Now" is in the action colour', (tester, lang) async {
      await _pump(tester, lang, dot: BvSpineDot.now, time: 'Now');
      expect(textStyle(tester, 'Now').color, BvColors.textAction);
      expect(textStyle(tester, '10:05').color, BvColors.textSecondary);
    });
  });

  test('dot fills, halos and the "Now" ring', () {
    expect(
      const BvSpineDotPainter(BvSpineDot.quiet).fill,
      BvColors.borderDefault,
    );
    expect(
      const BvSpineDotPainter(BvSpineDot.quiet).stroke,
      BvColors.surfaceApp,
    );
    const now = BvSpineDotPainter(BvSpineDot.now);
    expect(now.fill, BvColors.surfaceApp);
    expect(now.stroke, BvColors.actionPrimary);
  });
}
