import 'package:intl/intl.dart' show DateFormat;

import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_text_field.dart' show BvWesternDigitsFormatter;

/// "just now", "5 min ago", "2h ago", "yesterday", "3 days ago".
String formatAgo(AppLocalizations l10n, DateTime then, DateTime now) {
  final diff = now.difference(then);
  if (diff.inMinutes < 1) return l10n.timeJustNow;
  if (diff.inHours < 1) return l10n.timeMinutesAgo(diff.inMinutes);
  if (diff.inDays < 1) return l10n.timeHoursAgo(diff.inHours);
  if (diff.inDays == 1) return l10n.timeYesterday;
  return l10n.timeDaysAgo(diff.inDays);
}

/// Short times on post cards and replies, as drawn: "now", "4m", "3h",
/// "Yesterday", then the date ("12 Oct"), with Western digits.
String formatShortAgo(
  AppLocalizations l10n,
  DateTime then,
  DateTime now,
  String locale,
) {
  final diff = now.difference(then);
  if (diff.inMinutes < 1) return l10n.timeNowShort;
  if (diff.inHours < 1) return l10n.timeMinutesShort(diff.inMinutes);
  if (diff.inDays < 1) return l10n.timeHoursShort(diff.inHours);
  if (diff.inDays == 1) return l10n.timeYesterday;
  return BvWesternDigitsFormatter.normalise(
    DateFormat('d MMM', locale).format(then),
  );
}
