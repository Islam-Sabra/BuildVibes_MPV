import 'package:buildvibes/core/routing/app_router.dart';
import 'package:buildvibes/data/models/market.dart';
import 'package:buildvibes/features/entry/entry_state.dart';
import 'package:buildvibes/features/entry/phone_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

void main() {
  group('PhoneRules', () {
    test('national number: Western digits, no spaces, no trunk zero', () {
      final arabicDigits = String.fromCharCodes([0x0665, 0x0660, 0x0660]);
      expect(PhoneRules.national('5000 1234'), '50001234');
      expect(PhoneRules.national('$arabicDigits 01234'), '50001234');
      expect(PhoneRules.national('010 0000 0001'), '1000000001');
    });

    test('typed dial codes', () {
      expect(PhoneRules.dialCode('91'), '+91');
      expect(PhoneRules.dialCode('+ 971'), '+971');
      expect(PhoneRules.dialCode('0'), isNull);
      expect(PhoneRules.dialCode('12345'), isNull);
      expect(PhoneRules.dialCode(''), isNull);
    });

    test('numbers are checked against the market rules', () {
      expect(PhoneRules.isValid('50001234', kuwait), isTrue);
      expect(PhoneRules.isValid('20001234', kuwait), isFalse);
      expect(PhoneRules.isValid('5000123', kuwait), isFalse);
      expect(PhoneRules.isValid('1000000001', egypt), isTrue);
      // Another country code: a plausible length is enough.
      expect(PhoneRules.isValid('9800000001', null), isTrue);
      expect(PhoneRules.isValid('123', null), isFalse);
    });

    test('new accounts: live markets, or anyone with an invite', () {
      expect(PhoneRules.canCreateAccount(market: kuwait), isTrue);
      expect(PhoneRules.canCreateAccount(market: egypt), isFalse);
      expect(PhoneRules.canCreateAccount(market: null), isFalse);
      expect(
        PhoneRules.canCreateAccount(market: egypt, inviteCode: 'KCT021'),
        isTrue,
      );
      expect(
        PhoneRules.canCreateAccount(market: null, inviteCode: 'KCT021'),
        isTrue,
      );
      expect(
        PhoneRules.canCreateAccount(market: null, inviteCode: ''),
        isFalse,
      );
    });

    test('display format follows the market example', () {
      expect(PhoneRules.format('50001234', example: '5000 0000'), '5000 1234');
      expect(
        PhoneRules.format('1000000001', example: '100 000 0000'),
        '100 000 0001',
      );
      expect(PhoneRules.format('9800000001'), '98 0000 0001');
    });

    test('dial code to market', () {
      expect(PhoneRules.marketForDialCode(testMarkets, '+965'), kuwait);
      expect(PhoneRules.marketForDialCode(testMarkets, '+91'), isNull);
    });
  });

  group('entry state', () {
    test('default market: the phone region, else the first live market', () {
      expect(defaultMarket(testMarkets, 'EG'), egypt);
      expect(defaultMarket(testMarkets, 'KW'), kuwait);
      expect(defaultMarket(testMarkets, 'IN'), kuwait);
      expect(defaultMarket(testMarkets, null), kuwait);
    });

    test('sign-up data only carries a live home market', () {
      expect(signUpData(locale: 'ar', market: kuwait), {
        'locale': 'ar',
        'home_market_id': 'kw',
      });
      expect(signUpData(locale: 'en', market: egypt), {'locale': 'en'});
      expect(signUpData(locale: 'en', inviteCode: 'KCT021'), {
        'locale': 'en',
        'invite_code': 'KCT021',
      });
    });
  });

  group('redirectForGate', () {
    const cases = <(AppGate, String, String?)>[
      (AppGate.loading, AppRoutes.home, AppRoutes.loading),
      (AppGate.loading, AppRoutes.loading, null),
      (AppGate.signedOut, AppRoutes.home, AppRoutes.welcome),
      (AppGate.signedOut, AppRoutes.joinCode, null),
      (AppGate.signedOut, AppRoutes.onboardingName, AppRoutes.welcome),
      (AppGate.guest, AppRoutes.home, null),
      (AppGate.guest, AppRoutes.join, null),
      (AppGate.guest, AppRoutes.onboardingName, AppRoutes.home),
      (AppGate.guest, '/people/p-1', AppRoutes.home),
      (AppGate.guest, '/projects/p-1', AppRoutes.home),
      (AppGate.guest, AppRoutes.profileEditBasics, AppRoutes.home),
      (AppGate.guest, AppRoutes.profileSettings, null),
      (AppGate.ready, '/people/p-1', null),
      (AppGate.ready, AppRoutes.projectsNew, null),
      // Review 107: your name and your work before anything else.
      (AppGate.onboarding, AppRoutes.home, AppRoutes.onboardingName),
      (AppGate.onboarding, AppRoutes.joinCode, AppRoutes.onboardingName),
      (AppGate.onboarding, AppRoutes.onboardingWork, null),
      (AppGate.onboarding, AppRoutes.onboardingRole, null),
      (AppGate.onboarding, AppRoutes.onboardingSpace, AppRoutes.onboardingName),
      (AppGate.ready, AppRoutes.welcome, AppRoutes.home),
      (AppGate.ready, AppRoutes.loading, AppRoutes.home),
      // With a name and a work: your Space; your name and your work are
      // Edit profile's now; the old steps go Home (the lead's check Q5).
      (AppGate.ready, AppRoutes.onboardingSpace, null),
      (AppGate.ready, AppRoutes.onboardingWork, AppRoutes.profileEditBasics),
      (AppGate.ready, AppRoutes.onboardingName, AppRoutes.profileEditBasics),
      (AppGate.ready, AppRoutes.onboarding, AppRoutes.home),
      (AppGate.ready, '/onboarding/about', AppRoutes.home),
      (AppGate.ready, '/onboarding/people', AppRoutes.home),
      (AppGate.ready, AppRoutes.onboardingRole, null),
      (AppGate.ready, AppRoutes.profile, null),
      (AppGate.profileError, AppRoutes.home, AppRoutes.loading),
    ];
    for (final (gate, from, to) in cases) {
      test('$gate at $from → ${to ?? 'stays'}', () {
        expect(redirectForGate(gate, from), to);
      });
    }
    test('your work stays while it moves on after its save (Q5)', () {
      expect(
        redirectForGate(
          AppGate.ready,
          AppRoutes.onboardingWork,
          finishing: true,
        ),
        isNull,
      );
    });
  });

  test('fixtures: Kuwait is live, Egypt is coming soon', () {
    expect(kuwait.status, MarketStatus.live);
    expect(egypt.status, MarketStatus.soon);
  });
}
