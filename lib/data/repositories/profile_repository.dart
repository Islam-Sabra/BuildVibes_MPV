import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/market.dart';
import '../models/people.dart';
import '../supabase/supabase_provider.dart';

/// The signed-in person's profile, companies and suggestions. Every rule
/// (who can read or change what) is enforced by RLS on the server.
abstract class ProfileRepository {
  Future<MyProfile?> fetchMine(String userId);

  Future<void> saveAboutYou(String userId, AboutYouInput input);

  /// Registered companies whose name contains [query].
  Future<List<CompanySummary>> searchCompanies(
    String query, {
    String? marketId,
  });

  Future<List<PersonSuggestion>> suggestions(MyProfile me);

  /// Ids of the people [userId] follows.
  Future<Set<String>> following(String userId);

  Future<void> follow(String userId, String otherId);

  Future<void> unfollow(String userId, String otherId);
}

class SupabaseProfileRepository implements ProfileRepository {
  const SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  static const _mine =
      'id, first_name, last_name, locale, trade_id, headline, home_market_id, '
      'place_id, company_id, company_name_text, deletion_scheduled_at, '
      'trade:trades(name), company:companies!profiles_company_fk(name)';

  static const _person =
      'id, first_name, last_name, trade_id, headline, company_name_text, '
      'trade:trades(name), company:companies!profiles_company_fk(name), '
      'place:places(name)';

  static const _suggestionLimit = 8;

  @override
  Future<MyProfile?> fetchMine(String userId) async {
    final row = await _client
        .from('profiles')
        .select(_mine)
        .eq('id', userId)
        .maybeSingle();
    return row == null ? null : MyProfile.fromJson(row);
  }

  @override
  Future<void> saveAboutYou(String userId, AboutYouInput input) async {
    await _client
        .from('profiles')
        .update(input.toProfileUpdate())
        .eq('id', userId);
    final mobile = input.mobileE164;
    if (mobile != null && mobile.isNotEmpty) {
      await _client
          .from('profile_private')
          .update({'mobile_e164': mobile})
          .eq('id', userId);
    }
  }

  @override
  Future<List<CompanySummary>> searchCompanies(
    String query, {
    String? marketId,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    var request = _client
        .from('companies')
        .select('id, name')
        .ilike('name', '%${_escapeLike(q)}%');
    if (marketId != null) request = request.eq('market_id', marketId);
    final rows = await request.order('name', ascending: true).limit(10);
    return [for (final r in rows) CompanySummary.fromJson(r)];
  }

  @override
  Future<List<PersonSuggestion>> suggestions(MyProfile me) async {
    final seen = <String>{me.id};
    final out = <PersonSuggestion>[];

    Future<void> addFrom(
      PostgrestFilterBuilder<List<Map<String, dynamic>>> query,
      SuggestionReason reason,
    ) async {
      if (out.length >= _suggestionLimit) return;
      final rows = await query
          .neq('id', me.id)
          .neq('first_name', '')
          .limit(_suggestionLimit);
      for (final r in rows) {
        final id = r['id'] as String;
        if (!seen.add(id) || out.length >= _suggestionLimit) continue;
        out.add(_suggestion(r, reason));
      }
    }

    final base = _client.from('profiles');
    if (me.companyId != null) {
      await addFrom(
        base.select(_person).eq('company_id', me.companyId!),
        SuggestionReason.sameCompany,
      );
    }
    if (me.placeId != null) {
      await addFrom(
        base.select(_person).eq('place_id', me.placeId!),
        SuggestionReason.samePlace,
      );
    }
    if (me.homeMarketId != null) {
      await addFrom(
        base.select(_person).eq('home_market_id', me.homeMarketId!),
        SuggestionReason.sameMarket,
      );
    }
    return out;
  }

  PersonSuggestion _suggestion(
    Map<String, dynamic> r,
    SuggestionReason reason,
  ) {
    final trade = r['trade'] as Map<String, dynamic>?;
    final company = r['company'] as Map<String, dynamic>?;
    final place = r['place'] as Map<String, dynamic>?;
    return PersonSuggestion(
      id: r['id'] as String,
      firstName: r['first_name'] as String? ?? '',
      lastName: r['last_name'] as String? ?? '',
      reason: reason,
      tradeId: r['trade_id'] as String?,
      headline: r['headline'] as String?,
      tradeName: trade == null
          ? null
          : LocalizedText.fromJson(trade['name'] as Map<String, dynamic>),
      companyLabel:
          company?['name'] as String? ?? r['company_name_text'] as String?,
      placeName: place == null
          ? null
          : LocalizedText.fromJson(place['name'] as Map<String, dynamic>),
    );
  }

  @override
  Future<Set<String>> following(String userId) async {
    final rows = await _client
        .from('follows')
        .select('followee_id')
        .eq('follower_id', userId);
    return {for (final r in rows) r['followee_id'] as String};
  }

  @override
  Future<void> follow(String userId, String otherId) => _client
      .from('follows')
      .insert({'follower_id': userId, 'followee_id': otherId});

  @override
  Future<void> unfollow(String userId, String otherId) => _client
      .from('follows')
      .delete()
      .eq('follower_id', userId)
      .eq('followee_id', otherId);

  static String _escapeLike(String s) =>
      s.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => SupabaseProfileRepository(ref.watch(supabaseClientProvider)),
);
