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

  test('Y4: a point keeps its accuracy and the mock flag, for the server '
      'to judge', () {
    const p = LocationRead.point(1, 2, 250, mocked: true);
    expect(p.hasPoint, isTrue);
    expect(p.accuracyM, 250);
    expect(p.mocked, isTrue);
    expect(const LocationRead.point(1, 2, 8).mocked, isFalse);
  });

  test('Y4: a reading less sure than 100 m is tried once more; the better '
      'one goes', () async {
    final reader = FakeLocationReader([
      const LocationRead.point(1, 2, 250),
      const LocationRead.point(3, 4, 12),
    ]);
    final read = await readForCheckIn(reader);
    expect(reader.reads, 2);
    expect(read.lat, 3);
    expect(read.accuracyM, 12);
  });

  test('Y4: still unsure, the reading goes with its accuracy (the server '
      'counts it as not shared)', () async {
    final reader = FakeLocationReader([
      const LocationRead.point(1, 2, 250),
      const LocationRead.miss(LocationMiss.weak),
    ]);
    final read = await readForCheckIn(reader);
    expect(reader.reads, 2);
    expect(read.hasPoint, isTrue);
    expect(read.accuracyM, 250);
  });

  test('a point never shows its numbers when printed', () {
    expect(
      '${const LocationRead.point(29.37594, 47.9774, 8)}',
      isNot(contains('29')),
    );
  });
}
