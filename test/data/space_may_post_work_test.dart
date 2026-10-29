// The lead's check of 105A, H7: one "may post work" check, read by the
// camera's Walk and by Space info's daily report. A Lead or Crew pass
// with the right to create work items; never a Viewer, whatever the
// rights say.
import 'package:buildvibes/data/models/space.dart';
import 'package:flutter_test/flutter_test.dart';

SpaceDetail _space(SpacePass pass, {required bool createItems}) => SpaceDetail(
  id: 's',
  name: 'Kuwait City Tower',
  myPass: pass,
  iAmAdmin: false,
  myRights: MemberRights(createItems: createItems),
);

void main() {
  test('a Lead or Crew with the right may post work', () {
    expect(_space(SpacePass.lead, createItems: true).mayPostWork, isTrue);
    expect(_space(SpacePass.crew, createItems: true).mayPostWork, isTrue);
  });

  test('without the right, no one may', () {
    for (final pass in SpacePass.values) {
      expect(_space(pass, createItems: false).mayPostWork, isFalse);
    }
  });

  test('a Viewer never may', () {
    expect(_space(SpacePass.viewer, createItems: true).mayPostWork, isFalse);
  });
}
