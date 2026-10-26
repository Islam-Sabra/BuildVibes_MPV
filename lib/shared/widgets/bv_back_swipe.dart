import 'package:flutter/material.dart';

import '../../core/design/bv_specs.dart';

/// Back by swipe, everywhere (review 100 B6). Where a screen holds Back for
/// itself ([holding]: a `PopScope` that can't pop while writing, selecting
/// or a menu is open), the iPhone's own edge swipe is off; this one goes
/// back the way ← does, through [Navigator.maybePop], so the screen's own
/// order holds: the menu, the selection, the entry, then the screen.
/// Where the screen can pop, the iPhone's swipe does it, and Android's
/// system back (predictive) reaches the `PopScope` either way.
///
/// It swipes in from the leading edge: the left, the right in Arabic. Its
/// strip lets taps through to what is under it. The same widgets whether
/// it holds or not, so the screen under it is never built again.
class BvBackSwipe extends StatefulWidget {
  const BvBackSwipe({super.key, required this.holding, required this.child});

  final bool holding;
  final Widget child;

  @override
  State<BvBackSwipe> createState() => _BvBackSwipeState();
}

class _BvBackSwipeState extends State<BvBackSwipe> {
  double _dragged = 0;

  bool get _on =>
      widget.holding && Theme.of(context).platform == TargetPlatform.iOS;

  /// How far the swipe went toward the trailing side.
  double _forward(double dx) =>
      Directionality.of(context) == TextDirection.rtl ? -dx : dx;

  void _end(DragEndDetails d) {
    final width = MediaQuery.sizeOf(context).width;
    final fling = _forward(d.primaryVelocity ?? 0) > BvBackSwipeSpec.fling;
    final far = _dragged > width * BvBackSwipeSpec.distance;
    _dragged = 0;
    if (fling || far) Navigator.maybePop(context);
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      widget.child,
      PositionedDirectional(
        start: 0,
        top: 0,
        bottom: 0,
        width: BvBackSwipeSpec.edge,
        child: IgnorePointer(
          ignoring: !_on,
          child: GestureDetector(
            key: const Key('back-swipe'),
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: (_) => _dragged = 0,
            onHorizontalDragUpdate: (d) => _dragged += _forward(d.delta.dx),
            onHorizontalDragEnd: _end,
          ),
        ),
      ),
    ],
  );
}
