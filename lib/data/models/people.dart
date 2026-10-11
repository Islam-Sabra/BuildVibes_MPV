import 'package:flutter/foundation.dart';

import 'market.dart';

/// A trade or role from the role picker (E9b).
@immutable
class Trade {
  const Trade({
    required this.id,
    required this.familyId,
    required this.name,
    this.description,
    this.popularSort,
  });

  final String id;
  final String familyId;

  /// The market's local name when it has one, otherwise the trade's name.
  final LocalizedText name;
  final LocalizedText? description;

  /// Set when the trade is popular in the market (lower comes first).
  final int? popularSort;

  /// The trade for a role typed in by the person ("Not in the list?").
  static const otherId = 'other';
}

@immutable
class RoleFamily {
  const RoleFamily({
    required this.id,
    required this.name,
    required this.trades,
  });

  final String id;
  final LocalizedText name;
  final List<Trade> trades;
}

/// Everything the role picker shows for one market.
@immutable
class RolePicker {
  const RolePicker({required this.families, required this.other});

  final List<RoleFamily> families;

  /// The trade used for a role typed in by the person.
  final Trade other;

  List<Trade> get allTrades => [for (final f in families) ...f.trades];

  /// Every trade, plus the "other" trade used for typed roles.
  List<Trade> get allTradesWithOther => [...allTrades, other];

  List<Trade> get popular =>
      allTrades.where((t) => t.popularSort != null).toList()
        ..sort((a, b) => a.popularSort!.compareTo(b.popularSort!));

  Trade? byId(String? id) => allTrades.where((t) => t.id == id).firstOrNull;
}

/// The chosen role: a trade from the list, or the person's own words.
@immutable
class RoleChoice {
  const RoleChoice.trade(this.trade) : customText = null;
  const RoleChoice.custom(this.customText, {required this.trade});

  final Trade trade;

  /// Set when the person typed their own role (trade is "other").
  final String? customText;

  String label(String languageCode) {
    if (customText != null) return customText!;
    return languageCode == 'ar' ? trade.name.ar : trade.name.en;
  }
}

@immutable
class CompanySummary {
  const CompanySummary({required this.id, required this.name});

  factory CompanySummary.fromJson(Map<String, dynamic> json) =>
      CompanySummary(id: json['id'] as String, name: json['name'] as String);

  final String id;
  final String name;
}

/// The signed-in person's own profile, as far as entry needs it.
@immutable
class MyProfile {
  const MyProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.locale,
    this.tradeId,
    this.tradeName,
    this.headline,
    this.homeMarketId,
    this.placeId,
    this.companyId,
    this.companyName,
    this.companyNameText,
  });

  factory MyProfile.fromJson(Map<String, dynamic> json) {
    final trade = json['trade'] as Map<String, dynamic>?;
    final company = json['company'] as Map<String, dynamic>?;
    return MyProfile(
      id: json['id'] as String,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      locale: json['locale'] as String? ?? 'en',
      tradeId: json['trade_id'] as String?,
      tradeName: trade == null
          ? null
          : LocalizedText.fromJson(trade['name'] as Map<String, dynamic>),
      headline: json['headline'] as String?,
      homeMarketId: json['home_market_id'] as String?,
      placeId: json['place_id'] as String?,
      companyId: json['company_id'] as String?,
      companyName: company?['name'] as String?,
      companyNameText: json['company_name_text'] as String?,
    );
  }

  final String id;
  final String firstName;
  final String lastName;
  final String locale;
  final String? tradeId;
  final LocalizedText? tradeName;
  final String? headline;
  final String? homeMarketId;
  final String? placeId;
  final String? companyId;
  final String? companyName;
  final String? companyNameText;

  /// Onboarding step 1 is done once there is a name and a role.
  bool get isComplete =>
      firstName.trim().isNotEmpty &&
      lastName.trim().isNotEmpty &&
      tradeId != null;

  /// What shows under the name: the person's own words, or the trade.
  String? roleLabel(String languageCode) {
    // The headline when set ("BIM Manager"), otherwise the trade.
    if ((headline ?? '').trim().isNotEmpty) return headline;
    if (tradeId == Trade.otherId) return null;
    final name = tradeName;
    if (name == null) return headline;
    return languageCode == 'ar' ? name.ar : name.en;
  }

  /// The registered company's name, or the name as the person typed it.
  String? get companyLabel => companyName ?? companyNameText;
}

/// What the person filled in on "About you" (E9).
@immutable
class AboutYouInput {
  const AboutYouInput({
    required this.firstName,
    required this.lastName,
    required this.homeMarketId,
    required this.role,
    required this.locale,
    this.companyId,
    this.companyNameText,
    this.recoveryEmail,
  });

  final String firstName;
  final String lastName;
  final String homeMarketId;
  final RoleChoice role;
  final String locale;
  final String? companyId;
  final String? companyNameText;
  final String? recoveryEmail;

  Map<String, dynamic> toProfileUpdate() => {
    'first_name': firstName.trim(),
    'last_name': lastName.trim(),
    'home_market_id': homeMarketId,
    'trade_id': role.trade.id,
    'headline': role.customText?.trim(),
    'company_id': companyId,
    'company_name_text': companyId == null ? companyNameText?.trim() : null,
    'locale': locale,
  };
}

/// Someone suggested on "People to follow" (E10).
@immutable
class PersonSuggestion {
  const PersonSuggestion({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.reason,
    this.tradeName,
    this.headline,
    this.tradeId,
    this.companyLabel,
    this.placeName,
  });

  final String id;
  final String firstName;
  final String lastName;
  final SuggestionReason reason;
  final LocalizedText? tradeName;
  final String? headline;
  final String? tradeId;
  final String? companyLabel;
  final LocalizedText? placeName;

  String get fullName => '$firstName $lastName'.trim();

  String? roleLabel(String languageCode) {
    // The headline when set ("BIM Manager"), otherwise the trade.
    if ((headline ?? '').trim().isNotEmpty) return headline;
    if (tradeId == Trade.otherId) return null;
    final name = tradeName;
    if (name == null) return headline;
    return languageCode == 'ar' ? name.ar : name.en;
  }
}

enum SuggestionReason { sameCompany, samePlace, sameMarket }
