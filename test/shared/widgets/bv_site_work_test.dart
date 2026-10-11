import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_pass_card.dart';
import 'package:buildvibes/shared/widgets/bv_sign_off_strip.dart';
import 'package:buildvibes/shared/widgets/bv_site_photo.dart';
import 'package:buildvibes/shared/widgets/bv_site_tag.dart';
import 'package:buildvibes/shared/widgets/bv_stamp.dart';
import 'package:buildvibes/shared/widgets/bv_work_item_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

BvSiteTag _tag({bool overdue = false}) => BvSiteTag(
  itemId: 'KCT-021',
  team: 'STRUCTURE',
  title: 'Fix rebar',
  place: 'Level 2',
  from: 'Sara',
  owner: 'Omar',
  due: 'Sun 12 Oct',
  overdue: overdue,
);

void main() {
  group('BvSiteTag', () {
    testBoth('ID stamp, team, title block in the app language', (
      tester,
      lang,
    ) async {
      final l10n = _l10n(lang);
      await pumpComponent(tester, _tag(), lang: lang);
      expect(find.widgetWithText(BvStamp, 'KCT-021'), findsOneWidget);
      for (final label in [
        l10n.siteTagFrom,
        l10n.siteTagOwner,
        l10n.siteTagDue,
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(textStyle(tester, 'Sun 12 Oct').color, BvColors.textAction);

      // The stamp is at the start, the team at the end.
      final stamp = tester.getCenter(find.text('KCT-021')).dx;
      final team = tester.getCenter(find.text('STRUCTURE')).dx;
      expect(isRtl(lang) ? stamp > team : stamp < team, isTrue);

      // The punched hole is centred at the top.
      final hole = tester.getRect(find.byKey(const Key('site-tag-hole')));
      final card = tester.getRect(find.byType(BvSiteTag));
      expect(hole.center.dx, closeTo(card.center.dx, 0.5));
    });

    testBoth('an overdue date is red', (tester, lang) async {
      await pumpComponent(tester, _tag(overdue: true), lang: lang);
      expect(textStyle(tester, 'Sun 12 Oct').color, BvColors.textDestructive);
    });
  });

  group('BvSignOffStrip', () {
    testBoth('signed and waiting cells', (tester, lang) async {
      final l10n = _l10n(lang);
      await pumpComponent(
        tester,
        const BvSignOffStrip(
          steps: [
            BvSignOffStep(
              kind: BvSignOffStepKind.raised,
              person: 'Sara',
              when: '9 Oct · 08:10',
            ),
            BvSignOffStep(kind: BvSignOffStepKind.done),
            BvSignOffStep(kind: BvSignOffStepKind.checked),
          ],
        ),
        lang: lang,
      );
      expect(find.text(l10n.signOffLabel), findsOneWidget);
      expect(textStyle(tester, l10n.signOffRaised).color, BvColors.textAction);
      expect(textStyle(tester, 'Sara').color, BvColors.textPrimary);
      expect(textStyle(tester, l10n.signOffDone).color, BvColors.textSecondary);
      expect(find.text(l10n.signOffWaiting), findsNWidgets(2));
      expect(
        decorationOf(tester, find.byKey(const Key('sign-off-raised'))).color,
        BvColors.surfaceElevated,
      );
      expect(
        decorationOf(tester, find.byKey(const Key('sign-off-done'))).color,
        BvColors.surfaceSubtle,
      );
      // RAISED comes first in the reading direction.
      final raised = tester.getCenter(find.byKey(const Key('sign-off-raised')));
      final checked = tester.getCenter(
        find.byKey(const Key('sign-off-checked')),
      );
      expect(
        isRtl(lang) ? raised.dx > checked.dx : raised.dx < checked.dx,
        isTrue,
      );
    });
  });

  group('BvWorkItemCard', () {
    Widget card(BvWorkStatus status, {String? action, VoidCallback? onTap}) =>
        BvWorkItemCard(
          reference: 'KCT-021 · STRUCTURE',
          status: status,
          statusLine: 'STATUS',
          title: 'Fix rebar',
          place: 'Level 2',
          people: 'Owner: you',
          evidence: const BvWorkEvidence(text: 'Evidence'),
          actionLabel: action,
          onTap: onTap,
        );

    testBoth('status colour for each status', (tester, lang) async {
      for (final (status, color) in [
        (BvWorkStatus.open, BvColors.textAction),
        (BvWorkStatus.done, BvColors.textAction),
        (BvWorkStatus.checked, BvColors.textPositive),
        (BvWorkStatus.overdue, BvColors.textDestructive),
      ]) {
        await pumpComponent(tester, card(status), lang: lang);
        expect(textStyle(tester, 'STATUS').color, color);
      }
    });

    testBoth('evidence only for Done and Checked', (tester, lang) async {
      await pumpComponent(tester, card(BvWorkStatus.open), lang: lang);
      expect(find.byKey(const Key('work-evidence')), findsNothing);
      await pumpComponent(tester, card(BvWorkStatus.done), lang: lang);
      expect(textStyle(tester, 'Evidence').color, BvColors.textSecondary);
      await pumpComponent(tester, card(BvWorkStatus.checked), lang: lang);
      expect(textStyle(tester, 'Evidence').color, BvColors.textPositive);
    });

    testBoth('action row only when the viewer can act; card is tappable', (
      tester,
      lang,
    ) async {
      var taps = 0;
      await pumpComponent(
        tester,
        card(BvWorkStatus.open, onTap: () => taps++),
        lang: lang,
      );
      expect(find.byKey(const Key('work-action')), findsNothing);
      await tester.tap(find.text('Fix rebar'));
      expect(taps, 1);

      await pumpComponent(
        tester,
        card(BvWorkStatus.open, action: 'Sign as done'),
        lang: lang,
      );
      expect(textStyle(tester, 'Sign as done').color, BvColors.textAction);
    });
  });

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
