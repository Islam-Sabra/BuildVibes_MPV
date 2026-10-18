import 'package:flutter/material.dart';

import '../../core/design/around_specs.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';

/// Spec §3: top tabs. [BvTabs.small] are the Daybook's (H1 v3 Feed /
/// Spaces, R1 v4 the profile's tabs): small labels at the start, a short
/// line under the chosen one, no line under the row.
class BvTabs extends StatelessWidget {
  const BvTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelect,
    this.fill = false,
    this.dots = const {},
  }) : small = false;

  const BvTabs.small({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelect,
    this.dots = const {},
  }) : fill = false,
       small = true;

  final bool small;

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  /// Each tab takes an equal share of the width (Home: Feed | Spaces, H1e).
  /// Otherwise tabs fit their labels and scroll sideways when needed.
  final bool fill;

  /// Tabs with something new: an orange dot after the label, hidden while
  /// that tab is open. Never a number.
  final Set<int> dots;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    if (small) return _small(type);
    Widget tab(int i) => Semantics(
      button: true,
      selected: i == selectedIndex,
      child: InkWell(
        key: Key('tab-$i'),
        onTap: () => onSelect(i),
        splashFactory: NoSplash.splashFactory,
        child: SizedBox(
          height: BvTabsSpec.height,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: BvTabsSpec.paddingHorizontal,
                ),
                child: Center(
                  // Filled tabs centre the label in their share.
                  widthFactor: fill ? null : 1,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: BvSpace.s4,
                    children: [
                      Text(
                        labels[i],
                        maxLines: 1,
                        style: i == selectedIndex
                            ? type.labelLg.copyWith(color: BvColors.textPrimary)
                            : type.labelMd.copyWith(
                                color: BvColors.textSecondary,
                              ),
                      ),
                      if (dots.contains(i) && i != selectedIndex)
                        BvNewDot(key: Key('tab-dot-$i')),
                    ],
                  ),
                ),
              ),
              if (i == selectedIndex)
                const PositionedDirectional(
                  start: 0,
                  end: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    key: Key('tab-indicator'),
                    decoration: BoxDecoration(
                      color: BvColors.surfaceSelected,
                      borderRadius: BvTabsSpec.indicatorRadius,
                    ),
                    child: SizedBox(height: BvTabsSpec.indicatorHeight),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (fill) {
      return Row(
        children: [
          for (var i = 0; i < labels.length; i++) Expanded(child: tab(i)),
        ],
      );
    }
    // Scrolls sideways when the tabs don't fit (long Arabic labels, large
    // text sizes).
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [for (var i = 0; i < labels.length; i++) tab(i)]),
    );
  }
}

extension on BvTabs {
  Widget _small(BvTypeSet type) {
    Widget tab(int i) {
      final selected = i == selectedIndex;
      return Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          key: Key('tab-$i'),
          behavior: HitTestBehavior.opaque,
          onTap: () => onSelect(i),
          // The look is small; the touch area is 44 high.
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: BvSize.controlMd),
            child: Padding(
              padding: const EdgeInsetsDirectional.only(
                top: BvSmallTabsSpec.paddingTop,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: BvSmallTabsSpec.lineGap,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: BvSpace.s4,
                    children: [
                      Text(
                        labels[i],
                        maxLines: 1,
                        style: type.labelMd.copyWith(
                          color: selected
                              ? BvColors.textPrimary
                              : BvColors.textSecondary,
                        ),
                      ),
                      if (dots.contains(i) && !selected)
                        BvNewDot(key: Key('tab-dot-$i')),
                    ],
                  ),
                  DecoratedBox(
                    key: selected ? const Key('tab-indicator') : null,
                    decoration: BoxDecoration(
                      color: selected ? BvColors.actionPrimary : null,
                      borderRadius: BvSmallTabsSpec.lineRadius,
                    ),
                    child: const SizedBox(
                      width: BvSmallTabsSpec.lineWidth,
                      height: BvSmallTabsSpec.lineHeight,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: BvSmallTabsSpec.paddingHorizontal,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: BvSmallTabsSpec.gap,
        children: [for (var i = 0; i < labels.length; i++) tab(i)],
      ),
    );
  }
}

/// The orange "something new" dot. Never a number.
class BvNewDot extends StatelessWidget {
  const BvNewDot({super.key});

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      color: BvColors.iconAction,
      shape: BoxShape.circle,
    ),
    child: SizedBox.square(dimension: BvActivitySpec.newDot),
  );
}
