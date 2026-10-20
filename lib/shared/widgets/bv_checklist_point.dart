import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_kinds_specs.dart';
import '../../core/l10n/bv_time.dart';
import 'bv_avatar.dart';
import 'bv_clock_text.dart';

/// Who ticked a point, and when: their face and the time at the end.
typedef BvTick = ({String name, Color? tint, BvClockParts time});

/// One point of a checklist on its card (K1 v13 2594:36130): a box, the
/// words, and once ticked the box filled green, the words struck through
/// and grey, then who ticked it and when. A whole 48-point row is the
/// target. [onTap] null: read only (a Viewer, or a point not yours to
/// untick).
///
/// F54, a tick you can feel: your own tap gives a light haptic, the box
/// fills with its check and who and when slide in (an un-tick runs it
/// back). A tick or an un-tick that arrives from someone else glows softly
/// in the action colour, then fades. With the phone's animations off it
/// all shows at once and nothing glows; the haptic stays.
class BvChecklistPoint extends StatefulWidget {
  const BvChecklistPoint({
    super.key,
    required this.text,
    this.tick,
    this.onTap,
  });

  final String text;

  /// Null while unticked.
  final BvTick? tick;
  final VoidCallback? onTap;

  @override
  State<BvChecklistPoint> createState() => _BvChecklistPointState();
}

class _BvChecklistPointState extends State<BvChecklistPoint>
    with SingleTickerProviderStateMixin {
  late final _glow = AnimationController(
    vsync: this,
    duration: BvChecklistSpec.glowHold + BvChecklistSpec.glowFade,
  );
  late final Animation<double> _glowOpacity = TweenSequence<double>([
    TweenSequenceItem(
      tween: ConstantTween(1),
      weight: BvChecklistSpec.glowHold.inMilliseconds.toDouble(),
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1,
        end: 0,
      ).chain(CurveTween(curve: BvMotion.exit)),
      weight: BvChecklistSpec.glowFade.inMilliseconds.toDouble(),
    ),
  ]).animate(_glow);

  /// The next change is the reader's own tap, not someone else's.
  var _tapped = false;

  bool get _ticked => widget.tick != null;

  @override
  void didUpdateWidget(BvChecklistPoint old) {
    super.didUpdateWidget(old);
    if ((old.tick != null) == _ticked) return;
    if (_tapped) {
      _tapped = false;
    } else if (!MediaQuery.disableAnimationsOf(context)) {
      _glow.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  void _onTap() {
    unawaited(HapticFeedback.lightImpact());
    _tapped = true;
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final tick = widget.tick;
    final ticked = tick != null;
    final still = MediaQuery.disableAnimationsOf(context);
    final duration = still ? Duration.zero : BvChecklistSpec.tick;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: BvChecklistSpec.rowMinHeight,
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          vertical: BvChecklistSpec.rowPaddingVertical,
        ),
        child: Row(
          spacing: BvChecklistSpec.rowGap,
          children: [
            _Box(ticked: ticked, duration: duration),
            Expanded(
              child: Text(
                widget.text,
                style: type.bodyMd.copyWith(
                  color: ticked ? BvColors.textSecondary : BvColors.textPrimary,
                  decoration: ticked ? TextDecoration.lineThrough : null,
                  decorationColor: BvColors.textSecondary,
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: duration,
              switchInCurve: BvMotion.enter,
              switchOutCurve: BvMotion.exit,
              transitionBuilder: (child, animation) {
                final from = Directionality.of(context) == TextDirection.rtl
                    ? -BvChecklistSpec.tickSlide
                    : BvChecklistSpec.tickSlide;
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween(
                      begin: Offset(from, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: tick == null
                  ? const SizedBox.shrink()
                  : Row(
                      key: const Key('checklist-tick'),
                      mainAxisSize: MainAxisSize.min,
                      spacing: BvChecklistSpec.rowGap,
                      children: [
                        ExcludeSemantics(
                          child: BvAvatar(
                            name: tick.name,
                            size: BvAvatarSize.note,
                            tint: tick.tint,
                          ),
                        ),
                        BvClockText(
                          tick.time,
                          style: type.metadata.copyWith(
                            color: BvColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
    return Semantics(
      checked: ticked,
      enabled: widget.onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap == null ? null : _onTap,
        child: AnimatedBuilder(
          animation: _glow,
          builder: (context, child) => DecoratedBox(
            key: const Key('checklist-glow'),
            decoration: BoxDecoration(
              color: _glow.isAnimating
                  ? BvColors.surfaceBrandSoft.withValues(
                      alpha: _glowOpacity.value,
                    )
                  : null,
              borderRadius: BvChecklistSpec.glowRadius,
            ),
            child: child,
          ),
          child: row,
        ),
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.ticked, required this.duration});

  final bool ticked;
  final Duration duration;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    key: const Key('checklist-box'),
    duration: duration,
    curve: BvMotion.standard,
    width: BvChecklistSpec.box,
    height: BvChecklistSpec.box,
    decoration: BoxDecoration(
      color: ticked ? BvColors.feedbackSuccess : BvColors.surfaceElevated,
      borderRadius: BvChecklistSpec.boxRadius,
      border: Border.all(
        color: ticked ? BvColors.feedbackSuccess : BvColors.borderDefault,
        width: BvChecklistSpec.boxBorder,
      ),
    ),
    child: AnimatedSwitcher(
      duration: duration,
      switchInCurve: BvMotion.enter,
      switchOutCurve: BvMotion.exit,
      transitionBuilder: (child, animation) =>
          ScaleTransition(scale: animation, child: child),
      child: ticked
          ? const Icon(
              BvIcons.check,
              key: Key('checklist-check'),
              size: BvChecklistSpec.boxCheck,
              color: BvColors.textInverse,
            )
          : const SizedBox.shrink(),
    ),
  );
}

/// A checklist's progress (2594:36125): a thin green line and "2 of 5
/// ticked", the one count the Daybook shows. It counts the checklist's
/// own points, so it is progress, not a quality signal (rule 3).
class BvChecklistProgress extends StatelessWidget {
  const BvChecklistProgress({
    super.key,
    required this.ticked,
    required this.total,
    required this.label,
  });

  final int ticked;
  final int total;

  /// "2 of 5 ticked".
  final String label;

  @override
  Widget build(BuildContext context) {
    final share = total == 0 ? 0.0 : (ticked / total).clamp(0.0, 1.0);
    return Row(
      spacing: BvChecklistSpec.progressGap,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BvChecklistSpec.progressRadius,
            child: SizedBox(
              height: BvChecklistSpec.progressHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: BvColors.borderSubtle),
                  FractionallySizedBox(
                    key: const Key('checklist-progress'),
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: share,
                    child: const ColoredBox(color: BvColors.feedbackSuccess),
                  ),
                ],
              ),
            ),
          ),
        ),
        Text(
          label,
          style: BvType.of(
            context,
          ).labelSm.copyWith(color: BvColors.textSecondary),
        ),
      ],
    );
  }
}
