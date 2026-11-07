// A Space's clock from its market pack's zone name, whatever the machine's
// own zone. "Asia/Kuwait" is an IANA alias (of Asia/Riyadh): with the
// alias-free zone list it was not found, and the Space fell back to the
// phone's clock.
import 'package:buildvibes/features/work/space_day.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 04:24 UTC on 15 Oct 2026 is 07:24 in Kuwait (UTC+3, no daylight time).
  final at = DateTime.utc(2026, 10, 15, 4, 24);

  test('Asia/Kuwait: the wall clock is Kuwait\'s', () {
    final wall = spaceWallNow('Asia/Kuwait', at);
    expect((wall.hour, wall.minute), (7, 24));
  });

  test('Asia/Kuwait: the day ends at Kuwait\'s midnight', () {
    expect(
      spaceDayEnd('Asia/Kuwait', at).toUtc(),
      DateTime.utc(2026, 10, 15, 21),
    );
  });

  test('Africa/Cairo still reads (no alias)', () {
    final wall = spaceWallNow('Africa/Cairo', at);
    expect((wall.hour, wall.minute), (7, 24));
  });
}
