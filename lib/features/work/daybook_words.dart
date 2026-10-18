import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:intl/intl.dart';

import '../../core/l10n/bidi.dart';
import '../../data/models/daybook.dart';
import '../../data/models/work_item.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_text_field.dart';
import '../spaces/former_member.dart';

/// A time on the spine: the time, and on a 12-hour phone its part of the
/// day for the smaller line under it.
typedef SpineTime = ({String time, String? period});

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
    if (use24) return _clock24(t);
    final (time, period) = _clock12(t);
    return l10n.daybookClock12(time, period);
  }

  /// The time spine's label: "08:14"; on a 12-hour phone the time and,
  /// for a second smaller line under it, its part of the day ("11:58",
  /// "مساءً"), so the longest time fits the column in every language
  /// (review 50 F15).
  SpineTime spineClock(DateTime t) {
    if (use24) return (time: _clock24(t), period: null);
    final (time, period) = _clock12(t);
    return (time: time, period: l10n.daybookClockPeriod(period));
  }

  String _clock24(DateTime t) => BvWesternDigitsFormatter.normalise(
    DateFormat.Hm(locale).format(t.toLocal()),
  );

  /// "11:58" (or "2" on the hour) and the part of the day.
  (String, String) _clock12(DateTime t) {
    final local = t.toLocal();
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
    return (time, period);
  }

  /// "Thursday".
  String weekday(DateTime day) => _f('EEEE', day);

  /// Home's time spine (H1 v3): "06:10" today, "Wed" this past week, then
  /// "12 Oct".
  /// Today's time has its part of the day on a line of its own
  /// ([spineClock]).
  SpineTime feedTime(DateTime t, DateTime now) {
    final day = dayOf(t);
    final today = dayOf(now);
    if (day == today) return spineClock(t);
    if (today.difference(day).inDays < DateTime.daysPerWeek) {
      return (time: _f('EEE', day), period: null);
    }
    return (time: _f('d MMM', day), period: null);
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

  /// "For Omar Haddad · by Thu 15 Oct", "For you · by today 2 pm", "For
  /// you · was due Thu 15 Oct".
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

  /// "Thu", "today", "tomorrow": a day in an edit's line.
  String _dayWord(DateTime day, DateTime now) {
    final today = dayOf(now);
    return day == today
        ? l10n.daybookToday
        : day == today.add(const Duration(days: 1))
        ? l10n.daybookTomorrow
        : _f('EEE', day);
  }

  /// What [e] was, as its history line starts it ("Omar Haddad signed as
  /// done", "You sent it back", "Sara Al-Mutairi moved the due date from
  /// Thu to today"), or as a [trace] on an earlier day says it ("Omar
  /// Haddad added an update"). [me] reads "You".
  String eventPhrase(
    DaybookEvent e, {
    required String? me,
    required DateTime now,
    bool trace = false,
  }) {
    final you = e.byId != null && e.byId == me;
    final name = _inLine(personName(l10n, e.byName));
    final due = e.dueEdit;
    return switch (e.kind) {
      DaybookEventKind.done =>
        you ? l10n.daybookLineYouSigned : l10n.daybookLineSigned(name),
      DaybookEventKind.checked =>
        you ? l10n.daybookLineYouChecked : l10n.daybookLineChecked(name),
      DaybookEventKind.sentBack =>
        you ? l10n.daybookLineYouSentBack : l10n.daybookLineSentBack(name),
      DaybookEventKind.comment when trace =>
        you ? l10n.daybookLineYouUpdate : l10n.daybookLineUpdate(name),
      DaybookEventKind.comment => you ? l10n.daybookYou : name,
      DaybookEventKind.reassigned => _gave(e, you, name),
      DaybookEventKind.edited when due != null && due.removed =>
        you ? l10n.daybookLineYouRemovedDue : l10n.daybookLineRemovedDue(name),
      DaybookEventKind.edited when due != null && _moved(due, now) != null =>
        _movedLine(_moved(due, now)!, you, name),
      DaybookEventKind.edited =>
        you ? l10n.daybookLineYouEdited : l10n.daybookLineEdited(name),
      DaybookEventKind.cancelled =>
        you ? l10n.daybookLineYouCancelled : l10n.daybookLineCancelled(name),
      DaybookEventKind.raised || DaybookEventKind.unknown =>
        you ? l10n.daybookLineYouPosted : l10n.daybookLinePosted(name),
    };
  }

  String _gave(DaybookEvent e, bool you, String name) {
    final to = _inLine(personName(l10n, e.toName));
    final from = _inLine(personName(l10n, e.fromName));
    return you
        ? l10n.daybookLineYouGave(to, from)
        : l10n.daybookLineGave(name, to, from);
  }

  /// The due's "from" and "to" words: days, or times on the same day.
  (String, String)? _moved(DaybookDueEdit due, DateTime now) {
    if (due.from == null || due.to == null) return null;
    if (due.timeOnly) {
      if (due.fromAt == null || due.toAt == null) return null;
      return (clock(due.fromAt!), clock(due.toAt!));
    }
    return (_dayWord(due.from!, now), _dayWord(due.to!, now));
  }

  String _movedLine((String, String) moved, bool you, String name) => you
      ? l10n.daybookLineYouMovedDue(moved.$1, moved.$2)
      : l10n.daybookLineMovedDue(name, moved.$1, moved.$2);

  /// The rest of [e]'s history line, after its phrase: a sign-off's or an
  /// update's note, a send-back's reason and note, a cancel's note.
  String? eventDetail(DaybookEvent e) {
    final note = e.note?.trim() ?? '';
    return switch (e.kind) {
      DaybookEventKind.sentBack => sentBackText(e.reason, e.note),
      DaybookEventKind.done ||
      DaybookEventKind.comment ||
      DaybookEventKind.cancelled => note.isEmpty ? null : inOwnDirection(note),
      _ => null,
    };
  }
}
