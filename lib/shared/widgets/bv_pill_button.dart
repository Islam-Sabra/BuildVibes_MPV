import 'package:flutter/material.dart';

import '../../core/design/around_specs.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';

/// The Daybook's small round buttons (R1 v4 2556:35480 "Edit profile",
/// "Share"): [soft] is brand-soft with orange words, otherwise a thin
/// outline. The look is 32 high; the touch area is 44.
class BvPillButton extends StatelessWidget {
  const BvPillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.soft = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool soft;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return Semantics(
      button: true,
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
                color: soft ? BvColors.surfaceBrandSoft : null,
                borderRadius: BvRadius.roundAll,
                border: soft
                    ? null
                    : Border.all(
                        color: BvColors.borderDefault,
                        width: BvStroke.thin,
                      ),
              ),
              child: Text(
                label,
                style: type.labelMd.copyWith(
                  color: soft ? BvColors.textAction : BvColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
