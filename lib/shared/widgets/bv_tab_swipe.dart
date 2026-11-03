import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../core/design/bv_specs.dart';

/// A sideways swipe between tabs (review 115, 3): toward the end of reading
/// (to the left; to the right in Arabic) shows the next tab, the other way
/// the previous one. [onSelect] gets the new tab, between 0 and [count].
///
/// What already swipes sideways under it (photos, chips, tables, a slip's
/// swipe) keeps its swipe: the gesture goes to the one under the finger.
/// A [BvKeepSwipe] keeps it for something that only taps, such as a photo
/// strip. A swipe that starts in an edge strip is the phone's back gesture.
/// Off ([enabled] false) while writing or choosing: the same widgets, so
/// nothing under it is built again.
class BvTabSwipe extends StatefulWidget {
  const BvTabSwipe({
    super.key,
    required this.index,
    required this.count,
    required this.onSelect,
    required this.child,
    this.enabled = true,
  });

  final int index;
  final int count;
  final ValueChanged<int> onSelect;
  final bool enabled;
  final Widget child;

  @override
  State<BvTabSwipe> createState() => _BvTabSwipeState();
}

class _BvTabSwipeState extends State<BvTabSwipe> {
  /// The pointer a [BvKeepSwipe] under it took, and whether this swipe
  /// started there or in an edge strip.
  int? _keptPointer;
  var _ignored = false;
  double _dragged = 0;

  bool get _rtl => Directionality.of(context) == TextDirection.rtl;

  /// How far toward the next tab: the finger moves toward reading's start.
  double _forward(double dx) => _rtl ? dx : -dx;

  void _down(PointerDownEvent event) {
    final size = MediaQuery.sizeOf(context);
    final insets = MediaQuery.systemGestureInsetsOf(context);
    final x = event.position.dx;
    final fromEdge =
        x < math.max(BvTabSwipeSpec.edge, insets.left) ||
        x > size.width - math.max(BvTabSwipeSpec.edge, insets.right);
    _ignored = fromEdge || _keptPointer == event.pointer;
  }

  void _end(DragEndDetails details) {
    final width = MediaQuery.sizeOf(context).width;
    final velocity = _forward(details.primaryVelocity ?? 0);
    final dragged = _dragged;
    _dragged = 0;
    if (_ignored) return;
    final step = dragged.abs() > width * BvTabSwipeSpec.distance
        ? dragged.sign
        : velocity.abs() > BvTabSwipeSpec.fling
        ? velocity.sign
        : 0;
    final next = widget.index + step.toInt();
    if (step != 0 && next >= 0 && next < widget.count) widget.onSelect(next);
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.enabled;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _down,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: on ? (_) => _dragged = 0 : null,
        onHorizontalDragUpdate: on
            ? (d) => _dragged += _forward(d.delta.dx)
            : null,
        onHorizontalDragEnd: on ? _end : null,
        child: widget.child,
      ),
    );
  }
}

/// Something that only taps but sits where a swipe is expected (a post's
/// photo strip): a sideways swipe on it doesn't change the tab.
class BvKeepSwipe extends StatelessWidget {
  const BvKeepSwipe({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    // Before the tab swipe's own (the one under the finger hears first).
    onPointerDown: (event) =>
        context.findAncestorStateOfType<_BvTabSwipeState>()?._keptPointer =
            event.pointer,
    child: child,
  );
}
