import 'package:flutter/material.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_loop_specs.dart';

/// Swipe a slip towards the end side to add an update (Y1 2530:33953): the
/// slip gives way at its start and a round + shows there. A swipe past
/// half way stays open; tapping the + calls [onAction] and closes it, and
/// a tap on the slip or a swipe back closes it too. Mirrors in right to
/// left.
class BvSwipeReveal extends StatefulWidget {
  const BvSwipeReveal({
    super.key,
    required this.child,
    required this.actionLabel,
    required this.onAction,
  });

  final Widget child;

  /// Read out for the +.
  final String actionLabel;
  final VoidCallback onAction;

  @override
  State<BvSwipeReveal> createState() => _BvSwipeRevealState();
}

class _BvSwipeRevealState extends State<BvSwipeReveal> {
  var _offset = 0.0;
  var _dragging = false;

  bool get _open => _offset > 0;

  void _update(DragUpdateDetails d) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final delta = rtl ? -d.delta.dx : d.delta.dx;
    setState(() {
      _dragging = true;
      _offset = (_offset + delta).clamp(0, BvSwipeRevealSpec.reveal);
    });
  }

  void _end(DragEndDetails _) => setState(() {
    _dragging = false;
    _offset = _offset >= BvSwipeRevealSpec.openAt
        ? BvSwipeRevealSpec.reveal
        : 0;
  });

  void _close() => setState(() => _offset = 0);

  @override
  Widget build(BuildContext context) {
    final shown = _offset / BvSwipeRevealSpec.reveal;
    return GestureDetector(
      key: const Key('swipe-reveal'),
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _update,
      onHorizontalDragEnd: _end,
      child: Stack(
        children: [
          PositionedDirectional(
            start: BvSwipeRevealSpec.buttonStart,
            top: 0,
            bottom: 0,
            child: Center(
              child: Opacity(
                opacity: shown,
                child: Semantics(
                  button: true,
                  label: widget.actionLabel,
                  excludeSemantics: true,
                  child: GestureDetector(
                    key: const Key('swipe-reveal-action'),
                    behavior: HitTestBehavior.opaque,
                    onTap: _open
                        ? () {
                            _close();
                            widget.onAction();
                          }
                        : null,
                    child: const SizedBox.square(
                      dimension: BvSize.touchMin,
                      child: Center(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: BvColors.surfaceBrandSoft,
                            shape: BoxShape.circle,
                          ),
                          child: SizedBox.square(
                            dimension: BvSwipeRevealSpec.button,
                            child: Icon(
                              BvIcons.add,
                              size: BvSwipeRevealSpec.icon,
                              color: BvColors.textAction,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          AnimatedPadding(
            duration: _dragging ? Duration.zero : BvMotion.fast,
            curve: BvMotion.standard,
            padding: EdgeInsetsDirectional.only(start: _offset),
            // While open, a tap on the slip closes it instead.
            child: AbsorbPointer(absorbing: _open, child: widget.child),
          ),
          if (_open)
            PositionedDirectional(
              start: BvSwipeRevealSpec.reveal,
              top: 0,
              end: 0,
              bottom: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _close,
              ),
            ),
        ],
      ),
    );
  }
}
