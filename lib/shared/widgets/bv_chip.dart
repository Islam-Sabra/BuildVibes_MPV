import 'package:flutter/material.dart';

import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';

/// Spec §2 ("DS · Chip & Tab").
///
/// [ink] is for the "All" filter: when it is selected it turns ink instead
/// of brand-soft.
class BvChip extends StatelessWidget {
  const BvChip({
    super.key,
    required this.label,
    this.selected = false,
    this.ink = false,
    this.icon,
    this.onTap,
  });

  final String label;
  final bool selected;
  final bool ink;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final inkOn = ink && selected;
    final fill = inkOn
        ? BvColors.brandInk
        : selected
        ? BvColors.surfaceBrandSoft
        : BvColors.surfaceElevated;
    final border = inkOn
        ? BvColors.brandInk
        : selected
        ? BvColors.borderSelected
        : BvColors.borderDefault;
    final text = inkOn ? BvColors.textInverse : BvColors.textPrimary;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: BvRadius.controlAll,
          side: BorderSide(color: border, width: BvStroke.thin),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BvRadius.controlAll,
          splashFactory: NoSplash.splashFactory,
          child: Container(
            height: BvChipSpec.height,
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: BvChipSpec.paddingHorizontal,
              vertical: BvChipSpec.paddingVertical,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: BvChipSpec.gap,
              children: [
                if (icon != null)
                  Icon(icon, size: BvChipSpec.iconSize, color: text),
                Text(
                  label,
                  maxLines: 1,
                  style: BvType.of(context).labelMd.copyWith(color: text),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A row of chips that scrolls sideways, with the screen gutter at both ends.
class BvChipRow extends StatelessWidget {
  const BvChipRow({super.key, required this.chips});

  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: BvSpace.gutter,
      ),
      child: Row(spacing: BvChipSpec.rowGap, children: chips),
    );
  }
}
