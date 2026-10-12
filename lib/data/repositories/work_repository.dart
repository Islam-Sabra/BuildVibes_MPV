import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/space.dart';
import '../models/work_item.dart';
import '../supabase/supabase_provider.dart';
import 'space_repository.dart';

/// Work items (migration 7). The app reads; every change is a database
/// function. Failures arrive as [SpaceException].
abstract class WorkRepository {
  Future<List<WorkItem>> items(String spaceId);

  /// What needs the signed-in person in [spaceId].
  Future<WorkNeeds> needs(String spaceId);

  /// A short-lived link to a photo in the private bucket.
  Future<String> photoUrl(String path);
}

/// The private bucket for evidence photos: `<space_id>/<item_id>/<file>`.
const spaceFilesBucket = 'space-files';

class SupabaseWorkRepository implements WorkRepository {
  const SupabaseWorkRepository(this._client);

  final SupabaseClient _client;

  // Each table has several links to profiles: name the one meant.
  static const _item =
      'id, space_id, ref, title, status, created_at, owner_id, created_by, '
      'team_id, place_text, due_date, done_at, checked_by, checked_at, shown, '
      'owner:profiles!work_items_owner_id_fkey(first_name, last_name), '
      'creator:profiles!work_items_created_by_fkey(first_name, last_name), '
      'checker:profiles!work_items_checked_by_fkey(first_name, last_name), '
      'team:teams(name), '
      'events:work_item_events(kind, note, created_at), '
      'evidence:work_item_evidence(storage_path, created_at)';

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on PostgrestException catch (e) {
      throw SpaceException(spaceFailureFor(e.code), e.message);
    } on StorageException catch (e) {
      throw SpaceException(SpaceFailure.unknown, e.message);
    } on Exception catch (e) {
      final network = e is SocketException || '$e'.contains('SocketException');
      throw SpaceException(
        network ? SpaceFailure.network : SpaceFailure.unknown,
        '$e',
      );
    }
  }

  @override
  Future<List<WorkItem>> items(String spaceId) => _guard(() async {
    final rows = await _client
        .from('work_items')
        .select(_item)
        .eq('space_id', spaceId)
        .order('created_at', ascending: false);
    return [for (final r in rows) WorkItem.fromJson(r)];
  });

  @override
  Future<WorkNeeds> needs(String spaceId) => _guard(() async {
    final rows = (await _client.rpc<List<dynamic>>('needs_you'))
        .cast<Map<String, dynamic>>()
        .where((r) => r['space_id'] == spaceId && r['work_item_id'] != null);
    return WorkNeeds(
      toSign: {
        for (final r in rows)
          if (r['kind'] == 'open_owned') r['work_item_id'] as String,
      },
      toCheck: {
        for (final r in rows)
          if (r['kind'] == 'to_check') r['work_item_id'] as String,
      },
      toReassign: {
        for (final r in rows)
          if (r['kind'] == 'owner_left') r['work_item_id'] as String,
      },
    );
  });

  @override
  Future<String> photoUrl(String path) => _guard(
    () => _client.storage
        .from(spaceFilesBucket)
        .createSignedUrl(path, const Duration(hours: 1).inSeconds),
  );
}

final workRepositoryProvider = Provider<WorkRepository>(
  (ref) => SupabaseWorkRepository(ref.watch(supabaseClientProvider)),
);

final workItemsProvider = FutureProvider.autoDispose
    .family<List<WorkItem>, String>(
      (ref, spaceId) => ref.watch(workRepositoryProvider).items(spaceId),
    );

final workNeedsProvider = FutureProvider.autoDispose.family<WorkNeeds, String>(
  (ref, spaceId) => ref.watch(workRepositoryProvider).needs(spaceId),
);

/// Signed links last an hour; kept while a screen shows the photo.
final workPhotoUrlProvider = FutureProvider.autoDispose.family<String, String>(
  (ref, path) => ref.watch(workRepositoryProvider).photoUrl(path),
);
