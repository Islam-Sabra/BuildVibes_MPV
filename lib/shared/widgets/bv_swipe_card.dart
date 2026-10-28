import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../core/design/bv_specs.dart' show BvSwipeSpec;
import '../../core/design/bv_tokens.dart';

/// One round button behind a swiped card (review 100 Part 3b): its icon on
/// its colour, its word under it.
@immutable
class BvSwipeAction {
  const BvSwipeAction({
    required this.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.confirm,
  });

  final Key key;
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  /// Asked before the full swipe acts (Delete forever, review 100 H8):
  /// false, and the card goes back where it was.
  final Future<bool> Function()? confirm;
}

/// The cards of one list: only one is open at a time, and a scroll closes
/// it.
class BvSwipeGroup extends StatefulWidget {
  const BvSwipeGroup({super.key, required this.child});

  final Widget child;

  @override
  State<BvSwipeGroup> createState() => _BvSwipeGroupState();
}

class _BvSwipeGroupState extends State<BvSwipeGroup> {
  final _open = ValueNotifier<Object?>(null);

  @override
  void dispose() {
    _open.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollStartNotification>(
        onNotification: (_) {
          _open.value = null;
          return false;
        },
        child: _SwipeScope(open: _open, child: widget.child),
      );
}

class _SwipeScope extends InheritedWidget {
  const _SwipeScope({required this.open, required super.child});

  final ValueNotifier<Object?> open;

  @override
  bool updateShouldNotify(_SwipeScope old) => open != old.open;
}

/// A card that swipes (review 100 Part 3b, BH3).
///
/// - Toward the end, [endActions] (Pin · Reminder) show behind it as round
///   buttons on the page's background; past a quarter of its width it
///   stays open until a tap elsewhere or a scroll. A tap on a button acts
///   and closes it.
/// - Toward the start, [startAction] (Archive) shows as one round button;
///   past the full-swipe point it stretches into a pill under the finger,
///   and let go there the card flies off, its row closes, and it acts.
/// - The card lifts as it moves; a light haptic as the buttons open and
///   at the full-swipe point; with Reduce motion on, no springing.
/// - A swipe counts only when it starts at least 24 from the screen's
///   edges, which stay the system's back gesture. Off while not [enabled].
/// - Screen readers get every action as the card's own.
/// - [hint]: once, it slides open by a third and closes after a second.
class BvSwipeCard extends StatefulWidget {
  const BvSwipeCard({
    super.key,
    required this.id,
    required this.child,
    this.endActions = const [],
    this.startAction,
    this.enabled = true,
    this.hint = false,
    this.onHinted,
  });

  final String id;
  final Widget child;
  final List<BvSwipeAction> endActions;
  final BvSwipeAction? startAction;
  final bool enabled;
  final bool hint;
  final VoidCallback? onHinted;

  @override
  State<BvSwipeCard> createState() => _BvSwipeCardState();
}

class _BvSwipeCardState extends State<BvSwipeCard>
    with TickerProviderStateMixin {
  /// How far the card has moved along the reading direction: positive
  /// toward the end, negative toward the start.
  late final _offset = AnimationController.unbounded(vsync: this);

  /// The row closing after a full swipe.
  late final _row = AnimationController(
    vsync: this,
    duration: BvSwipeSpec.rowClose,
    value: 1,
  );

  bool _tracking = false;
  bool _pastFull = false;
  bool _gone = false;
  ValueNotifier<Object?>? _group;
  double _width = 0;

  bool get _still => MediaQuery.disableAnimationsOf(context);
  bool get _rtl => Directionality.of(context) == TextDirection.rtl;

  double get _endOpen =>
      widget.endActions.length * BvSwipeSpec.slot + BvSwipeSpec.inset;
  double get _startOpen => BvSwipeSpec.slot + BvSwipeSpec.inset;
  double get _fullPoint => _width * BvSwipeSpec.fullSwipe;

  @override
  void initState() {
    super.initState();
    _offset.addListener(() => setState(() {}));
    if (widget.hint) {
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_peek()));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final group = context
        .dependOnInheritedWidgetOfExactType<_SwipeScope>()
        ?.open;
    if (group != _group) {
      _group?.removeListener(_groupChanged);
      _group = group?..addListener(_groupChanged);
    }
  }

  @override
  void didUpdateWidget(BvSwipeCard old) {
    super.didUpdateWidget(old);
    if (!widget.enabled && _offset.value != 0) _settle(0);
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _group?.removeListener(_groupChanged);
    _offset.dispose();
    _row.dispose();
    super.dispose();
  }

