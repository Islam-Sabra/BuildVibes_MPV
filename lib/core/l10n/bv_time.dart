import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../l10n/gen/app_localizations.dart';
import 'bidi.dart';
import '../../shared/widgets/bv_text_field.dart' show BvWesternDigitsFormatter;

/// A time split for a two-line slot: the [time], and the part of the day
/// on a small second line ([period]; null when it stays on one line).
typedef BvClockParts = ({String time, String? period});

/// The app's one way of writing a time of day (review 54 A1). Every time
/// on screen comes from here: the daybook card's header, its history
/// lines and traces, the stamps, dues, post cards, the post page and its
/// replies, Activity, Needs you, Home → Spaces and Chat.
///
/// It follows the phone's own clock setting
/// (`MediaQuery.alwaysUse24HourFormat`), with Western digits:
/// - 24-hour, both languages: "14:00", "08:14".
/// - 12-hour, English: "2:00 pm", "8:14 am", always with the minutes.
/// - 12-hour, Arabic: the time and the part of the day in words, as the AR
///   frames write it: "2:00 ظهرًا", "8:14 صباحًا", "4:30 عصرًا",
///   "11:58 مساءً", never the short "م" / "ص", so a reader sees one form
///   everywhere.
///
/// A time is always one line (review 82 S1): the part of the day stays
/// beside the time, joined by a no-break space, in the card's header, its
/// history lines, a checklist point's tick, and inside sentences.
@immutable
class BvTime {
  const BvTime(this.l10n, this.locale, {required this.use24});

  /// The app language and the phone's clock setting in [context].
  factory BvTime.of(BuildContext context) => BvTime(
    AppLocalizations.of(context),
    Localizations.localeOf(context).toLanguageTag(),
    use24: MediaQuery.alwaysUse24HourFormatOf(context),
  );

  final AppLocalizations l10n;
  final String locale;
  final bool use24;

  /// [t] on one line.
  String clock(DateTime t) {
    final p = _parts(t);
    if (p.period == null) return p.time;
    final clock = l10n.timeClock12(p.time, p.period!);
    // In Arabic the time and its part of the day are one unit (F53): next
    // to a Latin name the period would otherwise sit by the name.
    return _arabic ? rtlRun(clock) : clock;
  }

  /// [t] for a time column (history lines, a point's tick): one line, as
  /// [clock] (review 82 S1; the two-line Arabic slot of review 51 F15 is
  /// gone).
  BvClockParts parts(DateTime t) => (time: clock(t), period: null);

  /// [from] to [to] on one line: "7:00 to 8:00 am", "14:00 to 15:30",
  /// "11:30 am to 1:00 pm"; the part of the day is said once when both
  /// share it.
  String range(DateTime from, DateTime to) {
    final a = _parts(from);
    final b = _parts(to);
    final start = a.period != null && a.period == b.period
        ? a.time
        : clock(from);
    return l10n.timeRange(start, clock(to));
  }

  /// When something happened, at the end of its row (post cards, replies,
  /// Home → Spaces): the time today, the weekday this past week ("Wed"),
  /// then the date ("12 Oct").
  String moment(DateTime t, DateTime now) {
    final local = t.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    final today = DateTime(now.year, now.month, now.day);
    if (day == today) return clock(t);
    if (today.difference(day).inDays < DateTime.daysPerWeek) {
      return _date('EEE', day);
    }
    return _date('d MMM', day);
  }

  bool get _arabic => locale.startsWith('ar');

  String _date(String pattern, DateTime d) =>
      BvWesternDigitsFormatter.normalise(DateFormat(pattern, locale).format(d));

  BvClockParts _parts(DateTime t) {
    final local = t.toLocal();
    final minutes = local.minute.toString().padLeft(2, '0');
    if (use24) {
      return (
        time: '${local.hour.toString().padLeft(2, '0')}:$minutes',
        period: null,
      );
    }
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    return (time: '$hour:$minutes', period: l10n.timePeriod(_period(local)));
  }

  /// The part of the day: morning (before noon), noon (12 to 3 pm),
  /// afternoon (3 to 6 pm) or evening. English says am or pm.
  static String _period(DateTime t) => t.hour < 12
      ? 'morning'
      : t.hour < 15
      ? 'noon'
      : t.hour < 18
      ? 'afternoon'
      : 'evening';
}
