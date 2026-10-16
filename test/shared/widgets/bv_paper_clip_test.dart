import 'dart:math' as math;

import 'package:buildvibes/core/design/daybook_paper_specs.dart';
import 'package:buildvibes/shared/widgets/bv_paper_clip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

void main() {
  group('BvPaperClip', () {
    testBoth('is 14 × 34, tilted +12° in LTR and −12° in RTL', (
      tester,
      lang,
    ) async {
      await pumpComponent(
        tester,
        const Center(child: BvPaperClip()),
        lang: lang,
      );
      expect(
        tester.getSize(
          find.descendant(
            of: find.byType(BvPaperClip),
            matching: find.byType(CustomPaint),
          ),
        ),
        BvPaperClipSpec.outerSize,
      );
      final m = tester
          .widget<Transform>(find.byKey(const Key('paper-clip-tilt')))
          .transform
          .storage;
      final degrees = math.atan2(m[1], m[0]) * 180 / math.pi;
      expect(degrees, closeTo(isRtl(lang) ? -12 : 12, 0.001));
    });
  });
}
