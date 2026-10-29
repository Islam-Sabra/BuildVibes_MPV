import 'package:flutter/material.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import 'bv_tap_target.dart';

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
            // At least the spec's height; taller when the phone's text is
            // larger.
            constraints: const BoxConstraints(minHeight: BvChipSpec.height),
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
                // Shortened with "…" rather than cut off where space is
                // tight.
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BvType.of(context).labelMd.copyWith(color: text),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A filter in force, as a chip (review 105C: Work for one place): the
/// selected look with its icon and words, and ✕ at its end, which takes
/// the filter off ([onClear], said [clearLabel]).
class BvFilterChip extends StatelessWidget {
  const BvFilterChip({
    super.key,
    required this.label,
    required this.clearLabel,
    required this.onClear,
    this.icon,
    this.clearKey,
  });

  final String label;
  final String clearLabel;
  final VoidCallback onClear;
  final IconData? icon;
  final Key? clearKey;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: BvColors.surfaceBrandSoft,
      borderRadius: BvRadius.controlAll,
      border: Border.all(color: BvColors.borderSelected, width: BvStroke.thin),
    ),
    child: Container(
      constraints: const BoxConstraints(minHeight: BvChipSpec.height),
      padding: const EdgeInsetsDirectional.only(
        start: BvChipSpec.paddingHorizontal,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: BvChipSpec.gap,
        children: [
          if (icon != null)
            Icon(icon, size: BvChipSpec.iconSize, color: BvColors.textPrimary),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BvType.of(
                context,
              ).labelMd.copyWith(color: BvColors.textPrimary),
            ),
          ),
          Semantics(
            button: true,
            label: clearLabel,
            excludeSemantics: true,
            child: BvTapTarget(
              child: InkWell(
                key: clearKey,
                onTap: onClear,
                borderRadius: BvRadius.controlAll,
                child: const Padding(
                  padding: EdgeInsetsDirectional.symmetric(
                    horizontal: BvSpace.s8,
                  ),
                  child: Icon(
                    BvIcons.close,
                    size: BvChipSpec.iconSize,
                    color: BvColors.iconSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
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
