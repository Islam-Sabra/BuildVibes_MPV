import 'package:flutter/material.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_writing_specs.dart';

// Spec §6 ("DS · Controls"). Each control has a 48 × 48 tap area and is
// disabled when its callback is null.

/// On/off for one setting. Never use switches for choices that exclude each
/// other: use [BvChoiceCard] for those.
class BvSwitch extends StatelessWidget {
  const BvSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    final track = !enabled
        ? BvColors.actionDisabled
        : value
        ? BvColors.actionPrimary
        : BvColors.borderInput;

    return _TapArea(
      semantics: (child) =>
          Semantics(toggled: value, enabled: enabled, child: child),
      onTap: enabled ? () => onChanged!(!value) : null,
      child: AnimatedContainer(
        duration: BvMotion.fast,
        curve: BvMotion.standard,
        width: BvControlSpec.switchWidth,
        height: BvControlSpec.switchHeight,
        padding: const EdgeInsetsDirectional.all(BvControlSpec.switchPadding),
        decoration: BoxDecoration(
          color: track,
          borderRadius: BvControlSpec.switchRadius,
        ),
        // The thumb sits at the end when on, so it mirrors in right to left.
        child: AnimatedAlign(
          duration: BvMotion.fast,
          curve: BvMotion.standard,
          alignment: value
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
          child: const DecoratedBox(
            key: Key('switch-thumb'),
            decoration: BoxDecoration(
              color: BvColors.surfaceElevated,
              shape: BoxShape.circle,
            ),
            child: SizedBox.square(dimension: BvControlSpec.switchThumb),
          ),
        ),
      ),
    );
  }
}

class BvCheckbox extends StatelessWidget {
  const BvCheckbox({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    final fill = value
        ? (enabled ? BvColors.actionPrimary : BvColors.actionDisabled)
        : BvColors.surfaceElevated;
    return _TapArea(
      semantics: (child) =>
          Semantics(checked: value, enabled: enabled, child: child),
      onTap: enabled ? () => onChanged!(!value) : null,
      child: Container(
        width: BvControlSpec.checkboxSize,
        height: BvControlSpec.checkboxSize,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BvControlSpec.checkboxRadius,
          border: value
              ? null
              : Border.all(
                  color: enabled
                      ? BvColors.borderInput
                      : BvColors.actionDisabled,
                  width: BvStroke.medium,
                ),
        ),
        child: value
            ? const Icon(
                BvIcons.check,
                size: BvControlSpec.checkIconSize,
                color: BvColors.iconInverse,
              )
            : null,
      ),
    );
  }
}

/// A radio mark. Usually shown inside a [BvChoiceCard], which handles the
/// tap; give [onTap] only when the radio stands alone.
///
/// [small] is the Daybook's 20 mark (send-back reasons): a light ring when
/// off, a thick orange ring with a white centre when on. Without [onTap] it
/// takes only its own size, so it fits a 38 row.
class BvRadio extends StatelessWidget {
  const BvRadio({
    super.key,
    required this.selected,
    this.onTap,
    this.small = false,
  });

  final bool selected;
  final VoidCallback? onTap;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final mark = small ? _smallMark() : _mark();
    Widget semantics(Widget child) => Semantics(
      checked: selected,
      inMutuallyExclusiveGroup: true,
      child: child,
    );
    if (small && onTap == null) return semantics(mark);
    return _TapArea(semantics: semantics, onTap: onTap, child: mark);
  }

  Widget _mark() => Container(
    width: BvControlSpec.radioSize,
    height: BvControlSpec.radioSize,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: BvColors.surfaceElevated,
      border: Border.all(
        color: selected ? BvColors.actionPrimary : BvColors.borderInput,
        width: selected ? BvStroke.thick : BvStroke.medium,
      ),
    ),
    child: selected
        ? const DecoratedBox(
            decoration: BoxDecoration(
              color: BvColors.actionPrimary,
              shape: BoxShape.circle,
            ),
            child: SizedBox.square(dimension: BvControlSpec.radioDot),
          )
        : null,
  );

  Widget _smallMark() => Container(
    width: BvRadioSmallSpec.size,
    height: BvRadioSmallSpec.size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: BvColors.surfaceElevated,
      border: Border.all(
        color: selected ? BvColors.actionPrimary : BvColors.borderDefault,
        width: selected ? BvRadioSmallSpec.onRing : BvRadioSmallSpec.offBorder,
      ),
    ),
  );
}

class _TapArea extends StatelessWidget {
  const _TapArea({
    required this.child,
    required this.onTap,
    required this.semantics,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Widget Function(Widget child) semantics;

  @override
  Widget build(BuildContext context) {
    return semantics(
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: BvControlSpec.tapArea,
          child: Center(child: child),
        ),
      ),
    );
  }
}
