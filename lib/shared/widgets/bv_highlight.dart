import 'package:flutter/material.dart';

import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_loop_specs.dart';

/// A ring around [child] for about a second, then it fades (F20): the
/// card that an Activity row, a push or a Needs you card opened. Each new
/// [flash] value (not null) shows it again.
class BvHighlight extends StatefulWidget {
  const BvHighlight({super.key, required this.flash, required this.child});

  final Object? flash;
  final Widget child;

  @override
  State<BvHighlight> createState() => _BvHighlightState();
}

class _BvHighlightState extends State<BvHighlight>
    with SingleTickerProviderStateMixin {
  static final _total = BvCardHighlightSpec.hold + BvCardHighlightSpec.fade;

  late final _controller = AnimationController(vsync: this, duration: _total);

  /// Full for [BvCardHighlightSpec.hold], then fading out.
  late final Animation<double> _opacity = TweenSequence<double>([
    TweenSequenceItem(
      tween: ConstantTween(1),
      weight: BvCardHighlightSpec.hold.inMilliseconds.toDouble(),
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1,
        end: 0,
      ).chain(CurveTween(curve: BvMotion.exit)),
      weight: BvCardHighlightSpec.fade.inMilliseconds.toDouble(),
    ),
  ]).animate(_controller);

  @override
  void initState() {
    super.initState();
    if (widget.flash != null) _controller.forward(from: 0);
  }

  @override
  void didUpdateWidget(BvHighlight old) {
    super.didUpdateWidget(old);
    if (widget.flash != null && widget.flash != old.flash) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const o = BvCardHighlightSpec.outset;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        Positioned(
          left: -o,
          top: -o,
          right: -o,
          bottom: -o,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => _controller.isAnimating
                  ? Opacity(
                      key: const Key('bv-highlight-ring'),
                      opacity: _opacity.value,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BvCardHighlightSpec.radius,
                          border: Border.fromBorderSide(
                            BorderSide(
                              color: BvColors.borderFocus,
                              width: BvCardHighlightSpec.width,
                            ),
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }
}
