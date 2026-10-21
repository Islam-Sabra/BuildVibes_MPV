import 'package:flutter/material.dart';

import '../../core/design/around_specs.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';

/// The Daybook's small round buttons (R1 v4 2556:35480 "Edit profile",
/// "Share"): [soft] is brand-soft with orange words, otherwise a thin
/// outline. The look is 32 high; the touch area is 44. With no [onTap]
/// it is grey and does nothing (P2 "Choose a pass").
class BvPillButton extends StatelessWidget {
  const BvPillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.soft = true,
  });

  final String label;
  final VoidCallback? onTap;
  final bool soft;

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
                color: off
                    ? BvColors.surfaceSubtle
                    : soft
                    ? BvColors.surfaceBrandSoft
                    : null,
                borderRadius: BvRadius.roundAll,
                border: soft || off
                    ? null
                    : Border.all(
                        color: BvColors.borderDefault,
                        width: BvStroke.thin,
                      ),
              ),
              child: Text(
                label,
                style: type.labelMd.copyWith(
                  color: off
                      ? BvColors.textSecondary
                      : soft
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
