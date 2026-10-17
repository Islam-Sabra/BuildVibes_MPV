import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_pass_card.dart';
import 'package:buildvibes/shared/widgets/bv_site_photo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

void main() {
  group('BvPassCard', () {
    testBoth('band at the start edge; selected shows the stamp', (
      tester,
      lang,
    ) async {
      final l10n = _l10n(lang);
      await pumpComponent(
        tester,
        const Column(
          children: [
            BvPassCard(
              key: Key('lead'),
              kind: BvPassKind.lead,
              opens: 'Opens: all',
              forWho: 'For leads',
            ),
            BvPassCard(
              key: Key('crew'),
              kind: BvPassKind.crew,
              opens: 'Opens: items',
              forWho: 'For crews',
              selected: true,
            ),
          ],
        ),
        lang: lang,
      );
      expect(find.text(l10n.passLead), findsOneWidget);
      expect(find.text(l10n.stampSelected), findsOneWidget);
      expect(
        materialColor(tester, find.text('Opens: items')),
        BvColors.brandEnergySoft,
      );
      expect(
        materialColor(tester, find.text('Opens: all')),
        BvColors.surfaceElevated,
      );

      final band = find.descendant(
        of: find.byKey(const Key('crew')),
        matching: find.byKey(const Key('pass-band')),
      );
      expect(decorationOf(tester, band).color, BvColors.actionPrimary);
      final bandRect = tester.getRect(band);
      final cardRect = tester.getRect(find.byKey(const Key('crew')));
      expect(
        isRtl(lang)
            ? (bandRect.right - cardRect.right).abs() < 3
            : (bandRect.left - cardRect.left).abs() < 3,
        isTrue,
      );
    });
  });

  group('BvSitePhoto', () {
    testBoth('placeholder when missing; stamp at the bottom start', (
      tester,
      lang,
    ) async {
      await pumpComponent(
        tester,
        const BvSitePhoto(photo: null, stamp: 'Level 2 · 09:40'),
        lang: lang,
      );
      expect(find.byKey(const Key('site-photo-placeholder')), findsOneWidget);
      final stamp = tester.getRect(find.byKey(const Key('site-photo-stamp')));
      final photo = tester.getRect(find.byType(BvSitePhoto));
      expect(photo.bottom - stamp.bottom, closeTo(12, 0.5));
      expect(
        isRtl(lang)
            ? (photo.right - stamp.right - 12).abs() < 0.5
            : (stamp.left - photo.left - 12).abs() < 0.5,
        isTrue,
      );
      expect(
        decorationOf(tester, find.byKey(const Key('site-photo-stamp'))).color,
        BvColors.brandInk,
      );
    });
  });
}
