import 'package:buildvibes/core/design/bv_icons.dart';
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/core/design/daybook_paper_specs.dart';
import 'package:buildvibes/shared/widgets/bv_avatar.dart';
import 'package:buildvibes/shared/widgets/bv_paper_clip.dart';
import 'package:buildvibes/shared/widgets/bv_slip.dart';
import 'package:buildvibes/shared/widgets/bv_stamp.dart';
import 'package:buildvibes/shared/widgets/bv_torn_edge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

const _stampKey = Key('the-stamp');

BvSlip _slip({
  bool cancelled = false,
  bool lifted = false,
  bool clip = false,
  VoidCallback? onTap,
  VoidCallback? onDoubleTap,
  VoidCallback? onLongPress,
}) => BvSlip(
  cancelled: cancelled,
  lifted: lifted,
  clip: clip,
  onTap: onTap,
  onDoubleTap: onDoubleTap,
  onLongPress: onLongPress,
  stamp: const BvInkStamp(key: _stampKey, label: 'DONE'),
  children: [
    BvSlipHeader(
      name: 'Omar Haddad',
      ref: '· KCT-014',
      time: '10:56',
      tint: BvAvatarTints.green,
    ),
    BvSlipTitle('Fix sleeves', cancelled: cancelled),
    const BvSlipFacts(
      children: [
        BvSlipFact(
          icon: BvIcons.person,
          text: 'For Omar Haddad · by Thu 15 Oct',
        ),
        BvSlipFact(icon: BvIcons.place, text: 'Level 2, grid C7'),
      ],
    ),
  ],
);

ShapeDecoration _paper(WidgetTester tester) =>
    tester.widget<DecoratedBox>(find.byKey(const Key('slip-paper'))).decoration
        as ShapeDecoration;