  void _groupChanged() {
    if (_group?.value != widget.id && _offset.value != 0 && !_gone) {
      _settle(0);
    }
  }

  Timer? _hintTimer;

  Future<void> _peek() async {
    if (!mounted || widget.endActions.isEmpty) return;
    widget.onHinted?.call();
    await _settle(_width / 3);
    if (!mounted) return;
    _hintTimer = Timer(BvSwipeSpec.hintHold, () {
      if (mounted && !_tracking) unawaited(_settle(0));
    });
  }

  Future<void> _settle(double to) {
    if (!mounted) return Future.value();
    if (_still) {
      _offset.value = to;
      return Future.value();
    }
    return _offset.animateTo(
      to,
      duration: BvSwipeSpec.settle,
      curve: BvMotion.standard,
    );
  }

  /// Where a finger went down is far enough from the screen's edges to be
  /// the card's (review 100 H7): one down at an edge is the back gesture's,
  /// and the card's drag never takes it.
  bool _offEdge(Offset down) {
    final screen = MediaQuery.sizeOf(context).width;
    return down.dx >= BvSwipeSpec.edge && down.dx <= screen - BvSwipeSpec.edge;
  }

  void _start(DragStartDetails d) {
    _tracking = widget.enabled && !_gone;
    if (!_tracking) return;
    _offset.stop();
    _group?.value = widget.id;
  }

  void _update(DragUpdateDetails d) {
    if (!_tracking) return;
    final delta = (_rtl ? -d.delta.dx : d.delta.dx);
    var next = _offset.value + delta;
    if (widget.endActions.isEmpty && next > 0) next = 0;
    if (widget.startAction == null && next < 0) next = 0;
    // Past its buttons (and the point that opens them), toward the end, it
    // pulls harder.
    final stiff = math.max(_endOpen, _width * BvSwipeSpec.halfSwipe) + 1;
    if (next > stiff) next = stiff + (next - stiff) / 3;
    next = math.max(next, -_width);
    final wasOpen = _offset.value.abs() >= _width * BvSwipeSpec.halfSwipe;
    final isOpen = next.abs() >= _width * BvSwipeSpec.halfSwipe;
    if (!wasOpen && isOpen) unawaited(HapticFeedback.lightImpact());
    final past = next <= -_fullPoint;
    if (past != _pastFull) {
      _pastFull = past;
      if (past) unawaited(HapticFeedback.selectionClick());
    }
    _offset.value = next;
  }

  void _end(DragEndDetails d) {
    if (!_tracking) return;
    _tracking = false;
    final v = _offset.value;
    if (v <= -_fullPoint && widget.startAction != null) {
      unawaited(_commit());
    } else if (v.abs() >= _width * BvSwipeSpec.halfSwipe) {
      unawaited(_settle(v > 0 ? _endOpen : -_startOpen));
    } else {
      unawaited(_settle(0));
    }
    _pastFull = false;
  }

  /// A full swipe, or Archive tapped: the card flies off, its row closes,
  /// then it acts.
  Future<void> _commit() async {
    final action = widget.startAction;
    if (action == null || _gone) return;
    _gone = true;
    if (action.confirm case final ask?) {
      final yes = await ask();
      if (!mounted) return;
      if (!yes) {
        _gone = false;
        await _settle(0);
        return;
      }
    }
    if (!_still) {
      await _offset.animateTo(
        -_width * BvSwipeSpec.flyPast,
        duration: BvSwipeSpec.fly,
        curve: BvMotion.standard,
      );
      await _row.reverse();
    }
    action.onTap();
  }

