import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/library.dart';
import '../models/space.dart';
import '../supabase/supabase_provider.dart';
import 'space_repository.dart';
import 'work_repository.dart' show newUuid;

/// The Space Library (migration 9): files for the whole Space or one Team,
/// revisions, and files attached to work items. Writes are function calls.
abstract class LibraryRepository {
  /// Current and older files, newest first.
  Future<List<LibraryFile>> files(String spaceId);

  /// F1: the file, what uses it and its revisions. Null when it's gone or
  /// you may not see it.
  Future<LibraryFileDetail?> detail(String fileId);

  /// Uploads to `<space>/library/<id>/<new uuid>.<ext>`; returns the path.
  Future<String> upload(String spaceId, String fileId, PhoneFile file);

  Future<void> add({
    required String id,
    required String spaceId,
    required String name,
    required String path,
    required String mime,
    int? bytes,
    String? teamId,
    String? revLabel,
    String? note,
    String? supersedesId,
  });

  /// W2-A / W3 "Attached". A Team file only goes on that Team's items.
  Future<void> attach(String itemId, String fileId);

  /// W3 "Attached".
  Future<List<LibraryFile>> itemFiles(String itemId);

  /// A short-lived link for previews.
  Future<String> fileUrl(String path);

  /// Download.
  Future<Uint8List> download(String path);
}

class SupabaseLibraryRepository implements LibraryRepository {
  const SupabaseLibraryRepository(this._client);

  final SupabaseClient _client;
  static const _bucket = 'space-files';

  // library_files links to profiles twice (uploaded_by, deleted_by).
  static const _file =
      'id, space_id, team_id, name, storage_path, mime, bytes, rev_label, '
      'note, supersedes_id, source, uploaded_by, created_at, team:teams(name), '
      'uploader:profiles!library_files_uploaded_by_fkey(first_name, last_name)';

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
  Future<List<LibraryFile>> files(String spaceId) => _guard(() async {
    final rows = await _client
        .from('library_files')
        .select(_file)
        .eq('space_id', spaceId)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);
    return [for (final r in rows) LibraryFile.fromJson(r)];
  });

  @override
  Future<LibraryFileDetail?> detail(String fileId) => _guard(() async {
    final row = await _client
        .from('library_files')
        .select(_file)
        .eq('id', fileId)
        .maybeSingle();
    if (row == null) return null;
    final file = LibraryFile.fromJson(row);
    final uses = await _client
        .from('work_item_attachments')
        .select('item:work_items(id, ref, title)')
        .eq('library_file_id', fileId);
    final newer = await _client
        .from('library_files')
        .select('id')
        .eq('supersedes_id', fileId)
        .isFilter('deleted_at', null)
        .limit(1);
    // Older revisions: follow the chain back.
    final older = <LibraryFile>[];
    var next = file.supersedesId;
    while (next != null && older.length < 20) {
      final r = await _client
          .from('library_files')
          .select(_file)
          .eq('id', next)
          .maybeSingle();
      if (r == null) break;
      final f = LibraryFile.fromJson(r);
      older.add(f);
      next = f.supersedesId;
    }
    return LibraryFileDetail(
      file: file,
      usedIn: [
        for (final u in uses)
          if (u['item'] case final Map<String, dynamic> item)
            FileUse(
              itemId: item['id'] as String,
              ref: item['ref'] as String,
              title: item['title'] as String,
            ),
      ],
      older: older,
      supersededById: newer.isEmpty ? null : newer.first['id'] as String,
    );
  });

  @override
  Future<String> upload(String spaceId, String fileId, PhoneFile file) =>
      _guard(() async {
        final path = '$spaceId/library/$fileId/${newUuid()}.${file.extension}';
        await _client.storage
            .from(_bucket)
            .upload(
              path,
              File(file.local),
              fileOptions: FileOptions(contentType: file.mime),
            );
        return path;
      });

  @override
  Future<void> add({
    required String id,
    required String spaceId,
    required String name,
    required String path,
    required String mime,
    int? bytes,
    String? teamId,
    String? revLabel,
    String? note,
    String? supersedesId,
  }) => _guard(
    () => _client.rpc(
      'add_library_file',
      params: {
        'p_id': id,
        'p_space': spaceId,
        'p_name': name,
        'p_path': path,
        'p_mime': mime,
        'p_bytes': bytes,
        'p_team': teamId,
        'p_rev_label': revLabel,
        'p_note': note,
        'p_supersedes': supersedesId,
      },
    ),
  );

  @override
  Future<void> attach(String itemId, String fileId) => _guard(
    () => _client.rpc(
      'attach_library_file',
      params: {'p_item': itemId, 'p_file': fileId},
    ),
  );

  @override
  Future<List<LibraryFile>> itemFiles(String itemId) => _guard(() async {
    final rows = await _client
        .from('work_item_attachments')
        .select('file:library_files($_file)')
        .eq('work_item_id', itemId)
        .order('created_at');
    return [
      for (final r in rows)
        if (r['file'] case final Map<String, dynamic> f)
          LibraryFile.fromJson(f),
    ];
  });

  @override
  Future<String> fileUrl(String path) => _guard(
    () => _client.storage.from(_bucket).createSignedUrl(path, 60 * 10),
  );

  @override
  Future<Uint8List> download(String path) =>
      _guard(() => _client.storage.from(_bucket).download(path));
}

final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) => SupabaseLibraryRepository(ref.watch(supabaseClientProvider)),
);

final libraryFilesProvider = FutureProvider.autoDispose
    .family<List<LibraryFile>, String>(
      (ref, spaceId) => ref.watch(libraryRepositoryProvider).files(spaceId),
    );

final libraryFileProvider = FutureProvider.autoDispose
    .family<LibraryFileDetail?, String>(
      (ref, fileId) => ref.watch(libraryRepositoryProvider).detail(fileId),
    );

final itemFilesProvider = FutureProvider.autoDispose
    .family<List<LibraryFile>, String>(
      (ref, itemId) => ref.watch(libraryRepositoryProvider).itemFiles(itemId),
    );

final fileUrlProvider = FutureProvider.autoDispose.family<String, String>(
  (ref, path) => ref.watch(libraryRepositoryProvider).fileUrl(path),
);
