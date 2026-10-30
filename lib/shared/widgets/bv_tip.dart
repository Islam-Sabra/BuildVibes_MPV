import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import 'bv_button.dart';

/// Where the real controls are, for a first-run tip's spotlight (review
/// 107 OB7). Each [BvTipAnchor] under a [BvTipAnchorScope] registers here
/// by its id; [rectOf] gives the topmost one on screen.
class BvTipAnchors extends ChangeNotifier {
  final _anchors = <Object, List<GlobalKey>>{};
  var _pending = false;
  var _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _add(Object id, GlobalKey key) {
    (_anchors[id] ??= []).add(key);
    _changed();
  }

  void _remove(Object id, GlobalKey key) {
    _anchors[id]?.remove(key);
    _changed();
  }

  /// Anchors come and go while their widgets build: listeners hear once,
  /// after the frame.
  void _changed() {
    if (_pending) return;
    _pending = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _pending = false;
      // An anchor that left as the page closed.
      if (!_disposed) notifyListeners();
    });
  }

  /// [id]'s topmost anchor laid out on screen, in global coordinates; null
  /// when there is none.
  Rect? rectOf(Object id, Size screen) {
    Rect? best;
    for (final key in _anchors[id] ?? const <GlobalKey>[]) {
      final box = key.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (!rect.overlaps(Offset.zero & screen)) continue;
      if (best == null || rect.top < best.top) best = rect;
    }
    return best;
  }
}

/// Gives the [BvTipAnchor]s under it their [anchors].
class BvTipAnchorScope extends InheritedWidget {
  const BvTipAnchorScope({
    super.key,
    required this.anchors,
    required super.child,
  });

  final BvTipAnchors anchors;

  static BvTipAnchors? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<BvTipAnchorScope>()?.anchors;

  @override
  bool updateShouldNotify(BvTipAnchorScope oldWidget) =>
      anchors != oldWidget.anchors;
}

/// A real control a tip may point at, by [id]. Outside a scope (or with no
/// id) it is just its [child].
class BvTipAnchor extends StatefulWidget {
  const BvTipAnchor({super.key, required this.id, required this.child});

  final Object? id;
  final Widget child;

  @override
  State<BvTipAnchor> createState() => _BvTipAnchorState();
}

class _BvTipAnchorState extends State<BvTipAnchor> {
  final _key = GlobalKey();
  BvTipAnchors? _anchors;
  Object? _id;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _register();
  }

  @override
  void didUpdateWidget(BvTipAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) _register();
  }

  void _register() {
    final anchors = BvTipAnchorScope.maybeOf(context);
    if (anchors == _anchors && widget.id == _id) return;
    if (_id != null) _anchors?._remove(_id!, _key);
    _anchors = anchors;
    _id = widget.id;
    if (_id != null) anchors?._add(_id!, _key);
  }

  @override
  void dispose() {
    if (_id != null) _anchors?._remove(_id!, _key);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: _key, child: widget.child);
}

/// A first-run tip over the whole screen (OB7, 2699:39168): the screen
/// dimmed but for a ring around the real control at [target], and the tip's
/// card beside it ("Tip 1 of 3", its words, Skip tips · Next). Taps on the
/// dimmed screen do nothing.
class BvTipLayer extends StatelessWidget {
  const BvTipLayer({
    super.key,
    required this.target,
    required this.count,
    required this.text,
    required this.skipLabel,
    required this.nextLabel,
    required this.onSkip,
    required this.onNext,
  });

  /// The control, in global coordinates.
  final Rect target;

  /// "Tip 1 of 3".
  final String count;
  final String text;
  final String skipLabel;
  final String nextLabel;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final screen = MediaQuery.sizeOf(context);
    final hole = target.inflate(BvEntrySpec.spotlightGap);
    final below = hole.center.dy < screen.height / 2;
    final width = BvEntrySpec.tipWidth.clamp(
      0.0,
      screen.width - 2 * BvSpace.gutter,
    );
    final left = (hole.center.dx - width / 2).clamp(
      BvSpace.gutter,
      screen.width - width - BvSpace.gutter,
    );
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: CustomPaint(painter: _Spotlight(hole)),
          ),
        ),
        Positioned.fromRect(
          rect: hole,
          child: const IgnorePointer(
            child: SizedBox.expand(key: Key('tip-spotlight')),
          ),
        ),
        Positioned(
          left: left,
          width: width,
          top: below ? hole.bottom + BvEntrySpec.tipGap : null,
          bottom: below ? null : screen.height - hole.top + BvEntrySpec.tipGap,
          child: Material(
            key: const Key('tip-card'),
            color: BvColors.surfaceElevated,
            borderRadius: BvRadius.cardAll,
            elevation: 0,
            child: Padding(
              padding: const EdgeInsetsDirectional.all(BvEntrySpec.tipPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                spacing: BvSpace.s8,
                children: [
                  Text(
                    count,
                    style: type.metadata.copyWith(color: BvColors.textAction),
                  ),
                  Text(text, style: type.labelLg),
                  Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: BvButton(
                            key: const Key('tip-skip'),
                            label: skipLabel,
                            style: BvButtonStyle.tertiary,
                            size: BvButtonSize.medium,
                            padded: false,
                            onPressed: onSkip,
                          ),
                        ),
                      ),
                      BvButton(
                        key: const Key('tip-next'),
                        label: nextLabel,
                        size: BvButtonSize.medium,
                        onPressed: onNext,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The dimmed screen with a round hole and a ring at [hole].
class _Spotlight extends CustomPainter {
  const _Spotlight(this.hole);

  final Rect hole;

  @override
  void paint(Canvas canvas, Size size) {
    // Round for a button; a card keeps its own corners.
    final round = hole.longestSide < hole.shortestSide * 1.5;
    final radius = Radius.circular(
      round ? hole.shortestSide / 2 : BvRadius.card + BvEntrySpec.spotlightGap,
    );
    final cut = RRect.fromRectAndRadius(hole, radius);
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRRect(cut),
      ),
      Paint()..color = BvColors.overlayScrim,
    );
    canvas.drawRRect(
      cut,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = BvEntrySpec.spotlightRing
        ..color = BvColors.surfaceElevated,
    );
  }

  @override
  bool shouldRepaint(_Spotlight oldDelegate) => oldDelegate.hole != hole;
}
