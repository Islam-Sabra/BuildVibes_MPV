import 'package:intl/intl.dart';

import '../../core/l10n/bidi.dart';
import '../../data/models/daybook.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_text_field.dart';
import '../spaces/former_member.dart';

/// The Daybook's words for days and times, in the app language with
/// Western digits. [use24] follows the phone's own clock setting
/// (MediaQuery.alwaysUse24HourFormat, review 44 answer 6), one format for
/// the whole screen.
class DaybookWords {
  const DaybookWords(this.l10n, this.locale, {required this.use24});

  final AppLocalizations l10n;
  final String locale;
  final bool use24;

  String _f(String pattern, DateTime d) =>
      BvWesternDigitsFormatter.normalise(DateFormat(pattern, locale).format(d));

  /// "08:14", or "8:14 AM" on a 12-hour phone.
  String clock(DateTime t) => BvWesternDigitsFormatter.normalise(
    (use24 ? DateFormat.Hm(locale) : DateFormat.jm(locale)).format(t.toLocal()),
  );

  /// "Thursday".
  String weekday(DateTime day) => _f('EEEE', day);

  /// "15 October".
  String dayMonth(DateTime day) => _f('d MMMM', day);

  /// "Thu 15 Oct".
  String shortDate(DateTime day) => _f('EEE d MMM', day);

  /// "15 October, day 41 on site": day 1 is [siteStart]; only the date
  /// without one, or before it.
  String dateLine(DateTime day, DateTime? siteStart) {
    final date = dayMonth(day);
    if (siteStart == null) return date;
    final start = DateTime(siteStart.year, siteStart.month, siteStart.day);
    // Calendar days, counted on dates so a change of clock can't shift it.
    final n =
        DateTime.utc(
          day.year,
          day.month,
          day.day,
        ).difference(DateTime.utc(start.year, start.month, start.day)).inDays +
        1;
    return n < 1 ? date : l10n.daybookDateLine(date, n);
  }

  /// "For Omar Haddad, by Thu 15 Oct", "For you, by today 2 pm", "For
  /// you, was due Thu 15 Oct".
  String meta(DaybookPost post, {required String? me, required DateTime now}) {
    final item = post.item;
    final who = item?.ownerId != null && item!.ownerId == me
        ? l10n.daybookForYou
        : l10n.daybookForPerson(_inLine(personName(l10n, item?.ownerName)));
    final due = _due(post, now);
    return due == null ? who : l10n.daybookMeta(who, due);
  }

  /// A name inside a sentence. One in the sentence's own direction stays
  /// as it is, so the Arabic "ل" joins it ("لعمر حداد"); another is kept
  /// whole in its own direction.
  String _inLine(String name) =>
      Bidi.startsWithRtl(name) == Bidi.isRtlLanguage(locale)
      ? name
      : inOwnDirection(name);

  String? _due(DaybookPost post, DateTime now) {
    final day = post.dueDate;
    if (day == null) return null;
    final today = dayOf(now);
    final time = post.dueAt == null ? null : clock(post.dueAt!);
    final isToday = day == today;
    final isTomorrow = day == today.add(const Duration(days: 1));
    final date = shortDate(day);
    if (post.isLate(now)) {
      if (time == null) return l10n.daybookWasDue(date);
      return isToday
          ? l10n.daybookWasDueTodayAt(time)
          : l10n.daybookWasDueAt(date, time);
    }
    if (time == null) {
      return isToday
          ? l10n.daybookDueToday
          : isTomorrow
          ? l10n.daybookDueTomorrow
          : l10n.daybookDueDate(date);
    }
    return isToday
        ? l10n.daybookDueTodayAt(time)
        : isTomorrow
        ? l10n.daybookDueTomorrowAt(time)
        : l10n.daybookDueDateAt(date, time);
  }

  /// "Edited: due moved from Thu to today", or null when the last edit
  /// didn't move the due (or cleared it).
  String? editedDue(DaybookDueEdit? edit, DateTime now) {
    if (edit == null || edit.from == null || edit.to == null) return null;
    if (edit.timeOnly) {
      if (edit.fromAt == null || edit.toAt == null) return null;
      return l10n.daybookEditedDue(clock(edit.fromAt!), clock(edit.toAt!));
    }
    final today = dayOf(now);
    String word(DateTime day) => day == today
        ? l10n.daybookToday
        : day == today.add(const Duration(days: 1))
        ? l10n.daybookTomorrow
        : _f('EEE', day);
    return l10n.daybookEditedDue(word(edit.from!), word(edit.to!));
  }
}
