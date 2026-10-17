import 'package:buildvibes/core/design/around_specs.dart';
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/shared/widgets/bv_space_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

void main() {
  testBoth('BvSpaceTile: the first letter, upper case, on the 26 tile', (
    tester,
    lang,
  ) async {
    final name = lang == 'ar' ? 'برج مدينة الكويت' : 'kuwait City Tower';
    await pumpComponent(tester, BvSpaceTile(name: name), lang: lang);
    expect(find.text(lang == 'ar' ? 'ب' : 'K'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('space-tile'))),
      const Size.square(BvNeedsSpec.spaceTile),
    );
    final box = tester.widget<Container>(find.byKey(const Key('space-tile')));
    expect((box.decoration! as BoxDecoration).color, BvColors.surfaceSubtle);
  });

  testBoth('BvSpaceTile: an empty name draws an empty tile', (
    tester,
    lang,
  ) async {
    await pumpComponent(tester, const BvSpaceTile(name: ''), lang: lang);
    expect(find.byKey(const Key('space-tile')), findsOneWidget);
  });
}
