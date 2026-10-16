import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_days_specs.dart';
import 'bv_text_field.dart';

/// The month that drops from under the Space header when the masthead is
/// tapped (spec §14). Each day shows whether it has posts (a dot) and
/// whether something is due (a ring); the selected day is filled.
///
/// [firstWeekday] comes from the market pack (0 = Sunday … 6 = Saturday).
/// Month and weekday names come from intl in the app language, with Western
/// digits.
class BvMonthDropdown extends StatelessWidget {
  const BvMonthDropdown({
    super.key,
    required this.month,
    required this.today,
    required this.firstWeekday,
    required this.postsLabel,
    required this.dueLabel,
    this.selected,
    this.postDays = const {},
    this.dueDays = const {},
    this.onDay,
    this.onPrevious,
    this.onNext,
  }) : assert(firstWeekday >= 0 && firstWeekday < 7);

  /// Any date in the month shown.
  final DateTime month;

  /// Later days have a quieter number.
  final DateTime today;

  /// The day the Daybook shows; today when null.
  final DateTime? selected;
  final int firstWeekday;

  /// Days of [month] (1 to 31) with posts, and with something due.
  final Set<int> postDays;
  final Set<int> dueDays;

  /// Legend: "Posts", "Something due".
  final String postsLabel;
  final String dueLabel;

  final ValueChanged<DateTime>? onDay;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    const days = BvMonthDropdownSpec.daysInWeek;
    final first = DateTime(month.year, month.month);
    final length = DateTime(month.year, month.month + 1, 0).day;
    // DateTime.weekday is 1 (Monday) … 7 (Sunday); % 7 makes Sunday 0.
    final lead = (first.weekday % days - firstWeekday + days) % days;
    final rows = ((lead + length) / days).ceil();
    final shown = selected ?? today;
    final todayDate = DateTime(today.year, today.month, today.day);

    Widget cell(int index) {
      final day = index - lead + 1;
      if (day < 1 || day > length) {
        return const SizedBox.square(dimension: BvMonthDropdownSpec.circle);
      }
      final date = DateTime(month.year, month.month, day);
      final isSelected = _sameDay(date, shown);
      final due = dueDays.contains(day);
      final number = isSelected
          ? BvColors.actionPrimaryForeground
          : due || date.isAfter(todayDate)
          ? BvColors.textSecondary
          : BvColors.textPrimary;
      return InkResponse(
        key: Key('month-day-$day'),
        onTap: onDay == null ? null : () => onDay!(date),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            vertical: BvMonthDropdownSpec.cellPaddingVertical,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: BvMonthDropdownSpec.cellGap,
            children: [
              DecoratedBox(
                key: Key('month-circle-$day'),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? BvColors.actionPrimary : null,
                  border: due && !isSelected
                      ? const Border.fromBorderSide(
                          BorderSide(
                            color: BvColors.actionPrimary,
                            width: BvMonthDropdownSpec.ring,
                          ),
                        )
                      : null,
                ),
                child: SizedBox.square(
                  dimension: BvMonthDropdownSpec.circle,
                  child: Center(
                    child: Text(
                      '$day',
                      style: type.labelMd.copyWith(color: number),
                    ),
                  ),
                ),
              ),
              SizedBox.square(
                dimension: BvMonthDropdownSpec.dot,
                child: postDays.contains(day)
                    ? DecoratedBox(
                        key: Key('month-dot-$day'),
                        decoration: const BoxDecoration(
                          color: BvColors.textSecondary,
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      );
    }

    Widget legend(Widget mark, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      spacing: BvMonthDropdownSpec.legendItemGap,
      children: [
        mark,
        Text(
          label,
          style: type.metadata.copyWith(color: BvColors.textSecondary),
        ),
      ],
    );

    Widget caret(IconData icon, VoidCallback? onTap, Key key) => InkResponse(
      key: key,
      onTap: onTap,
      radius: BvMonthDropdownSpec.caret,
      child: Icon(
        icon,
        size: BvMonthDropdownSpec.caret,
        color: BvColors.iconPrimary,
      ),
    );

    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: BvMonthDropdownSpec.radius,
        boxShadow: BvShadow.dropdown,
      ),
      child: Material(
        color: BvColors.surfaceElevated,
        borderRadius: BvMonthDropdownSpec.radius,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(BvMonthDropdownSpec.padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            spacing: BvMonthDropdownSpec.gap,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      BvWesternDigitsFormatter.normalise(
                        DateFormat.yMMMM(locale).format(first),
                      ),
                      style: type.titleLg,
                    ),
                  ),
                  caret(
                    BvIcons.caretBack,
                    onPrevious,
                    const Key('month-previous'),
                  ),
                  caret(BvIcons.caretForward, onNext, const Key('month-next')),
                ],
              ),
              Row(
                children: [
                  for (var i = 0; i < days; i++)
                    Expanded(
                      child: Text(
                        // 1 January 2023 was a Sunday.
                        DateFormat.E(locale).format(
                          DateTime(2023, 1, 1 + (firstWeekday + i) % days),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: type.labelSm.copyWith(
                          color: BvColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
              for (var r = 0; r < rows; r++)
                Row(
                  children: [
                    for (var c = 0; c < days; c++)
                      Expanded(child: Center(child: cell(r * days + c))),
                  ],
                ),
              Row(
                spacing: BvMonthDropdownSpec.legendGap,
                children: [
                  legend(
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        color: BvColors.textSecondary,
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox.square(
                        dimension: BvMonthDropdownSpec.legendDot,
                      ),
                    ),
                    postsLabel,
                  ),
                  legend(
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.fromBorderSide(
                          BorderSide(
                            color: BvColors.actionPrimary,
                            width: BvMonthDropdownSpec.ring,
                          ),
                        ),
                      ),
                      child: SizedBox.square(
                        dimension: BvMonthDropdownSpec.legendRing,
                      ),
                    ),
                    dueLabel,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
