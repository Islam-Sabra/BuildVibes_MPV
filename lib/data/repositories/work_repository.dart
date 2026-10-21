import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/space.dart';
import '../models/work_item.dart';
import '../supabase/supabase_provider.dart';
import 'space_repository.dart';

/// A send-back's new due (F62): a day, with a time or not; both null for
/// "No new date".
typedef SendBackDue = ({DateTime? day, DateTime? at});

String _isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Work items (migration 7). The app reads; every change is a database
/// function. Failures arrive as [SpaceException].
abstract class WorkRepository {
  Future<List<WorkItem>> items(String spaceId);

  /// A short-lived link to a photo in the private bucket.
  Future<String> photoUrl(String path);

  /// Uploads a photo to `<space>/<item>/<new uuid>.jpg` and returns the
  /// path. Every call uses a new name, so a retry never replaces a file.
  Future<String> uploadPhoto(String spaceId, String itemId, File file);

  Future<void> addComment(String itemId, String text);

  Future<void> reassign(String itemId, String ownerId);

  /// The owner signs as done. Photos are already uploaded.
  Future<void> signDone(String itemId, {String? note, List<WorkPhoto> photos});

  Future<void> checkItem(String itemId);

  /// [note] is required for [SendBackReason.other].
  /// [due] is the new date the author chose (F62, migration 33): a day,
  /// with a time or not, or `(day: null, at: null)` for "No new date".
  /// Null keeps the due as it was.
  Future<void> sendBack(
    String itemId,
    SendBackReason reason, {
    String? note,
    SendBackDue? due,
  });

  /// Show a Checked item on your profile, or hide it.
  Future<void> setShown(String itemId, bool shown);

  /// RE2: your Checked items, shown or hidden.
  Future<List<DeliveredWork>> myDeliveredWork();

  /// RE1: what [profileId] chose to show.
  Future<List<DeliveredWork>> shownWorkOf(String profileId);
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

  static const _item = 'id, space_id, ref, title';

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

  static List<Map<String, dynamic>> _photosJson(List<WorkPhoto> photos) => [
    for (final p in photos)
      {
        'path': p.path,
        'taken_at': p.takenAt?.toUtc().toIso8601String(),
        'place': p.place,
      },
  ];

  @override
  Future<void> signDone(
    String itemId, {
    String? note,
    List<WorkPhoto> photos = const [],
  }) => _guard(
    () => _client.rpc<void>(
      'sign_done',
      params: {
        'p_item': itemId,
        'p_note': note?.trim(),
        'p_evidence': _photosJson(photos),
      },
    ),
  );

  @override
  Future<void> checkItem(String itemId) =>
      _guard(() => _client.rpc<void>('check_item', params: {'p_item': itemId}));

  @override
  Future<void> sendBack(
    String itemId,
    SendBackReason reason, {
    String? note,
    SendBackDue? due,
  }) => _guard(
    () => _client.rpc<void>(
      'send_back',
      params: {
        'p_item': itemId,
        'p_reason': reason.json,
        'p_note': note?.trim(),
        if (due != null) ...{
          'p_due_set': true,
          'p_due': due.day == null ? null : _isoDay(due.day!),
          'p_due_at': due.at?.toUtc().toIso8601String(),
        },
      },
    ),
  );

  @override
  Future<void> setShown(String itemId, bool shown) => _guard(
    () => _client.rpc<void>(
      'set_shown_work',
      params: {'p_item': itemId, 'p_shown': shown},
    ),
  );

  @override
  Future<List<DeliveredWork>> myDeliveredWork() => _guard(() async {
    final rows = (await _client.rpc<List<dynamic>>(
      'my_delivered_work',
    )).cast<Map<String, dynamic>>();
    return [for (final r in rows) DeliveredWork.fromJson(r)];
  });

  @override
  Future<List<DeliveredWork>> shownWorkOf(String profileId) => _guard(() async {
    final rows = await _client
        .from('public_shown_work')
        .select()
        .eq('profile_id', profileId)
        .order('checked_at', ascending: false);
    return [for (final r in rows) DeliveredWork.fromJson(r)];
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

/// Signed links last an hour; kept while a screen shows the photo.
final workPhotoUrlProvider = FutureProvider.autoDispose.family<String, String>(
  (ref, path) => ref.watch(workRepositoryProvider).photoUrl(path),
);

final myDeliveredWorkProvider = FutureProvider.autoDispose<List<DeliveredWork>>(
  (ref) => ref.watch(workRepositoryProvider).myDeliveredWork(),
);

final shownWorkProvider = FutureProvider.autoDispose
    .family<List<DeliveredWork>, String>(
      (ref, profileId) =>
          ref.watch(workRepositoryProvider).shownWorkOf(profileId),
    );
