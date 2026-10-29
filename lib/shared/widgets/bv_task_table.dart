import 'package:flutter/material.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_page_specs.dart';
import '../../core/l10n/bidi.dart';

/// One row of a [BvTaskTable]: its id, the task, a note and its tick.
typedef BvTaskRow = ({String id, String text, String note, bool ticked});

/// Review 105 SP3 (2673:38823): a work item's table of tasks. A header
/// row (the tick's column, Task, Note) on a subtle fill, then a row for
/// each task: its tick at the start, the task, and a short note. A ticked
/// task is crossed out. The columns follow the reading direction, so in
/// Arabic the tick is at the right.
///
/// [onTick] makes each tick a tap (the owner, or a Lead); a tick is not a
/// signature. [onAdd] shows "Add a row" under the last row. The editor
/// draws its own fields in the cells ([task], [note]).
class BvTaskTable extends StatelessWidget {
  const BvTaskTable({
    super.key,
    required this.rows,
    required this.taskLabel,
    required this.noteLabel,
    required this.tickLabel,
    required this.emptyNote,
    this.addLabel,
    this.onTick,
    this.onAdd,
    this.task,
    this.note,
    this.onRowLongPress,
  });

  final List<BvTaskRow> rows;
  final String taskLabel;
  final String noteLabel;

  /// A row's tick for a screen reader, with that row's task.
  final String Function(String task) tickLabel;

  /// What an empty note shows.
  final String emptyNote;
  final String? addLabel;
  final ValueChanged<String>? onTick;
  final VoidCallback? onAdd;

  /// The editor's fields, by row.
  final Widget Function(int row)? task;
  final Widget Function(int row)? note;

  /// The editor's row menu (Delete row).
  final ValueChanged<int>? onRowLongPress;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final add = onAdd != null && addLabel != null;
    const line = BorderSide(
      color: BvColors.borderSubtle,
      width: BvStroke.thin,
    );

    Widget cell({double? width, required Widget child}) {
      final padded = Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: BvTaskTableSpec.cellPaddingHorizontal,
          vertical: BvTaskTableSpec.cellPaddingVertical,
        ),
        child: child,
      );
      return width == null
          ? Expanded(child: padded)
          : SizedBox(width: width, child: padded);
    }

    final header = DecoratedBox(
      decoration: const BoxDecoration(
        color: BvColors.surfaceSubtle,
        border: Border(bottom: line),
      ),
      child: Row(
        children: [
          cell(
            width: BvTaskTableSpec.tickColumn,
            child: const SizedBox.shrink(),
          ),
          cell(
            child: Text(
              taskLabel,
              style: type.labelSm.copyWith(color: BvColors.textSecondary),
            ),
          ),
          cell(
            width: BvTaskTableSpec.noteColumn,
            child: Text(
              noteLabel,
              style: type.labelSm.copyWith(color: BvColors.textSecondary),
            ),
          ),
        ],
      ),
    );

    Widget row(int i) {
      final r = rows[i];
      final last = i == rows.length - 1 && !add;
      final tick = _Tick(
        on: r.ticked,
        label: tickLabel(r.text),
        onTap: onTick == null ? null : () => onTick!(r.id),
        tapKey: Key('task-tick-${r.id}'),
      );
      final taskText =
          task?.call(i) ??
          Text(
            r.text,
            textDirection: r.text.isEmpty ? null : directionOf(r.text),
            style: r.ticked
                ? type.bodyMd.copyWith(
                    color: BvColors.textSecondary,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: BvColors.textSecondary,
                  )
                : type.bodyMd,
          );
      final noteText =
          note?.call(i) ??
          Text(
            r.note.trim().isEmpty ? emptyNote : r.note,
            textDirection: r.note.trim().isEmpty ? null : directionOf(r.note),
            style: type.metadata.copyWith(color: BvColors.textSecondary),
          );
      final content = DecoratedBox(
        key: Key('task-row-${r.id}'),
        decoration: BoxDecoration(
          border: last ? null : const Border(bottom: line),
        ),
        child: Row(
          children: [
            SizedBox(width: BvTaskTableSpec.tickColumn, child: tick),
            cell(child: taskText),
            cell(width: BvTaskTableSpec.noteColumn, child: noteText),
          ],
        ),
      );
      final longPress = onRowLongPress;
      return longPress == null
          ? content
          : GestureDetector(
              onLongPress: () => longPress(i),
              child: content,
            );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BvTaskTableSpec.radius,
        border: Border.all(color: BvColors.borderSubtle, width: BvStroke.thin),
      ),
      child: ClipRRect(
        borderRadius: BvTaskTableSpec.radius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            for (var i = 0; i < rows.length; i++) row(i),
            if (add)
              Semantics(
                button: true,
                child: InkWell(
                  key: const Key('task-add-row'),
                  onTap: onAdd,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.all(
                      BvTaskTableSpec.addPadding,
                    ),
                    child: Row(
                      spacing: BvTaskTableSpec.addGap,
                      children: [
                        const Icon(
                          BvIcons.create,
                          size: BvTaskTableSpec.addIcon,
                          color: BvColors.textAction,
                        ),
                        Text(
                          addLabel!,
                          style: type.labelMd.copyWith(
                            color: BvColors.textAction,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A row's tick: outlined, or filled with the action colour and a check.
class _Tick extends StatelessWidget {
  const _Tick({
    required this.on,
    required this.label,
    required this.tapKey,
    this.onTap,
  });

  final bool on;
  final String label;
  final Key tapKey;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: BvTaskTableSpec.tick,
      height: BvTaskTableSpec.tick,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: on ? BvColors.actionPrimary : null,
        borderRadius: BvTaskTableSpec.tickRadius,
        border: on
            ? null
            : Border.all(
                color: BvColors.textSecondary,
                width: BvStroke.medium,
              ),
      ),
      child: on
          ? const Icon(
              BvIcons.check,
              size: BvTaskTableSpec.check,
              color: BvColors.actionPrimaryForeground,
            )
          : null,
    );
    return Semantics(
      label: label,
      checked: on,
      button: onTap != null,
      child: GestureDetector(
        key: tapKey,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            vertical: BvTaskTableSpec.cellPaddingVertical,
          ),
          child: Center(widthFactor: 1, heightFactor: 1, child: box),
        ),
      ),
    );
  }
}
