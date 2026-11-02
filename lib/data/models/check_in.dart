import 'package:flutter/foundation.dart';

import 'space.dart';

/// Review 109: a Check-in post's facts, as the daybook card JSON has them
/// under "check_in", and what its reader may do at a time. Times are
/// instants from the server, worked out in the Space's time zone there;
/// the phone only compares them with its clock.

/// The allowances a check-in or a check-out may have, in minutes (§1: one
/// single choice).
const checkInAllowances = [0, 10, 15, 30];

/// The allowance a new check-in starts with (post_check_in's default).
const checkInDefaultAllowance = 15;

/// The distance from the site that counts as on site, in metres: fixed by
/// the app, with no setting (§1). The server makes the test; the phone
/// says it in words and treats a reading less sure than this as weak.
const checkInSiteMetres = 100;

/// A time of day on the Space's clock ("07:00").
@immutable
class DayTime {
  const DayTime(this.hour, this.minute);

  final int hour;
  final int minute;

  /// "7:05", "07:05" or "07:05:00"; null when it isn't a time.
  static DayTime? parse(Object? value) {
    if (value is! String) return null;
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }
    return DayTime(h, m);
  }

  /// "07:05", as post_check_in takes it.
  String get json =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// On [day] (a calendar day, as a wall clock).
  DateTime on(DateTime day) =>
      DateTime(day.year, day.month, day.day, hour, minute);

  @override
  bool operator ==(Object other) =>
      other is DayTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() => json;
}

/// Where the person was when they marked: within [checkInSiteMetres] of
/// the site, further away, or without sharing their location.
enum CheckInPlace {
  onSite('on_site'),
  away('away'),
  notShared('not_shared');

  const CheckInPlace(this.json);
  final String json;

  static CheckInPlace fromJson(Object? v) =>
      values.where((p) => p.json == v).firstOrNull ?? notShared;
}

/// In or Out.
enum CheckInMarkKind {
  checkIn('in'),
  checkOut('out');

  const CheckInMarkKind(this.json);
  final String json;

  static CheckInMarkKind fromJson(Object? v) =>
      v == checkOut.json ? checkOut : checkIn;
}

/// A stamp's colour (CI4): green, amber or grey.
enum CheckInTone { good, warn, quiet }

/// One mark: when, on time or not, and the place's result. Never the
/// person's point: the server keeps none.
@immutable
class CheckInMark {
  const CheckInMark({
    required this.at,
    required this.onTime,
    required this.place,
  });

  static CheckInMark? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final at = _time(json['at']);
    if (at == null) return null;
    return CheckInMark(
      at: at,
      onTime: json['on_time'] == true,
      place: CheckInPlace.fromJson(json['place']),
    );
  }

  final DateTime at;
  final bool onTime;
  final CheckInPlace place;

  /// ✓ On time · on site is green; late or not at site amber; location
  /// not shared (and on time) grey.
  CheckInTone get tone {
    if (!onTime || place == CheckInPlace.away) return CheckInTone.warn;
    if (place == CheckInPlace.notShared) return CheckInTone.quiet;
    return CheckInTone.good;
  }
}

/// Today's times for one check-in, from the server (§2).
@immutable
class CheckInToday {
  const CheckInToday({
    required this.day,
    required this.runs,
    required this.inOpensAt,
    required this.inUntil,
    required this.inClosesAt,
    required this.dayEndsAt,
    this.outOpensAt,
    this.outUntil,
  });

  static CheckInToday? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final day = _day(json['day']);
    final opens = _time(json['in_opens_at']);
    final until = _time(json['in_until']);
    final closes = _time(json['in_closes_at']);
    final ends = _time(json['day_ends_at']);
    if (day == null ||
        opens == null ||
        until == null ||
        closes == null ||
        ends == null) {
      return null;
    }
    return CheckInToday(
      day: day,
      runs: json['runs'] != false,
      inOpensAt: opens,
      inUntil: until,
      inClosesAt: closes,
      dayEndsAt: ends,
      outOpensAt: _time(json['out_opens_at']),
      outUntil: _time(json['out_until']),
    );
  }

  /// The Space's day these times are for.
  final DateTime day;

  /// A check-in day: false on a day off of an Every day one.
  final bool runs;
  final DateTime inOpensAt;

  /// On time up to here; late after it.
  final DateTime inUntil;

  /// Check-in stays open to here: check-out's opening, or the day's end.
  final DateTime inClosesAt;
  final DateTime dayEndsAt;
  final DateTime? outOpensAt;
  final DateTime? outUntil;
}