  void _act(BvSwipeAction a) {
    unawaited(_settle(0));
    a.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final v = _offset.value;
    final open = v != 0;
    final start = widget.startAction;

    Widget round(BvSwipeAction a, double shown, {double? pill}) {
      final grow = BvMotion.enter.transform(shown.clamp(0, 1));
      return Opacity(
        opacity: grow,
        child: Transform.scale(
          scale: BvSwipeSpec.growFrom + (1 - BvSwipeSpec.growFrom) * grow,
          child: Semantics(
            button: true,
            label: a.label,
            excludeSemantics: true,
            child: GestureDetector(
              key: a.key,
              behavior: HitTestBehavior.opaque,
              onTap: () => a == start ? unawaited(_commit()) : _act(a),
              child: pill != null
                  ? AnimatedContainer(
                      duration: _still ? Duration.zero : BvMotion.fast,
                      width: pill,
                      height: BvSwipeSpec.button,
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: BvSwipeSpec.pillPadding,
                      ),
                      decoration: BoxDecoration(
                        color: a.color,
                        borderRadius: BvRadius.roundAll,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        spacing: BvSpace.s8,
                        children: [
                          Flexible(
                            child: Text(
                              a.label,
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              style: type.labelSm.copyWith(
                                color: BvColors.textInverse,
                              ),
                            ),
                          ),
                          Icon(
                            a.icon,
                            size: BvSwipeSpec.icon,
                            color: BvColors.textInverse,
                          ),
                        ],
                      ),
                    )
                  // Review 102 P1: on a card shorter than the button with
                  // its word (a one-line entry), both are made smaller to
                  // fit; on any taller card they stay as they are.
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        spacing: BvSpace.s4,
                        // Its word stays inside its slot, made smaller if it
                        // must, so the card never covers the button.
                        children: [
                          Container(
                            width: BvSwipeSpec.button,
                            height: BvSwipeSpec.button,
                            decoration: BoxDecoration(
                              color: a.color,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              a.icon,
                              size: BvSwipeSpec.icon,
                              color: BvColors.textInverse,
                            ),
                          ),
                          SizedBox(
                            width: BvSwipeSpec.slot,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                a.label,
                                maxLines: 1,
                                style: type.labelSm.copyWith(
                                  color: BvColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      );
    }

    final behind = <Widget>[
      if (v > 0)
        PositionedDirectional(
          start: BvSwipeSpec.inset,
          top: 0,
          bottom: 0,
          child: Row(
            children: [
              for (final (i, a) in widget.endActions.indexed)
                SizedBox(
                  width: BvSwipeSpec.slot,
                  child: Center(
                    child: round(
                      a,
                      // The second follows the first a step behind.
                      (v - i * BvSwipeSpec.lag) / BvSwipeSpec.slot,
                    ),
                  ),
                ),
            ],
          ),
        ),
      if (v < 0 && start != null)
        PositionedDirectional(
          end: BvSwipeSpec.inset,
          top: 0,
          bottom: 0,
          child: Center(
            child: round(
              start,
              -v / BvSwipeSpec.slot,
              pill: -v >= _fullPoint
                  ? math.max(BvSwipeSpec.button, -v - BvSwipeSpec.inset * 2)
                  : null,
            ),
          ),
        ),
    ];

    final lift = (v.abs() / BvSwipeSpec.slot).clamp(0.0, 1.0);
    final card = Transform.translate(
      offset: Offset(_rtl ? -v : v, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BvSwipeSpec.cardRadius,
          boxShadow: lift == 0
              ? null
              : [
                  for (final s in BvShadow.slipLifted)
                    s.copyWith(
                      color: s.color.withValues(alpha: s.color.a * lift),
                    ),
                ],
        ),
        child: AbsorbPointer(absorbing: open, child: widget.child),
      ),
    );

    return SizeTransition(
      sizeFactor: _row,
      alignment: AlignmentDirectional.topStart,
      child: LayoutBuilder(
        builder: (context, box) {
          _width = box.maxWidth;
          return Semantics(
            key: Key('swipe-card-${widget.id}'),
            container: true,
            customSemanticsActions: widget.enabled
                ? {
                    for (final a in widget.endActions)
                      CustomSemanticsAction(label: a.label): a.onTap,
                    if (start != null)
                      CustomSemanticsAction(label: start.label): start.onTap,
                  }
                : null,
            child: TapRegion(
              onTapOutside: open && !_gone ? (_) => _settle(0) : null,
              child: RawGestureDetector(
                behavior: HitTestBehavior.translucent,
                gestures: {
                  if (widget.enabled)
                    _OffEdgeDrag:
                        GestureRecognizerFactoryWithHandlers<_OffEdgeDrag>(
                          () => _OffEdgeDrag(_offEdge),
                          (drag) => drag
                            ..dragStartBehavior = DragStartBehavior.down
                            ..onStart = _start
                            ..onUpdate = _update
                            ..onEnd = _end,
                        ),
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: open && !_gone ? () => _settle(0) : null,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [...behind, card],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The card's sideways drag, for a finger that went down off the screen's
/// edges only: one at an edge never enters the arena, so the system's
/// back gesture (B6) has it (review 100 H7).
class _OffEdgeDrag extends HorizontalDragGestureRecognizer {
  _OffEdgeDrag(this.offEdge);

  final bool Function(Offset down) offEdge;

  @override
  bool isPointerAllowed(PointerEvent event) =>
      offEdge(event.position) && super.isPointerAllowed(event);
}
