import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/library.dart';
import '../models/space.dart';
import '../supabase/supabase_provider.dart';
import '../supabase/upload_progress.dart';
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
  /// [onProgress] hears how many bytes went (F73).
  Future<String> upload(
    String spaceId,
    String fileId,
    PhoneFile file, {
    UploadProgress? onProgress,
  });

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

  /// LV1: per file in use, NEW VERSION for me and up to 4 receivers
  /// (library_overview), by file id.
  Future<Map<String, LibraryOverview>> overview(String spaceId);

  /// LV2: who received this version, oldest first (library_file_receipts).
  Future<List<LibraryReceipt>> receipts(String fileId);

  /// LV2: the post to mark Received through (library_file_post); null when
  /// no post carries this version (a file from chat).
  Future<String?> postFor(String fileId);

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
  Future<String> upload(
    String spaceId,
    String fileId,
    PhoneFile file, {
    UploadProgress? onProgress,
  }) => _guard(() async {
    final path = '$spaceId/library/$fileId/${newUuid()}.${file.extension}';
    if (onProgress != null) {
      await uploadWithProgress(
        _client,
        bucket: _bucket,
        path: path,
        file: File(file.local),
        contentType: file.mime,
        onProgress: onProgress,
      );
    } else {
      await _client.storage
          .from(_bucket)
          .upload(
            path,
            File(file.local),
            fileOptions: FileOptions(contentType: file.mime),
          );
    }
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

  List<Map<String, dynamic>> _rows(Object? data) => [
    for (final r in (data as List? ?? const [])) r as Map<String, dynamic>,
  ];

  @override
  Future<Map<String, LibraryOverview>> overview(String spaceId) =>
      _guard(() async {
        final rows = _rows(
          await _client.rpc<List<dynamic>>(
            'library_overview',
            params: {'p_space': spaceId},
          ),
        );
        return {
          for (final r in rows)
            r['file_id'] as String: LibraryOverview.fromJson(r),
        };
      });

  @override
  Future<List<LibraryReceipt>> receipts(String fileId) => _guard(() async {
    final rows = _rows(
      await _client.rpc<List<dynamic>>(
        'library_file_receipts',
        params: {'p_file': fileId},
      ),
    );
    return [for (final r in rows) LibraryReceipt.fromJson(r)];
  });

  @override
  Future<String?> postFor(String fileId) => _guard(
    () => _client.rpc<String?>('library_file_post', params: {'p_file': fileId}),
  );

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

/// A Library photo's bytes, read with the person's own session (as
/// Download and the PDF sheet are): review 61 G4.
final fileBytesProvider = FutureProvider.autoDispose.family<Uint8List, String>(
  (ref, path) => ref.watch(libraryRepositoryProvider).download(path),
);

/// LV1's extras: NEW VERSION and the receivers' faces, by file id.
final libraryOverviewProvider = FutureProvider.autoDispose
    .family<Map<String, LibraryOverview>, String>(
      (ref, spaceId) => ref.watch(libraryRepositoryProvider).overview(spaceId),
    );

/// LV2: who received this version.
final libraryReceiptsProvider = FutureProvider.autoDispose
    .family<List<LibraryReceipt>, String>(
      (ref, fileId) => ref.watch(libraryRepositoryProvider).receipts(fileId),
    );

/// LV2: the post its Received pill acts on, or null.
final libraryFilePostProvider = FutureProvider.autoDispose
    .family<String?, String>(
      (ref, fileId) => ref.watch(libraryRepositoryProvider).postFor(fileId),
    );

final fileUrlProvider = FutureProvider.autoDispose.family<String, String>(
  (ref, path) => ref.watch(libraryRepositoryProvider).fileUrl(path),
);
