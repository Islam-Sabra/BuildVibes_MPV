import 'package:flutter/material.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';

/// "New ↓": new entries came in at Now while the reader was up in older
/// ones. A tap goes to Now (F11). [below] is the Daybook, whose Now is at
/// the bottom; the Home feed's Now is at the top.
class BvNewChip extends StatelessWidget {
  const BvNewChip({
    super.key,
    required this.label,
    required this.onTap,
    this.below = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool below;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    // A 48 tap area around the 32 chip.
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          vertical: BvNewChipSpec.tapPadding,
        ),
        child: Container(
          height: BvNewChipSpec.height,
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: BvNewChipSpec.paddingHorizontal,
          ),
          decoration: const ShapeDecoration(
            color: BvColors.brandInk,
            shape: StadiumBorder(),
            shadows: BvShadow.popover,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: BvNewChipSpec.gap,
            children: [
              Text(
                label,
                style: BvType.of(
                  context,
                ).labelMd.copyWith(color: BvColors.textInverse),
              ),
              Icon(
                below ? BvIcons.newBelow : BvIcons.newAbove,
                size: BvNewChipSpec.icon,
                color: BvColors.iconInverse,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
