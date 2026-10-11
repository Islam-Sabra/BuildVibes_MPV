import 'package:buildvibes/data/models/people.dart';
import 'package:buildvibes/features/onboarding/about_you_screen.dart';
import 'package:buildvibes/features/onboarding/people_screen.dart';
import 'package:buildvibes/features/onboarding/role_picker_screen.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)).first);
  await tester.tap(find.byKey(Key(key)).first);
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  final field = find.descendant(
    of: find.byKey(Key(key)),
    matching: find.byType(TextField),
  );
  await tester.enterText(field, text);
  await tester.pump();
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);
    final locale = Locale(lang);

    testWidgets('new account opens About you, country from region [$lang]', (
      tester,
    ) async {
      await pumpApp(tester, language: lang, onboarded: false);
      expect(find.byType(AboutYouScreen), findsOneWidget);
      expect(find.text(l10n.aboutIntro), findsOneWidget);
      expect(find.text(kuwait.name.of(locale)), findsOneWidget);
      expect(find.text(l10n.countryChangeLater), findsOneWidget);
      // Decision 04: no recovery email; an optional private mobile instead.
      expect(find.text(l10n.mobileOptional), findsOneWidget);
      expect(find.text(l10n.mobileHelp), findsOneWidget);
      expect(find.text('+965'), findsOneWidget);
    });

    testWidgets('the mobile number is optional, private and checked [$lang]', (
      tester,
    ) async {
      final app = await pumpApp(tester, language: lang, onboarded: false);
      await _type(tester, 'about-first', 'Dana');
      await _type(tester, 'about-last', 'Ali');
      await _tap(tester, 'about-role');
      await _tap(tester, 'popular-electrician');
      await _tap(tester, 'role-save');

      await _type(tester, 'about-mobile', '2000');
      await _tap(tester, 'about-continue');
      expect(
        find.text(l10n.phoneErrorMarket(kuwait.name.of(locale), 8)),
        findsOneWidget,
      );
      expect(app.profiles.lastSaved, isNull);

      await _type(tester, 'about-mobile', '5000 0009');
      await _tap(tester, 'about-continue');
      expect(app.profiles.lastSaved!.mobileE164, '+96550000009');
    });

    testWidgets('left empty, no mobile number is saved [$lang]', (
      tester,
    ) async {
      final app = await pumpApp(tester, language: lang, onboarded: false);
      await _type(tester, 'about-first', 'Dana');
      await _type(tester, 'about-last', 'Ali');
      await _tap(tester, 'about-role');
      await _tap(tester, 'popular-electrician');
      await _tap(tester, 'role-save');
      await _tap(tester, 'about-continue');
      expect(app.profiles.lastSaved!.mobileE164, isNull);
    });

    testWidgets('a phone in Egypt: Kuwait is chosen, mobile code +20 [$lang]', (
      tester,
    ) async {
      await pumpApp(tester, language: lang, onboarded: false, region: 'EG');
      expect(find.text(kuwait.name.of(locale)), findsOneWidget);
      expect(find.text('+20'), findsOneWidget);
    });

    testWidgets('with a Space invite, Egypt can be the home country [$lang]', (
      tester,
    ) async {
      final auth = FakeAuthRepository(userId: 'user-1')..inviteCode = 'SPACE-1';
      final app = await pumpApp(
        tester,
        language: lang,
        onboarded: false,
        region: 'EG',
        auth: auth,
      );
      expect(find.text(egypt.name.of(locale)), findsOneWidget);
      await _type(tester, 'about-first', 'Mona');
      await _type(tester, 'about-last', 'Adel');
      await _tap(tester, 'about-role');
      await _tap(tester, 'popular-electrician');
      await _tap(tester, 'role-save');
      await _tap(tester, 'about-continue');
      expect(app.profiles.lastSaved!.homeMarketId, 'eg');
    });

    testWidgets('About you asks for the missing parts [$lang]', (tester) async {
      final app = await pumpApp(tester, language: lang, onboarded: false);
      await _tap(tester, 'about-continue');
      expect(find.text(l10n.firstNameRequired), findsOneWidget);
      expect(find.text(l10n.lastNameRequired), findsOneWidget);
      expect(find.text(l10n.roleRequired), findsOneWidget);
      expect(app.profiles.lastSaved, isNull);
    });

    testWidgets('full onboarding: names, role, company, then people [$lang]', (
      tester,
    ) async {
      final profiles = FakeProfileRepository()
        ..suggested = [
          PersonSuggestion(
            id: 'p-layla',
            firstName: 'Layla',
            lastName: 'Haddad',
            reason: SuggestionReason.sameCompany,
            tradeName: testRolePicker.byId('site_engineer')!.name,
            tradeId: 'site_engineer',
            companyLabel: 'Gulf Build Co.',
          ),
        ];
      await pumpApp(
        tester,
        language: lang,
        onboarded: false,
        profiles: profiles,
      );
      await _type(tester, 'about-first', 'Sami');
      await _type(tester, 'about-last', 'Al-Mansour');

      // Role picker: popular chips first.
      await _tap(tester, 'about-role');
      expect(find.byType(RolePickerScreen), findsOneWidget);
      expect(
        find.text(
          lang == 'en'
              ? l10n.rolePopularIn(kuwait.name.of(locale)).toUpperCase()
              : l10n.rolePopularIn(kuwait.name.of(locale)),
        ),
        findsOneWidget,
      );
      await _tap(tester, 'popular-site_engineer');
      await _tap(tester, 'role-save');
      expect(
        find.text(testRolePicker.byId('site_engineer')!.name.of(locale)),
        findsOneWidget,
      );

      // Company: a registered company from search.
      await _tap(tester, 'about-company');
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('company-search')),
          matching: find.byType(TextField),
        ),
        'gulf',
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      await _tap(tester, 'company-co-1');
      expect(find.text('Gulf Build Co.'), findsOneWidget);

      await _tap(tester, 'about-continue');
      final saved = profiles.lastSaved!;
      expect(saved.firstName, 'Sami');
      expect(saved.lastName, 'Al-Mansour');
      expect(saved.homeMarketId, 'kw');
      expect(saved.role.trade.id, 'site_engineer');
      expect(saved.companyId, 'co-1');
      expect(saved.companyNameText, isNull);
      expect(saved.locale, lang);

      // Step 2: people to follow, with a reason.
      expect(find.byType(PeopleScreen), findsOneWidget);
      expect(find.text(l10n.stepOf(2, 2)), findsOneWidget);
      expect(find.text('Layla Haddad'), findsOneWidget);
      expect(find.text(l10n.reasonCompany), findsOneWidget);
      await _tap(tester, 'follow-p-layla');
      expect(profiles.follows, contains('p-layla'));
      expect(find.text(l10n.following), findsOneWidget);

      await _tap(tester, 'people-continue');
      expect(find.byKey(const Key('nav-home')), findsOneWidget);
    });

    testWidgets('a role not in the list is saved in your own words [$lang]', (
      tester,
    ) async {
      final app = await pumpApp(tester, language: lang, onboarded: false);
      await _type(tester, 'about-first', 'Dana');
      await _type(tester, 'about-last', 'Ali');
      await _tap(tester, 'about-role');
      await _type(tester, 'role-search', 'Formwork supervisor');
      await _tap(tester, 'role-custom');
      expect(find.byKey(const Key('row-check')), findsOneWidget);
      await _tap(tester, 'role-save');
      await _tap(tester, 'about-continue');
      final role = app.profiles.lastSaved!.role;
      expect(role.trade.id, Trade.otherId);
      expect(role.customText, 'Formwork supervisor');
    });

    testWidgets('a typed company stays plain text [$lang]', (tester) async {
      final app = await pumpApp(tester, language: lang, onboarded: false);
      await _type(tester, 'about-first', 'Dana');
      await _type(tester, 'about-last', 'Ali');
      await _tap(tester, 'about-role');
      await _tap(tester, 'popular-electrician');
      await _tap(tester, 'role-save');
      await _tap(tester, 'about-company');
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('company-search')),
          matching: find.byType(TextField),
        ),
        'Small Workshop',
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      await _tap(tester, 'company-typed');
      await _tap(tester, 'about-continue');
      final saved = app.profiles.lastSaved!;
      expect(saved.companyId, isNull);
      expect(saved.companyNameText, 'Small Workshop');
    });

    testWidgets('Egypt is shown as coming soon and cannot be chosen [$lang]', (
      tester,
    ) async {
      await pumpApp(tester, language: lang, onboarded: false);
      await _tap(tester, 'about-country');
      expect(find.text(l10n.comingSoon), findsOneWidget);
      await tester.tap(find.text(egypt.name.of(locale)).last);
      await tester.pumpAndSettle();
      // Still open: the option is not available.
      expect(find.text(l10n.comingSoon), findsOneWidget);
    });

    testWidgets('no suggestions: step 2 is skipped, straight to Home [$lang]', (
      tester,
    ) async {
      await pumpApp(tester, language: lang, onboarded: false);
      await _type(tester, 'about-first', 'Dana');
      await _type(tester, 'about-last', 'Ali');
      await _tap(tester, 'about-role');
      await _tap(tester, 'popular-electrician');
      await _tap(tester, 'role-save');
      await _tap(tester, 'about-continue');
      expect(find.byType(PeopleScreen), findsNothing);
      expect(find.byKey(const Key('nav-home')), findsOneWidget);
    });

    testWidgets('back on About you signs out to start again [$lang]', (
      tester,
    ) async {
      final app = await pumpApp(tester, language: lang, onboarded: false);
      await _tap(tester, 'entry-back');
      expect(app.auth.signOuts, 1);
      expect(find.text(l10n.entryCreateAccount), findsOneWidget);
    });
  }
}
