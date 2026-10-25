import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/haptics.dart';
import 'bv_sheet.dart';
import 'bv_tap_target.dart';

/// Hold to confirm (review 94), for the three actions that can't be taken
/// back: Check, Cancel work item and Remove from Space. Held for
/// [BvMotion.hold], it acts; while held, the fill runs from the start side
/// to the end (right to left in Arabic), a light tick at the start and a
/// firm one at the end. Let go early, the fill runs back and nothing
/// happens; the first [BvHoldSpec.hintTimes] times on a phone, [hint]
/// shows under it.
///
/// With TalkBack or VoiceOver on, a double-tap asks [confirm] instead.
/// With Reduce motion on, nothing moves: the button turns solid at the
/// end of the hold.
class BvHoldButton extends StatefulWidget {
  const BvHoldButton({
    super.key,
    required this.label,
    required this.onConfirmed,
    required this.confirm,
    required this.hint,
    this.icon,
    this.destructive = false,
    this.expand = false,
  });

  /// "Hold to check", "Hold to cancel", "Hold to remove".
  final String label;
  final IconData? icon;
  final VoidCallback onConfirmed;

  /// For a screen reader: asks, and is true to go ahead.
  final Future<bool> Function() confirm;

  /// "Keep holding to confirm".
  final String hint;

  /// Cancel and Remove: in red.
  final bool destructive;

  /// A full-width bar (in a sheet) instead of a pill hugging its words.
  final bool expand;

  @override
  State<BvHoldButton> createState() => _BvHoldButtonState();
}

class _BvHoldButtonState extends State<BvHoldButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fill =
      AnimationController(vsync: this, duration: BvMotion.hold)
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed && _holding) _done();
        });

  /// Reduce motion: the hold's time, with nothing moving.
  Timer? _still;
  bool _holding = false;
  bool _hint = false;

  bool get _reduce => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  bool get _reader => MediaQuery.maybeAccessibleNavigationOf(context) ?? false;

  @override
  void dispose() {
    _still?.cancel();
    _fill.dispose();
    super.dispose();
  }

  void _down() {
    if (_reader) return;
    _holding = true;
    unawaited(bvHaptic(BvHaptic.tick));
    setState(() => _hint = false);
    if (_reduce) {
      // Solid at once at the end: the status listener acts.
      _still = Timer(BvMotion.hold, () {
        if (mounted && _holding) _fill.value = 1;
      });
    } else {
      unawaited(_fill.forward());
    }
  }

  void _up() {
    if (_reader) {
      unawaited(_ask());
      return;
    }
    if (!_holding) {
      // Done: full until the finger lifts, then at rest.
      _fill.value = 0;
      return;
    }
    _holding = false;
    _still?.cancel();
    if (_reduce) {
      _fill.value = 0;
    } else {
      // Back in the same 150 ms however far it got.
      unawaited(_fill.animateBack(0, duration: BvMotion.holdBack));
    }
    unawaited(_early());
  }

  /// The first times on this phone, a line says to keep holding.
  Future<void> _early() async {
    if (await HoldHints.take() && mounted) setState(() => _hint = true);
  }

  void _done() {
    _holding = false;
    unawaited(bvHaptic(BvHaptic.strong));
    widget.onConfirmed();
  }

  Future<void> _ask() async {
    if (await widget.confirm() && mounted) {
      unawaited(bvHaptic(BvHaptic.strong));
      widget.onConfirmed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final red = widget.destructive;
    Widget face(Color background, Color words) {
      final row = Row(
        mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: BvHoldSpec.gap,
        children: [
          if (widget.icon case final icon?)
            Icon(icon, size: BvHoldSpec.icon, color: words),
          Flexible(
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: type.labelMd.copyWith(color: words),
            ),
          ),
        ],
      );
      return Container(
        height: widget.expand ? BvHoldSpec.barHeight : null,
        alignment: widget.expand ? Alignment.center : null,
        padding: const EdgeInsetsDirectional.only(
          start: BvHoldSpec.paddingStart,
          end: BvHoldSpec.paddingEnd,
          top: BvHoldSpec.paddingVertical,
          bottom: BvHoldSpec.paddingVertical,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BvRadius.roundAll,
        ),
        child: row,
      );
    }

    final direction = Directionality.of(context);
    final button = Stack(
      children: [
        face(
          red ? BvColors.holdRestDestructive : BvColors.holdRest,
          red ? BvColors.holdLabelDestructive : BvColors.holdLabel,
        ),
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _fill,
            // Nothing of the fill until the hold begins.
            builder: (context, child) => _fill.value == 0
                ? const SizedBox.shrink()
                : ClipRRect(
                    borderRadius: BvRadius.roundAll,
                    child: ClipRect(
                      clipper: _FromStart(_fill.value, direction),
                      child: child,
                    ),
                  ),
            child: face(
              red ? BvColors.holdFillDestructive : BvColors.holdFill,
              BvColors.holdLabelFilled,
            ),
          ),
        ),
      ],
    );
    final held = Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      onTap: () => unawaited(_ask()),
      child: RawGestureDetector(
        key: const Key('hold-press'),
        behavior: HitTestBehavior.opaque,
        gestures: {
          _HoldRecognizer:
              GestureRecognizerFactoryWithHandlers<_HoldRecognizer>(
                () => _HoldRecognizer(debugOwner: this),
                (r) => r
                  ..onDown = _down
                  ..onUp = _up,
              ),
        },
        child: button,
      ),
    );
    return Column(
      key: const Key('hold-button'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: widget.expand
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.start,
      children: [
        if (widget.expand) held else BvTapTarget(child: held),
        if (_hint)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: BvHoldSpec.hintGap),
            child: Text(
              widget.hint,
              key: const Key('hold-hint'),
              textAlign: widget.expand ? TextAlign.center : TextAlign.start,
              style: type.labelSm.copyWith(color: BvColors.textSecondary),
            ),
          ),
      ],
    );
  }
}

