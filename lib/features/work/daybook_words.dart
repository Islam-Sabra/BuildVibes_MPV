import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:intl/intl.dart';

import '../../core/l10n/bidi.dart';
import '../../core/l10n/bv_time.dart';
import '../../data/models/daybook.dart';
import '../../data/models/work_item.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_marked_text.dart';
import '../../shared/widgets/bv_text_field.dart';
import '../library/library_parts.dart' show fileSize;
import '../spaces/former_member.dart';

/// The Daybook's words for days and times, in the app language with
/// Western digits. Every time of day in them is [time]'s, the app's one
/// time format (review 54 A1), which follows the phone's clock setting
/// ([use24]).
class DaybookWords {
  DaybookWords(this.l10n, this.locale, {required bool use24})
    : time = BvTime(l10n, locale, use24: use24);

  final AppLocalizations l10n;
  final String locale;

  /// The app's one time format.
  final BvTime time;

  String _f(String pattern, DateTime d) =>
      BvWesternDigitsFormatter.normalise(DateFormat(pattern, locale).format(d));

  String _clock(DateTime t) => time.clock(t);

  /// "Thursday".
  String weekday(DateTime day) => _f('EEEE', day);

  /// "15 October".
  String dayMonth(DateTime day) => _f('d MMMM', day);

  /// "Thu 15 Oct".
  String shortDate(DateTime day) => _f('EEE d MMM', day);

  /// "Thu": a day in My calendar's week strip.
  String shortWeekday(DateTime day) => _f('EEE', day);

  /// "15": a day's number in My calendar's week strip.
  String dayNumber(DateTime day) => _f('d', day);

  /// "Friday 16": a day's divider in My calendar.
  String weekdayDay(DateTime day) => _f('EEEE d', day);

  /// "October", and its year: My calendar's masthead.
  String month(DateTime day) => _f('MMMM', day);
  String year(DateTime day) => _f('y', day);

  /// A quoted message's line (review 64): "From Omar Haddad · 10:42", with
  /// the day when it wasn't today ("· Wed 14 Oct 10:42").
  String quoteFrom(DaybookQuote quote, DateTime now) {
    final name = _inLine(personName(l10n, quote.authorName));
    final at = quote.at;
    if (at == null) return l10n.daybookQuoteFromName(name);
    final when = dayOf(at) == dayOf(now)
        ? _clock(at)
        : '${shortDate(dayOf(at))} ${_clock(at)}';
    return l10n.daybookQuoteFrom(name, when);
  }

  /// An earlier day on the To do strip (F57, F61): "Mon" within the week,
  /// "Mon 12 Oct" before it; null for today.
  String? stripDay(DateTime day, DateTime now) {
    final today = dayOf(now);
    if (!day.isBefore(today)) return null;
    return today.difference(day).inDays < 7 ? _f('EEE', day) : shortDate(day);
  }

  /// "Thursday 15 October": the masthead's one line while writing.
  String compactDate(DateTime day) => _f('EEEE d MMMM', day);

  /// The due on the writing card: "Sun 18 Oct", or "Sun 18 Oct, 14:00".
  String dueProperty(DateTime day, DateTime? at) => at == null
      ? shortDate(day)
      : l10n.daybookDueProperty(shortDate(day), _clock(at));

