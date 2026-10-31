import 'package:buildvibes/core/routing/app_routes.dart';
import 'package:buildvibes/data/models/market.dart';
import 'package:buildvibes/features/entry/phone_screen.dart';
import 'package:buildvibes/features/onboarding/name_screen.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

/// Welcome → Continue with email → Use your phone number instead (phone
/// sign-in on; review 107: one welcome, the email first).
Future<void> _toPhone(WidgetTester tester) async {
  await _tap(tester, 'welcome-email');
  await _tap(tester, 'email-phone');
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);
    final kw = kuwait.name.of(Locale(lang));

    testWidgets('the phone screen sends to email while phone is off [$lang]', (
      tester,
    ) async {
      await pumpApp(tester, language: lang, signedIn: false);
      final context = tester.element(find.byKey(const Key('welcome-email')));
      GoRouter.of(context).go(AppRoutes.joinPhone);
      await tester.pumpAndSettle();
      expect(find.byType(PhoneScreen), findsNothing);
      expect(find.text(l10n.emailTitle), findsOneWidget);
    });

    testWidgets('phone sign-up: Kuwait number, code, then your name [$lang]', (
      tester,
    ) async {
      final app = await pumpApp(
        tester,
        language: lang,
        signedIn: false,
        phoneSignIn: true,
      );
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
      expect(find.byType(NameScreen), findsOneWidget);
    });

    testWidgets(
      'an onboarded account signing in goes Home, not your name [$lang]',
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
          phoneSignIn: true,
        );
        await _toPhone(tester);
        await tester.enterText(find.byType(TextField), '50000002');
        await _tap(tester, 'phone-send');
        await tester.enterText(find.byKey(const Key('code-input')), '123456');
        await tester.pumpAndSettle();
        expect(find.byType(NameScreen), findsNothing);
        expect(find.byKey(const Key('nav-home')), findsOneWidget);
      },
    );

    testWidgets('a wrong code shows an error and stays [$lang]', (
      tester,
    ) async {
      await pumpApp(tester, language: lang, signedIn: false, phoneSignIn: true);
      await _toPhone(tester);
      await tester.enterText(find.byType(TextField), '50000002');
      await _tap(tester, 'phone-send');
      await tester.enterText(find.byKey(const Key('code-input')), '000000');
      await tester.pumpAndSettle();
      expect(find.text(l10n.codeWrong), findsOneWidget);
      expect(find.text(l10n.codeTitleWhatsapp), findsOneWidget);
    });

    testWidgets('SMS instead of WhatsApp [$lang]', (tester) async {
      final app = await pumpApp(
        tester,
        language: lang,
        signedIn: false,
        phoneSignIn: true,
      );
      await _toPhone(tester);
      await tester.enterText(find.byType(TextField), '50000002');
      await _tap(tester, 'phone-sms');
      expect(app.auth.sent.single.channel, CodeChannel.sms);
      expect(find.text(l10n.codeTitleSms), findsOneWidget);
    });

    testWidgets('Egypt is coming soon: new numbers see why [$lang]', (
      tester,
    ) async {
      final app = await pumpApp(
        tester,
        language: lang,
        signedIn: false,
        phoneSignIn: true,
      );
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
      await pumpApp(
        tester,
        language: lang,
        signedIn: false,
        auth: auth,
        phoneSignIn: true,
      );
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
      await pumpApp(
        tester,
        language: lang,
        signedIn: false,
        auth: auth,
        phoneSignIn: true,
      );
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
      await _tap(tester, 'welcome-email');
      await tester.enterText(find.byType(TextField), 'not-an-email');
      await _tap(tester, 'email-send');
      expect(find.text(l10n.emailError), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'sami@example.com');
      await _tap(tester, 'email-send');
      expect(app.auth.sent.single.to, 'sami@example.com');
      expect(find.text(l10n.codeTitleEmail), findsOneWidget);
      // Masked (review 107).
      expect(find.textContaining('s•••@example.com'), findsOneWidget);
      expect(find.text(l10n.obTryAnotherWay), findsOneWidget);
    });

    testWidgets('guest: Just looking, and Create shows the join wall, then '
        'the email [$lang]', (tester) async {
      await pumpApp(tester, language: lang, signedIn: false);
      await _tap(tester, 'welcome-look');
      expect(find.byKey(const Key('nav-home')), findsOneWidget);
      await _tap(tester, 'nav-create');
      expect(find.text(l10n.joinWallTitle), findsOneWidget);
      await _tap(tester, 'join-create');
      expect(find.text(l10n.emailTitle), findsOneWidget);
      // Back goes to the welcome.
      await _tap(tester, 'entry-back');
      expect(find.text(l10n.obWelcomeTitle), findsOneWidget);
    });

    testWidgets('guest Profile tab asks to join [$lang]', (tester) async {
      await pumpApp(tester, language: lang, signedIn: false);
      await _tap(tester, 'welcome-look');
      await _tap(tester, 'nav-profile');
      expect(find.byKey(const Key('guest-card')), findsOneWidget);
      expect(find.byKey(const Key('row-sign-out')), findsNothing);
    });

    testWidgets('signing out returns to Welcome [$lang]', (tester) async {
      await pumpApp(tester, language: lang);
      await _tap(tester, 'nav-profile');
      await _tap(tester, 'profile-settings');
      await _tap(tester, 'row-sign-out');
      // S15 asks first.
      await _tap(tester, 'bv-dialog-confirm');
      expect(find.text(l10n.obWelcomeTitle), findsOneWidget);
    });
  }
}
