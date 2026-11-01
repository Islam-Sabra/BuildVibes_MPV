import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

/// The phone's own IANA time zone ("Asia/Kuwait"), or null when the phone
/// can't say. Review 109 Y1: a check-in in a Space with no time zone of
/// its own keeps its creator's. A provider so tests can stand in.
typedef PhoneZone = Future<String?> Function();

final phoneTimeZoneProvider = Provider<PhoneZone>(
  (ref) => () async {
    try {
      return (await FlutterTimezone.getLocalTimezone()).identifier;
    } on Object catch (e) {
      debugPrint('phone time zone: ${e.runtimeType}');
      return null;
    }
  },
);
