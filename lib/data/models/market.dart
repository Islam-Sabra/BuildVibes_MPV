import 'package:flutter/widgets.dart';

/// A label stored as {"en": …, "ar": …} in reference tables.
@immutable
class LocalizedText {
  const LocalizedText({required this.en, required this.ar});

  factory LocalizedText.fromJson(Map<String, dynamic> json) => LocalizedText(
    en: json['en'] as String? ?? '',
    ar: json['ar'] as String? ?? '',
  );

  final String en;
  final String ar;

  /// The text for [locale]; falls back to English.
  String of(Locale locale) =>
      locale.languageCode == 'ar' && ar.isNotEmpty ? ar : en;

  @override
  bool operator ==(Object other) =>
      other is LocalizedText && other.en == en && other.ar == ar;

  @override
  int get hashCode => Object.hash(en, ar);
}

enum MarketStatus { live, soon, hidden }

enum CodeChannel { whatsapp, sms }

/// One market pack (rule 5): everything country-specific comes from here.
@immutable
class Market {
  const Market({
    required this.id,
    required this.status,
    required this.name,
    required this.defaultLocale,
    required this.dialCode,
    required this.nationalLength,
    required this.mobilePrefixes,
    required this.phoneExample,
    required this.codeChannel,
    required this.currency,
    required this.currencyDecimals,
    required this.weekStart,
    required this.weekend,
    required this.needsReview,
    this.supportEmail,
    this.keyRoleSuggestions = const [],
    this.legal = const {},
  });

  factory Market.fromJson(Map<String, dynamic> json) {
    final rules = (json['phone_rules'] as Map<String, dynamic>?) ?? const {};
    return Market(
      id: json['id'] as String,
      status: MarketStatus.values.byName(json['status'] as String),
      name: LocalizedText.fromJson(json['name'] as Map<String, dynamic>),
      defaultLocale: json['default_locale'] as String,
      dialCode: json['dial_code'] as String,
      nationalLength: rules['national_length'] as int?,
      mobilePrefixes: [
        for (final p in (rules['mobile_prefixes'] as List? ?? const []))
          p as String,
      ],
      phoneExample: rules['example'] as String?,
      codeChannel: CodeChannel.values.byName(json['code_channel'] as String),
      currency: json['currency'] as String,
      currencyDecimals: json['currency_decimals'] as int,
      weekStart: json['week_start'] as int,
      weekend: [for (final d in (json['weekend'] as List)) d as int],
      needsReview: [
        for (final f in (json['needs_review'] as List? ?? const []))
          f as String,
      ],
      supportEmail: json['support_email'] as String?,
      keyRoleSuggestions: [
        for (final s in (json['key_role_suggestions'] as List? ?? const []))
          LocalizedText.fromJson(s as Map<String, dynamic>),
      ],
      legal: {
        for (final e
            in ((json['legal'] as Map<String, dynamic>?) ?? const {}).entries)
          if (e.value is Map<String, dynamic>)
            e.key: LocalizedText.fromJson(e.value as Map<String, dynamic>),
      },
    );
  }

  final String id;
  final MarketStatus status;
  final LocalizedText name;
  final String defaultLocale;
  final String dialCode;
  final int? nationalLength;
  final List<String> mobilePrefixes;
  final String? phoneExample;
  final CodeChannel codeChannel;
  final String currency;
  final int currencyDecimals;

  /// 0 = Sunday … 6 = Saturday.
  final int weekStart;
  final List<int> weekend;

  /// Fields a local reviewer still has to confirm.
  final List<String> needsReview;

  /// Where Help and feedback writes to; null until the founder sets it.
  final String? supportEmail;

  /// Key role names offered when a Space admin adds one (review 121).
  final List<LocalizedText> keyRoleSuggestions;

  /// Page links per language: "terms", "privacy", "delete_account".
  final Map<String, LocalizedText> legal;

  /// The link for [kind] in [locale]'s language, if there is one.
  Uri? legalLink(String kind, Locale locale) {
    final url = legal[kind]?.of(locale) ?? '';
    return url.isEmpty ? null : Uri.tryParse(url);
  }

  /// True when [national] (digits only, without the dial code) looks like a
  /// mobile number for this market.
  bool isMobileNumber(String national) {
    if (nationalLength != null && national.length != nationalLength) {
      return false;
    }
    return mobilePrefixes.isEmpty ||
        mobilePrefixes.any((p) => national.startsWith(p));
  }

  /// The number in E.164, for example +96550000000.
  String toE164(String national) => '$dialCode$national';

  /// The national digits of a number typed with or without the dial code,
  /// or with the trunk 0 some markets write first.
  String nationalOf(String typed) {
    var digits = typed.replaceAll(RegExp('[^0-9]'), '');
    final dial = dialCode.substring(1);
    final length = nationalLength;
    final withDial =
        typed.trim().startsWith('+') ||
        (length != null && digits.length == dial.length + length);
    if (withDial && digits.startsWith(dial)) {
      digits = digits.substring(dial.length);
    }
    if (length != null && digits.length == length + 1 && digits[0] == '0') {
      digits = digits.substring(1);
    }
    return digits;
  }

  /// An E.164 number of this market spaced as its example ("+965 5512
  /// 3456"); as it is otherwise.
  String grouped(String e164) {
    if (!e164.startsWith(dialCode)) return e164;
    final national = e164.substring(dialCode.length);
    final groups = [
      for (final g in (phoneExample ?? '').split(' '))
        if (g.isNotEmpty) g.length,
    ];
    if (groups.fold(0, (a, b) => a + b) != national.length) return e164;
    final out = StringBuffer(dialCode);
    var at = 0;
    for (final g in groups) {
      out.write(' ${national.substring(at, at + g)}');
      at += g;
    }
    return out.toString();
  }
}