  /// The large stamp's second line: "OMAR H · 09:40", "عمر ح · 09:40".
  /// Latin names in capitals, as the stamp prints them.
  String stampLine(String? name, DateTime at) {
    final parts = personName(l10n, name).trim().split(RegExp(r'\s+'));
    final short = parts.length < 2
        ? parts.first
        : '${parts.first} ${parts.last.characters.first}';
    // The name in its own direction, so the time beside it stays whole
    // (F53): "ISLAM A · 10:58 مساءً".
    return l10n.daybookStampBy(inOwnDirection(short.toUpperCase()), _clock(at));
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

  /// A send-back line's detail: the reason and note, then its new date
  /// when one was chosen (F62): "Photo missing · new date Thu 23 Oct".
  String _sentBackLine(DaybookEvent e) {
    final text = sentBackText(e.reason, e.note);
    final newDue = e.newDue;
    if (newDue == null) return text;
    final day = newDue.day;
    return joinMeta([
      text,
      day == null
          ? l10n.daybookLineNoNewDate
          : l10n.daybookLineNewDate(dueProperty(day, newDue.at)),
    ]);
  }

  /// "Level 2, grid C7 · 15 Oct 09:40 · Omar Haddad": the label on a proof
  /// photo (O2).
  /// The place and the name keep their own direction.
  String photoLabel({String? place, required DateTime at, String? name}) => [
    if ((place ?? '').isNotEmpty) inOwnDirection(place!),
    '${_f('d MMM', at)} ${_clock(at)}',
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

  /// What stands out on [post]'s facts line (review 50 F34), as [meta]
  /// writes it: who it is for (the name, or "you"), and the due with its
  /// tone: grey, ink today, and once passed the action colour for its
  /// owner and its author only; everyone else sees it grey (F57).
  ({String who, String? due, BvDueTone tone}) metaMarks(
    DaybookPost post, {
    required String? me,
    required DateTime now,
  }) {
    final item = post.item;
    final who = _whoMark(
      item?.ownerName,
      isMe: item?.ownerId != null && item!.ownerId == me,
    );
    final mine =
        (item?.ownerId != null && item!.ownerId == me) ||
        (post.authorId != null && post.authorId == me);
    final passed = post.isLate(now);
    return (
      who: who,
      due: _due(post, now),
      tone: passed
          ? (mine ? BvDueTone.passed : BvDueTone.quiet)
          : post.dueDate == dayOf(now)
          ? BvDueTone.today
          : BvDueTone.quiet,
    );
  }

  /// The writing card's who row once someone is chosen (F66), as the
  /// card's facts line says it: "For Islam Ahmed", "For you", with [who]
  /// the part that stands out. The row's caret is an icon (review 79 A2).
  ({String text, String who}) writingFor(
    String ownerId,
    String? ownerName, {
    required String? me,
  }) {
    final isMe = ownerId == me;
    return (
      text: isMe
          ? l10n.daybookForYou
          : l10n.daybookForPerson(_inLine(personName(l10n, ownerName))),
      who: _whoMark(ownerName, isMe: isMe),
    );
  }

  /// Who stands out in "For {name}": the name, or "you" in "For you", the
  /// words around the name in "For {name}" taken off ("For " in English;
  /// Arabic's "لك" is one word).
  String _whoMark(String? ownerName, {required bool isMe}) {
    if (!isMe) return _inLine(personName(l10n, ownerName));
    final around = l10n.daybookForPerson(_slot).split(_slot);
    final you = l10n.daybookForYou;
    return you.startsWith(around.first) && around.first.isNotEmpty
        ? you.substring(around.first.length)
        : you;
  }

  /// A stand-in for a name, to find the words around it in a sentence.
  static const _slot = '';

  /// A name inside a sentence, exactly as its owner typed it (F52: never
  /// translated). One in the sentence's own direction stays as it is
  /// ("لـ عمر حداد"); another is kept whole in its own direction ("لـ
  /// Omar Haddad").
  String _inLine(String name) =>
      Bidi.startsWithRtl(name) == Bidi.isRtlLanguage(locale)
      ? name
      : inOwnDirection(name);

  /// The due while the work is still to do (open or sent back); once it
  /// is signed as done the card says nothing of it (F57).
  String? _due(DaybookPost post, DateTime now) {
    final day = post.dueDate;
    if (day == null) return null;
    if (post.item != null && post.item!.status != WorkStatus.open) return null;
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
    final clock = at == null ? null : _clock(at);
    final isToday = day == today;
    final isTomorrow = day == today.add(const Duration(days: 1));
    final date = shortDate(day);
    if (late) {
      if (clock == null) return l10n.daybookWasDue(date);
      return isToday
          ? l10n.daybookWasDueTodayAt(clock)
          : l10n.daybookWasDueAt(date, clock);
    }
    if (clock == null) {
      return isToday
          ? l10n.daybookDueToday
          : isTomorrow
          ? l10n.daybookDueTomorrow
          : l10n.daybookDueDate(date);
    }
    return isToday
        ? l10n.daybookDueTodayAt(clock)
        : isTomorrow
        ? l10n.daybookDueTomorrowAt(clock)
        : l10n.daybookDueDateAt(date, clock);
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
      DaybookEventKind.comment =>
        you ? l10n.daybookLineYouComment : l10n.daybookLineComment(name),
      DaybookEventKind.reassigned => _gave(e, you, name),
      DaybookEventKind.edited when due != null && due.removed =>
        you ? l10n.daybookLineYouRemovedDue : l10n.daybookLineRemovedDue(name),
      DaybookEventKind.edited when due != null && _moved(due, now) != null =>
        _movedLine(_moved(due, now)!, you, name),
      // F91: only the page changed.
      DaybookEventKind.edited when e.pageOnly =>
        you ? l10n.daybookLineYouEditedPage : l10n.daybookLineEditedPage(name),
      DaybookEventKind.edited =>
        you ? l10n.daybookLineYouEdited : l10n.daybookLineEdited(name),
      DaybookEventKind.cancelled =>
        you ? l10n.daybookLineYouCancelled : l10n.daybookLineCancelled(name),
      DaybookEventKind.ticked when trace =>
        you ? l10n.daybookTraceYouTicked : l10n.daybookTraceTicked(name),
      DaybookEventKind.ticked =>
        you ? l10n.daybookLineYouTicked : l10n.daybookLineTicked(name),
      DaybookEventKind.unticked when trace =>
        you ? l10n.daybookTraceYouUnticked : l10n.daybookTraceUnticked(name),
      DaybookEventKind.unticked =>
        you ? l10n.daybookLineYouUnticked : l10n.daybookLineUnticked(name),
      DaybookEventKind.gotIt =>
        you ? l10n.daybookLineYouGotIt : l10n.daybookLineGotIt(name),
      DaybookEventKind.received =>
        you ? l10n.daybookLineYouReceived : l10n.daybookLineReceived(name),
      DaybookEventKind.onMyWay =>
        you ? l10n.daybookLineYouOnMyWay : l10n.daybookLineOnMyWay(name),
      DaybookEventKind.inMyCalendar =>
        you
            ? l10n.daybookLineYouInMyCalendar
            : l10n.daybookLineInMyCalendar(name),
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
      return (_clock(due.fromAt!), _clock(due.toAt!));
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
      DaybookEventKind.sentBack => _sentBackLine(e),
      DaybookEventKind.done ||
      DaybookEventKind.comment ||
      DaybookEventKind.cancelled => note.isEmpty ? null : inOwnDirection(note),
      // The point's words as they were when it was ticked.
      DaybookEventKind.ticked || DaybookEventKind.unticked =>
        (e.point ?? '').trim().isEmpty ? null : inOwnDirection(e.point!),
      _ => null,
    };
  }

  /// Every name, in the app language's list: "Sara Al-Mutairi and Omar
  /// Haddad", "A, B and C"; Arabic "سارة المطيري وعمر حداد".
  String names(List<String> all) {
    final shown = [for (final n in all) _inLine(n)];
    if (shown.isEmpty) return '';
    if (shown.length == 1) return shown.first;
    return l10n.daybookNamesAnd(
      shown.sublist(0, shown.length - 1).join(l10n.daybookNamesComma),
      shown.last,
    );
  }

  /// The first two names, then "and others" when there are more: never a
  /// number (rule 3).
  String someNames(List<String> all) {
    if (all.length <= _namesShown) return names(all);
    return l10n.daybookNamesOthers(
      [
        for (final n in all.take(_namesShown)) _inLine(n),
      ].join(l10n.daybookNamesComma),
    );
  }

  static const _namesShown = 2;

  /// "For Sara Al-Mutairi and Omar Haddad", "For you and Omar Haddad":
  /// who a checklist or an activity is for, [me] first as "you".
  String peopleFor(List<DaybookPerson> people, {required String? me}) {
    final mine = people.any((p) => p.id == me);
    final others = [
      for (final p in people)
        if (p.id != me) personName(l10n, p.name),
    ];
    if (mine && others.isEmpty) return l10n.daybookForYou;
    if (mine) return l10n.daybookForYouAnd(names(others));
    return l10n.daybookForPerson(names(others));
  }

  /// A checklist's due as its card says it: "By Sun 18 Oct", "By today
  /// 2 pm".
  String checklistDue(DaybookPost post, DateTime now) {
    final day = post.dueDate!;
    final at = post.dueAt;
    final today = dayOf(now);
    final date = day == today
        ? l10n.daybookToday
        : day == today.add(const Duration(days: 1))
        ? l10n.daybookTomorrow
        : shortDate(day);
    return at == null
        ? l10n.daybookChecklistBy(date)
        : l10n.daybookChecklistByAt(date, _clock(at));
  }

  /// The last day an announcement pinned [until] stays up, short, as the
  /// folded line's "until Fri" says it: "today", the weekday within the
  /// week, else the date.
  String pinnedDay(DateTime until, DateTime now) {
    final day = dayOf(pinnedLastDay(until));
    final today = dayOf(now);
    if (day == today) return l10n.daybookToday;
    return day.difference(today).inDays < DateTime.daysPerWeek
        ? _f('EEE', day)
        : _f('d MMM', day);
  }

  /// The writing card's pin (F82): "2:00 pm" today, "Wed 2:00 pm" on
  /// another day, and with no time only the day ("Wed").
  String pinnedShort(DateTime until, DateTime now) {
    if (!pinHasTime(until)) return pinnedDay(until, now);
    return dayOf(until) == dayOf(now)
        ? _clock(until)
        : '${pinnedDay(until, now)} ${_clock(until)}';
  }

  /// A pinned announcement's facts line (F85): "Until Friday 23 Oct",
  /// "Until Friday 23 Oct · 2:00 pm", "Until today · 2:00 pm", and on its
  /// last day without a time "Until today".
  String pinnedUntil(DateTime until, DateTime now) {
    final day = dayOf(pinnedLastDay(until));
    final date = day == dayOf(now) ? l10n.daybookToday : _f('EEEE d MMM', day);
    return pinHasTime(until)
        ? l10n.daybookPinnedUntilAt(date, _clock(until))
        : l10n.daybookPinnedUntil(date);
  }

  /// The calendar leaf's three lines: "FRI", "16", "Oct" (Arabic "الجمعة",
  /// "16", "أكتوبر").
  ({String weekday, String day, String month}) leaf(DateTime at) => (
    weekday: _arabic ? _f('EEEE', at) : _f('EEE', at).toUpperCase(),
    day: _f('d', at),
    month: _f('MMM', at),
  );

  bool get _arabic => locale.startsWith('ar');

  /// When an activity is, as its card says it: "Tomorrow, 7:00 to 8:00
  /// am", "Sat 17 Oct, 7:00 am"; on its day only the time, with "starts
  /// in 30 min" in its last hour and "on now" until it ends. A [cancelled]
  /// one never counts down (review 50 F46): only its day and time.
  String activityWhen(
    DateTime start,
    DateTime? end,
    DateTime now, {
    bool cancelled = false,
  }) {
    final time = end == null ? _clock(start) : this.time.range(start, end);
    final day = dayOf(start);
    final today = dayOf(now);
    if (day != today) {
      final word = day == today.add(const Duration(days: 1))
          ? l10n.daybookTomorrowStart
          : shortDate(day);
      return l10n.daybookActivityWhen(word, time);
    }
    if (cancelled) return time;
    final toStart = start.difference(now);
    if (!toStart.isNegative && toStart <= _soon) {
      return l10n.daybookStartsIn(time, toStart.inMinutes);
    }
    final over = end ?? start.add(DaybookPost.activityLength);
    if (toStart.isNegative && now.isBefore(over)) {
      return l10n.daybookOnNow(time);
    }
    return time;
  }

  /// "Starts in" shows in the activity's last hour before it starts.
  static const _soon = Duration(hours: 1);

  /// When someone acknowledged, in the list of who did (F48): the time
  /// today, else the day and the time ("Thu 15 Oct, 22:46").
  String ackTime(DateTime at, DateTime now) {
    final day = dayOf(at);
    if (day == dayOf(now)) return _clock(at);
    return l10n.daybookDayTime(shortDate(day), _clock(at));
  }

  /// F76: "Replaced by V2 · today" on an older version's post.
  String replacedBy(DaybookFile file, DateTime now) {
    final at = file.newerAt;
    final day = at == null ? null : dayOf(at);
    return l10n.daybookReplacedBy(
      file.newerVersionNo == null
          ? ''
          : l10n.libraryVersionNo(file.newerVersionNo!),
      day == null
          ? ''
          : day == dayOf(now)
          ? l10n.daybookToday
          : shortDate(day),
    );
  }

  /// "V1 · PDF · 2.4 MB": what a file post's file is (F75: its number).
  String fileFact(DaybookFile file) => [
    if (file.versionNo != null) l10n.libraryVersionNo(file.versionNo!),
    file.isPdf ? l10n.daybookPdf : l10n.daybookPhoto,
    if (file.bytes != null) fileSize(l10n, file.bytes),
  ].join(' · ');
}
