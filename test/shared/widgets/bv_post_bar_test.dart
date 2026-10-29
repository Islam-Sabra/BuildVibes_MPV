import 'package:buildvibes/core/design/bv_icons.dart';
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/core/design/daybook_days_specs.dart';
import 'package:buildvibes/shared/widgets/bv_post_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

void main() {
  group('BvPostBar', () {
    testBoth('notepad at the start, camera at the end; tap writes, tap '
        'opens the camera; a hold does nothing (H1: no signature on a hold)', (
      tester,
      lang,
    ) async {
      var writes = 0, shots = 0;
      await pumpComponent(
        tester,
        BvPostBar(
          placeholder: 'Work item',
          onWrite: () => writes++,
          onCamera: () => shots++,
        ),
        lang: lang,
        scroll: false,
      );
      final notepad = tester.getRect(find.byKey(const Key('post-bar-notepad')));
      final camera = tester.getRect(find.byKey(const Key('post-bar-camera')));
      expect(notepad.height, BvPostBarSpec.notepadHeight);
      expect(camera.size, const Size.square(BvPostBarSpec.cameraSize));
      expect(
        isRtl(lang)
            ? notepad.center.dx > camera.center.dx
            : notepad.center.dx < camera.center.dx,
        isTrue,
      );
      expect(textStyle(tester, 'Work item').color, BvColors.textSecondary);
      expect(find.byIcon(BvIcons.workItems), findsOneWidget);
      expect(
        materialColor(tester, find.byIcon(BvIcons.camera)),
        BvColors.actionPrimary,
      );

      await tester.tap(find.text('Work item'));
      await tester.tap(find.byIcon(BvIcons.camera));
      await tester.longPress(find.byIcon(BvIcons.camera));
      expect((writes, shots), (1, 2));
    });

    testBoth('Viewer: a pass chip and "Read only", nothing to write', (
      tester,
      lang,
    ) async {
      await pumpComponent(
        tester,
        const BvPostBar.viewer(passLabel: 'Viewer', readOnly: 'Read only'),
        lang: lang,
        scroll: false,
      );
      expect(find.widgetWithText(BvPassChip, 'Viewer'), findsOneWidget);
      expect(textStyle(tester, 'Read only').color, BvColors.textSecondary);
      expect(find.byIcon(BvIcons.camera), findsNothing);
      expect(find.byKey(const Key('post-bar-notepad')), findsNothing);
      final chip = tester.getCenter(find.byType(BvPassChip)).dx;
      final note = tester.getCenter(find.text('Read only')).dx;
      expect(isRtl(lang) ? chip > note : chip < note, isTrue);
    });
  });

  testBoth('the 44 notepad has a 48 high touch area', (tester, lang) async {
    var writes = 0;
    await pumpComponent(
      tester,
      BvPostBar(
        placeholder: 'Work item',
        onWrite: () => writes++,
        onCamera: () {},
      ),
      lang: lang,
      scroll: false,
    );
    final notepad = tester.getRect(find.byKey(const Key('post-bar-notepad')));
    const reach = BvSize.touchMin / 2 - 1;
    await tapEach(tester, [
      notepad.center.translate(0, -reach),
      notepad.center.translate(0, reach),
    ]);
    expect(writes, 2);
  });
}
