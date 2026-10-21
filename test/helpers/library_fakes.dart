import 'dart:typed_data';

import 'package:buildvibes/data/models/library.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/repositories/library_repository.dart';

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
    // As add_library_file: an id is used once.
    if (_find(id) != null) {
      throw const SpaceException(SpaceFailure.badInput, 'this id is taken');
    }
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
}
