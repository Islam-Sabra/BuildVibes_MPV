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
  bool home = false,
}) => pumpComponent(
  tester,
  BvDaybookSpine(
    home: home,
    children: [
      BvSpineEntry(time: time, dot: dot, home: home, child: _slip),
      BvSpineEntry(
        time: '10:05',
        home: home,
        child: const SizedBox(height: 40),
      ),
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
    testBoth('a minimum height: the line runs it all, entries at the bottom', (
      tester,
      lang,
    ) async {
      await pumpComponent(
        tester,
        const SingleChildScrollView(
          child: BvDaybookSpine(
            minHeight: 600,
            children: [BvSpineEntry(time: '08:14', child: _slip)],
          ),
        ),
        lang: lang,
        scroll: false,
      );
      final spine = tester.getRect(find.byType(BvDaybookSpine));
      final line = tester.getRect(find.byKey(const Key('daybook-spine-line')));
      final slip = tester.getRect(find.byKey(const Key('slip')));
      expect(spine.height, 600);
      expect(line.height, 600);
      expect(spine.bottom - slip.bottom, BvSpineSpec.paddingBottom);
    });

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

    testBoth('Home has a 48 time column', (tester, lang) async {
      await _pump(tester, lang, home: true);
      expect(_fromStart(tester, lang), BvSpineSpec.homeTimeColumn);
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
      const BvSpineDotPainter(BvSpineDot.needsYou).fill,
      BvColors.actionPrimary,
    );
    expect(
      const BvSpineDotPainter(BvSpineDot.checked).fill,
      BvColors.textPositive,
    );
    for (final dot in [
      BvSpineDot.quiet,
      BvSpineDot.needsYou,
      BvSpineDot.checked,
    ]) {
      expect(BvSpineDotPainter(dot).stroke, BvColors.surfaceApp);
    }
    const now = BvSpineDotPainter(BvSpineDot.now);
    expect(now.fill, BvColors.surfaceApp);
    expect(now.stroke, BvColors.actionPrimary);
  });
}
