import 'package:flutter/material.dart';

import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_days_specs.dart';

/// What the dot on the spine says about its entry (spec §5).
enum BvSpineDot {
  /// A post on the feed.
  quiet,

  /// The writing card: a hollow ring, and the time label in action colour.
  now,
}

/// Home's diary column (H1 v3): a thin line at the end of the time column,
/// with the entries ([BvSpineEntry]) on top of it, 22 apart. The Space's
/// daybook has no spine since v13 (review 53); Home loses it with H1 v4.
class BvDaybookSpine extends StatelessWidget {
  const BvDaybookSpine({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    const column = BvSpineSpec.timeColumn;
    return Stack(
      children: [
        PositionedDirectional(
          start: column - BvSpineSpec.lineWidth / 2,
          top: 0,
          bottom: 0,
          width: BvSpineSpec.lineWidth,
          child: const ColoredBox(
            key: Key('daybook-spine-line'),
            color: BvColors.borderDefault,
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(
            top: BvSpineSpec.paddingTop,
            bottom: BvSpineSpec.paddingBottom,
            end: BvSpineSpec.paddingEnd,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: BvSpineSpec.entryGap,
            children: children,
          ),
        ),
      ],
    );
  }
}

/// One entry on the spine: the time ("08:14", "Now", "Wed"), the dot on the
/// spine, then [child] (the slip) to its end.
///
/// On a 12-hour phone [period] ("pm", "مساءً") goes on a second, smaller
/// line under the time, so "11:58 مساءً" never cuts off in the column
/// (review 50 F15).
class BvSpineEntry extends StatelessWidget {
  const BvSpineEntry({
    super.key,
    required this.time,
    required this.child,
    this.period,
    this.dot = BvSpineDot.quiet,
  });

  final String time;
  final String? period;
  final Widget child;
  final BvSpineDot dot;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    const column = BvSpineSpec.timeColumn;
    final color = dot == BvSpineDot.now
        ? BvColors.textAction
        : BvColors.textSecondary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: BvSpineSpec.slipGap,
      children: [
        SizedBox(
          width: column,
          height: BvSpineSpec.rowHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              PositionedDirectional(
                start: 0,
                top: BvSpineSpec.labelTop,
                width: column - BvSpineSpec.labelToSpine,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      time,
                      key: const Key('spine-time'),
                      maxLines: 1,
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.visible,
                      softWrap: false,
                      style: type.labelSm.copyWith(color: color),
                    ),
                    if (period != null)
                      Text(
                        period!,
                        key: const Key('spine-period'),
                        maxLines: 1,
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.visible,
                        softWrap: false,
                        style: type.metadata.copyWith(
                          color: color,
                          fontSize: BvSpineSpec.periodSize,
                          height:
                              BvSpineSpec.periodLine / BvSpineSpec.periodSize,
                          letterSpacing: 0,
                        ),
                      ),
                  ],
                ),
              ),
              PositionedDirectional(
                start: column - BvSpineSpec.dotSize / 2,
                top: BvSpineSpec.dotTop,
                child: CustomPaint(
                  key: const Key('spine-dot'),
                  size: const Size.square(BvSpineSpec.dotSize),
                  painter: BvSpineDotPainter(dot),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

/// Paints a spine dot: a 3.5 circle filled with the state's colour and a
/// 2 px stroke in the page colour that cuts the spine. "Now" swaps them: a
/// page-coloured centre with an action ring.
class BvSpineDotPainter extends CustomPainter {
  const BvSpineDotPainter(this.dot);

  final BvSpineDot dot;

  /// The circle's fill.
  Color get fill => switch (dot) {
    BvSpineDot.quiet => BvColors.borderDefault,
    BvSpineDot.now => BvColors.surfaceApp,
  };

  /// The circle's stroke: the halo, or the ring for "Now".
  Color get stroke =>
      dot == BvSpineDot.now ? BvColors.actionPrimary : BvColors.surfaceApp;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    canvas
      ..drawCircle(centre, BvSpineSpec.dotRadius, Paint()..color = fill)
      ..drawCircle(
        centre,
        BvSpineSpec.dotRadius,
        Paint()
          ..color = stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = BvSpineSpec.dotStroke,
      );
  }

  @override
  bool shouldRepaint(BvSpineDotPainter old) => old.dot != dot;
}
