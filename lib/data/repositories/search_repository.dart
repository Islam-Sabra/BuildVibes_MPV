import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/space.dart';
import '../models/space_search.dart';
import '../models/work_item.dart';
import '../supabase/supabase_provider.dart';
import 'space_repository.dart';

/// Search inside a Space (S, search_space): what the caller may read,
/// newest first, 30 at most.
abstract class SearchRepository {
  /// Nothing under [minLength] characters (the server says the same).
  static const minLength = 2;

  /// The server refuses longer.
  static const maxLength = 100;

  Future<List<SpaceSearchHit>> search(String spaceId, String query);
}

class SupabaseSearchRepository implements SearchRepository {
  const SupabaseSearchRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<SpaceSearchHit>> search(String spaceId, String query) async {
    final q = query.trim();
    if (q.length < SearchRepository.minLength) return const [];
    try {
      final rows = await _client.rpc<List<dynamic>>(
        'search_space',
        params: {'p_space': spaceId, 'p_q': q},
      );
      final hits = [
        for (final r in rows)
          ?SpaceSearchHit.fromJson(r as Map<String, dynamic>),
      ];
      // A work item's stamp: its status, read under its own rule.
      final ids = {
        for (final h in hits)
          if (h.isWork && h.ref != null) h.postId!,
      };
      if (ids.isEmpty) return hits;
      final items = await _client
          .from('work_items')
          .select('id, status')
          .inFilter('id', ids.toList());
      final status = {
        for (final i in items)
          i['id'] as String: WorkStatus.fromJson(i['status']),
      };
      return [
        for (final h in hits)
          h.isWork && status.containsKey(h.postId)
              ? h.withStatus(status[h.postId])
              : h,
      ];
    } on PostgrestException catch (e) {
      throw SpaceException(spaceFailureFor(e.code), e.message);
    } on Exception catch (e) {
      final network = e is SocketException || '$e'.contains('SocketException');
      throw SpaceException(
        network ? SpaceFailure.network : SpaceFailure.unknown,
        '$e',
      );
    }
  }
}

final searchRepositoryProvider = Provider<SearchRepository>(
  (ref) => SupabaseSearchRepository(ref.watch(supabaseClientProvider)),
);

/// What a Space search finds for a query (trimmed).
final spaceSearchProvider = FutureProvider.autoDispose
    .family<List<SpaceSearchHit>, ({String spaceId, String query})>(
      (ref, key) =>
          ref.watch(searchRepositoryProvider).search(key.spaceId, key.query),
    );
