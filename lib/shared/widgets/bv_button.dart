import 'package:flutter/material.dart';

import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';

enum BvButtonStyle { primary, secondary, tertiary, destructive }

enum BvButtonSize { large, medium }

/// Spec §1 ("DS · Button"). Disabled when [onPressed] is null.
/// Full-width buttons in footers use [BvButtonSize.large] and [expand].
class BvButton extends StatelessWidget {
  const BvButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = BvButtonStyle.primary,
    this.size = BvButtonSize.large,
    this.icon,
    this.expand = false,
    this.focusNode,
    this.autofocus = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final BvButtonStyle style;
  final BvButtonSize size;
  final IconData? icon;
  final bool expand;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final large = size == BvButtonSize.large;
    final height = large ? BvButtonSpec.heightLarge : BvButtonSpec.heightMedium;
    final padding = large
        ? BvButtonSpec.paddingLarge
        : BvButtonSpec.paddingMedium;

    final button = TextButton(
      onPressed: onPressed,
      focusNode: focusNode,
      autofocus: autofocus,
      style: ButtonStyle(
        minimumSize: WidgetStatePropertyAll(Size(height, height)),
        maximumSize: WidgetStatePropertyAll(Size(double.infinity, height)),
        padding: WidgetStatePropertyAll(
          EdgeInsetsDirectional.symmetric(horizontal: padding),
        ),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BvRadius.controlAll),
        ),
        textStyle: WidgetStatePropertyAll(type.button),
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStateProperty.resolveWith(_fill),
        foregroundColor: WidgetStateProperty.resolveWith(_text),
        iconColor: WidgetStateProperty.resolveWith(_text),
        iconSize: const WidgetStatePropertyAll(BvButtonSpec.iconSize),
        side: WidgetStateProperty.resolveWith(_border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: BvButtonSpec.gap,
        children: [
          if (icon != null) Icon(icon),
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }

  Color _fill(Set<WidgetState> states) {
    final disabled = states.contains(WidgetState.disabled);
    final pressed = states.contains(WidgetState.pressed);
    return switch (style) {
      BvButtonStyle.primary =>
        disabled
            ? BvColors.actionDisabled
            : pressed
            ? BvColors.actionPrimaryPressed
            : BvColors.actionPrimary,
      BvButtonStyle.secondary || BvButtonStyle.destructive =>
        disabled
            ? BvColors.actionDisabled
            : pressed
            ? BvColors.surfaceSubtle
            : BvColors.actionSecondary,
      BvButtonStyle.tertiary =>
        !disabled && pressed ? BvColors.surfaceSubtle : Colors.transparent,
    };
  }

  Color _text(Set<WidgetState> states) {
    if (states.contains(WidgetState.disabled)) {
      return BvColors.actionDisabledForeground;
    }
    return switch (style) {
      BvButtonStyle.primary => BvColors.actionPrimaryForeground,
      BvButtonStyle.secondary => BvColors.textPrimary,
      BvButtonStyle.tertiary => BvColors.textAction,
      BvButtonStyle.destructive => BvColors.textDestructive,
    };
  }

  BorderSide _border(Set<WidgetState> states) {
    if (states.contains(WidgetState.disabled)) return BorderSide.none;
    if (states.contains(WidgetState.focused)) {
      return const BorderSide(
        color: BvColors.borderFocus,
        width: BvStroke.thick,
      );
    }
    return switch (style) {
      BvButtonStyle.secondary => const BorderSide(
        color: BvColors.borderInput,
        width: BvStroke.thin,
      ),
      BvButtonStyle.destructive => const BorderSide(
        color: BvColors.borderDestructive,
        width: BvStroke.thin,
      ),
      _ => BorderSide.none,
    };
  }
}
