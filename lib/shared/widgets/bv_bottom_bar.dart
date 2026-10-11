import 'package:flutter/material.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';

/// One tab in [BvBottomBar].
class BvBottomBarItem {
  const BvBottomBarItem({
    required this.key,
    required this.icon,
    required this.label,
  });

  final Key key;

  /// The same glyph is used when the tab is active; only the colour changes.
  final IconData icon;
  final String label;
}

/// The app's bottom bar: four tabs with the Create action in the middle.
/// Matches the Figma component "DS · Navigation / Bottom nav" (2022:18).
///
/// Create is an action (it opens a sheet), never a selected tab. The row
/// follows the reading direction, so in Arabic Home sits on the right.
class BvBottomBar extends StatelessWidget {
  const BvBottomBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    required this.createLabel,
    required this.onCreate,
  }) : assert(items.length == 4);

  /// Tabs in order: two before Create, two after.
  final List<BvBottomBarItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final String createLabel;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final half = items.length ~/ 2;
    Widget tab(int i) => _TabSlot(
      item: items[i],
      selected: i == selectedIndex,
      onTap: () => onSelect(i),
    );

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: BvColors.surfaceElevated,
        border: Border(
          top: BorderSide(
            color: BvColors.borderDefault,
            width: BvSpace.borderWidth,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: BvBottomBarSize.height,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(
              top: BvBottomBarSize.paddingTop,
              start: BvBottomBarSize.paddingSide,
              end: BvBottomBarSize.paddingSide,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < half; i++) tab(i),
                _CreateSlot(label: createLabel, onTap: onCreate),
                for (var i = half; i < items.length; i++) tab(i),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabSlot extends StatelessWidget {
  const _TabSlot({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final BvBottomBarItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: _SlotTap(
        key: item.key,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Kept in the layout when inactive, so icons never jump.
            DecoratedBox(
              key: selected ? const Key('nav-indicator') : null,
              decoration: BoxDecoration(
                color: selected ? BvColors.surfaceSelected : Colors.transparent,
                borderRadius: BvBottomBarSize.indicatorRadius,
              ),
              child: const SizedBox(
                width: BvBottomBarSize.indicatorWidth,
                height: BvBottomBarSize.indicatorHeight,
              ),
            ),
            const SizedBox(height: BvBottomBarSize.gap),
            Icon(
              item.icon,
              color: selected ? BvColors.iconPrimary : BvColors.iconSecondary,
              size: BvSize.iconLg,
            ),
            const SizedBox(height: BvBottomBarSize.gap),
            _Label(
              item.label,
              color: selected ? BvColors.textPrimary : BvColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateSlot extends StatelessWidget {
  const _CreateSlot({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: _SlotTap(
        key: const Key('nav-create'),
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              key: const Key('nav-create-button'),
              width: BvBottomBarSize.createWidth,
              height: BvBottomBarSize.createHeight,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: BvColors.actionPrimary,
                borderRadius: BvRadius.controlAll,
              ),
              child: const Icon(
                BvIcons.create,
                color: BvColors.iconInverse,
                size: BvSize.iconMd,
              ),
            ),
            const SizedBox(height: BvBottomBarSize.gap),
            _Label(label, color: BvColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _SlotTap extends StatelessWidget {
  const _SlotTap({super.key, required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BvRadius.controlAll,
      splashFactory: NoSplash.splashFactory,
      child: SizedBox(
        width: BvBottomBarSize.slotWidth,
        height: BvBottomBarSize.slotHeight,
        child: Center(child: child),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Same weight active and inactive; only the colour changes. Shrinks only
    // when a very large text size would not fit the slot.
    return Flexible(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          maxLines: 1,
          style: BvType.of(context).labelSm.copyWith(color: color),
        ),
      ),
    );
  }
}
