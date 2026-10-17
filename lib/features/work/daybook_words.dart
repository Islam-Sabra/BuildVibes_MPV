import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:intl/intl.dart';

import '../../core/l10n/bidi.dart';
import '../../data/models/daybook.dart';
import '../../data/models/work_item.dart';
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

  /// "08:14"; on a 12-hour phone "8:14 am", "2 pm" ("2 ظهرًا" in Arabic,
  /// the AR frames' words).
  String clock(DateTime t) {
    final local = t.toLocal();
    if (use24) {
      return BvWesternDigitsFormatter.normalise(
        DateFormat.Hm(locale).format(local),
      );
    }
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final time = local.minute == 0
        ? '$hour'
        : '$hour:${local.minute.toString().padLeft(2, '0')}';
    final period = local.hour < 12
        ? 'morning'
        : local.hour < 15
        ? 'noon'
        : local.hour < 18
        ? 'afternoon'
        : 'evening';
    return l10n.daybookClock12(time, period);
  }

  /// "Thursday".
  String weekday(DateTime day) => _f('EEEE', day);

  /// Home's time spine (H1 v3): "06:10" today, "Wed" this past week, then
  /// "12 Oct".
  String feedTime(DateTime t, DateTime now) {
    final day = dayOf(t);
    final today = dayOf(now);
    if (day == today) return clock(t);
    if (today.difference(day).inDays < DateTime.daysPerWeek) {
      return _f('EEE', day);
    }
    return _f('d MMM', day);
  }

  /// "15 October".
  String dayMonth(DateTime day) => _f('d MMMM', day);

  /// "Thu 15 Oct".
  String shortDate(DateTime day) => _f('EEE d MMM', day);

  /// "Thursday 15 October": the masthead's one line while writing.
  String compactDate(DateTime day) => _f('EEEE d MMMM', day);

  /// The due on the writing card: "Sun 18 Oct", or "Sun 18 Oct, 14:00".
  String dueProperty(DateTime day, DateTime? at) => at == null
      ? shortDate(day)
      : l10n.daybookDueProperty(shortDate(day), clock(at));

  /// The large stamp's second line: "OMAR H · 09:40", "عمر ح · 09:40".
  /// Latin names in capitals, as the stamp prints them.
  String stampLine(String? name, DateTime at) {
    final parts = personName(l10n, name).trim().split(RegExp(r'\s+'));
    final short = parts.length < 2
        ? parts.first
        : '${parts.first} ${parts.last.characters.first}';
    return l10n.daybookStampBy(short.toUpperCase(), clock(at));
  }

  /// A send-back reason, as the card lists it.
  String reason(SendBackReason? r) => switch (r) {
    SendBackReason.photoMissing => l10n.daybookReasonPhotoMissing,
    SendBackReason.notAsAsked => l10n.daybookReasonNotAsAsked,
    SendBackReason.notFinished => l10n.daybookReasonNotFinished,
    SendBackReason.other || null => l10n.daybookReasonOther,
  };

  /// "Not as asked. One sleeve is 50 mm short.": a send-back's reason and
  /// its note, in the note's own direction.
  String sentBackText(SendBackReason? r, String? note) {
    final text = note?.trim() ?? '';
    return text.isEmpty
        ? reason(r)
        : l10n.daybookSentBackText(reason(r), inOwnDirection(text));
  }

  /// "Level 2, grid C7 · 15 Oct 09:40 · Omar Haddad": the label on a proof
  /// photo (O2).
  /// The place and the name keep their own direction.
  String photoLabel({String? place, required DateTime at, String? name}) => [
    if ((place ?? '').isNotEmpty) inOwnDirection(place!),
    '${_f('d MMM', at)} ${clock(at)}',
    if ((name ?? '').isNotEmpty) inOwnDirection(name!),
  ].join(' · ');

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
    return due(day, post.dueAt, now: now, late: post.isLate(now));
  }

  /// "by today 14:00", "by Sun 18 Oct", "was due Wed 14 Oct": a work
  /// item's due as its slip says it (Needs you rows too).
  String due(
    DateTime day,
    DateTime? at, {
    required DateTime now,
    required bool late,
  }) {
    final today = dayOf(now);
    final time = at == null ? null : clock(at);
    final isToday = day == today;
    final isTomorrow = day == today.add(const Duration(days: 1));
    final date = shortDate(day);
    if (late) {
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

  /// "Edited: due moved from Thu to today", "Edited: due removed", or null
  /// when the last edit didn't touch the due.
  String? editedDue(DaybookDueEdit? edit, DateTime now) {
    if (edit != null && edit.removed) return l10n.daybookEditedDueRemoved;
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