/// What the person's card offers at a time (CI4).
enum CheckInAction {
  /// Nothing to tap.
  none,

  /// Check in, not yet open: "Check in · from 6:45", off.
  inSoon,
  checkIn,

  /// Check out, not yet open: "Check out · from 14:45", off.
  outSoon,
  checkOut,
}

typedef CheckInStep = ({CheckInAction action, bool tryAgain, bool missed});

/// A Check-in post (review 109), as the card JSON has it.
@immutable
class CheckInSetup {
  const CheckInSetup({
    required this.inTime,
    required this.inAllow,
    this.outTime,
    this.outAllow,
    this.daily = false,
    this.teams,
    this.stopped = false,
    this.siteSet = true,
    this.seesList = false,
    this.canStop = false,
    this.asked = false,
    this.today,
    this.myIn,
    this.myOut,
    this.missed = false,
    this.zone,
    this.siteLat,
    this.siteLng,
  });

  static CheckInSetup? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final inTime = DayTime.parse(json['in_time']);
    if (inTime == null) return null;
    final teams = json['teams'];
    return CheckInSetup(
      inTime: inTime,
      inAllow: (json['in_allow'] as num?)?.toInt() ?? checkInDefaultAllowance,
      outTime: DayTime.parse(json['out_time']),
      outAllow: (json['out_allow'] as num?)?.toInt(),
      daily: json['daily'] == true,
      teams: teams is List
          ? [
              for (final t in teams)
                (
                  id: (t as Map<String, dynamic>)['id'] as String,
                  name: t['name'] as String? ?? '',
                ),
            ]
          : null,
      stopped: json['stopped'] == true,
      siteSet: json['site_set'] != false,
      seesList: json['sees_list'] == true,
      canStop: json['can_stop'] == true,
      asked: json['asked'] == true,
      today: CheckInToday.fromJson(json['today']),
      myIn: CheckInMark.fromJson(json['my_in']),
      myOut: CheckInMark.fromJson(json['my_out']),
      missed: json['missed'] == true,
      zone: json['tz'] as String?,
      siteLat: (json['site_lat'] as num?)?.toDouble(),
      siteLng: (json['site_lng'] as num?)?.toDouble(),
    );
  }

  /// Y1: the check-in's own clock (an IANA name): the Space's time zone,
  /// or its creator's phone's when the Space has none. Its times show in
  /// it.
  final String? zone;

  /// The site, when the card gives it (review 113's nudge reuses it).
  final double? siteLat;
  final double? siteLng;

  final DayTime inTime;
  final int inAllow;
  final DayTime? outTime;
  final int? outAllow;

  /// Every day (the market pack's working days), or once.
  final bool daily;

  /// The Teams asked; null: the whole Space.
  final List<({String id, String name})>? teams;
  final bool stopped;
  final bool siteSet;

  /// The reader sees the list (CI5): its creator, or the Space admin once
  /// the creator has left.
  final bool seesList;

  /// The reader may Stop it (the server says: its creator, or a Space
  /// admin once the creator left, on a daily one not yet stopped).
  final bool canStop;

  /// The reader is asked to check in (in an asked Team, not a Viewer).
  final bool asked;
  final CheckInToday? today;
  final CheckInMark? myIn;
  final CheckInMark? myOut;

  /// The server says the reader missed today's check-in.
  final bool missed;

  /// What the reader's card offers at [now] (§2): Check in from its
  /// opening to its close; then Check out from its opening to the day's
  /// end. Missed: no In once check-in closed.
  CheckInStep stepAt(DateTime now) {
    const nothing = (
      action: CheckInAction.none,
      tryAgain: false,
      missed: false,
    );
    final t = today;
    if (!asked || t == null) return nothing;
    // A past once-only check-in, or a stopped one, keeps its day (runs is
    // false): nothing to tap, but a miss still shows.
    if (stopped || !t.runs) {
      return (
        action: CheckInAction.none,
        tryAgain: false,
        missed: myIn == null && missed,
      );
    }
    final inOpen = !now.isBefore(t.inOpensAt) && now.isBefore(t.inClosesAt);
    final mine = myIn;
    if (mine == null) {
      if (missed || !now.isBefore(t.inClosesAt)) {
        // Y5: a check-out without a check-in is allowed: In is missed,
        // and Check out is offered once its window opens.
        final outOpens = t.outOpensAt;
        final out =
            outTime != null &&
            outOpens != null &&
            myOut == null &&
            !now.isBefore(outOpens) &&
            now.isBefore(t.dayEndsAt);
        return (
          action: out ? CheckInAction.checkOut : CheckInAction.none,
          tryAgain: false,
          missed: true,
        );
      }
      return (
        action: inOpen ? CheckInAction.checkIn : CheckInAction.inSoon,
        tryAgain: false,
        missed: false,
      );
    }
    final tryAgain = inOpen && mine.place == CheckInPlace.away;
    final outOpens = t.outOpensAt;
    if (outTime == null || outOpens == null || myOut != null) {
      return (action: CheckInAction.none, tryAgain: tryAgain, missed: false);
    }
    if (now.isBefore(outOpens)) {
      return (action: CheckInAction.outSoon, tryAgain: tryAgain, missed: false);
    }
    if (!now.isBefore(t.dayEndsAt)) return nothing;
    return (action: CheckInAction.checkOut, tryAgain: false, missed: false);
  }
}

