import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/models/check_in.dart' show checkInSiteMetres;

/// Why a reading has no point: the person refused the phone's permission,
/// the phone's location is off, or the signal was too weak to say.
enum LocationMiss { refused, off, weak }

/// One reading of the phone's location (review 109): a point, or why
/// there is none. It lives only as long as the call that passes it on;
/// nothing keeps it, and it never prints its numbers.
@immutable
class LocationRead {
  const LocationRead._(
    this.lat,
    this.lng,
    this.accuracyM,
    this.miss, {
    this.mocked = false,
  });

  /// Y4: with its accuracy and Android's mock flag, which go to the server
  /// with it (a mocked or unsure reading counts as not shared there).
  const LocationRead.point(
    double lat,
    double lng,
    double accuracyM, {
    bool mocked = false,
  }) : this._(lat, lng, accuracyM, null, mocked: mocked);

  const LocationRead.miss(LocationMiss miss) : this._(null, null, null, miss);

  final double? lat;
  final double? lng;
  final double? accuracyM;
  final LocationMiss? miss;
  final bool mocked;

  bool get hasPoint => miss == null && lat != null && lng != null;

  /// Less sure than the site's distance: the 100 m test can't be made.
  bool get unsure => !hasPoint || (accuracyM ?? 0) > checkInSiteMetres;

  @override
  String toString() => hasPoint ? 'LocationRead(point)' : 'LocationRead($miss)';
}

/// The phone's location, read once per call, in the foreground only:
/// ACCESS_FINE_LOCATION on Android and "when in use" on iOS. There is no
/// background location anywhere, and nothing follows the person. Behind
/// an interface so tests use a fake.
abstract class LocationReader {
  /// Reads where the phone is now. The first time, the phone asks its own
  /// permission (once); refused, off or weak come back as a [miss].
  Future<LocationRead> readOnce();
}

/// One tap's reading for a check-in (§3): a weak signal, or a point less
/// sure than 100 m, is tried again once, quietly. Then the better of the
/// two goes (a point over none); still weak, it counts as not shared.
/// Refused and off are never tried again.
Future<LocationRead> readForCheckIn(LocationReader reader) async {
  final first = await reader.readOnce();
  final weak =
      first.miss == LocationMiss.weak || (first.hasPoint && first.unsure);
  if (!weak) return first;
  final second = await reader.readOnce();
  if (!second.hasPoint) return first.hasPoint ? first : second;
  if (!first.hasPoint) return second;
  return (second.accuracyM ?? 0) <= (first.accuracyM ?? 0) ? second : first;
}

/// geolocator, foreground only.
class GeolocatorLocationReader implements LocationReader {
  const GeolocatorLocationReader();

  /// A reading takes at most this long before it counts as weak.
  static const timeLimit = Duration(seconds: 15);

  @override
  Future<LocationRead> readOnce() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationRead.miss(LocationMiss.off);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever ||
          permission == LocationPermission.unableToDetermine) {
        return const LocationRead.miss(LocationMiss.refused);
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeLimit,
        ),
      );
      return LocationRead.point(
        p.latitude,
        p.longitude,
        p.accuracy,
        mocked: p.isMocked,
      );
    } on LocationServiceDisabledException {
      return const LocationRead.miss(LocationMiss.off);
    } on PermissionDeniedException {
      return const LocationRead.miss(LocationMiss.refused);
    } on Object {
      // A timeout or anything else: no point this time. Never logged with
      // where the phone was.
      return const LocationRead.miss(LocationMiss.weak);
    }
  }
}

final locationReaderProvider = Provider<LocationReader>(
  (ref) => const GeolocatorLocationReader(),
);
