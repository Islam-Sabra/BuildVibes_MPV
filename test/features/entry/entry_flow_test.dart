import 'package:buildvibes/data/models/market.dart';
import 'package:buildvibes/features/onboarding/about_you_screen.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

/// Welcome → Create account → Continue with phone.
Future<void> _toPhone(WidgetTester tester) async {
  await _tap(tester, 'welcome-create');
  await _tap(tester, 'join-phone');
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);
    final kw = kuwait.name.of(Locale(lang));

    testWidgets('signed out: Welcome names the live market [$lang]', (
      tester,
    ) async {
      await pumpApp(tester, language: lang, signedIn: false);
      expect(find.text(l10n.entryStartingIn(kw)), findsOneWidget);
      expect(find.text(l10n.entryBuiltFor(kw)), findsOneWidget);
      expect(find.text(l10n.entryCreateAccount), findsOneWidget);
      expect(find.text(l10n.entrySignIn), findsOneWidget);
      expect(find.text(l10n.entrySkipToHome), findsOneWidget);
    });

    testWidgets('join: phone first; Google and Apple hidden for now [$lang]', (
      tester,
    ) async {
      await pumpApp(tester, language: lang, signedIn: false);
      await _tap(tester, 'welcome-create');
      expect(find.text(l10n.entryContinuePhone), findsOneWidget);
      expect(find.byKey(const Key('join-social')), findsNothing);
      expect(find.text(l10n.entryUseEmail), findsOneWidget);
      expect(find.text(l10n.entryNoPassword), findsOneWidget);
    });

    testWidgets('phone sign-up: Kuwait number, code, then About you [$lang]', (
      tester,
    ) async {
      final app = await pumpApp(tester, language: lang, signedIn: false);
      await _toPhone(tester);
      expect(find.text('+965'), findsOneWidget);
      expect(find.text(l10n.phoneHelpWhatsapp), findsOneWidget);

      // A wrong-looking number is caught before anything is sent.
      await tester.enterText(find.byType(TextField), '2000');
      await _tap(tester, 'phone-send');
      expect(find.text(l10n.phoneErrorMarket(kw, 8)), findsOneWidget);
      expect(app.auth.sent, isEmpty);

      await tester.enterText(find.byType(TextField), '5000 0002');
      await _tap(tester, 'phone-send');
      final sent = app.auth.sent.single;
      expect(sent.to, '+96550000002');
      expect(sent.channel, CodeChannel.whatsapp);
      expect(sent.allowSignUp, isTrue);
      expect(sent.data, {'locale': lang, 'home_market_id': 'kw'});

      expect(find.text(l10n.codeTitleWhatsapp), findsOneWidget);
      expect(find.textContaining('5000 0002'), findsOneWidget);
      expect(find.byKey(const Key('code-timer')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('code-input')), '123456');
      await tester.pumpAndSettle();
      expect(find.byType(AboutYouScreen), findsOneWidget);
    });

    testWidgets(
      'an onboarded account signing in goes Home, not About you [$lang]',
      (tester) async {
        final auth = FakeAuthRepository()..existing.add('+96550000002');
        // A real profile takes a moment to load; that gap caused the bug.
        final profiles = FakeProfileRepository()
          ..fetchDelay = const Duration(milliseconds: 300);
        profiles.profiles[FakeAuthRepository.newUserId] = completeProfile(
          FakeAuthRepository.newUserId,
        );
        await pumpApp(
          tester,
          language: lang,
          signedIn: false,
          auth: auth,
          profiles: profiles,
        );
        await _tap(tester, 'welcome-sign-in');
        await _tap(tester, 'join-phone');
        await tester.enterText(find.byType(TextField), '50000002');
        await _tap(tester, 'phone-send');
        await tester.enterText(find.byKey(const Key('code-input')), '123456');
        await tester.pumpAndSettle();
        expect(find.byType(AboutYouScreen), findsNothing);
        expect(find.byKey(const Key('nav-home')), findsOneWidget);
      },
    );

    testWidgets('a wrong code shows an error and stays [$lang]', (
      tester,
    ) async {
      await pumpApp(tester, language: lang, signedIn: false);
      await _toPhone(tester);
      await tester.enterText(find.byType(TextField), '50000002');
      await _tap(tester, 'phone-send');
      await tester.enterText(find.byKey(const Key('code-input')), '000000');
      await tester.pumpAndSettle();
      expect(find.text(l10n.codeWrong), findsOneWidget);
      expect(find.text(l10n.codeTitleWhatsapp), findsOneWidget);
    });

    testWidgets('SMS instead of WhatsApp [$lang]', (tester) async {
      final app = await pumpApp(tester, language: lang, signedIn: false);
      await _toPhone(tester);
      await tester.enterText(find.byType(TextField), '50000002');
      await _tap(tester, 'phone-sms');
      expect(app.auth.sent.single.channel, CodeChannel.sms);
      expect(find.text(l10n.codeTitleSms), findsOneWidget);
    });

    testWidgets('Egypt is coming soon: new numbers see why [$lang]', (
      tester,
    ) async {
      final app = await pumpApp(tester, language: lang, signedIn: false);
      await _toPhone(tester);
      await _tap(tester, 'dial-code-box');
      await _tap(tester, 'dial-eg');
      expect(find.text('+20'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '1000000001');
      await _tap(tester, 'phone-send');
      expect(find.byKey(const Key('not-open-sheet')), findsOneWidget);
      expect(
        find.text(l10n.notOpenSoon(egypt.name.of(Locale(lang)))),
        findsOneWidget,
      );
      expect(app.auth.sent, isEmpty);
    });

    testWidgets('an existing Egypt account still signs in [$lang]', (
      tester,
    ) async {
      final auth = FakeAuthRepository()..existing.add('+201000000001');
      await pumpApp(tester, language: lang, signedIn: false, auth: auth);
      await _toPhone(tester);
      await _tap(tester, 'dial-code-box');
      await _tap(tester, 'dial-eg');
      await tester.enterText(find.byType(TextField), '01000000001');
      await _tap(tester, 'phone-send');
      final sent = auth.sent.single;
      expect(sent.to, '+201000000001', reason: 'the trunk zero is dropped');
      expect(sent.allowSignUp, isFalse);
      expect(find.text(l10n.codeTitleWhatsapp), findsOneWidget);
    });

    testWidgets('another country code can be typed [$lang]', (tester) async {
      final auth = FakeAuthRepository()..existing.add('+919800000001');
      await pumpApp(tester, language: lang, signedIn: false, auth: auth);
      await _toPhone(tester);
      await _tap(tester, 'dial-code-box');
      await _tap(tester, 'dial-other');
      await tester.enterText(find.byKey(const Key('dial-other-field')), '91');
      await tester.pump();
      await _tap(tester, 'dial-other-confirm');
      expect(find.text('+91'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '9800000001');
      await _tap(tester, 'phone-send');
      expect(auth.sent.single.to, '+919800000001');
      expect(auth.sent.single.allowSignUp, isFalse);
    });

    testWidgets('email: a 6-digit code, never a password [$lang]', (
      tester,
    ) async {
      final app = await pumpApp(tester, language: lang, signedIn: false);
      await _tap(tester, 'welcome-sign-in');
      await _tap(tester, 'join-email');
      await tester.enterText(find.byType(TextField), 'not-an-email');
      await _tap(tester, 'email-send');
      expect(find.text(l10n.emailError), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'sami@example.com');
      await _tap(tester, 'email-send');
      expect(app.auth.sent.single.to, 'sami@example.com');
      expect(find.text(l10n.codeTitleEmail), findsOneWidget);
      expect(find.textContaining('sami@example.com'), findsOneWidget);
      expect(find.text(l10n.codeDifferentEmail), findsOneWidget);
    });

    testWidgets('guest: Skip to Home, and Create shows the join wall [$lang]', (
      tester,
    ) async {
      await pumpApp(tester, language: lang, signedIn: false);
      await _tap(tester, 'welcome-skip');
      expect(find.byKey(const Key('nav-home')), findsOneWidget);
      await _tap(tester, 'nav-create');
      expect(find.text(l10n.joinWallTitle), findsOneWidget);
      await _tap(tester, 'join-create');
      expect(find.text(l10n.entryContinuePhone), findsOneWidget);
    });

    testWidgets('guest Profile tab asks to join [$lang]', (tester) async {
      await pumpApp(tester, language: lang, signedIn: false);
      await _tap(tester, 'welcome-skip');
      await _tap(tester, 'nav-profile');
      expect(find.byKey(const Key('guest-card')), findsOneWidget);
      expect(find.byKey(const Key('row-sign-out')), findsNothing);
    });

    testWidgets('signing out returns to Welcome [$lang]', (tester) async {
      await pumpApp(tester, language: lang);
      await _tap(tester, 'nav-profile');
      await _tap(tester, 'profile-settings');
      await _tap(tester, 'row-sign-out');
      expect(find.text(l10n.entryCreateAccount), findsOneWidget);
    });
  }
}
