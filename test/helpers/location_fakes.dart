import 'package:buildvibes/core/location/location_reader.dart';

/// The phone's location in tests (review 109): each read gives the next
/// of [results], the last one again once they run out.
class FakeLocationReader implements LocationReader {
  FakeLocationReader([List<LocationRead>? results])
    : results = results ?? [LocationRead.point(29.3759, 47.9774, 8)];

  final List<LocationRead> results;
  var reads = 0;

  @override
  Future<LocationRead> readOnce() async {
    final r = results[reads < results.length ? reads : results.length - 1];
    reads++;
    return r;
  }
}
