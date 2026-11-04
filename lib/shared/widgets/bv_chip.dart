import 'package:flutter/material.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart' show metaDot;
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
    this.danger = false,
    this.tight = false,
  });

  /// Less room at its sides, the type unchanged: for a row of choices
  /// that must share one line.
  final bool tight;

  final String label;
  final bool selected;
  final bool ink;

  /// Review 110 TG1: chosen, a danger choice (Safety) is red, with a
  /// check at its end.
  final bool danger;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final inkOn = ink && selected;
    final red = danger && selected;
    final fill = inkOn
        ? BvColors.brandInk
        : red
        ? BvColors.surfaceDestructiveSoft
        : selected
        ? BvColors.surfaceBrandSoft
        : BvColors.surfaceElevated;
    final border = inkOn
        ? BvColors.brandInk
        : red
        ? BvColors.borderDestructive
        : selected
        ? BvColors.borderSelected
        : BvColors.borderDefault;
    final text = inkOn
        ? BvColors.textInverse
        : red
        ? BvColors.textDestructive
        : BvColors.textPrimary;

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
            padding: EdgeInsetsDirectional.symmetric(
              horizontal: tight
                  ? BvChipSpec.paddingHorizontalTight
                  : BvChipSpec.paddingHorizontal,
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
                if (red)
                  Icon(BvIcons.check, size: BvChipSpec.iconSize, color: text),
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
    this.onTap,
    this.danger = false,
    this.detail,
  });

  final String label;
  final String clearLabel;

  /// Facts after the label ("Scanned · 3 pages · 74 KB"): always in full;
  /// only the label shortens with "…" (the lead's check of review 103, D24).
  final String? detail;

  /// Review 110 TG1: a danger tag (Safety) shows red.
  final bool danger;
  final VoidCallback onClear;
  final IconData? icon;
  final Key? clearKey;

  /// A tap on its words changes it (review 110 CP4: the place, the due).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: danger
          ? BvColors.surfaceDestructiveSoft
          : BvColors.surfaceBrandSoft,
      borderRadius: BvRadius.controlAll,
      border: Border.all(
        color: danger ? BvColors.borderDestructive : BvColors.borderSelected,
        width: BvStroke.thin,
      ),
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
          Flexible(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: LayoutBuilder(
                builder: (context, box) {
                  final style = BvType.of(context).labelMd.copyWith(
                    color: danger
                        ? BvColors.textDestructive
                        : BvColors.textPrimary,
                  );
                  final facts = detail == null ? null : '$metaDot $detail';
                  final words = Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: style,
                  );
                  // D24: beside the name when they fit, under it when they
                  // don't; never cut.
                  final beside =
                      facts == null ||
                      _width(context, facts, style) +
                              (icon == null
                                  ? 0
                                  : BvChipSpec.iconSize + BvChipSpec.gap) +
                              BvChipSpec.gap +
                              BvChipSpec.nameMin <=
                          box.maxWidth;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: BvChipSpec.gap,
                    children: [
                      if (icon != null)
                        Icon(
                          icon,
                          size: BvChipSpec.iconSize,
                          color: danger
                              ? BvColors.textDestructive
                              : BvColors.textPrimary,
                        ),
                      if (beside) ...[
                        Flexible(child: words),
                        if (facts != null)
                          Text(facts, maxLines: 1, style: style),
                      ] else
                        Flexible(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              words,
                              Text(detail!, style: style),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
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

/// How wide [text] is on one line, as the chip would draw it.
double _width(BuildContext context, String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    maxLines: 1,
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}
