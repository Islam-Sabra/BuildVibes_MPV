import 'package:flutter/material.dart';

import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';

/// Spec §3: top tabs, for example Home's Feed / Spaces.
class BvTabs extends StatelessWidget {
  const BvTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    // Scrolls sideways when the tabs don't fit (long Arabic labels, large
    // text sizes).
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Semantics(
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
                          widthFactor: 1,
                          child: Text(
                            labels[i],
                            maxLines: 1,
                            style: i == selectedIndex
                                ? type.labelLg.copyWith(
                                    color: BvColors.textPrimary,
                                  )
                                : type.labelMd.copyWith(
                                    color: BvColors.textSecondary,
                                  ),
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
            ),
        ],
      ),
    );
  }
}
