import 'package:buildvibes/core/design/bv_icons.dart';
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/core/design/daybook_days_specs.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_post_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

Future<void> _loadAppFonts() async {
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final f in files) {
      loader.addFont(rootBundle.load('assets/fonts/$f'));
    }
    await loader.load();
  }

  await family(BvFonts.latin, [
    'PlusJakartaSans-Regular.ttf',
    'PlusJakartaSans-Bold.ttf',
  ]);
  await family(BvFonts.arabic, ['Almarai-Regular.ttf', 'Almarai-Bold.ttf']);
}

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

    // Review 110 X1: at 390, "Thank someone" was cut to "Thank some…": the
    // two words shared the spare width. Nothing in the bar is cut; with a
    // larger text size, Thank someone goes under the pass instead.
    for (final scale in [1.0, 1.3, 2.0]) {
      testBoth('a Viewer\'s bar at 390: nothing is cut (text x$scale)', (
        tester,
        lang,
      ) async {
        // The app's own fonts, so the bar is measured as the phone draws it.
        await tester.runAsync(_loadAppFonts);
        final l10n = lookupAppLocalizations(Locale(lang));
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pumpComponent(
          tester,
          Align(
            alignment: AlignmentDirectional.bottomCenter,
            child: BvPostBar.viewer(
              passLabel: l10n.spacesPassViewer,
              readOnly: l10n.daybookReadOnly,
              thankLabel: l10n.thanksSomeone,
              onThank: () {},
            ),
          ),
          lang: lang,
          scroll: false,
        );
        expect(tester.takeException(), isNull);
        for (final words in [
          l10n.spacesPassViewer,
          l10n.daybookReadOnly,
          l10n.thanksSomeone,
        ]) {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text(words),
          );
          expect(paragraph.didExceedMaxLines, isFalse, reason: words);
        }
      });
    }
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
