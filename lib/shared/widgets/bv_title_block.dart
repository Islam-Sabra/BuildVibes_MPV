import 'package:flutter/material.dart';

import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import 'bv_stamp.dart';

/// One cell of a [BvTitleBlock]: a label in capitals and its value. With
/// [onTap] it is a field (P14): it shows [placeholder] when empty, and an
/// [icon] at the end.
class BvTitleCell {
  const BvTitleCell({
    required this.label,
    this.value,
    this.placeholder,
    this.onTap,
    this.icon,
    this.error = false,
    this.key,
  });

  final String label;
  final String? value;
  final String? placeholder;
  final VoidCallback? onTap;
  final IconData? icon;

  /// The label turns red (a required cell left empty).
  final bool error;
  final Key? key;
}

/// A project record drawn like a drawing title block (PJ1, P14): a header
/// strip with a label and a stamp, then rows of one or two cells.
class BvTitleBlock extends StatelessWidget {
  const BvTitleBlock({
    super.key,
    required this.label,
    required this.rows,
    this.stamp,
  });

  final String label;

  /// For example "SHARED RECORD · NO OWNER" or "REV A · DRAFT".
  final String? stamp;
  final List<List<BvTitleCell>> rows;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    const line = BorderSide(
      color: BvColors.borderDefault,
      width: BvStroke.thin,
    );

    Widget cell(BvTitleCell c) {
      final empty = (c.value ?? '').isEmpty;
      final content = Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: BvTitleBlockSpec.paddingHorizontal,
          vertical: BvTitleBlockSpec.cellPaddingVertical,
        ),
        child: Row(
          spacing: BvSpace.s8,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: BvTitleBlockSpec.cellGap,
                children: [
                  Text(
                    c.label,
                    style: type.overline.copyWith(
                      color: c.error
                          ? BvColors.textDestructive
                          : BvColors.textSecondary,
                    ),
                  ),
                  Text(
                    empty ? (c.placeholder ?? '') : c.value!,
                    style: type.titleMd.copyWith(
                      color: empty
                          ? BvColors.textSecondary
                          : BvColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            if (c.icon != null)
              Icon(
                c.icon,
                size: BvTitleBlockSpec.iconSize,
                color: BvColors.iconSecondary,
              ),
          ],
        ),
      );
      return Expanded(
        child: c.onTap == null
            ? KeyedSubtree(key: c.key, child: content)
            : Semantics(
                button: true,
                child: InkWell(
                  key: c.key,
                  onTap: c.onTap,
                  splashFactory: NoSplash.splashFactory,
                  child: content,
                ),
              ),
      );
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: BvColors.surfaceElevated,
        borderRadius: BvTitleBlockSpec.radius,
        border: Border.all(
          color: BvColors.brandInk,
          width: BvTitleBlockSpec.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: BvColors.surfaceSubtle,
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: BvTitleBlockSpec.paddingHorizontal,
              vertical: BvTitleBlockSpec.headerPaddingVertical,
            ),
            // Label at the start, stamp at the end; the stamp moves to a
            // second line when both don't fit.
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: BvSpace.s8,
              runSpacing: BvSpace.s8,
              children: [
                Text(
                  label,
                  style: type.overline.copyWith(color: BvColors.textSecondary),
                ),
                if (stamp != null)
                  BvStamp(label: stamp!, tone: BvStampTone.ink),
              ],
            ),
          ),
          for (final row in rows)
            DecoratedBox(
              decoration: const BoxDecoration(border: Border(top: line)),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < row.length; i++) ...[
                      if (i > 0)
                        const VerticalDivider(
                          width: BvStroke.thin,
                          thickness: BvStroke.thin,
                          color: BvColors.borderDefault,
                        ),
                      cell(row[i]),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
