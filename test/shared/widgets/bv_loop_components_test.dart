// The loop's components (slice 1 part 1d): the swipe that adds an update
// (Y1), the slip's red line, the writing card's "Couldn't send", and the
// small face.
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/core/design/daybook_loop_specs.dart';
import 'package:buildvibes/shared/widgets/bv_slip.dart';
import 'package:buildvibes/shared/widgets/bv_swipe_reveal.dart';
import 'package:buildvibes/shared/widgets/bv_writing_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

void main() {
  group('BvSwipeReveal', () {
    Future<void> pumpReveal(
      WidgetTester tester,
      String lang, {
      required List<int> calls,
    }) async {
      await pumpComponent(
        tester,
        BvSwipeReveal(
          actionLabel: 'Add update',
          onAction: () => calls.add(1),
          child: const SizedBox(
            key: Key('slip'),
            height: 120,
            width: double.infinity,
            child: ColoredBox(color: BvColors.surfaceElevated),
          ),
        ),
        lang: lang,
      );
    }

    testBoth('a swipe to the end side gives way and shows the round +; the '
        '+ adds an update and closes', (tester, lang) async {
      final calls = <int>[];
      await pumpReveal(tester, lang, calls: calls);
      final before = tester.getRect(find.byKey(const Key('slip')));
      await tester.drag(
        find.byKey(const Key('slip')),
        Offset(isRtl(lang) ? -80 : 80, 0),
      );
      await tester.pumpAndSettle();
      final open = tester.getRect(find.byKey(const Key('slip')));
      expect(before.width - open.width, BvSwipeRevealSpec.reveal);
      expect(
        isRtl(lang) ? open.right < before.right : open.left > before.left,
        isTrue,
      );
      final plus = find.byKey(const Key('swipe-reveal-action'));
      expect(tester.getSize(plus), const Size.square(BvSize.touchMin));
      await tester.tap(plus);
      await tester.pumpAndSettle();
      expect(calls, [1]);
      expect(tester.getRect(find.byKey(const Key('slip'))), before);
    });

    testBoth('a short swipe or a swipe to the start side springs back', (
      tester,
      lang,
    ) async {
      final calls = <int>[];
      await pumpReveal(tester, lang, calls: calls);
      final before = tester.getRect(find.byKey(const Key('slip')));
      await tester.drag(
        find.byKey(const Key('slip')),
        Offset(isRtl(lang) ? -10 : 10, 0),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(const Key('slip'))), before);
      await tester.drag(
        find.byKey(const Key('slip')),
        Offset(isRtl(lang) ? 80 : -80, 0),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(const Key('slip'))), before);
      // Nothing to tap while closed.
      await tester.tap(
        find.byKey(const Key('swipe-reveal-action')),
        warnIfMissed: false,
      );
      expect(calls, isEmpty);
    });

    testBoth('while open, a tap on the slip closes it', (tester, lang) async {
      final calls = <int>[];
      await pumpReveal(tester, lang, calls: calls);
      final before = tester.getRect(find.byKey(const Key('slip')));
      await tester.drag(
        find.byKey(const Key('slip')),
        Offset(isRtl(lang) ? -80 : 80, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('slip')), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(const Key('slip'))), before);
      expect(calls, isEmpty);
    });
  });

  testBoth('BvSlipError: a red line in label-sm', (tester, lang) async {
    await pumpComponent(
      tester,
      const BvSlipError("Couldn't send. Tap to fix"),
      lang: lang,
    );
    final style = textStyle(tester, "Couldn't send. Tap to fix");
    expect(style.color, BvColors.textDestructive);
    expect(
      style.fontSize,
      BvType.of(tester.element(find.byType(BvSlipError))).labelSm.fontSize,
    );
  });

  testBoth('BvWritingCard: a refused post shows its red line at the foot', (
    tester,
    lang,
  ) async {
    final title = TextEditingController(text: 'Cable tray hangers');
    final body = TextEditingController();
    addTearDown(title.dispose);
    addTearDown(body.dispose);
    await pumpComponent(
      tester,
      BvWritingCard(
        titleController: title,
        titlePlaceholder: 'Title',
        bodyController: body,
        bodyPlaceholder: 'Write what needs doing',
        draftLabel: 'Draft',
        errorLine: "Couldn't send. Tap to fix",
      ),
      lang: lang,
    );
    final line = find.byKey(const Key('writing-card-error'));
    expect(line, findsOneWidget);
    expect(tester.widget<Text>(line).style!.color, BvColors.textDestructive);
    // Under the text.
    expect(
      tester.getTopLeft(line).dy,
      greaterThan(tester.getTopLeft(find.byKey(const Key('writing-body'))).dy),
    );
  });
}
