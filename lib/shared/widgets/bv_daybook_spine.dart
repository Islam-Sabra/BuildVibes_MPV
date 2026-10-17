import 'package:flutter/material.dart';

import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_days_specs.dart';

/// What the dot on the spine says about its entry (spec §5).
enum BvSpineDot {
  /// Nothing for you: someone's post, or your own posted item.
  quiet,

  /// Needs you: the slip has a paper clip.
  needsYou,
  checked,

  /// The writing card: a hollow ring, and the time label in action colour.
  now,
}

/// The Daybook's diary column: a thin line at the end of the time column,
/// with the entries ([BvSpineEntry]) on top of it, 22 apart.
///
/// Set [home] for Home's narrower time column (48 instead of 56); the
/// entries must use the same setting.
///
/// With [minHeight] (the page's height) the spine runs the whole page and
/// the entries sit at its bottom, newest last, as in Figma's diary.
class BvDaybookSpine extends StatelessWidget {
  const BvDaybookSpine({
    super.key,
    required this.children,
    this.home = false,
    this.minHeight,
  });

  final List<Widget> children;
  final bool home;
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    final column = home ? BvSpineSpec.homeTimeColumn : BvSpineSpec.timeColumn;
    final spine = Stack(
      // A minimum height reaches the entries' column, which then fills it.
      fit: minHeight == null ? StackFit.loose : StackFit.passthrough,
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
    if (minHeight == null) return spine;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight!),
      child: spine,
    );
  }
}

/// One entry on the spine: the time ("08:14", "Now", "Wed"), the dot on the
/// spine, then [child] (the slip) to its end.
class BvSpineEntry extends StatelessWidget {
  const BvSpineEntry({
    super.key,
    required this.time,
    required this.child,
    this.dot = BvSpineDot.quiet,
    this.home = false,
  });

  final String time;
  final Widget child;
  final BvSpineDot dot;
  final bool home;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final column = home ? BvSpineSpec.homeTimeColumn : BvSpineSpec.timeColumn;
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
                child: Text(
                  time,
                  maxLines: 1,
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.visible,
                  softWrap: false,
                  style: type.labelSm.copyWith(
                    color: dot == BvSpineDot.now
                        ? BvColors.textAction
                        : BvColors.textSecondary,
                  ),
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
    BvSpineDot.needsYou => BvColors.actionPrimary,
    BvSpineDot.checked => BvColors.textPositive,
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
