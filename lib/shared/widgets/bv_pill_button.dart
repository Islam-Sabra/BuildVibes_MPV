import 'package:flutter/material.dart';

import '../../core/design/around_specs.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';

/// The Daybook's small round buttons (R1 v4 2556:35480 "Edit profile",
/// "Share"): [soft] is brand-soft with orange words, otherwise a thin
/// outline. The look is 32 high; the touch area is 44. With no [onTap]
/// it is grey and does nothing (P2 "Choose a pass"). Review 105 SP8: a
/// [strong] one is the action colour with white words (Confirm); a [quiet]
/// one grey with grey words (Decline). Review 108 PL2: a [grey] one is
/// grey with dark words (Edit).
class BvPillButton extends StatelessWidget {
  const BvPillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.soft = true,
    this.strong = false,
    this.quiet = false,
    this.grey = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool soft;
  final bool strong;
  final bool quiet;
  final bool grey;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final off = onTap == null;
    return Semantics(
      button: true,
      enabled: !off,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: BvSize.controlMd),
          child: Center(
            widthFactor: 1,
            child: Container(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: BvProfileHeadSpec.pillPaddingHorizontal,
                vertical: BvProfileHeadSpec.pillPaddingVertical,
              ),
              decoration: BoxDecoration(
                color: off || quiet || grey
                    ? BvColors.surfaceSubtle
                    : strong
                    ? BvColors.actionPrimary
                    : soft
                    ? BvColors.surfaceBrandSoft
                    : null,
                borderRadius: BvRadius.roundAll,
                border: soft || off || strong || quiet || grey
                    ? null
                    : Border.all(
                        color: BvColors.borderDefault,
                        width: BvStroke.thin,
                      ),
              ),
              child: Text(
                label,
                style: (strong ? type.emphasis : type.labelMd).copyWith(
                  color: off || quiet
                      ? BvColors.textSecondary
                      : strong
                      ? BvColors.actionPrimaryForeground
                      : soft && !grey
                      ? BvColors.textAction
                      : BvColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
