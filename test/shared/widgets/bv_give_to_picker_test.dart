import 'package:buildvibes/core/design/bv_icons.dart';
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/core/design/daybook_writing_specs.dart';
import 'package:buildvibes/shared/widgets/bv_avatar.dart';
import 'package:buildvibes/shared/widgets/bv_give_to_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

const _people = [
  BvGiveToPerson(id: 'omar', name: 'Omar Haddad', team: 'Site'),
  BvGiveToPerson(id: 'rakesh', name: 'Rakesh Nair', team: 'MEP'),
  BvGiveToPerson(id: 'lina', name: 'Lina Saad', team: 'Site'),
];

Widget _picker({ValueChanged<BvGiveToPerson>? onPick}) => BvGiveToPicker(
  people: _people,
  currentOwnerId: 'omar',
  currentLabel: 'now',
  searchPlaceholder: 'Give to…',
  onPick: onPick ?? (_) {},
);

void main() {
  testBoth('people rows: "now" and a check on the current owner', (
    tester,
    lang,
  ) async {
    BvGiveToPerson? picked;
    await pumpComponent(tester, _picker(onPick: (p) => picked = p), lang: lang);
    expect(
      tester.getSize(find.byType(BvGiveToPicker)).width,
      BvGiveToSpec.width,
    );
    expect(find.text('now'), findsOneWidget);
    expect(find.text('MEP'), findsOneWidget);
    expect(find.byIcon(BvIcons.check), findsOneWidget);
    final avatar = tester.widget<BvAvatar>(find.byType(BvAvatar).first);
    expect(avatar.size, BvAvatarSize.list);
    expect(avatar.tint, BvAvatarTints.forId('omar'));

    // The check is at the end: on the left in Arabic.
    final check = tester.getCenter(find.byIcon(BvIcons.check)).dx;
    final name = tester.getCenter(find.text('Omar Haddad')).dx;
    expect(isRtl(lang) ? check < name : check > name, isTrue);
    final row = find.ancestor(
      of: find.text('Rakesh Nair'),
      matching: find.byType(InkWell),
    );
    expect(
      tester.getSize(row).height,
      greaterThanOrEqualTo(BvGiveToSpec.rowHeight),
    );

    await tester.tap(find.text('Rakesh Nair'));
    expect(picked?.id, 'rakesh');
  });

  testBoth('typing filters by name or Team', (tester, lang) async {
    await pumpComponent(tester, _picker(), lang: lang);
    await tester.enterText(find.byType(TextField), 'rak');
    await tester.pump();
    expect(find.text('Rakesh Nair'), findsOneWidget);
    expect(find.text('Omar Haddad'), findsNothing);

    await tester.enterText(find.byType(TextField), 'site');
    await tester.pump();
    expect(find.text('Lina Saad'), findsOneWidget);
    expect(find.text('Omar Haddad'), findsOneWidget);
    expect(find.text('Rakesh Nair'), findsNothing);
  });
}