/// A short sheet that asks with [title] and [body], answered by holding
/// [label] (review 94): from a menu, where a button can't be held in
/// place. True once held. With a screen reader, the sheet is the question:
/// a double-tap on the button answers it.
Future<bool> showBvHoldSheet(
  BuildContext context, {
  required String title,
  required String body,
  required String label,
  required String hint,
  IconData? icon,
  bool destructive = false,
}) async =>
    await showBvSheet<bool>(
      context: context,
      title: title,
      builder: (sheet) => Column(
        key: const Key('hold-sheet'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BvHoldSpec.sheetGap,
        children: [
          Text(
            body,
            style: BvType.of(
              sheet,
            ).bodyMd.copyWith(color: BvColors.textSecondary),
          ),
          BvHoldButton(
            label: label,
            icon: icon,
            hint: hint,
            destructive: destructive,
            expand: true,
            onConfirmed: () => Navigator.of(sheet).pop(true),
            confirm: () async => true,
          ),
        ],
      ),
    ) ??
    false;

/// The part of the button the fill has reached, from the start side.
class _FromStart extends CustomClipper<Rect> {
  const _FromStart(this.t, this.direction);

  final double t;
  final TextDirection direction;

  @override
  Rect getClip(Size size) {
    final w = size.width * t;
    return direction == TextDirection.rtl
        ? Rect.fromLTWH(size.width - w, 0, w, size.height)
        : Rect.fromLTWH(0, 0, w, size.height);
  }

  @override
  bool shouldReclip(_FromStart old) => old.t != t || old.direction != direction;
}

/// Takes the finger at once, so neither the page's scroll nor a card's
/// long-press menu cuts a hold short; a finger that wanders off lets go.
class _HoldRecognizer extends OneSequenceGestureRecognizer {
  _HoldRecognizer({super.debugOwner});

  VoidCallback? onDown;
  VoidCallback? onUp;
  Offset? _start;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    _start = event.position;
    resolve(GestureDisposition.accepted);
    onDown?.call();
  }

  @override
  void handleEvent(PointerEvent event) {
    final start = _start;
    if (start == null) return;
    if (event is PointerUpEvent ||
        event is PointerCancelEvent ||
        (event is PointerMoveEvent &&
            (event.position - start).distance > BvHoldSpec.slop)) {
      _start = null;
      stopTrackingPointer(event.pointer);
      onUp?.call();
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'hold';
}

/// How many times this phone has said "Keep holding to confirm".
abstract final class HoldHints {
  static const _key = 'hold_hints_shown';

  /// True (and counted) while it has said so fewer than
  /// [BvHoldSpec.hintTimes] times.
  static Future<bool> take() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shown = prefs.getInt(_key) ?? 0;
      if (shown >= BvHoldSpec.hintTimes) return false;
      await prefs.setInt(_key, shown + 1);
      return true;
    } on Object {
      return false;
    }
  }
}
