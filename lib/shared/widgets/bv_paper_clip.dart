import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../core/design/around_specs.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_paper_specs.dart';

/// Spec §4: the paper clip on a slip that needs you. Two rounded
/// rectangles in the action colour, tilted +12° in left to right and
/// mirrored in right to left. [BvSlip] places it over its top end corner.
///
/// [BvPaperClip.row] is the small clip at the end of a Needs-you row
/// (2544:35089): one rounded rectangle.
class BvPaperClip extends StatelessWidget {
  const BvPaperClip({super.key}) : row = false;

  const BvPaperClip.row({super.key}) : row = true;

  final bool row;

  /// The tilt in radians for [direction]: clockwise in left to right.
  static double tiltFor(TextDirection direction) {
    const radians = BvPaperClipSpec.tiltDegrees * math.pi / 180;
    return direction == TextDirection.rtl ? -radians : radians;
  }

  @override
  Widget build(BuildContext context) => Transform.rotate(
    key: const Key('paper-clip-tilt'),
    angle: tiltFor(Directionality.of(context)),
    child: CustomPaint(
      size: row ? BvNeedsSpec.clip : BvPaperClipSpec.outerSize,
      painter: _ClipPainter(row: row),
    ),
  );
}

class _ClipPainter extends CustomPainter {
  const _ClipPainter({required this.row});

  final bool row;

  @override
  void paint(Canvas canvas, Size size) {
    Paint stroke(double width) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = BvColors.actionPrimary;
    if (row) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Offset.zero & BvNeedsSpec.clip,
          const Radius.circular(BvNeedsSpec.clipRadius),
        ),
        stroke(BvStroke.thick),
      );
      return;
    }
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          Offset.zero & BvPaperClipSpec.outerSize,
          const Radius.circular(BvPaperClipSpec.outerRadius),
        ),
        stroke(BvPaperClipSpec.outerStroke),
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          BvPaperClipSpec.innerOffset & BvPaperClipSpec.innerSize,
          const Radius.circular(BvPaperClipSpec.innerRadius),
        ),
        stroke(BvPaperClipSpec.innerStroke),
      );
  }

  @override
  bool shouldRepaint(_ClipPainter oldDelegate) => oldDelegate.row != row;
}
