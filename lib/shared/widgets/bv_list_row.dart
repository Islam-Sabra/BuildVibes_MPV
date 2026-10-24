import 'package:flutter/material.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import 'bv_controls.dart';
import 'bv_faces.dart';

/// What sits at the end of a [BvListRow]: a chevron, a switch, a value
/// followed by a chevron, a badge, or nothing.
sealed class BvRowTrailing {
  const BvRowTrailing();

  const factory BvRowTrailing.chevron() = _Chevron;
  const factory BvRowTrailing.value(String text) = _Value;
  const factory BvRowTrailing.toggle({
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) = _Toggle;
  const factory BvRowTrailing.none() = _None;

  /// A [BvBadge] (or another small widget) instead of the chevron.
  const factory BvRowTrailing.badge(Widget badge) = _Badge;

  /// A check mark when [selected]; empty space otherwise.
  const factory BvRowTrailing.check({required bool selected}) = _Check;

  /// Up to three small faces, then the chevron: who is in it, never how
  /// many (a team in People, review 54 A4).
  const factory BvRowTrailing.faces(List<BvFace> faces) = _Faces;
}

class _Faces extends BvRowTrailing {
  const _Faces(this.faces);
  final List<BvFace> faces;
}

class _Chevron extends BvRowTrailing {
  const _Chevron();
}

class _Value extends BvRowTrailing {
  const _Value(this.text);
  final String text;
}

class _Toggle extends BvRowTrailing {
  const _Toggle({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool>? onChanged;
}

class _None extends BvRowTrailing {
  const _None();
}

class _Badge extends BvRowTrailing {
  const _Badge(this.badge);
  final Widget badge;
}

class _Check extends BvRowTrailing {
  const _Check({required this.selected});
  final bool selected;
}

/// Spec §7 ("DS · Rows").
class BvListRow extends StatelessWidget {
  const BvListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing = const BvRowTrailing.chevron(),
    this.onTap,
    this.onLongPress,
    this.titleMark,
    this.destructive = false,
  });

  final String title;
  final String? subtitle;

  /// A [BvRowIcon] or an avatar.
  final Widget? leading;
  final BvRowTrailing trailing;
  final VoidCallback? onTap;

  /// A row's quick menu (F102: Mute / Unmute on a Space).
  final VoidCallback? onLongPress;

  /// A small mark right after the title (F102: the bell-slash).
  final Widget? titleMark;

  /// The title in red, for actions such as Delete or Leave (S15).
  final bool destructive;

  bool get hasLeading => leading != null;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final trailing = this.trailing;
    // A row with a switch toggles when tapped anywhere.
    final tap = switch (trailing) {
      _Toggle(:final value, :final onChanged) when onChanged != null =>
        () => onChanged(!value),
      _ => onTap,
    };

    final titleText = Text(
      title,
      style: type.titleMd.copyWith(
        color: destructive ? BvColors.textDestructive : BvColors.textPrimary,
      ),
    );

    const chevron = Icon(
      BvIcons.caretForward,
      size: BvListRowSpec.chevronSize,
      color: BvColors.iconSecondary,
    );

    return Material(
      color: BvColors.surfaceElevated,
      child: InkWell(
        onTap: tap,
        onLongPress: onLongPress,
        splashFactory: NoSplash.splashFactory,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: BvListRowSpec.minHeight),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: BvListRowSpec.paddingHorizontal,
              vertical: BvListRowSpec.paddingVertical,
            ),
            child: Row(
              spacing: BvListRowSpec.gap,
              children: [
                ?leading,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    spacing: BvListRowSpec.textGap,
                    children: [
                      if (titleMark case final mark?)
                        Row(
                          children: [
                            Flexible(child: titleText),
                            mark,
                          ],
                        )
                      else
                        titleText,
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: type.bodySm.copyWith(
                            color: BvColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                switch (trailing) {
                  _Chevron() => chevron,
                  _Value(:final text) => Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: BvSpace.s4,
                    children: [
                      Text(
                        text,
                        style: type.bodyMd.copyWith(
                          color: BvColors.textSecondary,
                        ),
                      ),
                      chevron,
                    ],
                  ),
                  // The row handles the tap; the switch only shows it.
                  _Toggle(:final value, :final onChanged) => IgnorePointer(
                    child: BvSwitch(value: value, onChanged: onChanged),
                  ),
                  _None() => const SizedBox.shrink(),
                  _Badge(:final badge) => badge,
                  _Faces(:final faces) => Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: BvSpace.s8,
                    children: [BvFaces(faces), chevron],
                  ),
                  _Check(:final selected) => SizedBox.square(
                    dimension: BvListRowSpec.chevronSize,
                    child: selected
                        ? const Icon(
                            BvIcons.check,
                            key: Key('row-check'),
                            size: BvListRowSpec.chevronSize,
                            color: BvColors.iconAction,
                          )
                        : null,
                  ),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The 40 tile at the start of a row: brand-soft fill with an action icon,
/// or an ink icon when [ink] (S1 Space rows).
class BvRowIcon extends StatelessWidget {
  const BvRowIcon(
    this.icon, {
    super.key,
    this.ink = false,
    this.destructive = false,
  });

  final IconData icon;
  final bool ink;

  /// A red icon, beside a destructive row.
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: BvListRowSpec.leadingSize,
      height: BvListRowSpec.leadingSize,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: BvColors.brandEnergySoft,
        borderRadius: BvRadius.controlAll,
      ),
      child: Icon(
        icon,
        size: BvListRowSpec.leadingIconSize,
        color: destructive
            ? BvColors.textDestructive
            : ink
            ? BvColors.iconPrimary
            : BvColors.iconAction,
      ),
    );
  }
}

/// Rows with 1 px dividers between them. A divider starts after the
/// leading tile when the row above has one.
class BvListGroup extends StatelessWidget {
  const BvListGroup({super.key, required this.rows});

  final List<BvListRow> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0)
            ColoredBox(
              color: BvColors.surfaceElevated,
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  start: rows[i - 1].hasLeading
                      ? BvListRowSpec.dividerInset
                      : BvListRowSpec.paddingHorizontal,
                ),
                child: const Divider(
                  height: BvStroke.thin,
                  thickness: BvStroke.thin,
                  color: BvColors.borderDefault,
                ),
              ),
            ),
          rows[i],
        ],
      ],
    );
  }
}
