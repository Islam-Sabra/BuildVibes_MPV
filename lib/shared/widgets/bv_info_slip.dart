import 'package:flutter/material.dart';

import '../../core/design/around_specs.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';

/// A group of settings on a white slip, under a small label (SI1
/// 2562:35605 "You", "Invite", "Space"). Lines between the rows.
class BvInfoGroup extends StatelessWidget {
  const BvInfoGroup({super.key, required this.label, required this.rows});

  final String label;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BvInfoSpec.labelGap,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(
            start: BvInfoSpec.labelPaddingStart,
          ),
          child: Text(
            label,
            style: type.labelSm.copyWith(color: BvColors.textSecondary),
          ),
        ),
        Container(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: BvInfoSpec.slipPaddingHorizontal,
          ),
          decoration: const BoxDecoration(
            color: BvColors.surfaceElevated,
            borderRadius: BvInfoSpec.slipRadius,
            boxShadow: BvShadow.infoSlip,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < rows.length; i++)
                DecoratedBox(
                  decoration: i == 0
                      ? const BoxDecoration()
                      : const BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: BvColors.borderSubtle,
                              width: BvStroke.thin,
                            ),
                          ),
                        ),
                  child: rows[i],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// How a [BvInfoRow]'s title reads.
enum BvInfoTone { plain, quiet, destructive }

/// One row of a [BvInfoGroup]: the title, then what sits at its end
/// ([trailing]) or under it ([below], a one-choice control).
class BvInfoRow extends StatelessWidget {
  const BvInfoRow({
    super.key,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.below,
    this.tone = BvInfoTone.plain,
    this.onTap,
  });

  final String title;

  /// A second line under the title in its own weight ("KCT · 48Q7").
  final Widget? subtitle;

  /// Plain text at the end ("Islam Ahmed").
  final String? value;
  final Widget? trailing;
  final Widget? below;
  final BvInfoTone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final style = switch (tone) {
      BvInfoTone.plain => type.bodyMd,
      BvInfoTone.quiet => type.labelMd.copyWith(color: BvColors.textSecondary),
      BvInfoTone.destructive => type.bodyMd.copyWith(
        color: BvColors.textDestructive,
      ),
    };
    final row = Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        vertical: BvInfoSpec.rowPaddingVertical,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BvInfoSpec.rowGap,
        children: [
          Row(
            spacing: BvInfoSpec.rowGap,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: BvSpace.s2,
                  children: [
                    Text(title, style: style),
                    ?subtitle,
                  ],
                ),
              ),
              if (value != null)
                Text(
                  value!,
                  style: type.bodyMd.copyWith(color: BvColors.textSecondary),
                ),
              ?trailing,
            ],
          ),
          ?below,
        ],
      ),
    );
    if (onTap == null) return row;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: BvSize.touchMin),
          child: row,
        ),
      ),
    );
  }
}

/// A small brand-soft label or button at a row's end: the pass ("Lead",
/// a tag) or Copy (a round pill, [onTap]).
class BvInfoPill extends StatelessWidget {
  const BvInfoPill({
    super.key,
    required this.label,
    required this.icon,
    this.onTap,
  });

  final String label;
  final IconData icon;

  /// A button when set: round, a little larger.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final button = onTap != null;
    final pill = Container(
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: button
            ? BvInfoSpec.pillPaddingHorizontal
            : BvInfoSpec.passPaddingHorizontal,
        vertical: button
            ? BvInfoSpec.pillPaddingVertical
            : BvInfoSpec.passPaddingVertical,
      ),
      decoration: BoxDecoration(
        color: BvColors.surfaceBrandSoft,
        borderRadius: button ? BvRadius.roundAll : BvRadius.smallAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: button ? BvSpace.s6 : BvSpace.s4,
        children: [
          Icon(
            icon,
            size: button ? BvInfoSpec.pillIcon : BvInfoSpec.passIcon,
            color: BvColors.textAction,
          ),
          Text(label, style: type.labelMd.copyWith(color: BvColors.textAction)),
        ],
      ),
    );
    if (!button) return pill;
    // The look stays small; the touch area is 48 (review 44, C4).
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: BvSize.touchMin),
          child: Center(widthFactor: 1, child: pill),
        ),
      ),
    );
  }
}
