import 'dart:typed_data';

import 'package:buildvibes/data/models/library.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/repositories/library_repository.dart';

/// The Library with no network. Tests fill [filesBySpace] (newest first),
/// [usedIn] and [attachedTo].
class FakeLibraryRepository implements LibraryRepository {
  FakeLibraryRepository({DateTime? now}) : now = now ?? DateTime(2026, 10, 11);

  final DateTime now;
  final filesBySpace = <String, List<LibraryFile>>{};
  final usedIn = <String, List<FileUse>>{};
  final attachedTo = <String, List<String>>{};
  final uploads = <String>[];
  final calls = <String>[];

  /// The next attach is refused with this failure.
  SpaceFailure? refuseAttach;

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

  @override
  Future<String> upload(String spaceId, String fileId, PhoneFile file) async {
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
  }) async {
    calls.add(
      'add $name team:${teamId ?? '-'} rev:${revLabel ?? '-'} '
      'supersedes:${supersedesId ?? '-'}',
    );
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
            uploadedById: 'user-1',
            uploadedByName: 'Omar Haddad',
          ),
        );
  }

  @override
  Future<void> attach(String itemId, String fileId) async {
    final refuse = refuseAttach;
    if (refuse != null) {
      refuseAttach = null;
      throw SpaceException(refuse);
    }
    calls.add('attach $itemId $fileId');
    attachedTo.putIfAbsent(itemId, () => []).add(fileId);
  }

  @override
  Future<List<LibraryFile>> itemFiles(String itemId) async => [
    for (final id in attachedTo[itemId] ?? const <String>[]) ?_find(id),
  ];

  /// False gives links (to play a voice note); true, the default, is no
  /// network: previews show "can't show".
  bool offline = true;

  @override
  Future<String> fileUrl(String path) async => offline
      ? throw const SpaceException(SpaceFailure.network)
      : 'https://files.test/$path';

  @override
  Future<Uint8List> download(String path) async {
    calls.add('download $path');
    return Uint8List.fromList(const [37, 80, 68, 70]);
  }
}
