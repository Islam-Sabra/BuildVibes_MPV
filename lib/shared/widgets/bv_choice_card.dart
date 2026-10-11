import 'package:flutter/material.dart';

import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import 'bv_badge.dart';
import 'bv_controls.dart';

/// Spec §8. Use it for every set of choices that exclude each other (rule 6),
/// never switches. [BvChoiceList] builds a whole set.
class BvChoiceCard extends StatelessWidget {
  const BvChoiceCard({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.description,
    this.icon,
    this.badge,
  });

  final String title;
  final String? description;
  final IconData? icon;
  final bool selected;

  /// Null shows the card as not available.
  final VoidCallback? onTap;

  /// A short tag after the title, such as "Coming soon".
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      enabled: onTap != null,
      child: Material(
        color: onTap == null
            ? BvColors.surfaceSubtle
            : selected
            ? BvColors.surfaceBrandSoft
            : BvColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BvRadius.cardAll,
          side: selected
              ? const BorderSide(
                  color: BvColors.borderSelected,
                  width: BvStroke.thick,
                )
              : const BorderSide(
                  color: BvColors.borderDefault,
                  width: BvStroke.thin,
                ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BvRadius.cardAll,
          splashFactory: NoSplash.splashFactory,
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: BvChoiceCardSpec.paddingHorizontal,
              vertical: BvChoiceCardSpec.paddingVertical,
            ),
            child: Row(
              spacing: BvChoiceCardSpec.gap,
              children: [
                if (icon != null)
                  Icon(
                    icon,
                    size: BvChoiceCardSpec.iconSize,
                    color: selected
                        ? BvColors.iconAction
                        : BvColors.iconSecondary,
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    spacing: BvSpace.s2,
                    children: [
                      Wrap(
                        spacing: BvSpace.s8,
                        runSpacing: BvSpace.s4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            title,
                            style: type.titleMd.copyWith(
                              color: onTap == null
                                  ? BvColors.textSecondary
                                  : BvColors.textPrimary,
                            ),
                          ),
                          if (badge != null) BvBadge(label: badge!),
                        ],
                      ),
                      if (description != null)
                        Text(
                          description!,
                          style: type.bodySm.copyWith(
                            color: BvColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                // The card handles the tap; the radio only shows the state.
                if (onTap != null)
                  ExcludeSemantics(child: BvRadio(selected: selected)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BvChoiceOption<T> {
  const BvChoiceOption({
    required this.value,
    required this.title,
    this.description,
    this.icon,
    this.key,
    this.enabled = true,
    this.badge,
  });

  final T value;
  final String title;
  final String? description;
  final IconData? icon;
  final Key? key;
  final bool enabled;
  final String? badge;
}

/// A single-choice list of [BvChoiceCard]s.
class BvChoiceList<T> extends StatelessWidget {
  const BvChoiceList({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<BvChoiceOption<T>> options;
  final T? value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BvChoiceCardSpec.listGap,
      children: [
        for (final o in options)
          BvChoiceCard(
            key: o.key,
            title: o.title,
            description: o.description,
            icon: o.icon,
            badge: o.badge,
            selected: o.value == value,
            onTap: o.enabled ? () => onChanged(o.value) : null,
          ),
      ],
    );
  }
}
