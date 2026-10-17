import 'package:flutter/material.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_days_specs.dart';

/// The strip under the Daybook's masthead naming what is due today for you
/// or by you (L1 2539:34715): brand-soft, a calendar and the words in the
/// action colour.
class BvDueTodayStrip extends StatelessWidget {
  const BvDueTodayStrip(this.text, {super.key});

  /// "Due today: Cable tray hangers, level 4".
  final String text;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: BvColors.surfaceBrandSoft,
    child: Padding(
      padding: const EdgeInsetsDirectional.only(
        start: BvDueTodaySpec.paddingStart,
        end: BvDueTodaySpec.paddingEnd,
        top: BvDueTodaySpec.paddingVertical,
        bottom: BvDueTodaySpec.paddingVertical,
      ),
      child: Row(
        spacing: BvDueTodaySpec.gap,
        children: [
          const Icon(
            BvIcons.month,
            size: BvDueTodaySpec.icon,
            color: BvColors.textAction,
          ),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: BvType.of(
                context,
              ).labelSm.copyWith(color: BvColors.textAction),
            ),
          ),
        ],
      ),
    ),
  );
}
