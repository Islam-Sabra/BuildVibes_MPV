import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether pushes can reach this phone (F9).
enum PushHealth {
  /// Not known yet: the phone is still asked, or notifications are off.
  unknown,

  /// The phone has a push token and it was given to the server.
  working,

  /// Allowed, but the phone gave no push token after its tries: nothing
  /// will arrive. Home and Settings → Notifications say so, with Fix it.
  notReaching,
}

final pushHealthProvider = NotifierProvider<PushHealthState, PushHealth>(
  PushHealthState.new,
);

class PushHealthState extends Notifier<PushHealth> {
  @override
  PushHealth build() => PushHealth.unknown;

  void set(PushHealth health) => state = health;
}

/// A push that arrived while the app was open: the pages it is about read
/// again (F11). Its [spaceId] is the Space's, when it is about one.
@immutable
class PushArrival {
  const PushArrival(this.data);

  final Map<String, String> data;

  String? get spaceId => data['space_id'];
}

final pushArrivalProvider = NotifierProvider<PushArrivals, PushArrival?>(
  PushArrivals.new,
);

class PushArrivals extends Notifier<PushArrival?> {
  @override
  PushArrival? build() => null;

  // A new object each time, so the same push data twice still tells.
  void add(Map<String, String> data) => state = PushArrival(data);
}

/// Waits between tries for this phone's push token, after the first. Some
/// phones (a Xiaomi in the pilot) fail the first registration and Firebase
/// doesn't try again by itself. Tests make them instant.
final pushTokenRetryDelaysProvider = Provider<List<Duration>>(
  (ref) => const [
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 30),
    Duration(seconds: 60),
  ],
);
