import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/first_run_tip.dart';
import '../supabase/supabase_provider.dart';

/// The first-run tips the signed-in account has seen (review 107 OB7).
/// The server keeps them per account (profile_tips_seen), so a tip seen on
/// one phone isn't shown on another.
abstract class TipsRepository {
  Future<Set<FirstRunTip>> seen();

  /// mark_tip_seen: kept once; the caller's own only.
  Future<void> markSeen(FirstRunTip tip);
}

class SupabaseTipsRepository implements TipsRepository {
  const SupabaseTipsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Set<FirstRunTip>> seen() async {
    final rows = await _client.from('profile_tips_seen').select('tip');
    return {
      for (final r in rows) ?FirstRunTip.fromJson(r['tip']),
    };
  }

  @override
  Future<void> markSeen(FirstRunTip tip) =>
      _client.rpc<void>('mark_tip_seen', params: {'p_tip': tip.json});
}

final tipsRepositoryProvider = Provider<TipsRepository>(
  (ref) => SupabaseTipsRepository(ref.watch(supabaseClientProvider)),
);
