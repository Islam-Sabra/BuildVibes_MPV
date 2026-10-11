import 'package:flutter/material.dart';

import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';

/// [action] is the solid badge for counts that need a tap (S1 "1 needs
/// you").
enum BvBadgeTone { neutral, brand, positive, warning, action }

/// Spec §10 ("DS · Avatar & Badge"). An optional [icon] sits before the
/// label in the same colour (E2: "Confirmed by teammates").
class BvBadge extends StatelessWidget {
  const BvBadge({
    super.key,
    required this.label,
    this.tone = BvBadgeTone.neutral,
    this.icon,
  });

  final String label;
  final BvBadgeTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (fill, text) = switch (tone) {
      BvBadgeTone.neutral => (BvColors.surfaceSubtle, BvColors.textSecondary),
      BvBadgeTone.brand => (BvColors.surfaceBrandSoft, BvColors.textAction),
      BvBadgeTone.positive => (BvColors.surfaceSubtle, BvColors.textPositive),
      BvBadgeTone.warning => (BvColors.surfaceSubtle, BvColors.textWarning),
      BvBadgeTone.action => (
        BvColors.actionPrimary,
        BvColors.actionPrimaryForeground,
      ),
    };
    return Container(
      height: BvBadgeSpec.height,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: BvBadgeSpec.paddingHorizontal,
        vertical: BvBadgeSpec.paddingVertical,
      ),
      decoration: BoxDecoration(color: fill, borderRadius: BvBadgeSpec.radius),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: BvSpace.s4,
        children: [
          if (icon != null) Icon(icon, size: BvBadgeSpec.iconSize, color: text),
          Text(
            label,
            maxLines: 1,
            style: BvType.of(context).labelSm.copyWith(color: text),
          ),
        ],
      ),
    );
  }
}
