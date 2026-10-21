import 'package:flutter/material.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_days_specs.dart';

/// One item on the To do strip: its title, after its day when it was due
/// on an earlier day ("Mon"; null for today).
typedef BvStripItem = ({String? day, String title});

/// The To do strip under the Daybook's masthead (L1 2539:34715; review 50
/// F61): what is still yours to do, today or from earlier days, oldest
/// first. Brand-soft, a calendar, the label and the titles in the action
/// colour; an earlier day in grey (F57: never a warning).
class BvDueTodayStrip extends StatelessWidget {
  const BvDueTodayStrip({super.key, required this.label, required this.items});

  /// "To do:".
  final String label;
  final List<BvStripItem> items;

  /// The strip's words as one line: "To do: Mon Rebar · Cable trays".
  String get text => [
    label,
    items
        .map((i) => i.day == null ? i.title : '${i.day} ${i.title}')
        .join(' · '),
  ].join(' ');

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
                    children: [
                      TextSpan(text: '$label '),
                      for (final (n, i) in items.indexed) ...[
                        if (n > 0) const TextSpan(text: ' · '),
                        if (i.day != null) ...[
                          TextSpan(text: i.day, style: grey),
                          const TextSpan(text: ' '),
                        ],
                        TextSpan(text: i.title),
                      ],
                    ],
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
