import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/market.dart';
import '../supabase/supabase_provider.dart';

/// Reads the market packs. Reference tables are readable without signing in.
class MarketRepository {
  const MarketRepository(this._client);

  final SupabaseClient _client;

  /// Live and coming-soon markets, in display order. Hidden markets are
  /// filtered out by the database.
  Future<List<Market>> fetchMarkets() async {
    final rows = await _client
        .from('markets')
        .select(
          'id, status, name, default_locale, dial_code, phone_rules, '
          'code_channel, currency, currency_decimals, week_start, weekend, '
          'needs_review',
        )
        // Ascending: the client's default is descending.
        .order('sort', ascending: true);
    return [for (final row in rows) Market.fromJson(row)];
  }
}

final marketRepositoryProvider = Provider<MarketRepository>(
  (ref) => MarketRepository(ref.watch(supabaseClientProvider)),
);

final marketsProvider = FutureProvider<List<Market>>(
  (ref) => ref.watch(marketRepositoryProvider).fetchMarkets(),
);