/// mark_check_in's answer.
@immutable
class CheckInResult {
  const CheckInResult({
    required this.day,
    required this.kind,
    required this.mark,
  });

  factory CheckInResult.fromJson(Map<String, dynamic> json) => CheckInResult(
    day: _day(json['day']) ?? DateTime.now(),
    kind: CheckInMarkKind.fromJson(json['kind']),
    mark:
        CheckInMark.fromJson(json) ??
        CheckInMark(
          at: DateTime.now(),
          onTime: false,
          place: CheckInPlace.notShared,
        ),
  );

  final DateTime day;
  final CheckInMarkKind kind;
  final CheckInMark mark;
}

/// One person on the creator's list (CI5): their In and Out, or missed.
@immutable
class CheckInLine {
  const CheckInLine({
    required this.userId,
    this.name,
    this.team,
    this.inMark,
    this.outMark,
    this.missed = false,
  });

  factory CheckInLine.fromJson(Map<String, dynamic> json) {
    CheckInMark? mark(String side) {
      final at = _time(json['${side}_at']);
      if (at == null) return null;
      return CheckInMark(
        at: at,
        onTime: json['${side}_on_time'] == true,
        place: CheckInPlace.fromJson(json['${side}_place']),
      );
    }

    return CheckInLine(
      userId: json['user_id'] as String,
      name: json['name'] as String?,
      team: json['team'] as String?,
      inMark: mark('in'),
      outMark: mark('out'),
      missed: json['missed'] == true,
    );
  }

  final String userId;

  /// Null across a block or for a hidden account: "Former member".
  final String? name;
  final String? team;
  final CheckInMark? inMark;
  final CheckInMark? outMark;
  final bool missed;
}

/// Why mark_check_in (or stop_check_in) said no, from its message; each
/// has its own plain line.
enum CheckInRefusal {
  notAllowed,
  notOpenYet,
  closed,
  notToday,
  stopped,
  already,

  /// Y4: more than the day's tries for one person, post and kind.
  tooMany,

  /// Check out on a check-in without one (the server's 'no check-out').
  noCheckOut,
  network,
  unknown;

  static CheckInRefusal of(SpaceException e) {
    final m = (e.message ?? '').toLowerCase();
    if (e.failure == SpaceFailure.network) return network;
    if (m.contains('not open yet')) return notOpenYet;
    if (m.contains('not a check-in day')) return notToday;
    if (m.contains('already checked in')) return already;
    if (m.contains('too many tries')) return tooMany;
    if (m.contains('no check-out')) return noCheckOut;
    if (m.contains('stopped')) return stopped;
    if (m.contains('closed')) return closed;
    if (e.failure == SpaceFailure.notAllowed) return notAllowed;
    return unknown;
  }
}

DateTime? _time(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

/// A calendar day ("2026-10-15"), as a plain date.
DateTime? _day(Object? value) {
  if (value is! String) return null;
  final parts = value.split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

/// Check-out must open after check-in's on-time limit (post_check_in:
/// "check-out opens after check-in's allowance").
bool checkOutFits({
  required DayTime inTime,
  required int inAllow,
  required DayTime outTime,
  required int outAllow,
}) => _minutes(outTime) - outAllow > _minutes(inTime) + inAllow;

/// The check-in time and its allowance fit in the day (post_check_in).
bool checkInFitsDay(DayTime inTime, int inAllow) =>
    _minutes(inTime) - inAllow >= 0 &&
    _minutes(inTime) + inAllow < Duration.minutesPerDay;

int _minutes(DayTime t) => t.hour * Duration.minutesPerHour + t.minute;

/// A calendar day as the server takes it ("2026-10-15").
String checkInDayJson(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// For tests and the list: [checkInDayJson] read back.
DateTime? checkInDayOf(String value) => _day(value);
