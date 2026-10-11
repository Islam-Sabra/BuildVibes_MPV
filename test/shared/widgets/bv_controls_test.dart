import 'package:buildvibes/core/design/bv_specs.dart';
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/shared/widgets/bv_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

Color? _trackColor(WidgetTester tester) =>
    (tester
                .widget<AnimatedContainer>(find.byType(AnimatedContainer))
                .decoration!
            as BoxDecoration)
        .color;

void main() {
  testBoth('switch toggles and the thumb sits at the end when on', (
    tester,
    lang,
  ) async {
    var on = false;
    await pumpComponent(
      tester,
      Center(
        child: StatefulBuilder(
          builder: (context, setState) =>
              BvSwitch(value: on, onChanged: (v) => setState(() => on = v)),
        ),
      ),
      lang: lang,
    );
    expect(tester.getSize(find.byType(BvSwitch)), const Size.square(48));
    expect(_trackColor(tester), BvColors.borderInput);
    final track = find.byType(AnimatedContainer);
    expect(
      tester.getSize(track),
      const Size(BvControlSpec.switchWidth, BvControlSpec.switchHeight),
    );

    await tester.tap(find.byType(BvSwitch));
    await tester.pumpAndSettle();
    expect(on, isTrue);
    expect(_trackColor(tester), BvColors.actionPrimary);

    final thumb = tester.getCenter(find.byKey(const Key('switch-thumb'))).dx;
    final centre = tester.getCenter(track).dx;
    // "End" is right in English and left in Arabic.
    expect(isRtl(lang) ? thumb < centre : thumb > centre, isTrue);
  });

  testBoth('a disabled switch does not change', (tester, lang) async {
    await pumpComponent(
      tester,
      const BvSwitch(value: true, onChanged: null),
      lang: lang,
    );
    expect(_trackColor(tester), BvColors.actionDisabled);
    await tester.tap(find.byType(BvSwitch));
    await tester.pumpAndSettle();
    expect(_trackColor(tester), BvColors.actionDisabled);
  });

  testBoth('checkbox: checked fill and unchecked border', (tester, lang) async {
    var checked = false;
    await pumpComponent(
      tester,
      StatefulBuilder(
        builder: (context, setState) => BvCheckbox(
          value: checked,
          onChanged: (v) => setState(() => checked = v),
        ),
      ),
      lang: lang,
    );
    BoxDecoration box() => decorationOf(
      tester,
      find
          .descendant(
            of: find.byType(BvCheckbox),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(box().color, BvColors.surfaceElevated);
    expect((box().border! as Border).top.width, BvStroke.medium);

    await tester.tap(find.byType(BvCheckbox));
    await tester.pumpAndSettle();
    expect(checked, isTrue);
    expect(box().color, BvColors.actionPrimary);
    expect(find.byType(Icon), findsOneWidget);
  });

  testBoth('radio: selected ring and dot', (tester, lang) async {
    await pumpComponent(
      tester,
      const Row(
        children: [
          BvRadio(key: Key('on'), selected: true),
          BvRadio(key: Key('off'), selected: false),
        ],
      ),
      lang: lang,
    );
    BoxDecoration ring(String key) => decorationOf(
      tester,
      find
          .descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(Container),
          )
          .first,
    );
    final on = ring('on').border! as Border;
    expect(on.top.color, BvColors.actionPrimary);
    expect(on.top.width, BvStroke.thick);
    final off = ring('off').border! as Border;
    expect(off.top.color, BvColors.borderInput);
    expect(off.top.width, BvStroke.medium);
    expect(
      find.descendant(
        of: find.byKey(const Key('on')),
        matching: find.byType(DecoratedBox),
      ),
      findsWidgets,
    );
    expect(tester.getSize(find.byKey(const Key('on'))), const Size.square(48));
  });
}
