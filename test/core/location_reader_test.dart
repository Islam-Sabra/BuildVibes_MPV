// Review 109 §3, §5: the location is read once per tap; a weak signal is
// tried again once, quietly, then counts as not shared; refused or off
// are never tried again.
import 'package:buildvibes/core/location/location_reader.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/location_fakes.dart';

void main() {
  test('a point comes back at once', () async {
    final reader = FakeLocationReader([LocationRead.point(29.37, 47.97, 8)]);
    final read = await readForCheckIn(reader);
    expect(read.hasPoint, isTrue);
    expect(read.lat, 29.37);
    expect(reader.reads, 1);
  });

  test('weak is tried again once, quietly', () async {
    final reader = FakeLocationReader([
      const LocationRead.miss(LocationMiss.weak),
      LocationRead.point(29.37, 47.97, 12),
    ]);
    final read = await readForCheckIn(reader);
    expect(read.hasPoint, isTrue);
    expect(reader.reads, 2);
  });

  test('weak twice counts as not shared', () async {
    final reader = FakeLocationReader([
      const LocationRead.miss(LocationMiss.weak),
      const LocationRead.miss(LocationMiss.weak),
      LocationRead.point(1, 2, 3),
    ]);
    final read = await readForCheckIn(reader);
    expect(read.hasPoint, isFalse);
    expect(read.miss, LocationMiss.weak);
    expect(reader.reads, 2);
  });

  test('refused or off is not tried again', () async {
    for (final miss in [LocationMiss.refused, LocationMiss.off]) {
      final reader = FakeLocationReader([
        LocationRead.miss(miss),
        LocationRead.point(1, 2, 3),
      ]);
      final read = await readForCheckIn(reader);
      expect(read.miss, miss);
      expect(reader.reads, 1);
    }
  });

  test('a reading less sure than the site distance is weak', () {
    expect(LocationRead.ofAccuracy(1, 2, 40).hasPoint, isTrue);
    expect(LocationRead.ofAccuracy(1, 2, 250).miss, LocationMiss.weak);
  });

  test('a point never shows its numbers when printed', () {
    expect(
      '${LocationRead.point(29.37594, 47.9774, 8)}',
      isNot(contains('29')),
    );
  });
}
