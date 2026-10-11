import 'package:flutter/material.dart';

import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';

enum BvBadgeTone { neutral, brand, positive, warning }

/// Spec §10 ("DS · Avatar & Badge").
class BvBadge extends StatelessWidget {
  const BvBadge({
    super.key,
    required this.label,
    this.tone = BvBadgeTone.neutral,
  });

  final String label;
  final BvBadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final (fill, text) = switch (tone) {
      BvBadgeTone.neutral => (BvColors.surfaceSubtle, BvColors.textSecondary),
      BvBadgeTone.brand => (BvColors.surfaceBrandSoft, BvColors.textAction),
      BvBadgeTone.positive => (BvColors.surfaceSubtle, BvColors.textPositive),
      BvBadgeTone.warning => (BvColors.surfaceSubtle, BvColors.textWarning),
    };
    return Container(
      height: BvBadgeSpec.height,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: BvBadgeSpec.paddingHorizontal,
        vertical: BvBadgeSpec.paddingVertical,
      ),
      decoration: BoxDecoration(color: fill, borderRadius: BvBadgeSpec.radius),
      child: Text(
        label,
        maxLines: 1,
        style: BvType.of(context).labelSm.copyWith(color: text),
      ),
    );
  }
}
