import 'package:buildvibes/core/design/bv_icons.dart';
import 'package:buildvibes/core/design/bv_specs.dart';
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/shared/widgets/bv_avatar.dart';
import 'package:buildvibes/shared/widgets/bv_badge.dart';
import 'package:buildvibes/shared/widgets/bv_stamp.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

void main() {
  group('BvAvatar', () {
    test('tile initials: one word still gives two letters', () {
      expect(BvAvatar.tileInitialsOf('Everyone'), 'EV');
      expect(BvAvatar.tileInitialsOf('Structure'), 'ST');
      expect(BvAvatar.tileInitialsOf('MEP Team'), 'MT');
      expect(BvAvatar.tileInitialsOf('Al-Rashid'), 'RA');
      // "الجميع": the article is skipped, then one letter.
      expect(BvAvatar.tileInitialsOf('الجميع'), 'ج');
    });

    test('initials: first and last word as typed; Arabic one letter', () {
      expect(BvAvatar.initialsOf('Omar Haddad'), 'OH');
      expect(BvAvatar.initialsOf('sara al mutairi'), 'SM');
      expect(BvAvatar.initialsOf('Omar'), 'O');
      expect(BvAvatar.initialsOf('Sara Al-Mutairi'), 'SA');
      expect(BvAvatar.initialsOf('Hany El-Sayed'), 'HE');
      expect(BvAvatar.initialsOf('Jean-Paul Smith'), 'JS');
      expect(BvAvatar.initialsOf('  '), '');
      final omar = String.fromCharCode(0x0639); // ع
      final haddad = String.fromCharCode(0x062D); // ح
      expect(BvAvatar.initialsOf('$omarمر $haddadداد'), omar);
    });

    test('Arabic initials skip the prefixes "ال" and "لل"', () {
      String word(List<int> codes) => String.fromCharCodes(codes);
      const alef = 0x0627, lam = 0x0644, noon = 0x0646, waw = 0x0648;
      const reh = 0x0631, meem = 0x0645, qaf = 0x0642;
      final alNoor = word([alef, lam, noon, waw, reh]); // النور
      final lilMuqawalat = word([lam, lam, meem, qaf, alef]); // للمقا…
      expect(BvAvatar.initialsOf('$alNoor $lilMuqawalat'), word([noon]));
      expect(BvAvatar.initialsOf(lilMuqawalat), word([meem]));
      // A short word that only looks like a prefix is kept as it is.
      expect(BvAvatar.initialsOf(word([alef, lam, noon])), word([alef]));
    });

    testBoth('sizes, person circle and company square', (tester, lang) async {
      await pumpComponent(
        tester,
        const Wrap(
          children: [
            BvAvatar(
              key: Key('sm'),
              name: 'Omar Haddad',
              size: BvAvatarSize.sm,
            ),
            BvAvatar(
              key: Key('xl'),
              name: 'Omar Haddad',
              size: BvAvatarSize.xl,
            ),
            BvAvatar(
              key: Key('co'),
              name: 'Al Noor',
              size: BvAvatarSize.lg,
              company: true,
            ),
          ],
        ),
        lang: lang,
      );
      expect(
        tester.getSize(find.byKey(const Key('sm'))),
        const Size.square(BvAvatarSpec.sm),
      );
      expect(
        tester.getSize(find.byKey(const Key('xl'))),
        const Size.square(BvAvatarSpec.xl),
      );
      ShapeDecoration deco(String key) =>
          tester
                  .widget<Container>(
                    find
                        .descendant(
                          of: find.byKey(Key(key)),
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration!
              as ShapeDecoration;
      expect(deco('sm').shape, isA<CircleBorder>());
      expect(deco('sm').color, BvColors.surfaceSubtle);
      final co = deco('co').shape as RoundedRectangleBorder;
      expect(co.borderRadius, BvAvatarSpec.companyRadiusLarge);
      expect(find.text('OH'), findsNWidgets(2));
    });

    testBoth('project avatar keeps its colour for an id', (tester, lang) async {
      await pumpComponent(
        tester,
        const BvProjectAvatar(id: 'kw-001', icon: BvIcons.company),
        lang: lang,
      );
      final box = decorationOf(
        tester,
        find
            .descendant(
              of: find.byType(BvProjectAvatar),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(box.color, BvProjectColors.forId('kw-001'));
      expect(
        tester.widget<Icon>(find.byIcon(BvIcons.company)).color,
        BvColors.iconInverse,
      );
    });
  });

  group('BvBadge', () {
    testBoth('tones and height', (tester, lang) async {
      await pumpComponent(
        tester,
        const Wrap(
          children: [
            BvBadge(label: 'N'),
            BvBadge(label: 'B', tone: BvBadgeTone.brand),
            BvBadge(label: 'P', tone: BvBadgeTone.positive),
            BvBadge(label: 'W', tone: BvBadgeTone.warning),
          ],
        ),
        lang: lang,
      );
      expect(textStyle(tester, 'N').color, BvColors.textSecondary);
      expect(textStyle(tester, 'B').color, BvColors.textAction);
      expect(textStyle(tester, 'P').color, BvColors.textPositive);
      expect(textStyle(tester, 'W').color, BvColors.textWarning);
      final brand = decorationOf(
        tester,
        find.ancestor(of: find.text('B'), matching: find.byType(Container)),
      );
      expect(brand.color, BvColors.surfaceBrandSoft);
      expect(
        tester.getSize(find.byType(BvBadge).first).height,
        BvBadgeSpec.height,
      );
    });
  });

  group('BvStamp', () {
    testBoth('text and border share the tone colour', (tester, lang) async {
      await pumpComponent(
        tester,
        const Wrap(
          children: [
            BvStamp(label: 'KCT-021'),
            BvStamp(label: 'OK', tone: BvStampTone.positive),
          ],
        ),
        lang: lang,
      );
      for (final (label, color) in [
        ('KCT-021', BvColors.textAction),
        ('OK', BvColors.textPositive),
      ]) {
        expect(textStyle(tester, label).color, color);
        final box = decorationOf(
          tester,
          find.ancestor(of: find.text(label), matching: find.byType(Container)),
        );
        final border = box.border! as Border;
        expect(border.top.color, color);
        expect(border.top.width, BvStampSpec.border);
      }
      expect(find.byKey(const Key('stamp-tilt')), findsNothing);
    });

    testBoth('a status stamp leans -3° (LTR) or +3° (RTL)', (
      tester,
      lang,
    ) async {
      await pumpComponent(
        tester,
        const BvStamp(label: 'CHECKED', tilted: true),
        lang: lang,
      );
      expect(find.byKey(const Key('stamp-tilt')), findsOneWidget);
      final angle = BvStamp.tiltFor(
        isRtl(lang) ? TextDirection.rtl : TextDirection.ltr,
      );
      expect(isRtl(lang) ? angle > 0 : angle < 0, isTrue);
      expect(angle.abs(), closeTo(0.0524, 0.0001));
    });
  });
}
