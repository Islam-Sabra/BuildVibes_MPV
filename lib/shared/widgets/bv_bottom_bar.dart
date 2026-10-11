import 'package:flutter/material.dart';

import '../../core/design/bv_tokens.dart';

/// One tab in [BvBottomBar].
class BvBottomBarItem {
  const BvBottomBarItem({
    required this.key,
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final Key key;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// The app's bottom bar: four tabs with the Create action in the middle.
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
    Widget tab(int i) => Expanded(
      child: _TabSlot(
        item: items[i],
        selected: i == selectedIndex,
        onTap: () => onSelect(i),
      ),
    );

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: BvColors.surfaceElevated,
        border: Border(
          top: BorderSide(
            color: BvColors.borderSubtle,
            width: BvSpace.borderWidth,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: BvSpace.s4,
            vertical: BvSpace.s6,
          ),
          child: Row(
            children: [
              for (var i = 0; i < half; i++) tab(i),
              Expanded(
                child: _CreateSlot(label: createLabel, onTap: onCreate),
              ),
              for (var i = half; i < items.length; i++) tab(i),
            ],
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
    final color = selected ? BvColors.brandEnergy : BvColors.iconSecondary;
    final type = BvType.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: _SlotTap(
        key: item.key,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? item.selectedIcon : item.icon,
              color: color,
              size: BvSize.iconLg,
            ),
            const SizedBox(height: BvSpace.s2),
            _Label(
              item.label,
              style: type.labelSm.copyWith(
                color: color,
                fontWeight: selected ? type.labelLg.fontWeight : null,
              ),
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
            DecoratedBox(
              decoration: const BoxDecoration(
                color: BvColors.surfaceSelected,
                borderRadius: BvRadius.controlAll,
              ),
              child: const Padding(
                padding: EdgeInsetsDirectional.symmetric(
                  horizontal: BvSpace.s8,
                  vertical: BvSpace.s2,
                ),
                child: Icon(
                  Icons.add,
                  color: BvColors.iconInverse,
                  size: BvSize.iconMd,
                ),
              ),
            ),
            const SizedBox(height: BvSpace.s2),
            _Label(
              label,
              style: BvType.of(
                context,
              ).labelSm.copyWith(color: BvColors.textSecondary),
            ),
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
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: BvSize.touchMin),
        child: Center(heightFactor: 1, child: child),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    // Shrinks only when a very large text size would not fit the slot.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(text, maxLines: 1, style: style),
    );
  }
}
