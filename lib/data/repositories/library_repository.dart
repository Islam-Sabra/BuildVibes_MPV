import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/library.dart';
import '../models/library_folder.dart';
import '../models/space.dart';
import '../models/upload_rules.dart';
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
    String? folderId,
  });

  /// Review 113 LB1: the folders I can see (space_library_folders).
  Future<List<LibraryFolder>> folders(String spaceId);

  /// LB1, LB2: a folder, or a linked folder when [FolderChange.url] is
  /// set (create_library_folder).
  Future<void> createFolder(FolderChange folder);

  /// Its name and who sees it (update_library_folder): its creator or the
  /// Space admin.
  Future<void> updateFolder(FolderChange folder);

  /// delete_library_folder: refused while it holds files.
  Future<void> deleteFolder(String folderId);

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
      'note, supersedes_id, source, uploaded_by, created_at, version_no, '
      'chain_id, folder_id, team:teams(name), '
      'uploader:profiles!library_files_uploaded_by_fkey(first_name, last_name)';

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on SpaceException {
      rethrow;
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
    // F75, F80: the chain's versions by number; exactly one is in use, the
    // highest number not removed (as library_file_in_force sees through a
    // removed middle version).
    final chain = file.chainId;
    if (chain != null) {
      final rows = await _client
          .from('library_files')
          .select(_file)
          .eq('chain_id', chain)
          .isFilter('deleted_at', null)
          .order('version_no', ascending: false)
          .limit(50);
      final versions = [for (final r in rows) LibraryFile.fromJson(r)];
      final inUse = versions.firstOrNull;
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
        older: [
          for (final v in versions)
            if ((v.versionNo ?? 0) < (file.versionNo ?? 0)) v,
        ],
        supersededById: inUse == null || inUse.id == file.id ? null : inUse.id,
      );
    }
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
  }) => _guard(
    // Review 113 bug 7: the bucket's size and type checked first; the
    // type from the file's extension; storage's refusal in plain words.
    () => uploadSpaceFile(file, (type) async {
      final path =
          '$spaceId/library/$fileId/${newUuid()}.${spaceFileExtension(type)}';
      if (onProgress != null) {
        await uploadWithProgress(
          _client,
          bucket: _bucket,
          path: path,
          file: File(file.local),
          contentType: type,
          onProgress: onProgress,
        );
      } else {
        await _client.storage
            .from(_bucket)
            .upload(
              path,
              File(file.local),
              fileOptions: FileOptions(contentType: type),
            );
      }
      return path;
    }, library: true),
  );

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
    String? folderId,
  }) => _guard(
    () => _client.rpc(
      'add_library_file',
      params: {
        // Review 113 (8): into a folder; left out for the Space's Library,
        // so a server without folders takes it as before.
        'p_folder': ?folderId,
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
  Future<List<LibraryFolder>> folders(String spaceId) => _guard(() async {
    final rows = _rows(
      await _client.rpc<List<dynamic>>(
        'space_library_folders',
        params: {'p_space': spaceId},
      ),
    );
    return [for (final r in rows) LibraryFolder.fromJson(r)];
  });

  @override
  Future<void> createFolder(FolderChange f) => _guard(
    () => _client.rpc(
      'create_library_folder',
      params: {
        'p_id': f.id,
        'p_space': f.spaceId,
        'p_name': f.name.trim(),
        'p_share': f.share.json,
        'p_share_person': f.share == FolderShare.person ? f.personId : null,
        'p_share_team': f.share == FolderShare.team ? f.teamId : null,
        'p_url': f.url?.trim(),
      },
    ),
  );

  @override
  Future<void> updateFolder(FolderChange f) => _guard(
    () => _client.rpc(
      'update_library_folder',
      params: {
        'p_id': f.id,
        'p_name': f.name.trim(),
        'p_share': f.share.json,
        'p_share_person': f.share == FolderShare.person ? f.personId : null,
        'p_share_team': f.share == FolderShare.team ? f.teamId : null,
      },
    ),
  );

  @override
  Future<void> deleteFolder(String folderId) => _guard(
    () => _client.rpc('delete_library_folder', params: {'p_id': folderId}),
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

/// Review 113 LB1: a Space's folders I can see.
final libraryFoldersProvider = FutureProvider.autoDispose
    .family<List<LibraryFolder>, String>(
      (ref, spaceId) => ref.watch(libraryRepositoryProvider).folders(spaceId),
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
