import 'package:flutter/material.dart';

import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_writing_specs.dart';

/// One choice on a [BvIconGrid]: its icon and its name.
class BvIconGridItem {
  const BvIconGridItem({
    required this.id,
    required this.icon,
    required this.label,
    this.selected = false,
  });

  final String id;
  final IconData icon;
  final String label;
  final bool selected;
}

/// Review 110 CP2, CP3 (2707:39412, 2707:39502): a grid of round icons
/// with their names under them, like a phone's attach menu, in place of
/// the keyboard, under [title]. [columns] to a row; at the largest text
/// sizes [largeColumns], so names never break mid-word. The circles and
/// names grow with the phone's text size; the chosen one is a filled
/// brand circle with a white icon. Rows start at the start (right in
/// Arabic). Each tile is keyed "[keyPrefix]-[id]".
class BvIconGrid extends StatelessWidget {
  const BvIconGrid({
    super.key,
    required this.title,
    required this.items,
    required this.keyPrefix,
    required this.onSelected,
    required this.columns,
    required this.largeColumns,
  });

  final String title;
  final List<BvIconGridItem> items;
  final String keyPrefix;
  final ValueChanged<String> onSelected;
  final int columns;
  final int largeColumns;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final large =
        MediaQuery.textScalerOf(context).scale(1) >= BvIconGridSpec.largeFrom;
    final perRow = large ? largeColumns : columns;
    return ColoredBox(
      color: BvColors.surfaceApp,
      child: SingleChildScrollView(
        padding: BvIconGridSpec.padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: BvIconGridSpec.titleGap,
          children: [
            Text(
              title,
              style: type.metadata.copyWith(color: BvColors.textSecondary),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth / perRow;
                return Wrap(
                  runSpacing: BvIconGridSpec.rowGap,
                  children: [
                    for (final i in items)
                      SizedBox(
                        width: width,
                        child: BvIconGridTile(
                          key: Key('$keyPrefix-${i.id}'),
                          circleKey: Key('$keyPrefix-${i.id}-circle'),
                          item: i,
                          selected: i.selected,
                          onTap: () => onSelected(i.id),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// A round icon with its name under it (up to 2 lines, centred).
class BvIconGridTile extends StatelessWidget {
  const BvIconGridTile({
    super.key,
    required this.item,
    required this.selected,
    required this.onTap,
    this.circleKey,
  });

  /// At the phone's usual text size.
  static const circle = BvIconGridSpec.circle;

  final BvIconGridItem item;
  final bool selected;
  final VoidCallback onTap;
  final Key? circleKey;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final type = BvType.of(context);
    final size = scaler.scale(circle);
    final icon = scaler.scale(BvIconGridSpec.icon);
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BvRadius.controlAll,
        splashFactory: NoSplash.splashFactory,
        child: Padding(
          padding: BvIconGridSpec.tilePadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: BvIconGridSpec.labelGap,
            children: [
              Container(
                key: circleKey,
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? BvColors.actionPrimary
                      : BvColors.surfaceElevated,
                  border: selected
                      ? null
                      : Border.all(
                          color: BvColors.borderDefault,
                          width: BvStroke.thin,
                        ),
                ),
                child: Icon(
                  item.icon,
                  size: icon,
                  color: selected
                      ? BvColors.actionPrimaryForeground
                      : BvColors.iconPrimary,
                ),
              ),
              Text(
                item.label,
                maxLines: BvIconGridSpec.labelLines,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: (selected ? type.emphasisSm : type.metadata).copyWith(
                  color: selected ? BvColors.textAction : BvColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
