import 'package:flutter/foundation.dart';

String? _name(Object? row) {
  if (row is! Map) return null;
  final name = '${row['first_name'] ?? ''} ${row['last_name'] ?? ''}'.trim();
  return name.isEmpty ? null : name;
}

/// Where a Library file came from: added in the Library, shared in chat,
/// or published from BuildVibes 360 (a model view, migration 27).
enum LibrarySource { upload, chat, modelView }

/// A file in a Space's Library (S13k): a drawing (PDF) or a photo, for the
/// whole Space or one Team. A new revision supersedes an older one, which
/// is kept in the record.
@immutable
class LibraryFile {
  const LibraryFile({
    required this.id,
    required this.spaceId,
    required this.name,
    required this.path,
    required this.mime,
    required this.createdAt,
    this.teamId,
    this.teamName,
    this.bytes,
    this.revLabel,
    this.note,
    this.supersedesId,
    this.source = LibrarySource.upload,
    this.uploadedById,
    this.uploadedByName,
  });

  /// A row of library_files with `team:teams(name)` and
  /// `uploader:profiles!library_files_uploaded_by_fkey(first_name, last_name)`.
  factory LibraryFile.fromJson(Map<String, dynamic> json) {
    final team = json['team'];
    return LibraryFile(
      id: json['id'] as String,
      spaceId: json['space_id'] as String? ?? '',
      name: json['name'] as String,
      path: json['storage_path'] as String? ?? '',
      mime: json['mime'] as String? ?? 'application/pdf',
      createdAt: json['created_at'] == null
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.parse(json['created_at'] as String),
      teamId: json['team_id'] as String?,
      teamName: team is Map ? team['name'] as String? : null,
      bytes: (json['bytes'] as num?)?.toInt(),
      revLabel: json['rev_label'] as String?,
      note: json['note'] as String?,
      supersedesId: json['supersedes_id'] as String?,
      source: switch (json['source']) {
        'chat' => LibrarySource.chat,
        'model_view' => LibrarySource.modelView,
        _ => LibrarySource.upload,
      },
      uploadedById: json['uploaded_by'] as String?,
      uploadedByName: _name(json['uploader']),
    );
  }

  final String id;
  final String spaceId;
  final String name;

  /// In the private bucket: `<space>/library/<id>/…`, or the chat path for
  /// a document shared in chat.
  final String path;
  final String mime;
  final DateTime createdAt;
  final String? teamId;
  final String? teamName;
  final int? bytes;

  /// For example "Rev C". Latin, as written on the drawing.
  final String? revLabel;
  final String? note;
  final String? supersedesId;
  final LibrarySource source;
  final String? uploadedById;
  final String? uploadedByName;

  bool get isPdf => mime == 'application/pdf';
  bool get isImage => mime.startsWith('image/');
}

/// A work item that uses a Library file ("Used in KCT-021 · …").
@immutable
class FileUse {
  const FileUse({required this.itemId, required this.ref, required this.title});

  final String itemId;
  final String ref;
  final String title;
}

/// F1: a file, the items that use it, and its revisions.
@immutable
class LibraryFileDetail {
  const LibraryFileDetail({
    required this.file,
    this.usedIn = const [],
    this.older = const [],
    this.supersededById,
  });

  final LibraryFile file;
  final List<FileUse> usedIn;

  /// Earlier revisions, newest first; kept in the record.
  final List<LibraryFile> older;

  /// Set when a newer revision replaced this one.
  final String? supersededById;

  bool get isCurrent => supersededById == null;
}

/// A file picked on the phone, waiting to be uploaded (chat or Library).
@immutable
class PhoneFile {
  const PhoneFile({
    required this.local,
    required this.name,
    required this.mime,
    this.bytes,
    this.durationMs,
  });

  final String local;
  final String name;
  final String mime;
  final int? bytes;

  /// A voice note's length.
  final int? durationMs;

  bool get isPdf => mime == 'application/pdf';
  bool get isVoice => mime.startsWith('audio/');

  /// The extension the upload gets, from the type.
  String get extension => switch (mime) {
    'application/pdf' => 'pdf',
    'image/png' => 'png',
    'image/webp' => 'webp',
    'image/heic' => 'heic',
    'audio/mp4' || 'audio/x-m4a' || 'audio/aac' => 'm4a',
    _ => 'jpg',
  };
}

/// The type of a picked file, from its name. Null when it isn't a PDF or a
/// photo the Space accepts.
String? mimeOfName(String name) {
  final dot = name.lastIndexOf('.');
  final ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  return switch (ext) {
    'pdf' => 'application/pdf',
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'heic' => 'image/heic',
    'm4a' => 'audio/mp4',
    _ => null,
  };
}
