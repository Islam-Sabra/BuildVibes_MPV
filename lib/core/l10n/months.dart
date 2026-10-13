import 'package:intl/intl.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_text_field.dart';

/// Month dates are stored as the first day of the month.
DateTime firstOfMonth(DateTime d) => DateTime(d.year, d.month);

DateTime? parseMonth(Object? value) =>
    value == null ? null : firstOfMonth(DateTime.parse(value as String));

String? monthToJson(DateTime? d) => d == null
    ? null
    : '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-01';

/// "Mar 2023" / "مارس 2023", always with Western digits.
String formatMonth(DateTime d, String locale) =>
    BvWesternDigitsFormatter.normalise(DateFormat.yMMM(locale).format(d));

/// "12 Sep" / "12 سبتمبر": day first, as on cards and R3, with Western
/// digits.
String formatDayMonth(DateTime d, String locale) =>
    BvWesternDigitsFormatter.normalise(DateFormat('d MMM', locale).format(d));

/// "18 Oct" / "18 أكتوبر", always with Western digits.
String formatDay(DateTime d, String locale) =>
    BvWesternDigitsFormatter.normalise(DateFormat.MMMd(locale).format(d));

/// "Mar 2023 – Present", or "Mar 2023 – Expected Jun 2026".
String formatMonthRange(
  AppLocalizations l10n,
  String locale, {
  required DateTime? start,
  required DateTime? end,
  bool endExpected = false,
}) {
  if (start == null && end == null) return '';
  final from = start == null ? '' : formatMonth(start, locale);
  final to = end == null
      ? l10n.present
      : endExpected
      ? l10n.expectedMonth(formatMonth(end, locale))
      : formatMonth(end, locale);
  return start == null ? to : l10n.dateRange(from, to);
}
