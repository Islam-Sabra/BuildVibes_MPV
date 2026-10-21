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

/// The To do docket under the Daybook's masthead (review 50 F68b,
/// 2604:36389 EN, 2604:37123 AR; it replaces F68's line): a small tear-off
/// ticket. A brand-soft stub with the list-checks icon, a dashed
/// perforation, then [title] ("2 work items for you") and, smaller and
/// grey, the oldest item: its [oldest] title, cut with … on one line, then
/// [rest] ("· from Sun, and 1 more"), which always shows whole. The caret
/// mirrors in right to left. The whole docket is tapped to see every item
/// (review 73 A1: [showBvToDoSheet]).
class BvDueTodayStrip extends StatelessWidget {
  const BvDueTodayStrip({
    super.key,
    required this.title,
    required this.oldest,
    required this.rest,
    this.onTap,
  });

  /// "2 work items for you". The count is the viewer's own open and
  /// sent-back items, due today or earlier (F65); Western digits.
  final String title;

  /// The oldest item's title.
  final String oldest;

  /// After it: its due or day, and how many more ("· from Sun, and 1
  /// more").
  final String rest;

  /// Opens the To do sheet.
  final VoidCallback? onTap;

  /// The docket's words, in reading order.
  String get text => '$title $oldest$rest';

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final small = type.metadata.copyWith(color: BvColors.textSecondary);
    return Padding(
      padding: BvDueTodaySpec.outer,
      child: Semantics(
        button: onTap != null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: BvDueTodaySpec.minHeight,
            ),
            decoration: BoxDecoration(
              color: BvColors.surfaceElevated,
              borderRadius: BvDueTodaySpec.radius,
              border: Border.all(
                color: BvColors.borderSubtle,
                width: BvStroke.thin,
              ),
            ),
            child: ClipRRect(
              borderRadius: BvDueTodaySpec.radius,
              child: CustomPaint(
                key: const Key('to-do-perforation'),
                // The stub's brand-soft and the dashed perforation, the
                // docket's full height whatever its lines need.
                painter: _Stub(Directionality.of(context)),
                child: Row(
                  children: [
                    const SizedBox(
                      key: Key('to-do-stub'),
                      width: BvDueTodaySpec.stubWidth,
                      child: Center(
                        child: Icon(
                          BvIcons.workItems,
                          size: BvDueTodaySpec.icon,
                          color: BvColors.iconAction,
                        ),
                      ),
                    ),
                    const SizedBox(width: BvStroke.thin),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: BvDueTodaySpec.bodyPaddingStart,
                          top: BvDueTodaySpec.bodyPaddingVertical,
                          bottom: BvDueTodaySpec.bodyPaddingVertical,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: BvDueTodaySpec.lineGap,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: type.labelMd.copyWith(
                                color: BvColors.textPrimary,
                              ),
                            ),
                            _OldestLine(
                              oldest: oldest,
                              rest: rest,
                              style: small,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: BvDueTodaySpec.caretWidth,
                      child: Center(
                        child: Icon(
                          BvIcons.caretForward,
                          size: BvDueTodaySpec.caret,
                          color: BvColors.iconSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The docket's second line: the oldest title cut with … first, so [rest]
/// shows whole; only when even [rest] can't fit is the line cut at its end.
class _OldestLine extends StatelessWidget {
  const _OldestLine({
    required this.oldest,
    required this.rest,
    required this.style,
  });

  final String oldest;
  final String rest;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final painter = TextPainter(
        text: TextSpan(text: rest, style: style),
        maxLines: 1,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final fits = painter.width < box.maxWidth;
      painter.dispose();
      if (!fits) {
        return Text(
          '$oldest$rest',
          key: const Key('to-do-oldest'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        );
      }
      return Row(
        children: [
          Flexible(
            child: Text(
              oldest,
              key: const Key('to-do-oldest'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          Text(rest, maxLines: 1, style: style),
        ],
      );
    },
  );
}

/// The stub's brand-soft at the start, and the dashed line between it and
/// the body, 3 on, 3 off.
class _Stub extends CustomPainter {
  const _Stub(this.direction);

  final TextDirection direction;

  @override
  void paint(Canvas canvas, Size size) {
    final rtl = direction == TextDirection.rtl;
    const w = BvDueTodaySpec.stubWidth;
    final stub = rtl
        ? Rect.fromLTWH(size.width - w, 0, w, size.height)
        : Rect.fromLTWH(0, 0, w, size.height);
    canvas.drawRect(stub, Paint()..color = BvColors.surfaceBrandSoft);
    final x = rtl ? size.width - w - BvStroke.thin / 2 : w + BvStroke.thin / 2;
    final dash = Paint()
      ..color = BvColors.borderSubtle
      ..strokeWidth = BvStroke.thin;
    for (
      var y = 0.0;
      y < size.height;
      y += BvDueTodaySpec.dash + BvDueTodaySpec.dashGap
    ) {
      canvas.drawLine(
        Offset(x, y),
        Offset(x, (y + BvDueTodaySpec.dash).clamp(0, size.height)),
        dash,
      );
    }
  }

  @override
  bool shouldRepaint(_Stub old) => old.direction != direction;
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
