import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart' show StorageException;

import 'library.dart';
import 'space.dart';

/// Review 113, bug 7: the private bucket `space-files` checks every upload
/// itself, and a refusal came back as a bare HTTP 400. The phone checks
/// the same two things first, and names a refusal in plain words.
///
/// The bucket as the migrations leave it (20261012140000_chat_library,
/// 20261120120000_check_in): 25 MB, and these types. Change them together.

/// The bucket's `file_size_limit`.
const spaceFilesMaxBytes = 26214400;

/// The bucket's `allowed_mime_types`, exactly.
const spaceFilesAllowedTypes = {
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/heic',
  'application/pdf',
  'audio/mp4',
  'audio/aac',
  'audio/mpeg',
  'audio/x-m4a',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
};

/// The type sent for a file's extension. Some pickers and drives say a
/// PDF is `application/octet-stream`, which the bucket refuses: the
/// extension decides.
const spaceFilesTypesByExtension = {
  'pdf': 'application/pdf',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
  'heic': 'image/heic',
  'm4a': 'audio/mp4',
  'aac': 'audio/aac',
  'mp3': 'audio/mpeg',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
};

/// The extension a stored file gets, from its type.
String spaceFileExtension(String type) => switch (type) {
  'audio/x-m4a' => 'm4a',
  _ =>
    spaceFilesTypesByExtension.entries
            .where((e) => e.value == type)
            .firstOrNull
            ?.key ??
        'bin',
};

String _extensionOf(String name) {
  final dot = name.lastIndexOf('.');
  return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
}

/// The type [file] goes with: from its name's extension; with none the
/// table knows, the type it came with when the bucket takes it. Null when
/// the bucket would refuse it.
String? spaceFileType(PhoneFile file) {
  final known = spaceFilesTypesByExtension[_extensionOf(file.name)];
  if (known != null) return known;
  // "A-501 Rev.C": a dot that names no type; the type it came with.
  return spaceFilesAllowedTypes.contains(file.mime) ? file.mime : null;
}

/// The types the Library itself takes (add_library_file: images and
/// PDF), narrower than the bucket's: a post's file goes to the Library.
const libraryFileTypes = {
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/heic',
  'application/pdf',
};

/// What is wrong with a file the bucket (or the Library) refuses:
/// [notPdfOrPhoto] is a type the bucket takes but the Library doesn't;
/// [gone] is a draft's file no longer on the phone (review 113 Z13).
enum UploadProblem { tooBig, wrongType, notPdfOrPhoto, gone }

/// A file the bucket refuses, said before it goes or read from storage's
/// answer. A [SpaceException], so every caller that catches those still
/// does; [code] travels with a refused post and comes back by [fromCode].
class FileRefused extends SpaceException {
  const FileRefused(this.problem, {this.bytes, this.fileId})
    : super(SpaceFailure.badInput, 'file refused');

  final UploadProblem problem;

  /// The file's size, when known.
  final int? bytes;

  /// The post's file (its Library id; a photo's or a voice note's place on
  /// the phone), so Remove takes that one off.
  final String? fileId;

  /// Whole megabytes, rounded up ("38 MB"): the phone's megabyte.
  int? get megabytes =>
      bytes == null ? null : (bytes! + _megabyte - 1) ~/ _megabyte;

  static const _megabyte = 1024 * 1024;
  static const _prefix = 'file:';

  FileRefused withFile(String? id) =>
      FileRefused(problem, bytes: bytes, fileId: id);

  String get code =>
      _prefix + jsonEncode({'p': problem.name, 'b': ?bytes, 'f': ?fileId});

  static FileRefused? fromCode(String? code) {
    if (code == null || !code.startsWith(_prefix)) return null;
    try {
      final j = jsonDecode(code.substring(_prefix.length)) as Map;
      final problem = UploadProblem.values
          .where((p) => p.name == j['p'])
          .firstOrNull;
      if (problem == null) return null;
      return FileRefused(
        problem,
        bytes: (j['b'] as num?)?.toInt(),
        fileId: j['f'] as String?,
      );
    } on Object {
      return null;
    }
  }

  @override
  String toString() => 'FileRefused($problem, $bytes)';
}

/// Null when [file] may go to `space-files`; otherwise why not. With
/// [library], only what the Library takes (a PDF or a photo).
FileRefused? checkSpaceFile(PhoneFile file, {bool library = false}) {
  final type = spaceFileType(file);
  if (type == null) {
    return FileRefused(UploadProblem.wrongType, bytes: file.bytes);
  }
  if (library && !libraryFileTypes.contains(type)) {
    return FileRefused(UploadProblem.notPdfOrPhoto, bytes: file.bytes);
  }
  final bytes = file.bytes;
  if (bytes != null && bytes > spaceFilesMaxBytes) {
    return FileRefused(UploadProblem.tooBig, bytes: bytes);
  }
  return null;
}

/// Storage's refusal of [file] in plain words: HTTP 400 with an inner 413
/// (or a plain 413) is too big; an unsupported mime type (415,
/// invalid_mime_type) is the wrong type. Null for anything else.
FileRefused? uploadRefusalOf(StorageException e, PhoneFile file) {
  final words = '${e.message} ${e.error ?? ''}'.toLowerCase();
  if (e.statusCode == '413' ||
      words.contains('"413"') ||
      words.contains('payload too large') ||
      words.contains('entity too large') ||
      words.contains('entitytoolarge') ||
      words.contains('maximum allowed size')) {
    return FileRefused(UploadProblem.tooBig, bytes: file.bytes);
  }
  if (e.statusCode == '415' ||
      words.contains('"415"') ||
      words.contains('invalid_mime_type') ||
      words.contains('mime type')) {
    return FileRefused(UploadProblem.wrongType, bytes: file.bytes);
  }
  return null;
}

/// Uploads [file] with [send] (given the type to send) after the checks
/// ([library]: the Library's narrower types), and turns storage's
/// refusals into [FileRefused].
Future<T> uploadSpaceFile<T>(
  PhoneFile file,
  Future<T> Function(String type) send, {
  bool library = false,
}) async {
  final refused = checkSpaceFile(file, library: library);
  if (refused != null) throw refused;
  try {
    return await send(spaceFileType(file)!);
  } on StorageException catch (e) {
    throw uploadRefusalOf(e, file) ?? e;
  }
}
