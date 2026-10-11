import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/market.dart';
import '../models/people.dart';
import '../supabase/supabase_provider.dart';

/// Reference data for onboarding. Readable without signing in.
abstract class ReferenceRepository {
  Future<RolePicker> fetchRolePicker(String marketId);
}

class SupabaseReferenceRepository implements ReferenceRepository {
  const SupabaseReferenceRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<RolePicker> fetchRolePicker(String marketId) async {
    final families = await _client
        .from('role_families')
        .select('id, name, sort')
        // Ascending: the client's default is descending.
        .order('sort', ascending: true);
    final trades = await _client
        .from('trades')
        .select('id, family_id, name, description, sort')
        .order('sort', ascending: true);
    final local = await _client
        .from('market_trades')
        .select('trade_id, visible, local_name, popular_sort')
        .eq('market_id', marketId);
    return buildRolePicker(
      families: families,
      trades: trades,
      marketTrades: local,
    );
  }
}

/// Joins the three reference tables into the picker. Pure, so it is tested
/// without a server.
RolePicker buildRolePicker({
  required List<Map<String, dynamic>> families,
  required List<Map<String, dynamic>> trades,
  required List<Map<String, dynamic>> marketTrades,
}) {
  final byTrade = {for (final m in marketTrades) m['trade_id'] as String: m};
  Trade toTrade(Map<String, dynamic> t) {
    final m = byTrade[t['id']];
    final localName = m?['local_name'] as Map<String, dynamic>?;
    final description = t['description'] as Map<String, dynamic>?;
    return Trade(
      id: t['id'] as String,
      familyId: t['family_id'] as String,
      name: LocalizedText.fromJson(
        localName ?? t['name'] as Map<String, dynamic>,
      ),
      description: description == null
          ? null
          : LocalizedText.fromJson(description),
      popularSort: m?['popular_sort'] as int?,
    );
  }

  final visible = [
    for (final t in trades)
      if (byTrade[t['id']]?['visible'] != false) toTrade(t),
  ];
  return RolePicker(
    other: visible.firstWhere((t) => t.id == Trade.otherId),
    families: [
      for (final f in families)
        RoleFamily(
          id: f['id'] as String,
          name: LocalizedText.fromJson(f['name'] as Map<String, dynamic>),
          trades: [
            for (final t in visible)
              if (t.familyId == f['id'] && t.id != Trade.otherId) t,
          ],
        ),
    ],
  );
}

final referenceRepositoryProvider = Provider<ReferenceRepository>(
  (ref) => SupabaseReferenceRepository(ref.watch(supabaseClientProvider)),
);

final rolePickerProvider = FutureProvider.family<RolePicker, String>(
  (ref, marketId) =>
      ref.watch(referenceRepositoryProvider).fetchRolePicker(marketId),
);
