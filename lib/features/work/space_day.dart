import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../data/models/daybook.dart';

bool _zonesLoaded = false;

/// When the Space's day that holds [now] ends (review 105B): midnight in
/// its [zone] (an IANA name from its project's market pack,
/// space_time_zone). With none known, or one this phone can't read, the
/// phone's own midnight.
DateTime spaceDayEnd(String? zone, DateTime now) {
  final place = _place(zone);
  if (place == null) return pinToEndOf(dayOf(now));
  final there = tz.TZDateTime.from(now, place);
  return _endOf(place, there.year, there.month, there.day);
}

/// When [day] (a calendar day, as the phone picked it) ends in the Space
/// (review 105B L6): today is the Space's today, as [spaceDayEnd]; another
/// day ends at midnight in [zone]. With none known, the phone's.
DateTime spaceDayEndOf(String? zone, DateTime day, DateTime now) {
  if (day == dayOf(now)) return spaceDayEnd(zone, now);
  final place = _place(zone);
  if (place == null) return pinToEndOf(day);
  return _endOf(place, day.year, day.month, day.day);
}

/// [hour]:[minute] on the Space's day [days] after today (review 108 RM1:
/// "Tomorrow 7:00"), in its [zone]; with none known, the phone's own.
DateTime spaceTimeOn(
  String? zone,
  DateTime now, {
  int days = 0,
  required int hour,
  int minute = 0,
}) {
  final place = _place(zone);
  if (place == null) {
    return DateTime(now.year, now.month, now.day + days, hour, minute);
  }
  final there = tz.TZDateTime.from(now, place);
  final at = tz.TZDateTime(
    place,
    there.year,
    there.month,
    there.day + days,
    hour,
    minute,
  );
  return DateTime.fromMillisecondsSinceEpoch(at.millisecondsSinceEpoch);
}

/// [wall] (a day and time as written) in the Space's [zone] (review 108
/// V3: Pick… and Post later in a Space); with none known, the phone's.
DateTime spaceTimeAt(String? zone, DateTime wall) {
  final place = _place(zone);
  if (place == null) return wall;
  final at = tz.TZDateTime(
    place,
    wall.year,
    wall.month,
    wall.day,
    wall.hour,
    wall.minute,
  );
  return DateTime.fromMillisecondsSinceEpoch(at.millisecondsSinceEpoch);
}

/// The Space's own day and time now in its [zone], as a wall clock; with
/// none known, the phone's.
DateTime spaceWallNow(String? zone, DateTime now) {
  final place = _place(zone);
  if (place == null) return now;
  final there = tz.TZDateTime.from(now, place);
  return DateTime(there.year, there.month, there.day, there.hour, there.minute);
}

tz.Location? _place(String? zone) {
  if (zone == null) return null;
  try {
    if (!_zonesLoaded) {
      tz_data.initializeTimeZones();
      _zonesLoaded = true;
    }
    return tz.getLocation(zone);
  } on tz.LocationNotFoundException {
    return null;
  }
}

DateTime _endOf(tz.Location place, int year, int month, int day) {
  final end = tz.TZDateTime(place, year, month, day + 1);
  return DateTime.fromMillisecondsSinceEpoch(end.millisecondsSinceEpoch);
}
