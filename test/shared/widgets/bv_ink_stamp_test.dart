import 'dart:math' as math;

import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/core/design/daybook_paper_specs.dart';
import 'package:buildvibes/shared/widgets/bv_stamp.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

/// The tilt of the stamp around [label], in degrees.
double _angleOf(WidgetTester tester, String label) {
  final m = tester
      .widget<Transform>(
        find.ancestor(
          of: find.text(label),
          matching: find.byKey(const Key('ink-stamp-tilt')),
        ),
      )
      .transform
      .storage;
  return math.atan2(m[1], m[0]) * 180 / math.pi;
}

void main() {
  group('BvInkStamp', () {
    testBoth('white fill; text and border share the tone colour', (
      tester,
      lang,
    ) async {
      await pumpComponent(
        tester,
        const Wrap(
          children: [
            BvInkStamp(label: 'DONE'),
            BvInkStamp(label: 'CHECKED', tone: BvInkStampTone.positive),
            BvInkStamp(label: 'CANCELLED', tone: BvInkStampTone.muted),
            BvInkStamp(label: 'SENT BACK', tone: BvInkStampTone.destructive),
          ],
        ),
        lang: lang,
      );
      for (final (label, color) in [
        ('DONE', BvColors.textAction),
        ('CHECKED', BvColors.textPositive),
        ('CANCELLED', BvColors.textSecondary),
        ('SENT BACK', BvColors.textDestructive),
      ]) {
        expect(textStyle(tester, label).color, color);
        final box = decorationOf(
          tester,
          find.ancestor(of: find.text(label), matching: find.byType(Container)),
        );
        expect(box.color, BvColors.surfaceElevated);
        expect((box.border! as Border).top.color, color);
      }
    });

    testBoth('each size has its border, type, radius and opacity', (
      tester,
      lang,
    ) async {
      await pumpComponent(
        tester,
        const Wrap(
          children: [
            BvInkStamp(label: 'XS', size: BvInkStampSize.xs),
            BvInkStamp(label: 'SM', size: BvInkStampSize.sm),
            BvInkStamp(label: 'MD'),
            BvInkStamp(label: 'LG', size: BvInkStampSize.lg),
          ],
        ),
        lang: lang,
      );
      for (final (label, border, font, opacity) in [
        ('XS', BvInkStampSpec.borderXs, BvInkStampSpec.fontSizeXs, 1.0),
        ('SM', BvInkStampSpec.borderSm, BvInkStampSpec.fontSizeSm, 1.0),
        ('MD', BvInkStampSpec.borderMd, BvInkStampSpec.fontSizeMd, 0.9),
        ('LG', BvInkStampSpec.borderLg, BvInkStampSpec.fontSizeLg, 0.9),
      ]) {
        final box = decorationOf(
          tester,
          find.ancestor(of: find.text(label), matching: find.byType(Container)),
        );
        expect((box.border! as Border).top.width, border);
        expect(
          box.borderRadius,
          label == 'XS' ? BvInkStampSpec.radiusXs : BvInkStampSpec.radius,
        );
        expect(textStyle(tester, label).fontSize, font);
        final fade = tester.widget<Opacity>(
          find.ancestor(of: find.text(label), matching: find.byType(Opacity)),
        );
        expect(fade.opacity, opacity);
      }
    });

    testBoth('Latin is ExtraBold and tracked; Arabic is Bold, untracked', (
      tester,
      lang,
    ) async {
      await pumpComponent(
        tester,
        const Wrap(
          children: [
            BvInkStamp(label: 'MD'),
            BvInkStamp(label: 'XS', size: BvInkStampSize.xs),
          ],
        ),
        lang: lang,
      );
      final md = textStyle(tester, 'MD');
      final xs = textStyle(tester, 'XS');
      if (isRtl(lang)) {
        expect(md.fontWeight, FontWeight.w700);
        expect(md.letterSpacing, 0);
        expect(xs.letterSpacing, 0);
      } else {
        expect(md.fontWeight, FontWeight.w800);
        expect(md.letterSpacing, closeTo(2.1, 0.001));
        expect(xs.letterSpacing, closeTo(1.2, 0.001));
      }
    });

    testBoth('the large stamp carries a second line; others do not', (
      tester,
      lang,
    ) async {
      await pumpComponent(
        tester,
        const Column(
          children: [
            BvInkStamp(
              label: 'DONE',
              size: BvInkStampSize.lg,
              subline: 'OMAR H · 09:40',
            ),
            BvInkStamp(label: 'MD', subline: 'IGNORED'),
          ],
        ),
        lang: lang,
      );
      final sub = textStyle(tester, 'OMAR H · 09:40');
      expect(sub.fontSize, BvInkStampSpec.sublineFontSize);
      expect(sub.fontWeight, FontWeight.w700);
      expect(sub.letterSpacing, isRtl(lang) ? 0 : closeTo(0.8, 0.001));
      expect(find.text('IGNORED'), findsNothing);
    });

    testBoth('tilts clockwise in LTR and mirrors in RTL', (tester, lang) async {
      await pumpComponent(
        tester,
        const Wrap(
          children: [
            BvInkStamp(label: 'XS', size: BvInkStampSize.xs),
            BvInkStamp(label: 'SM', size: BvInkStampSize.sm),
            BvInkStamp(label: 'MD'),
            BvInkStamp(label: 'LG', size: BvInkStampSize.lg),
          ],
        ),
        lang: lang,
      );
      final sign = isRtl(lang) ? -1 : 1;
      for (final (label, degrees) in [
        ('XS', BvInkStampSpec.tiltXs),
        ('SM', BvInkStampSpec.tiltSm),
        ('MD', BvInkStampSpec.tiltMd),
        ('LG', BvInkStampSpec.tiltLg),
      ]) {
        expect(_angleOf(tester, label), closeTo(sign * degrees, 0.001));
      }
      expect(BvInkStampSpec.tiltLg, 9);
      expect(BvInkStampSpec.tiltMd, 7);
      expect(BvInkStampSpec.tiltXs, 5);
    });

    testBoth('lands from scale 1.3, more tilt and faint ink in 180 ms', (
      tester,
      lang,
    ) async {
      final shown = ValueNotifier(false);
      addTearDown(shown.dispose);
      await pumpComponent(
        tester,
        ValueListenableBuilder(
          valueListenable: shown,
          builder: (_, show, _) => show
              ? const BvInkStamp(
                  label: 'CHECKED',
                  size: BvInkStampSize.lg,
                  land: true,
                )
              : const SizedBox(),
        ),
        lang: lang,
      );
      shown.value = true;
      await tester.pump();
      final opacity = find.byKey(const Key('ink-stamp-opacity'));
      final sign = isRtl(lang) ? -1 : 1;
      expect(
        tester.widget<Opacity>(opacity).opacity,
        closeTo(BvInkStampSpec.landOpacity, 0.001),
      );
      expect(_angleOf(tester, 'CHECKED'), closeTo(sign * 15, 0.001));
      final scale = tester.widget<Transform>(
        find.descendant(
          of: find.byKey(const Key('ink-stamp-tilt')),
          matching: find.byType(Transform),
        ),
      );
      expect(
        scale.transform.storage[0],
        closeTo(BvInkStampSpec.landScale, 0.001),
      );

      await tester.pump(BvInkStampSpec.landDuration);
      expect(tester.widget<Opacity>(opacity).opacity, closeTo(0.9, 0.001));
      expect(_angleOf(tester, 'CHECKED'), closeTo(sign * 9, 0.001));
    });
  });
}
