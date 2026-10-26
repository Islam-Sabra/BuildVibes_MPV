import 'package:flutter/material.dart';

import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_writing_specs.dart';

/// A small card next to a line being written (review 98): the "/" card
/// (NBY1) and the line menu (NBY2). It floats in the overlay, so the line
/// keeps the keyboard and stays in sight: under the line, over the bar and
/// the keyboard, as the frames draw it, when it fits on the screen;
/// otherwise over the line. The "/" card lines up with the
/// line's start; the line menu with its end. It opens in 150 ms from the
/// line, and at once with Reduce motion.
///
/// [barrier]: a tap anywhere else closes it ([onDismiss]); the "/" card has
/// none, as typing goes on in the line under it.
class BvLinePopover {
  OverlayEntry? _entry;

  bool get isOpen => _entry != null;

  void show(
    BuildContext context, {
    required BuildContext? Function() anchor,
    required WidgetBuilder builder,
    bool atEnd = false,
    bool barrier = false,
    double gap = BvLineMenuSpec.cardGap,
    VoidCallback? onDismiss,
  }) {
    hide();
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (overlayContext) {
        final box = overlay.context.findRenderObject() as RenderBox?;
        final at = anchor();
        final line = at != null && at.mounted
            ? at.findRenderObject() as RenderBox?
            : null;
        if (box == null || line == null || !line.attached) {
          return const SizedBox.shrink();
        }
        final rect = line.localToGlobal(Offset.zero, ancestor: box) & line.size;
        final media = MediaQuery.of(overlayContext);
        return Stack(
          children: [
            if (barrier)
              Positioned.fill(
                child: GestureDetector(
                  key: const Key('line-popover-barrier'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onDismiss,
                ),
              ),
            Positioned.fill(
              child: CustomSingleChildLayout(
                delegate: _NextToLine(
                  line: rect,
                  atEnd: atEnd,
                  gap: gap,
                  textDirection: Directionality.of(context),
                  top: media.padding.top + BvLineMenuSpec.screenMargin,
                  // Over the keyboard too (lead, 26 Oct).
                  bottom: media.padding.bottom + BvLineMenuSpec.screenMargin,
                ),
                child: _PopIn(
                  atEnd: atEnd,
                  child: Builder(builder: builder),
                ),
              ),
            ),
          ],
        );
      },
    );
    _entry = entry;
    overlay.insert(entry);
  }

  /// Drawn again (the "/" card's rows follow what is typed).
  void rebuild() => _entry?.markNeedsBuild();

  void hide() {
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
  }
}

/// Under the line if it fits on the screen, else over it; its start
/// (or, [atEnd], its end) lined up with the line's.
class _NextToLine extends SingleChildLayoutDelegate {
  _NextToLine({
    required this.line,
    required this.atEnd,
    required this.gap,
    required this.textDirection,
    required this.top,
    required this.bottom,
  });

  final Rect line;
  final bool atEnd;
  final double gap;
  final TextDirection textDirection;
  final double top;
  final double bottom;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size child) {
    final below = line.bottom + gap;
    final above = line.top - gap - child.height;
    final y = below + child.height <= size.height - bottom
        ? below
        : above >= top
        ? above
        : top;
    final rtl = textDirection == TextDirection.rtl;
    final x = rtl != atEnd ? line.right - child.width : line.left;
    final most = size.width - child.width - BvLineMenuSpec.screenMargin;
    return Offset(x.clamp(BvLineMenuSpec.screenMargin, most < 0 ? 0 : most), y);
  }

  @override
  bool shouldRelayout(_NextToLine old) =>
      old.line != line ||
      old.atEnd != atEnd ||
      old.gap != gap ||
      old.textDirection != textDirection ||
      old.top != top ||
      old.bottom != bottom;
}

/// Fades and grows in from the line's side, in [BvMotion.menu].
class _PopIn extends StatefulWidget {
  const _PopIn({required this.atEnd, required this.child});

  final bool atEnd;
  final Widget child;

  @override
  State<_PopIn> createState() => _PopInState();
}

class _PopInState extends State<_PopIn> with SingleTickerProviderStateMixin {
  late final _open = AnimationController(vsync: this, duration: BvMotion.menu);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_open.isAnimating || _open.isCompleted) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _open.value = 1;
    } else {
      _open.forward();
    }
  }

  @override
  void dispose() {
    _open.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _open, curve: BvMotion.enter);
    return FadeTransition(
      opacity: curve,
      child: ScaleTransition(
        scale: Tween(begin: BvLineMenuSpec.openScale, end: 1.0).animate(curve),
        alignment: widget.atEnd
            ? AlignmentDirectional.topEnd.resolve(Directionality.of(context))
            : AlignmentDirectional.topStart.resolve(Directionality.of(context)),
        child: widget.child,
      ),
    );
  }
}
