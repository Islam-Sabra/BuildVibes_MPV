import 'package:buildvibes/core/l10n/bidi.dart';
import 'package:buildvibes/core/l10n/months.dart';
import 'package:buildvibes/core/routing/app_router.dart';
import 'package:buildvibes/data/repositories/account_repository.dart';
import 'package:buildvibes/features/account/delete_screens.dart';
import 'package:buildvibes/features/entry/entry_state.dart';
import 'package:buildvibes/features/spaces/former_member.dart';
import 'package:buildvibes/features/spaces/transfer_screen.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/features/profile/settings_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/account_fakes.dart';
import '../../helpers/pump_app.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)).first);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)).first);
  await tester.pumpAndSettle();
}

Future<void> _openSettings(WidgetTester tester) async {
  await _tap(tester, 'nav-profile');
  await _tap(tester, 'profile-settings');
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);

    testWidgets('S1: who you are, then one list, each entry once (review '
        '54 A5) [$lang]', (tester) async {
      await pumpApp(tester, language: lang);
      await _openSettings(tester);
      expect(find.text(inOwnDirection('Omar Haddad')), findsOneWidget);
      expect(find.byKey(const Key('settings-view-profile')), findsOneWidget);
      // The five entries, in this order, each once.
      final titles = [
        l10n.accountSecurity,
        l10n.settingsNotifications,
        l10n.privacySafety,
        l10n.settingsLanguageRow,
        l10n.aboutLegal,
      ];
      final keys = [
        'row-account',
        'row-notifications',
        'row-privacy',
        'row-language',
        'row-about',
      ];
      for (final (i, t) in titles.indexed) {
        expect(find.text(t), findsOneWidget, reason: t);
        expect(
          find.descendant(of: find.byKey(Key(keys[i])), matching: find.text(t)),
          findsOneWidget,
        );
      }
      final tops = [
        for (final k in keys) tester.getTopLeft(find.byKey(Key(k))).dy,
      ];
      expect(tops, [...tops]..sort());
      // No second list in words, and no Language and region row.
      expect(find.byKey(const Key('words-privacy')), findsNothing);
      expect(find.byKey(const Key('words-notifications')), findsNothing);
      expect(find.byKey(const Key('words-language')), findsNothing);
      expect(find.text(l10n.languageRegion), findsNothing);
    });

    testWidgets('S1: Components only in a debug build, never in release '
        '[$lang]', (tester) async {
      // Tests run in debug: the row shows, from the same switch the release
      // build reads (kDebugMode is false there).
      expect(kReleaseMode, isFalse);
      expect(
        ProviderContainer().read(devToolsProvider),
        kDebugMode && !kReleaseMode,
      );
      await pumpApp(tester, language: lang);
      await _openSettings(tester);
      expect(find.byKey(const Key('row-components')), findsOneWidget);
    });

    testWidgets('S1: a release build has no Components row [$lang]', (
      tester,
    ) async {
      await pumpApp(
        tester,
        language: lang,
        overrides: [devToolsProvider.overrideWithValue(false)],
      );
      await _openSettings(tester);
      expect(find.byKey(const Key('row-components')), findsNothing);
      expect(find.text(l10n.componentsGallery), findsNothing);
    });

    testWidgets('S15: sign out asks first, with code wording [$lang]', (
      tester,
    ) async {
      final app = await pumpApp(tester, language: lang);
      await _openSettings(tester);
      await _tap(tester, 'row-sign-out');
      expect(find.text(l10n.signOutTitle), findsOneWidget);
      expect(find.text(l10n.signOutBody), findsOneWidget);
      await _tap(tester, 'bv-dialog-cancel');
      expect(app.auth.signOuts, 0);
      await _tap(tester, 'row-sign-out');
      await _tap(tester, 'bv-dialog-confirm');
      expect(app.auth.signOuts, 1);
    });

    testWidgets('Support: Help writes to the pack address; About has Terms '
        '[$lang]', (tester) async {
      final app = await pumpApp(tester, language: lang);
      await _openSettings(tester);
      // Help and feedback is in the About sheet (review 54 A5).
      expect(find.byKey(const Key('row-help')), findsNothing);
      await _tap(tester, 'row-about');
      await _tap(tester, 'row-help');
      expect(
        app.opened.single,
        Uri(scheme: 'mailto', path: 'help@example.com'),
      );
      expect(find.byKey(const Key('legal-privacy')), findsNothing);
      await _tap(tester, 'legal-terms');
      expect(
        app.opened.last.toString(),
        lang == 'ar'
            ? 'https://example.com/ar/terms'
            : 'https://example.com/terms',
      );
    });

    testWidgets('S5: Blocked accounts and where Space work lives [$lang]', (
      tester,
    ) async {
      await pumpApp(tester, language: lang);
      await _openSettings(tester);
      await _tap(tester, 'row-privacy');
      expect(find.text(l10n.privacyNote), findsOneWidget);
      await _tap(tester, 'row-blocked');
      expect(find.text(l10n.blockedNone), findsOneWidget);
    });

    testWidgets('S8: language as one choice, live countries, week start '
        'read-only [$lang]', (tester) async {
      final app = await pumpApp(tester, language: lang);
      await _openSettings(tester);
      await _tap(tester, 'row-language');
      expect(find.byKey(const Key('language-en')), findsOneWidget);
      expect(find.byKey(const Key('language-ar')), findsOneWidget);
      expect(find.text(weekdayName(0, lang)), findsOneWidget);
      await _tap(tester, 'row-country');
      // Egypt is "soon": not a choice yet.
      expect(find.byKey(const Key('country-kw')), findsOneWidget);
      expect(find.byKey(const Key('country-eg')), findsNothing);
      await _tap(tester, 'country-kw');
      expect(app.account.calls, isEmpty, reason: 'the same country');
    });

    testWidgets('S2 → S10 → S11: one request, then it waits [$lang]', (
      tester,
    ) async {
      final app = await pumpApp(tester, language: lang);
      await _openSettings(tester);
      await _tap(tester, 'row-account');
      await _tap(tester, 'row-download');
      expect(find.text(l10n.downloadHeading), findsOneWidget);
      expect(
        find.text(l10n.downloadFoot(ltrRun('omar@example.com'))),
        findsOneWidget,
      );
      await _tap(tester, 'download-request');
      expect(app.account.calls, ['data']);
      expect(find.text(l10n.requestReceived), findsOneWidget);
      // Back and in again: still received, no second request.
      Navigator.of(
        tester.element(find.byKey(const Key('data-request-received'))),
      ).pop();
      await tester.pumpAndSettle();
      await _tap(tester, 'row-download');
      expect(find.byKey(const Key('data-request-received')), findsOneWidget);
      expect(find.byKey(const Key('download-request')), findsNothing);
    });

    testWidgets('S12 → S13 → S14 → Restore [$lang]', (tester) async {
      final app = await pumpApp(tester, language: lang);
      await _openSettings(tester);
      await _tap(tester, 'row-account');
      await _tap(tester, 'row-delete');
      expect(find.text(l10n.deleteHeading), findsOneWidget);
      await _tap(tester, 'delete-continue');
      // S13: a code to the account's email, never a password.
      expect(app.auth.confirmCodes, ['omar@example.com']);
      expect(
        find.text(l10n.confirmBody(ltrRun('omar@example.com'))),
        findsOneWidget,
      );
      expect(
        find.text(
          l10n.deleteFoot(
            formatLongDate(testNow.add(const Duration(days: 30)), lang),
          ),
        ),
        findsOneWidget,
      );
      final button = find.byKey(const Key('delete-confirm-button'));
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(app.account.calls, isEmpty, reason: 'it waits for 6 digits');

      await tester.enterText(find.byType(EditableText).first, '000000');
      await tester.pumpAndSettle();
      await _tap(tester, 'delete-confirm-button');
      expect(find.text(_l10n(lang).codeWrong), findsOneWidget);
      expect(app.account.calls, isEmpty);

      await tester.enterText(find.byType(EditableText).first, '123456');
      await tester.pumpAndSettle();
      await _tap(tester, 'delete-confirm-button');
      expect(app.account.calls, ['delete']);
      // The gate: S14 only, with the date.
      expect(find.byType(DeletionScheduledScreen), findsOneWidget);
      expect(
        find.text(
          l10n.scheduledBody(formatLongDate(DateTime(2026, 11, 10), lang)),
        ),
        findsOneWidget,
      );
      await _tap(tester, 'restore-account');
      expect(app.account.calls.last, 'restore');
      expect(find.byType(DeletionScheduledScreen), findsNothing);
      expect(find.byKey(const Key('nav-home')), findsOneWidget);
    });

    testWidgets('S13: the server wants a fresh code [$lang]', (tester) async {
      final account = FakeAccountRepository()..freshCode = false;
      await pumpApp(tester, language: lang, account: account);
      await _openSettings(tester);
      await _tap(tester, 'row-account');
      await _tap(tester, 'row-delete');
      await _tap(tester, 'delete-continue');
      await tester.enterText(find.byType(EditableText).first, '123456');
      await tester.pumpAndSettle();
      await _tap(tester, 'delete-confirm-button');
      expect(find.text(l10n.codeExpired), findsOneWidget);
      expect(find.byType(DeletionScheduledScreen), findsNothing);
    });

    testWidgets('S12b: the only admin of a Space transfers it first [$lang]', (
      tester,
    ) async {
      final account = FakeAccountRepository(
        blockers: [
          const DeletionBlocker(spaceId: 's1', spaceName: 'Gulf Tower — Site'),
        ],
      );
      final app = await pumpApp(tester, language: lang, account: account);
      await _openSettings(tester);
      await _tap(tester, 'row-account');
      await _tap(tester, 'row-delete');
      await _tap(tester, 'delete-continue');
      expect(find.text(l10n.transferFirst), findsOneWidget);
      expect(find.byKey(const Key('blocker-s1')), findsOneWidget);
      expect(app.auth.confirmCodes, isEmpty, reason: 'no code yet');
      await _tap(tester, 'blocked-transfer');
      expect(find.byType(TransferScreen), findsOneWidget);
    });

    test('Former member when a Space person has no profile [$lang]', () {
      expect(personName(l10n, null), l10n.formerMember);
      expect(personName(l10n, ' '), l10n.formerMember);
      expect(personName(l10n, 'Omar Haddad'), 'Omar Haddad');
      expect(personFirstName(l10n, null), l10n.formerMember);
      expect(personFirstName(l10n, 'Omar Haddad'), 'Omar');
    });
  }

  test('the gate keeps a scheduled account on S14, and lets it go after', () {
    expect(
      redirectForGate(AppGate.scheduled, AppRoutes.home),
      AppRoutes.scheduled,
    );
    expect(redirectForGate(AppGate.scheduled, AppRoutes.scheduled), isNull);
    expect(redirectForGate(AppGate.ready, AppRoutes.scheduled), AppRoutes.home);
    expect(
      redirectForGate(AppGate.signedOut, AppRoutes.scheduled),
      AppRoutes.welcome,
    );
  });
}
