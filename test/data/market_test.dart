import 'package:buildvibes/data/models/market.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// Shaped like a row from the markets table (migration 1).
final _kuwaitRow = <String, dynamic>{
  'id': 'kw',
  'status': 'live',
  'name': {'en': 'Kuwait', 'ar': 'الكويت'},
  'default_locale': 'ar',
  'dial_code': '+965',
  'phone_rules': {
    'national_length': 8,
    'mobile_prefixes': ['5', '6', '9'],
    'example': '5000 0000',
  },
  'code_channel': 'whatsapp',
  'currency': 'KWD',
  'currency_decimals': 3,
  'week_start': 0,
  'weekend': [5, 6],
  'needs_review': ['phone_rules', 'code_channel', 'legal'],
};

void main() {
  test('a market row parses into a Market', () {
    final m = Market.fromJson(_kuwaitRow);
    expect(m.id, 'kw');
    expect(m.status, MarketStatus.live);
    expect(m.name.of(const Locale('ar')), 'الكويت');
    expect(m.name.of(const Locale('en')), 'Kuwait');
    expect(m.dialCode, '+965');
    expect(m.codeChannel, CodeChannel.whatsapp);
    expect(m.currencyDecimals, 3);
    expect(m.weekend, [5, 6]);
    expect(m.needsReview, contains('phone_rules'));
  });

  test('phone checks use the market rules', () {
    final m = Market.fromJson(_kuwaitRow);
    expect(m.isMobileNumber('50000000'), isTrue);
    expect(
      m.isMobileNumber('20000000'),
      isFalse,
      reason: 'not a mobile prefix',
    );
    expect(m.isMobileNumber('5000000'), isFalse, reason: 'too short');
    expect(m.toE164('50000000'), '+96550000000');
  });

  test('missing phone rules do not break parsing', () {
    final m = Market.fromJson({
      ..._kuwaitRow,
      'phone_rules': <String, dynamic>{},
    });
    expect(m.nationalLength, isNull);
    expect(m.isMobileNumber('123'), isTrue);
  });

  test('a label falls back to English when Arabic is missing', () {
    const label = LocalizedText(en: 'Site engineer', ar: '');
    expect(label.of(const Locale('ar')), 'Site engineer');
  });
}
