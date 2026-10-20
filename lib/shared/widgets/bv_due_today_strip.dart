import 'package:flutter/material.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_days_specs.dart';
import 'bv_marked_text.dart';

/// The strip under the Daybook's masthead naming what is due today for you
/// or by you (L1 2539:34715): brand-soft, a calendar and the words in the
/// action colour. F57: [quiet] parts (an earlier day, "Mon") are grey.
class BvDueTodayStrip extends StatelessWidget {
  const BvDueTodayStrip(this.text, {super.key, this.quiet = const []});

  /// "Due today: Cable tray hangers, level 4".
  final String text;

  /// The parts of [text] in grey, in order.
  final List<String> quiet;

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
            child: Builder(
              builder: (context) {
                final style = BvType.of(
                  context,
                ).labelSm.copyWith(color: BvColors.textAction);
                final grey = style.copyWith(color: BvColors.textSecondary);
                return Text.rich(
                  TextSpan(
                    children: bvMarkedSpans(text, style, [
                      for (final q in quiet) (part: q, style: grey),
                    ]),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
