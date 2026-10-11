import '../../l10n/gen/app_localizations.dart';

/// "just now", "5 min ago", "2h ago", "yesterday", "3 days ago".
String formatAgo(AppLocalizations l10n, DateTime then, DateTime now) {
  final diff = now.difference(then);
  if (diff.inMinutes < 1) return l10n.timeJustNow;
  if (diff.inHours < 1) return l10n.timeMinutesAgo(diff.inMinutes);
  if (diff.inDays < 1) return l10n.timeHoursAgo(diff.inHours);
  if (diff.inDays == 1) return l10n.timeYesterday;
  return l10n.timeDaysAgo(diff.inDays);
}
