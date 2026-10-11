import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../l10n/gen/app_localizations.dart';
import 'bv_chip.dart';
import 'bv_choice_card.dart';
import 'bv_sheet.dart';
import 'bv_text_field.dart';

/// The answer of [showBvMonthSheet]: a month, or "still going".
sealed class MonthChoice {
  const MonthChoice();
}

class PickedMonth extends MonthChoice {
  const PickedMonth(this.month);
  final DateTime month;
}

class StillGoing extends MonthChoice {
  const StillGoing();
}

/// A sheet to pick a month and year ("Mar 2023"). With [allowStillGoing]
/// it offers "Still going" for an end date. Returns null when dismissed.
Future<MonthChoice?> showBvMonthSheet(
  BuildContext context, {
  required String title,
  DateTime? initial,
  bool allowStillGoing = false,
  bool stillGoing = false,
  required DateTime now,
}) {
  return showBvSheet<MonthChoice>(
    context: context,
    title: title,
    builder: (_) => _MonthPicker(
      initial: initial,
      allowStillGoing: allowStillGoing,
      stillGoing: stillGoing,
      now: now,
    ),
  );
}

class _MonthPicker extends StatefulWidget {
  const _MonthPicker({
    required this.initial,
    required this.allowStillGoing,
    required this.stillGoing,
    required this.now,
  });

  final DateTime? initial;
  final bool allowStillGoing;
  final bool stillGoing;
  final DateTime now;

  @override
  State<_MonthPicker> createState() => _MonthPickerState();
}

class _MonthPickerState extends State<_MonthPicker> {
  late int _year = (widget.initial ?? widget.now).year;

  int get _lastYear => widget.now.year + BvMonthPickerSpec.yearsAhead;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final monthName = DateFormat.MMM(locale);
    final selected = widget.stillGoing ? null : widget.initial;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: BvSpace.s16,
      children: [
        if (widget.allowStillGoing)
          BvChoiceCard(
            key: const Key('month-still-going'),
            title: l10n.monthPickerPresent,
            selected: widget.stillGoing,
            onTap: () => Navigator.of(context).pop(const StillGoing()),
          ),
        Row(
          children: [
            IconButton(
              key: const Key('month-year-back'),
              icon: const Icon(BvIcons.caretBack),
              onPressed: _year > BvMonthPickerSpec.firstYear
                  ? () => setState(() => _year--)
                  : null,
            ),
            Expanded(
              child: Text(
                '$_year',
                key: const Key('month-year'),
                textAlign: TextAlign.center,
                style: BvType.latin.headingMd,
              ),
            ),
            IconButton(
              key: const Key('month-year-forward'),
              icon: const Icon(BvIcons.caretForward),
              onPressed: _year < _lastYear
                  ? () => setState(() => _year++)
                  : null,
            ),
          ],
        ),
        GridView.count(
          crossAxisCount: BvMonthPickerSpec.columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: BvMonthPickerSpec.gap,
          crossAxisSpacing: BvMonthPickerSpec.gap,
          childAspectRatio: BvMonthPickerSpec.cellAspect,
          children: [
            for (var m = 1; m <= 12; m++)
              BvChip(
                key: Key('month-$m'),
                label: BvWesternDigitsFormatter.normalise(
                  monthName.format(DateTime(_year, m)),
                ),
                selected:
                    selected != null &&
                    selected.year == _year &&
                    selected.month == m,
                onTap: () =>
                    Navigator.of(context).pop(PickedMonth(DateTime(_year, m))),
              ),
          ],
        ),
      ],
    );
  }
}
