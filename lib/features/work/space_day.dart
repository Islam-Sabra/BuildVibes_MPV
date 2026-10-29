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
