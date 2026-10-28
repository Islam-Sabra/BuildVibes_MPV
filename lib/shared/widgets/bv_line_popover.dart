import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_writing_specs.dart';

/// A small card next to a line being written (review 98): the "/" card
/// (NBY1) and the line menu (NBY2). It floats in the overlay, so the line
/// keeps the keyboard and stays in sight: under the line when it fits in
/// what the top bar and the keyboard leave, otherwise over the line; never
/// under the keyboard (review 100 B4), and a card taller than that room
/// scrolls inside it. The "/" card lines up with the
/// line's start; the line menu with its end. It opens in 150 ms from the
/// line, and at once with Reduce motion.
///
/// [barrier]: a tap anywhere else closes it ([onDismiss]); the "/" card has
/// none, as typing goes on in the line under it. [above]: over the line
/// when it fits there, else under it (the notebook's page picker, PG3).
///
/// [makeRoom] (review 100 D5, D6): when the card, as it is laid out,
/// fits neither under the line nor over it in the room the top bar and the
/// keyboard leave, it stands off the screen while the host scrolls the line
/// [up] by what the card needs under it (or [down] by what it needs over
/// it), then shows next to the line. A card that fits opens at once.
class BvLinePopover {
  OverlayEntry? _entry;

  /// Room is being made: the card stands off the screen until it is.
  bool _making = false;

  /// Room is asked for once per opening, however often it is laid out.
  bool _asked = false;

  /// The page the line scrolls in: the card follows it (review 100 D6).
  ScrollPosition? _page;

  bool get isOpen => _entry != null;

  void show(
    BuildContext context, {
    required BuildContext? Function() anchor,
    required WidgetBuilder builder,
    bool atEnd = false,
    bool barrier = false,
    bool dim = false,
    bool above = false,
    double gap = BvLineMenuSpec.cardGap,
    VoidCallback? onDismiss,
    Future<void> Function({required double up, required double down})? makeRoom,
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
        // The overlay's own insets: the keyboard is in them here (D5).
        final media = MediaQuery.of(overlayContext);
        return Stack(
          children: [
            if (barrier)
              Positioned.fill(
                child: GestureDetector(
                  key: const Key('line-popover-barrier'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onDismiss,
                  // A swipe behind it (an iPhone's back, B6) only closes it,
                  // as a tap does.
                  onHorizontalDragEnd: onDismiss == null
                      ? null
                      : (_) => onDismiss(),
                  // [dim]: the screen behind is dimmed (the Filter, BH9).
                  child: dim
                      ? const ColoredBox(
                          key: Key('line-popover-dim'),
                          color: BvColors.overlayDim,
                        )
                      : null,
                ),
              ),
            Positioned.fill(
              child: CustomSingleChildLayout(
                delegate: _NextToLine(
                  line: rect,
                  atEnd: atEnd,
                  above: above,
                  gap: gap,
                  textDirection: Directionality.of(context),
                  // Review 100 B4: inside what the top bar and the keyboard
                  // leave, never under the keyboard.
                  top: visibleTop(media),
                  bottom: visibleBottom(media),
                  noRoom: makeRoom == null
                      ? null
                      : (up, down) => _noRoom(up, down, makeRoom),
                ),
                child: _PopIn(
                  atEnd: atEnd,
                  child: SingleChildScrollView(
                    child: Builder(builder: builder),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    _making = false;
    _asked = false;
    _entry = entry;
    overlay.insert(entry);
    // The host's page, not a field's own scrolling (EditableText has one).
    _page = Scrollable.maybeOf(context)?.position;
    _page?.addListener(_follow);
  }

  /// The page scrolled: the card is placed again, next to the line.
  void _follow() {
    final entry = _entry;
    if (entry == null) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (_entry == entry) entry.markNeedsBuild();
      });
    } else {
      entry.markNeedsBuild();
    }
  }

  /// The card fits neither way: true while it stands off the screen for
  /// the host to make room (asked once, after this frame).
  bool _noRoom(
    double up,
    double down,
    Future<void> Function({required double up, required double down}) makeRoom,
  ) {
    if (_asked) return _making;
    _asked = true;
    _making = true;
    final entry = _entry;
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      await makeRoom(up: up, down: down);
      if (_entry != entry) return;
      _making = false;
      entry?.markNeedsBuild();
    });
    return true;
  }

  /// Drawn again (the "/" card's rows follow what is typed).
  void rebuild() => _entry?.markNeedsBuild();

  void hide() {
    _making = false;
    _page?.removeListener(_follow);
    _page = null;
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
  }
}

/// Where a card may stand (review 100 B4): under the top bar, and above the
/// keyboard (or the phone's own bar), with [BvLineMenuSpec.screenMargin].
double visibleTop(MediaQueryData media) =>
    media.padding.top + BvSize.topBar + BvLineMenuSpec.screenMargin;

double visibleBottom(MediaQueryData media) =>
    math.max(media.viewInsets.bottom, media.padding.bottom) +
    BvLineMenuSpec.screenMargin;

/// Under the line if it fits on the screen, else over it; its start
/// (or, [atEnd], its end) lined up with the line's.
class _NextToLine extends SingleChildLayoutDelegate {
  _NextToLine({
    required this.line,
    required this.atEnd,
    required this.above,
    required this.gap,
    required this.textDirection,
    required this.top,
    required this.bottom,
    this.noRoom,
  });

  final Rect line;
  final bool atEnd;
  final bool above;
  final double gap;
  final TextDirection textDirection;
  final double top;
  final double bottom;

  /// The card fits neither way, though it fits the room: given how far the
  /// line must go up (for room under it) and down (over it); true while it
  /// stays off the screen.
  final bool Function(double up, double down)? noRoom;

  @override
  /// Never taller than the room; a taller card scrolls inside it.
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen().copyWith(
        maxHeight: (constraints.maxHeight - top - bottom).clamp(
          0,
          constraints.maxHeight,
        ),
      );

  @override
  Offset getPositionForChild(Size size, Size child) {
    final below = line.bottom + gap;
    final above = line.top - gap - child.height;
    final fitsBelow = below + child.height <= size.height - bottom;
    final fitsAbove = above >= top;
    if (!fitsBelow &&
        !fitsAbove &&
        child.height <= size.height - bottom - top &&
        (noRoom?.call(
              below + child.height - (size.height - bottom),
              top - above,
            ) ??
            false)) {
      return Offset(0, size.height);
    }
    final y = this.above
        ? (fitsAbove ? above : (fitsBelow ? below : top))
        : (fitsBelow ? below : (fitsAbove ? above : top));
    final rtl = textDirection == TextDirection.rtl;
    final x = rtl != atEnd ? line.right - child.width : line.left;
    final most = size.width - child.width - BvLineMenuSpec.screenMargin;
    return Offset(x.clamp(BvLineMenuSpec.screenMargin, most < 0 ? 0 : most), y);
  }

  @override
  bool shouldRelayout(_NextToLine old) =>
      old.line != line ||
      old.atEnd != atEnd ||
      old.above != above ||
      old.gap != gap ||
      old.textDirection != textDirection ||
      old.top != top ||
      old.bottom != bottom ||
      old.noRoom != noRoom;
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
