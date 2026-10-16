import 'package:flutter/material.dart';

import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_days_specs.dart';

/// Where one day ends and the next begins, when scrolling back through the
/// Daybook (spec §7): a dashed line, then the weekday and, at the end, the
/// date. It lies across the full width, over the spine.
class BvDayDivider extends StatelessWidget {
  const BvDayDivider({super.key, required this.weekday, required this.date});

  /// "Thursday".
  final String weekday;

  /// "15 October".
  final String date;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: BvDayDividerSpec.paddingHorizontal,
        end: BvDayDividerSpec.paddingHorizontal,
        top: BvDayDividerSpec.paddingTop,
        bottom: BvDayDividerSpec.paddingBottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BvDayDividerSpec.gap,
        children: [
          const CustomPaint(
            key: Key('day-divider-line'),
            size: Size.fromHeight(BvDayDividerSpec.lineWidth),
            painter: BvDashedLinePainter(),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(
              top: BvDayDividerSpec.rowPaddingTop,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              spacing: BvDayDividerSpec.rowGap,
              children: [
                Expanded(
                  child: Text(
                    weekday,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: type.headingLg,
                  ),
                ),
                Text(
                  date,
                  style: type.bodySm.copyWith(color: BvColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A 1.5 line of 2 px dashes every 7 px, with 1 px caps at both ends, as
/// Figma's day-divider-line. Symmetric, so it needs no direction.
class BvDashedLinePainter extends CustomPainter {
  const BvDashedLinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = BvColors.borderDefault
      ..strokeWidth = size.height;
    final y = size.height / 2;
    void dash(double from, double length) =>
        canvas.drawLine(Offset(from, y), Offset(from + length, y), paint);

    const cap = BvDayDividerSpec.cap;
    const step = BvDayDividerSpec.dash + BvDayDividerSpec.dashGap;
    dash(0, cap);
    dash(size.width - cap, cap);
    for (
      var x = BvDayDividerSpec.firstDash;
      x + BvDayDividerSpec.dash <= size.width - cap;
      x += step
    ) {
      dash(x, BvDayDividerSpec.dash);
    }
  }

  @override
  bool shouldRepaint(BvDashedLinePainter old) => false;
}