void main() {
  group('BvSlip', () {
    testBoth('white torn paper with the slip shadow and padding', (
      tester,
      lang,
    ) async {
      await pumpComponent(tester, _slip(), lang: lang);
      final paper = _paper(tester);
      expect(paper.color, BvColors.surfaceElevated);
      expect(paper.shape, isA<BvSlipBorder>());
      expect(paper.shadows, BvShadow.slip);
      final padding = tester.widget<Padding>(
        find
            .descendant(
              of: find.byKey(const Key('slip-paper')),
              matching: find.byType(Padding),
            )
            .first,
      );
      expect(
        padding.padding,
        const EdgeInsetsDirectional.only(
          top: BvSlipBorder.edgeHeightDefault + BvSlipSpec.paddingTop,
          bottom: BvSlipSpec.paddingBottom,
          start: BvSlipSpec.paddingSide,
          end: BvSlipSpec.paddingSide,
        ),
      );
      expect(find.byType(BvPaperClip), findsNothing);
      expect(find.byKey(const Key('slip-cancelled')), findsNothing);
    });

    testBoth('the stamp and clip sit at the top end corner, never on '
        'each other', (tester, lang) async {
      await pumpComponent(tester, _slip(clip: true), lang: lang);
      final slip = tester.getRect(find.byKey(const Key('slip-paper')));
      final stamp = tester.getRect(find.byKey(_stampKey));
      // Both are placed before their tilt.
      final clip = tester.getRect(find.byType(BvPaperClip));
      const edge = BvSlipBorder.edgeHeightDefault;
      expect(stamp.top - slip.top, edge + BvSlipSpec.stampTop);
      expect(clip.top - slip.top, edge + BvSlipSpec.clipTop);
      if (isRtl(lang)) {
        expect(stamp.left - slip.left, BvSlipSpec.stampEndWithClip);
        expect(clip.left - slip.left, BvSlipSpec.clipEnd);
      } else {
        expect(slip.right - stamp.right, BvSlipSpec.stampEndWithClip);
        expect(slip.right - clip.right, BvSlipSpec.clipEnd);
      }
      // Even tilted, the clip stays clear of the stamp.
      expect(stamp.overlaps(clip.inflate(-BvSpace.s2)), isFalse);
    });

    testBoth('a stamp alone sits in the corner', (tester, lang) async {
      await pumpComponent(tester, _slip(), lang: lang);
      final slip = tester.getRect(find.byKey(const Key('slip-paper')));
      final stamp = tester.getRect(find.byKey(_stampKey));
      expect(
        isRtl(lang) ? stamp.left - slip.left : slip.right - stamp.right,
        BvSlipSpec.stampEnd,
      );
    });

    testBoth('cancelled: faded, title struck through', (tester, lang) async {
      await pumpComponent(tester, _slip(cancelled: true), lang: lang);
      expect(
        tester.widget<Opacity>(find.byKey(const Key('slip-cancelled'))).opacity,
        BvSlipSpec.cancelledOpacity,
      );
      expect(
        textStyle(tester, 'Fix sleeves').decoration,
        TextDecoration.lineThrough,
      );
      final slip = tester.getRect(find.byKey(const Key('slip-paper')));
      expect(
        tester.getRect(find.byKey(_stampKey)).top - slip.top,
        BvSlipBorder.edgeHeightDefault + BvSlipSpec.stampTopCancelled,
      );
    });

    testBoth('lifted: the deeper shadow', (tester, lang) async {
      await pumpComponent(tester, _slip(lifted: true), lang: lang);
      expect(_paper(tester).shadows, BvShadow.slipLifted);
    });

    testBoth('tap, double-tap and long-press reach their callbacks', (
      tester,
      lang,
    ) async {
      final calls = <String>[];
      await pumpComponent(
        tester,
        _slip(
          onTap: () => calls.add('tap'),
          onDoubleTap: () => calls.add('double'),
          onLongPress: () => calls.add('long'),
        ),
        lang: lang,
      );
      final title = find.text('Fix sleeves');
      await tester.tap(title);
      // A single tap waits out the double-tap window.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(title);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(title);
      await tester.pumpAndSettle();
      await tester.longPress(title);
      await tester.pumpAndSettle();
      expect(calls, ['tap', 'double', 'long']);
    });

    testBoth('header: avatar 24 in its tint, name and action phrase', (
      tester,
      lang,
    ) async {
      await pumpComponent(tester, _slip(), lang: lang);
      final avatar = tester.widget<BvAvatar>(find.byType(BvAvatar));
      expect(avatar.size, BvAvatarSize.xs);
      expect(avatar.tint, BvAvatarTints.green);
      expect(textStyle(tester, 'Omar Haddad').color, BvColors.textPrimary);
      expect(textStyle(tester, '· KCT-014').color, BvColors.textSecondary);
      // The time of the latest activity at the end of the header.
      final header = tester.getRect(find.byType(BvSlipHeader));
      final time = tester.getRect(find.text('10:56'));
      expect(
        isRtl(lang) ? time.left - header.left : header.right - time.right,
        moreOrLessEquals(0, epsilon: 0.5),
      );
      expect(
        tester.getSize(find.byType(BvSlipHeader)).height,
        BvSlipSpec.headerHeight,
      );
    });

    testBoth('facts: grey lines, each after its icon', (tester, lang) async {
      await pumpComponent(tester, _slip(), lang: lang);
      final pin = tester.widget<Icon>(find.byIcon(BvIcons.place));
      expect(pin.size, BvSlipSpec.factIconSize);
      expect(pin.color, BvColors.iconSecondary);
      expect(
        textStyle(tester, 'For Omar Haddad · by Thu 15 Oct').color,
        BvColors.textSecondary,
      );
      expect(
        tester.getTopLeft(find.text('Level 2, grid C7')).dy,
        greaterThan(
          tester.getTopLeft(find.text('For Omar Haddad · by Thu 15 Oct')).dy,
        ),
      );
      final pinX = tester.getCenter(find.byIcon(BvIcons.place)).dx;
      final textX = tester.getCenter(find.text('Level 2, grid C7')).dx;
      expect(isRtl(lang) ? pinX > textX : pinX < textX, isTrue);
    });
  });

  group('Slip parts', () {
    testBoth('attachment chip: subtle, radius 6, 14 icon', (
      tester,
      lang,
    ) async {
      await pumpComponent(
        tester,
        const BvSlipChips(
          children: [
            BvSlipChip(icon: BvIcons.document, label: 'M-201 Rev C'),
            BvSlipChip(icon: BvIcons.workItems, label: '2 points'),
          ],
        ),
        lang: lang,
      );
      final box = decorationOf(
        tester,
        find
            .ancestor(
              of: find.text('M-201 Rev C'),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(box.color, BvColors.surfaceSubtle);
      expect(box.borderRadius, BvSlipSpec.chipRadius);
      expect(
        tester.widget<Icon>(find.byIcon(BvIcons.document)).size,
        BvSlipSpec.chipIconSize,
      );
      expect(
        tester.getSize(find.byType(BvSlipChip).first).height,
        BvSlipSpec.chipHeight,
      );
    });

    testBoth('quote: a 2 × 16 action bar and one ellipsised line', (
      tester,
      lang,
    ) async {
      await pumpComponent(
        tester,
        BvSlipQuote('Sleeves at grid C7 before the pour ' * 4),
        lang: lang,
      );
      expect(
        tester.getSize(find.byKey(const Key('slip-quote-bar'))),
        const Size(BvSlipSpec.quoteBarWidth, BvSlipSpec.quoteBarHeight),
      );
      final text = tester.widget<Text>(find.textContaining('Sleeves'));
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
    });

    testBoth('photo: given height, radius 8, stamp at top start; '
        'double-tap', (tester, lang) async {
      var checked = 0;
      await pumpComponent(
        tester,
        BvSlipPhoto(
          height: BvSlipSpec.photoHeightProof,
          stamp: const BvInkStamp(
            key: _stampKey,
            label: 'DONE',
            size: BvInkStampSize.lg,
          ),
          onDoubleTap: () => checked++,
        ),
        lang: lang,
      );
      final photo = find.byKey(const Key('slip-photo'));
      expect(tester.getSize(photo).height, BvSlipSpec.photoHeightProof);
      expect(decorationOf(tester, photo).borderRadius, BvSlipSpec.photoRadius);
      final rect = tester.getRect(photo);
      final stamp = tester.getRect(find.byKey(_stampKey));
      expect(stamp.top - rect.top, BvSlipSpec.photoStampTop);
      expect(
        isRtl(lang) ? rect.right - stamp.right : stamp.left - rect.left,
        BvSlipSpec.photoStampStart,
      );
      await tester.tap(photo);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(photo);
      await tester.pumpAndSettle();
      expect(checked, 1);
    });

    testBoth('hint pill and action pill', (tester, lang) async {
      var signed = 0;
      await pumpComponent(
        tester,
        Column(
          children: [
            const BvSlipPill.hint(label: 'Double-tap the photo to check it'),
            BvSlipPill.action(
              icon: BvIcons.camera,
              label: 'Sign as done',
              onTap: () => signed++,
            ),
          ],
        ),
        lang: lang,
      );
      final hint = textStyle(tester, 'Double-tap the photo to check it');
      final action = textStyle(tester, 'Sign as done');
      expect(hint.color, BvColors.textAction);
      expect(action.color, BvColors.textAction);
      final type = isRtl(lang) ? BvType.arabic : BvType.latin;
      expect(hint.fontSize, type.labelSm.fontSize);
      expect(action.fontSize, type.labelMd.fontSize);
      final camera = tester.widget<Icon>(find.byIcon(BvIcons.camera));
      expect(camera.size, BvSlipSpec.actionIconSize);
      expect(camera.color, BvColors.textAction);
      final pill = decorationOf(
        tester,
        find
            .ancestor(
              of: find.text('Sign as done'),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(pill.color, BvColors.surfaceBrandSoft);
      expect(pill.borderRadius, BvRadius.roundAll);
      await tester.tap(find.text('Sign as done'));
      expect(signed, 1);
    });

    testBoth('Sign as done and a tappable chip: 48 × 48 touch areas', (
      tester,
      lang,
    ) async {
      var signed = 0;
      var opened = 0;
      await pumpComponent(
        tester,
        Column(
          spacing: BvSpace.s24,
          children: [
            BvSlip(
              children: [
                const BvSlipTitle('Sleeves at grid C7 before the pour'),
                BvSlipChips(
                  children: [
                    BvSlipChip(
                      key: const Key('chip'),
                      icon: BvIcons.document,
                      label: 'M-201',
                      onTap: () => opened++,
                    ),
                  ],
                ),
              ],
            ),
            BvSlip(
              children: [
                const BvSlipTitle('Rebar spacing, level 3 slab'),
                BvSlipPill.action(
                  icon: BvIcons.camera,
                  label: 'Sign as done',
                  onTap: () => signed++,
                ),
              ],
            ),
          ],
        ),
        lang: lang,
      );
      final pill = find.byKey(const Key('slip-pill-action'));
      expect(tester.getSize(pill).height, lessThan(BvSize.touchMin));
      await tapEach(tester, touchSquareEdges(tester, pill));
      expect(signed, 4);

      final chip = find.byKey(const Key('chip'));
      expect(tester.getSize(chip).height, BvSlipSpec.chipHeight);
      await tapEach(tester, touchSquareEdges(tester, chip));
      expect(opened, 4);
    });

    testBoth('"You": the label shows, the avatar keeps the real name', (
      tester,
      lang,
    ) async {
      await pumpComponent(
        tester,
        const BvSlipHeader(name: 'Islam Ahmed', label: 'You'),
        lang: lang,
      );
      expect(find.text('You'), findsOneWidget);
      expect(find.text('Islam Ahmed'), findsNothing);
      expect(
        tester.widget<BvAvatar>(find.byType(BvAvatar)).name,
        'Islam Ahmed',
      );
      expect(find.text('IA'), findsOneWidget);
    });

    testBoth('note and quiet lines', (tester, lang) async {
      await pumpComponent(
        tester,
        const Column(
          children: [
            BvSlipNote('All six fixed.'),
            BvSlipQuiet('Waiting to send'),
          ],
        ),
        lang: lang,
      );
      expect(textStyle(tester, 'All six fixed.').color, BvColors.textPrimary);
      expect(
        textStyle(tester, 'Waiting to send').color,
        BvColors.textSecondary,
      );
    });

    testBoth('late: a 14 calendar and the words in red, calendar first', (
      tester,
      lang,
    ) async {
      await pumpComponent(
        tester,
        const BvSlipLate('Late by 1 day'),
        lang: lang,
      );
      final icon = tester.widget<Icon>(find.byIcon(BvIcons.month));
      expect(icon.size, BvSlipSpec.lateIconSize);
      expect(icon.color, BvColors.textDestructive);
      expect(
        textStyle(tester, 'Late by 1 day').color,
        BvColors.textDestructive,
      );
      final iconBox = tester.getRect(find.byIcon(BvIcons.month));
      final text = tester.getRect(find.text('Late by 1 day'));
      final gap = isRtl(lang)
          ? iconBox.left - text.right
          : text.left - iconBox.right;
      expect(gap, BvSlipSpec.lateGap);
    });
  });
}
