import 'dart:async';
import 'dart:typed_data';

import 'package:buildvibes/data/models/library.dart';
import 'package:buildvibes/data/models/library_folder.dart';
import 'package:buildvibes/data/models/upload_rules.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/repositories/library_repository.dart';
import 'package:buildvibes/data/supabase/upload_progress.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show StorageException;

/// The Library with no network. Tests fill [filesBySpace] (newest first),
/// and [usedIn].
class FakeLibraryRepository implements LibraryRepository {
  FakeLibraryRepository({DateTime? now}) : now = now ?? DateTime(2026, 10, 11);

  final DateTime now;
  final filesBySpace = <String, List<LibraryFile>>{};
  final usedIn = <String, List<FileUse>>{};
  final uploads = <String>[];

  /// library_overview's rows, by file id; receipts and the file post, by
  /// file id.
  final overviewBySpace = <String, Map<String, LibraryOverview>>{};
  final receiptsByFile = <String, List<LibraryReceipt>>{};
  final postByFile = <String, String>{};
  final calls = <String>[];

  LibraryFile? _find(String id) {
    for (final list in filesBySpace.values) {
      for (final f in list) {
        if (f.id == id) return f;
      }
    }
    return null;
  }

  @override
  Future<List<LibraryFile>> files(String spaceId) async =>
      List.of(filesBySpace[spaceId] ?? const []);

  @override
  Future<LibraryFileDetail?> detail(String fileId) async {
    final f = _find(fileId);
    if (f == null) return null;
    final older = <LibraryFile>[];
    var next = f.supersedesId;
    while (next != null) {
      final o = _find(next);
      if (o == null) break;
      older.add(o);
      next = o.supersedesId;
    }
    final newer = filesBySpace[f.spaceId]
        ?.where((x) => x.supersedesId == f.id)
        .firstOrNull;
    return LibraryFileDetail(
      file: f,
      usedIn: usedIn[fileId] ?? const [],
      older: older,
      supersededById: newer?.id,
    );
  }

  /// While set, an upload stops half way (F73) until it completes.
  Completer<void>? holdUpload;

  /// Review 113 bug 7: what storage answers the next upload with (a 400
  /// with an inner 413, an unsupported type); the bucket's own checks run
  /// first, as the app's do.
  StorageException? storageRefuses;

  /// The types each upload went with, in order.
  final uploadTypes = <String>[];

  @override
  Future<String> upload(
    String spaceId,
    String fileId,
    PhoneFile file, {
    UploadProgress? onProgress,
  }) => uploadSpaceFile(file, (type) async {
    uploadTypes.add(type);
    final refused = storageRefuses;
    if (refused != null) {
      storageRefuses = null;
      throw refused;
    }
    return _upload(spaceId, fileId, file, onProgress);
  }, library: true);

