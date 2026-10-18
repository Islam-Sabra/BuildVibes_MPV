// The loop's components (slice 1 part 1d): the update note (Y2), the
// swipe that adds one (Y1), the slip's red line, the writing card's
// "Couldn't send", and the update's small face.
import 'package:buildvibes/core/design/bv_specs.dart';
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/core/design/daybook_loop_specs.dart';
import 'package:buildvibes/shared/widgets/bv_avatar.dart';
import 'package:buildvibes/shared/widgets/bv_slip.dart';
import 'package:buildvibes/shared/widgets/bv_swipe_reveal.dart';
import 'package:buildvibes/shared/widgets/bv_update_note.dart';
import 'package:buildvibes/shared/widgets/bv_writing_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

void main() {
  group('BvUpdateNote', () {
    testBoth('the subtle note: a quote bar and the title, a face and the '
        'words', (tester, lang) async {
      await pumpComponent(
        tester,
        const BvUpdateNote(
          key: Key('note'),
          quote: 'Sleeves at grid C7 before the pour',
          name: 'Omar Haddad',
          text: 'Sleeves arrived. Fixing them now.',
          tint: BvAvatarTints.green,
        ),
        lang: lang,
      );
      final box = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(const Key('note')),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = box.decoration! as BoxDecoration;
      expect(decoration.color, BvColors.surfaceSubtle);
      expect(decoration.borderRadius, BvUpdateNoteSpec.radius);
      expect(
        tester.getSize(find.byKey(const Key('update-quote-bar'))),
        const Size(
          BvUpdateNoteSpec.quoteBarWidth,
          BvUpdateNoteSpec.quoteBarHeight,
        ),
      );
      expect(
        tester.getSize(find.byType(BvAvatar)),
        const Size.square(BvAvatarSpec.note),
      );
      expect(
        textStyle(tester, 'Sleeves arrived. Fixing them now.').color,
        BvColors.textPrimary,
      );
      expect(
        textStyle(tester, 'Sleeves at grid C7 before the pour').color,
        BvColors.textSecondary,
      );
      // The bar, then the quote, from the start side.
      final bar = tester.getCenter(find.byKey(const Key('update-quote-bar')));
      final quote = tester.getCenter(
        find.text('Sleeves at grid C7 before the pour'),
      );
      expect(isRtl(lang) ? bar.dx > quote.dx : bar.dx < quote.dx, isTrue);
    });
  });

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
