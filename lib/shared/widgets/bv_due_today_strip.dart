import 'package:flutter/material.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_days_specs.dart';
import 'bv_list_row.dart';
import 'bv_sheet.dart';

/// One item on the To do sheet: its title, and its day when it was due on
/// an earlier day ("Mon"; null for today).
typedef BvStripItem = ({String? day, String title});

/// The To do strip under the Daybook's masthead (review 50 F68, replacing
/// the look in F61): one light line, as a folded announcement is drawn
/// (review 61 G1). The calendar and [label] in the action colour, the
/// [count] in ink, and › in grey, which mirrors in right to left. On the
/// page, with a hairline under it. No titles and no days: the whole line
/// is tapped to see them (review 73 A1: [showBvToDoSheet]).
class BvDueTodayStrip extends StatelessWidget {
  const BvDueTodayStrip({
    super.key,
    required this.label,
    required this.count,
    this.onTap,
  });

  /// "To do".
  final String label;

  /// The viewer's own open and sent-back items, due today or earlier
  /// (F65). Western digits in both languages.
  final int count;

  /// Opens the To do sheet.
  final VoidCallback? onTap;

  /// The strip's words as one line: "To do · 5".
  String get text => '$label · $count';

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final style = type.labelMd.copyWith(color: BvColors.textPrimary);
    return Semantics(
      button: onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: BvDueTodaySpec.minHeight,
          ),
          padding: const EdgeInsetsDirectional.only(
            start: BvDueTodaySpec.paddingStart,
            end: BvDueTodaySpec.paddingEnd,
            top: BvDueTodaySpec.paddingVertical,
            bottom: BvDueTodaySpec.paddingVertical,
          ),
          decoration: const BoxDecoration(
            color: BvColors.surfaceApp,
            border: Border(
              bottom: BorderSide(
                color: BvColors.borderSubtle,
                width: BvStroke.thin,
              ),
            ),
          ),
          child: Row(
            spacing: BvDueTodaySpec.gap,
            children: [
              const Icon(
                BvIcons.month,
                size: BvDueTodaySpec.icon,
                color: BvColors.iconAction,
              ),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: label,
                        style: style.copyWith(color: BvColors.textAction),
                      ),
                      TextSpan(text: ' · $count'),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ),
              const Icon(
                BvIcons.caretForward,
                size: BvDueTodaySpec.caret,
                color: BvColors.iconSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The To do sheet (review 73 A1): every item the strip counts, oldest first,
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