  Future<String> _upload(
    String spaceId,
    String fileId,
    PhoneFile file,
    UploadProgress? onProgress,
  ) async {
    final total = file.bytes ?? 0;
    onProgress?.call(0, total);
    final hold = holdUpload;
    if (hold != null) {
      onProgress?.call(total ~/ 3, total);
      await hold.future;
    }
    onProgress?.call(total, total);
    final path =
        '$spaceId/library/$fileId/upload-${uploads.length + 1}.${file.extension}';
    uploads.add(path);
    return path;
  }

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
  }) async {
    // As add_library_file: an id is used once.
    if (_find(id) != null) {
      throw const SpaceException(SpaceFailure.badInput, 'this id is taken');
    }
    calls.add(
      'add $name team:${teamId ?? '-'} rev:${revLabel ?? '-'} '
      'supersedes:${supersedesId ?? '-'}'
      '${folderId == null ? '' : ' folder:$folderId'}',
    );
    // As library_file_number (F75): the next number in its chain.
    final older = supersedesId == null ? null : _find(supersedesId);
    final versionNo = older?.versionNo == null ? null : older!.versionNo! + 1;
    filesBySpace
        .putIfAbsent(spaceId, () => [])
        .insert(
          0,
          LibraryFile(
            id: id,
            spaceId: spaceId,
            name: name,
            path: path,
            mime: mime,
            createdAt: now,
            teamId: teamId,
            bytes: bytes,
            revLabel: revLabel,
            note: note,
            supersedesId: supersedesId,
            versionNo: versionNo,
            uploadedById: 'user-1',
            uploadedByName: 'Omar Haddad',
            folderId: folderId,
          ),
        );
    if (loseAnswer) {
      loseAnswer = false;
      throw const SpaceException(SpaceFailure.network);
    }
  }

  /// The next add reaches the Library but its answer is lost (a weak
  /// signal): the phone hears no signal.
  bool loseAnswer = false;

  /// False gives links (to play a voice note); true, the default, is no
  /// network: previews show "can't show".
  bool offline = true;

  @override
  Future<Map<String, LibraryOverview>> overview(String spaceId) async =>
      Map.of(overviewBySpace[spaceId] ?? const {});

  @override
  Future<List<LibraryReceipt>> receipts(String fileId) async =>
      List.of(receiptsByFile[fileId] ?? const []);

  @override
  Future<String?> postFor(String fileId) async => postByFile[fileId];

  @override
  Future<String> fileUrl(String path) async => offline
      ? throw const SpaceException(SpaceFailure.network)
      : 'https://files.test/$path';

  /// What a download gives for a path (a real photo, say); else the
  /// start of a PDF.
  final bytesByPath = <String, Uint8List>{};

  @override
  Future<Uint8List> download(String path) async {
    calls.add('download $path');
    return bytesByPath[path] ?? Uint8List.fromList(const [37, 80, 68, 70]);
  }

  /// Review 113 LB1: the folders by Space, as space_library_folders gives
  /// them; [folderCalls] what was asked.
  final foldersBySpace = <String, List<LibraryFolder>>{};
  final folderCalls = <String>[];

  /// The next folder call fails with this.
  SpaceException? folderRefuses;

  void _folderRefusal() {
    final e = folderRefuses;
    if (e != null) {
      folderRefuses = null;
      throw e;
    }
  }

  @override
  Future<List<LibraryFolder>> folders(String spaceId) async =>
      List.of(foldersBySpace[spaceId] ?? const []);

  @override
  Future<void> createFolder(FolderChange f) async {
    folderCalls.add(
      'create ${f.name} ${f.share.json}'
      '${f.personId == null ? '' : ' person:${f.personId}'}'
      '${f.teamId == null ? '' : ' team:${f.teamId}'}'
      '${f.url == null ? '' : ' url:${f.url}'}',
    );
    _folderRefusal();
    foldersBySpace
        .putIfAbsent(f.spaceId, () => [])
        .add(
          LibraryFolder(
            id: f.id,
            name: f.name.trim(),
            share: f.share,
            url: f.url,
            service: f.url == null ? null : linkServiceOf(f.url!),
            sharePersonId: f.personId,
            shareTeamId: f.teamId,
            mine: true,
          ),
        );
  }

  @override
  Future<void> updateFolder(FolderChange f) async {
    folderCalls.add('update ${f.id} ${f.name} ${f.share.json}');
    _folderRefusal();
    final list = foldersBySpace[f.spaceId];
    if (list == null) return;
    final i = list.indexWhere((x) => x.id == f.id);
    if (i < 0) return;
    final old = list[i];
    list[i] = LibraryFolder(
      id: old.id,
      name: f.name.trim(),
      share: f.share,
      url: old.url,
      service: old.service,
      sharePersonId: f.personId,
      shareTeamId: f.teamId,
      mine: old.mine,
      createdBy: old.createdBy,
    );
  }

  @override
  Future<void> deleteFolder(String folderId) async {
    folderCalls.add('delete $folderId');
    _folderRefusal();
    for (final list in foldersBySpace.values) {
      list.removeWhere((f) => f.id == folderId);
    }
  }
}
