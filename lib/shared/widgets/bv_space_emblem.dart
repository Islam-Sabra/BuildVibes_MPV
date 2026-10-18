import 'package:flutter/material.dart';

import '../../core/design/around_specs.dart';
import '../../core/design/bv_tokens.dart';

/// The Space emblem (Figma Space/Plan 2307:68648): a floor plan, people as
/// dots and an open doorway; the orange dot is you. [height] is 40 in the
/// Space header and 56 in Space info; the width keeps the 72 × 56 shape.
/// The plan mirrors in right to left, so "you" stay on the start side.
class BvSpaceEmblem extends StatelessWidget {
  const BvSpaceEmblem({super.key, this.height = BvSpaceEmblemSpec.header});

  final double height;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return ExcludeSemantics(
      child: SizedBox(
        key: const Key('space-emblem'),
        height: height,
        width: height * BvSpaceEmblemSpec.width / BvSpaceEmblemSpec.height,
        child: CustomPaint(painter: _PlanPainter(mirrored: rtl)),
      ),
    );
  }
}

class _PlanPainter extends CustomPainter {
  const _PlanPainter({required this.mirrored});

  final bool mirrored;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.height / BvSpaceEmblemSpec.height;
    canvas.save();
    if (mirrored) {
      canvas
        ..translate(size.width, 0)
        ..scale(-1, 1);
    }
    canvas.scale(scale);
    final tile = RRect.fromRectAndRadius(
      Offset.zero &
          const Size(BvSpaceEmblemSpec.width, BvSpaceEmblemSpec.height),
      const Radius.circular(BvSpaceEmblemSpec.radius),
    );
    canvas
      ..drawRRect(tile, Paint()..color = BvColors.surfaceSubtle)
      ..drawRect(
        BvSpaceEmblemSpec.room,
        Paint()
          ..color = BvColors.iconPrimary
          ..style = PaintingStyle.stroke
          ..strokeWidth = BvSpaceEmblemSpec.roomStroke,
      )
      // The doorway is a gap in the wall.
      ..drawRect(
        BvSpaceEmblemSpec.doorway,
        Paint()..color = BvColors.surfaceSubtle,
      )
      ..drawCircle(
        BvSpaceEmblemSpec.you,
        BvSpaceEmblemSpec.dot,
        Paint()..color = BvColors.actionPrimary,
      );
    final ink = Paint()..color = BvColors.iconPrimary;
    for (final o in BvSpaceEmblemSpec.others) {
      canvas.drawCircle(o, BvSpaceEmblemSpec.dot, ink);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PlanPainter old) => old.mirrored != mirrored;
}
