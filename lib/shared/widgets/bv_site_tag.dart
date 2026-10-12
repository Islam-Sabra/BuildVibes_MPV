import 'package:flutter/material.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../l10n/gen/app_localizations.dart';
import 'bv_stamp.dart';

/// Spec §13: the work item detail header (W3a), drawn like a site tag with
/// a punched hole, the item ID stamp and a FROM / OWNER / DUE title block.
class BvSiteTag extends StatelessWidget {
  const BvSiteTag({
    super.key,
    required this.itemId,
    required this.team,
    required this.title,
    required this.place,
    required this.from,
    required this.owner,
    required this.due,
    this.overdue = false,
    this.checkedStamp,
  });

  final String itemId;
  final String team;
  final String title;
  final String place;
  final String from;
  final String owner;
  final String due;
  final bool overdue;

  /// "CHECKED · 10 OCT · S. AL-MANSOUR": a tilted green stamp beside the
  /// reference once the item is closed (W3d, W3g).
  final String? checkedStamp;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final l10n = AppLocalizations.of(context);
    const border = BorderSide(
      color: BvColors.borderDefault,
      width: BvSiteTagSpec.border,
    );
    const cellBorder = BorderSide(
      color: BvColors.borderDefault,
      width: BvStroke.thin,
    );

    Widget cell(String label, String value, {Color? valueColor}) => Expanded(
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: BvSiteTagSpec.cellPaddingHorizontal,
          vertical: BvSiteTagSpec.cellPaddingVertical,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: BvSiteTagSpec.cellGap,
          children: [
            Text(
              label,
              style: type.overline.copyWith(color: BvColors.textSecondary),
            ),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: type.labelMd.copyWith(
                color: valueColor ?? BvColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: BvColors.surfaceElevated,
        borderRadius: BvSiteTagSpec.radius,
        border: Border.fromBorderSide(border),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  top: BvSiteTagSpec.headPaddingTop,
                  start: BvSiteTagSpec.headPaddingSide,
                  end: BvSiteTagSpec.headPaddingSide,
                  bottom: BvSiteTagSpec.headPaddingBottom,
                ),
                child: Row(
                  spacing: BvSiteTagSpec.headGap,
                  children: [
                    BvStamp(label: itemId),
                    if (checkedStamp != null)
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: BvStamp(
                            key: const Key('site-tag-checked'),
                            label: checkedStamp!,
                            tone: BvStampTone.positive,
                            tilted: true,
                          ),
                        ),
                      ),
                    if (checkedStamp == null) const Spacer(),
                    Flexible(
                      child: Text(
                        team,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: type.overline.copyWith(
                          color: BvColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: BvSiteTagSpec.bodyPaddingSide,
                  end: BvSiteTagSpec.bodyPaddingSide,
                  bottom: BvSiteTagSpec.bodyPaddingBottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: BvSiteTagSpec.bodyGap,
                  children: [
                    Text(title, style: type.titleLg),
                    Row(
                      spacing: BvSiteTagSpec.placeGap,
                      children: [
                        const Icon(
                          BvIcons.place,
                          size: BvSiteTagSpec.placeIconSize,
                          color: BvColors.iconSecondary,
                        ),
                        Expanded(
                          child: Text(
                            place,
                            style: type.bodyMd.copyWith(
                              color: BvColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              DecoratedBox(
                decoration: const BoxDecoration(
                  border: Border(top: cellBorder),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      cell(l10n.siteTagFrom, from),
                      const VerticalDivider(
                        width: BvStroke.thin,
                        thickness: BvStroke.thin,
                        color: BvColors.borderDefault,
                      ),
                      cell(l10n.siteTagOwner, owner),
                      const VerticalDivider(
                        width: BvStroke.thin,
                        thickness: BvStroke.thin,
                        color: BvColors.borderDefault,
                      ),
                      cell(
                        l10n.siteTagDue,
                        due,
                        valueColor: overdue
                            ? BvColors.textDestructive
                            : BvColors.textAction,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // The punched hole, top centre.
          const PositionedDirectional(
            top: BvSiteTagSpec.holeTop,
            start: 0,
            end: 0,
            child: Center(
              child: DecoratedBox(
                key: Key('site-tag-hole'),
                decoration: BoxDecoration(
                  color: BvColors.surfaceApp,
                  shape: BoxShape.circle,
                  border: Border.fromBorderSide(border),
                ),
                child: SizedBox.square(dimension: BvSiteTagSpec.holeSize),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
