import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../data/models/daybook.dart';

bool _zonesLoaded = false;

/// When the Space's day that holds [now] ends (review 105B): midnight in
/// its [zone] (an IANA name from its market pack, space_time_zone). With
/// none known, or one this phone can't read, the phone's own midnight.
DateTime spaceDayEnd(String? zone, DateTime now) {
  if (zone == null) return pinToEndOf(dayOf(now));
  try {
    if (!_zonesLoaded) {
      tz_data.initializeTimeZones();
      _zonesLoaded = true;
    }
    final place = tz.getLocation(zone);
    final there = tz.TZDateTime.from(now, place);
    final end = tz.TZDateTime(place, there.year, there.month, there.day + 1);
    return DateTime.fromMillisecondsSinceEpoch(end.millisecondsSinceEpoch);
  } on tz.LocationNotFoundException {
    return pinToEndOf(dayOf(now));
  }
}
