import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../core/design/bv_tokens.dart';

/// Gives a small control a touch area of at least 48 × 48 (rule 2: a
/// foreman on site, with gloves) without changing its look or its layout.
///
/// A touch in the larger area goes to the nearest point of [child], so put
/// the target around the control's gesture detector (or around a row of
/// them, like a line of chips). The parents must have room for the larger
/// area: in the Daybook's parts it falls in the padding and the gaps around
/// the control. Where a later neighbour would take part of it, give
/// [outset] to move the area away from that neighbour.
class BvTapTarget extends SingleChildRenderObjectWidget {
  const BvTapTarget({super.key, required Widget super.child, this.outset});

  /// The extra area on each side. Null: centred, enough for 48 × 48.
  final EdgeInsetsDirectional? outset;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderTapTarget(outset?.resolve(Directionality.of(context)));

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderTapTarget).outset = outset?.resolve(
      Directionality.of(context),
    );
  }
}

class _RenderTapTarget extends RenderProxyBox {
  _RenderTapTarget(this.outset);

  EdgeInsets? outset;

  Rect get _area {
    final extra =
        outset ??
        EdgeInsets.symmetric(
          horizontal: math.max(0, (BvSize.touchMin - size.width) / 2),
          vertical: math.max(0, (BvSize.touchMin - size.height) / 2),
        );
    return extra.inflateRect(Offset.zero & size);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null || !_area.contains(position)) return false;
    // The nearest point of the child; Size.contains excludes the far edge.
    final inside = Offset(
      position.dx.clamp(0, size.width - precisionErrorTolerance),
      position.dy.clamp(0, size.height - precisionErrorTolerance),
    );
    if (!child.hitTest(result, position: inside)) return false;
    result.add(BoxHitTestEntry(this, position));
    return true;
  }
}
