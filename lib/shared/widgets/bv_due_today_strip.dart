import 'package:flutter/material.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_days_specs.dart';
import 'bv_list_row.dart';
import 'bv_sheet.dart';

/// One item on the To do strip: its title, after its day when it was due
/// on an earlier day ("Mon"; null for today).
typedef BvStripItem = ({String? day, String title});

/// The To do strip under the Daybook's masthead (L1 2539:34715; review 50
/// F61): what is still yours to do, today or from earlier days, oldest
/// first. Brand-soft, a calendar, the label and the titles in the action
/// colour; an earlier day in grey (F57: never a warning). It stops at two
/// lines with "…"; the whole strip is tapped to see every item (review 73
/// A1: [showBvToDoSheet]).
class BvDueTodayStrip extends StatelessWidget {
  const BvDueTodayStrip({
    super.key,
    required this.label,
    required this.items,
    this.onTap,
  });

  /// "To do:".
  final String label;
  final List<BvStripItem> items;

  /// Opens the To do sheet.
  final VoidCallback? onTap;

  /// The strip's words as one line: "To do: Mon Rebar · Cable trays".
  String get text => [
    label,
    items
        .map((i) => i.day == null ? i.title : '${i.day} ${i.title}')
        .join(' · '),
  ].join(' ');

  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: _strip(),
    ),
  );

  Widget _strip() => ColoredBox(
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

/// The To do sheet (review 73 A1): every item on the strip, oldest first,
/// an earlier day in grey under its title. A row closes the sheet and
/// [onOpen]s its item (by its place in [items]). No count, no "+ more".
Future<void> showBvToDoSheet(
  BuildContext context, {
  required String title,
  required List<BvStripItem> items,
  required ValueChanged<int> onOpen,
}) => showBvSheet<void>(
  context: context,
  title: title,
  builder: (sheet) => ClipRRect(
    key: const Key('to-do-sheet'),
    borderRadius: BvRadius.cardAll,
    child: BvListGroup(
      rows: [
        for (final (n, i) in items.indexed)
          BvListRow(
            key: Key('to-do-row-$n'),
            title: i.title,
            subtitle: i.day,
            onTap: () {
              Navigator.of(sheet).pop();
              onOpen(n);
            },
          ),
      ],
    ),
  ),
);
