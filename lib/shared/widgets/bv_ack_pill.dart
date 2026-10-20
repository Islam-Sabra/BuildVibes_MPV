import 'package:flutter/material.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_kinds_specs.dart';
import 'bv_tap_target.dart';

/// How a [BvAckPill] looks.
enum BvAckPillTone {
  /// The brand-soft pill: Got it, Received, Add to my calendar
  /// (2594:36097).
  soft,

  /// The full orange fill, the screen's main action: On my way on the
  /// activity's day (2594:77465, daybook rule 6).
  primary,

  /// Already said: the same words with a check, quiet on the subtle
  /// surface. A tap takes it back.
  done,
}

/// A post's one action for the reader, as a round pill with a 48-point
/// target: Got it on an announcement, Received on a file, Add to my
/// calendar and On my way on an activity.
class BvAckPill extends StatelessWidget {
  const BvAckPill({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.tone = BvAckPillTone.soft,
  });

  final String label;
  final IconData? icon;
  final BvAckPillTone tone;

  /// Null: not now (read only).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final (fill, ink) = switch (tone) {
      BvAckPillTone.soft => (BvColors.surfaceBrandSoft, BvColors.textAction),
      BvAckPillTone.primary => (
        BvColors.actionPrimary,
        BvColors.actionPrimaryForeground,
      ),
      BvAckPillTone.done => (BvColors.surfaceSubtle, BvColors.textSecondary),
    };
    final shownIcon = tone == BvAckPillTone.done ? BvIcons.check : icon;
    final primary = tone == BvAckPillTone.primary;
    final pill = Container(
      padding: EdgeInsetsDirectional.only(
        start: primary
            ? BvAckPillSpec.paddingPrimary
            : BvAckPillSpec.paddingStart,
        end: primary ? BvAckPillSpec.paddingPrimary : BvAckPillSpec.paddingEnd,
        top: BvAckPillSpec.paddingVertical,
        bottom: BvAckPillSpec.paddingVertical,
      ),
      decoration: BoxDecoration(color: fill, borderRadius: BvRadius.roundAll),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: BvAckPillSpec.gap,
        children: [
          if (shownIcon != null)
            Icon(shownIcon, size: BvAckPillSpec.icon, color: ink),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: type.labelLg.copyWith(color: ink),
            ),
          ),
        ],
      ),
    );
    return BvTapTarget(
      child: Semantics(
        button: true,
        enabled: onTap != null,
        selected: tone == BvAckPillTone.done,
        child: GestureDetector(
          key: const Key('ack-pill'),
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: pill,
        ),
      ),
    );
  }
}
