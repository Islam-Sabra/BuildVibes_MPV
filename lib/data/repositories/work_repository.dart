import 'dart:io';
import 'dart:math';

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

  /// The item page: the item and its whole record. Null when it is gone or
  /// you are not a member.
  Future<WorkItemDetail?> detail(String itemId);

  /// The reference the next item will get ("KCT-006"), for the W2 stamp.
  Future<String?> nextRef(String spaceId);

  /// Uploads a photo to `<space>/<item>/<new uuid>.jpg` and returns the
  /// path. Every call uses a new name, so a retry never replaces a file.
  Future<String> uploadPhoto(String spaceId, String itemId, File file);

  /// [itemId] is chosen by the app: a retry returns the same item.
  Future<void> createItem(NewWorkItem item);

  Future<void> addComment(String itemId, String text);

  Future<void> reassign(String itemId, String ownerId);
}

/// What W2 sends to create_work_item. Photos are already uploaded.
class NewWorkItem {
  const NewWorkItem({
    required this.id,
    required this.spaceId,
    required this.title,
    required this.ownerId,
    this.due,
    this.teamId,
    this.place,
    this.photos = const [],
  });

  final String id;
  final String spaceId;
  final String title;
  final String ownerId;
  final DateTime? due;
  final String? teamId;
  final String? place;
  final List<WorkPhoto> photos;
}

/// A random version 4 UUID (item ids and photo names).
String newUuid() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = [for (final x in b) x.toRadixString(16).padLeft(2, '0')].join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
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

  static const _event =
      'id, kind, note, reason, created_at, actor_id, '
      'actor:profiles!work_item_events_actor_id_fkey(first_name, last_name), '
      'evidence:work_item_evidence(storage_path, taken_at, place_text)';

  @override
  Future<WorkItemDetail?> detail(String itemId) => _guard(() async {
    final row = await _client
        .from('work_items')
        .select('$_item, record:work_item_events($_event)')
        .eq('id', itemId)
        .maybeSingle();
    if (row == null) return null;
    final events = [
      for (final e in row['record'] as List? ?? const [])
        _eventFrom(e as Map<String, dynamic>),
    ]..sort((a, b) => a.at.compareTo(b.at));
    return WorkItemDetail(item: WorkItem.fromJson(row), events: events);
  });

  static WorkEvent _eventFrom(Map<String, dynamic> e) {
    final actor = e['actor'] as Map<String, dynamic>?;
    final name = actor == null
        ? null
        : '${actor['first_name'] ?? ''} ${actor['last_name'] ?? ''}'.trim();
    return WorkEvent(
      id: e['id'] as String,
      kind: WorkEventKind.fromJson(e['kind']),
      at: DateTime.parse(e['created_at'] as String),
      actorId: e['actor_id'] as String?,
      actorName: (name ?? '').isEmpty ? null : name,
      note: e['note'] as String?,
      reason: SendBackReason.fromJson(e['reason']),
      photos: [
        for (final p in e['evidence'] as List? ?? const [])
          WorkPhoto(
            path: (p as Map<String, dynamic>)['storage_path'] as String,
            takenAt: p['taken_at'] == null
                ? null
                : DateTime.parse(p['taken_at'] as String),
            place: p['place_text'] as String?,
          ),
      ],
    );
  }

  @override
  Future<String?> nextRef(String spaceId) => _guard(() async {
    final row = await _client
        .from('spaces')
        .select('ref_prefix, next_item_number')
        .eq('id', spaceId)
        .maybeSingle();
    if (row == null) return null;
    final n = (row['next_item_number'] as num).toInt();
    return '${row['ref_prefix']}-${n.toString().padLeft(3, '0')}';
  });

  @override
  Future<String> uploadPhoto(String spaceId, String itemId, File file) =>
      _guard(() async {
        final path = '$spaceId/$itemId/${newUuid()}.jpg';
        await _client.storage
            .from(spaceFilesBucket)
            .upload(
              path,
              file,
              fileOptions: const FileOptions(contentType: 'image/jpeg'),
            );
        return path;
      });

  @override
  Future<void> createItem(NewWorkItem item) => _guard(
    () => _client.rpc<String>(
      'create_work_item',
      params: {
        'p_space': item.spaceId,
        'p_title': item.title.trim(),
        'p_owner': item.ownerId,
        'p_due': item.due == null
            ? null
            : '${item.due!.year.toString().padLeft(4, '0')}-'
                  '${item.due!.month.toString().padLeft(2, '0')}-'
                  '${item.due!.day.toString().padLeft(2, '0')}',
        'p_team': item.teamId,
        'p_place': item.place?.trim(),
        'p_evidence': [
          for (final p in item.photos)
            {
              'path': p.path,
              'taken_at': p.takenAt?.toUtc().toIso8601String(),
              'place': p.place,
            },
        ],
        'p_id': item.id,
      },
    ),
  );

  @override
  Future<void> addComment(String itemId, String text) => _guard(
    () => _client.rpc<String>(
      'add_comment',
      params: {'p_item': itemId, 'p_note': text.trim()},
    ),
  );

  @override
  Future<void> reassign(String itemId, String ownerId) => _guard(
    () => _client.rpc<void>(
      'reassign_work_item',
      params: {'p_item': itemId, 'p_owner': ownerId},
    ),
  );

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

final workItemDetailProvider = FutureProvider.autoDispose
    .family<WorkItemDetail?, String>(
      (ref, itemId) => ref.watch(workRepositoryProvider).detail(itemId),
    );
