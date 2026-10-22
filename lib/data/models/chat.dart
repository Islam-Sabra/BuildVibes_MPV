import 'package:flutter/foundation.dart';

import 'library.dart';
import 'work_item.dart';

/// What a message carries. Work item cards are posted by the server.
enum ChatKind {
  text,
  photo,
  file,
  voice,
  workItem,

  /// A week report shared in the chat (slice 9, share_week_report).
  report;

  static ChatKind fromJson(Object? value) => switch (value) {
    'report' => ChatKind.report,
    'photo' => ChatKind.photo,
    'file' => ChatKind.file,
    'voice' => ChatKind.voice,
    'work_item' => ChatKind.workItem,
    _ => ChatKind.text,
  };
}

String? _name(Object? row) {
  if (row is! Map) return null;
  final name = '${row['first_name'] ?? ''} ${row['last_name'] ?? ''}'.trim();
  return name.isEmpty ? null : name;
}

DateTime? _time(Object? value) =>
    value == null ? null : DateTime.parse(value as String);

/// A row of space_threads(): Everyone ([teamId] null) or a Team, with its
/// last message and what you haven't read.
@immutable
class ChatThread {
  const ChatThread({
    required this.id,
    this.teamId,
    this.teamName,
    this.lastMessageId,
    this.lastKind,
    this.lastBody,
    this.lastAuthorId,
    this.lastAt,
    this.lastDeleted = false,
    this.unread = 0,
  });

  factory ChatThread.fromJson(Map<String, dynamic> json) => ChatThread(
    id: json['thread_id'] as String,
    teamId: json['team_id'] as String?,
    teamName: json['team_name'] as String?,
    lastMessageId: json['last_message_id'] as String?,
    lastKind: json['last_message_id'] == null
        ? null
        : ChatKind.fromJson(json['last_kind']),
    lastBody: json['last_body'] as String?,
    lastAuthorId: json['last_author_id'] as String?,
    lastAt: _time(json['last_at']),
    lastDeleted: json['last_deleted'] as bool? ?? false,
    unread: (json['unread'] as num?)?.toInt() ?? 0,
  );

  final String id;
  final String? teamId;
  final String? teamName;

  final String? lastMessageId;

  /// Null when the thread has no messages yet.
  final ChatKind? lastKind;
  final String? lastBody;
  final String? lastAuthorId;
  final DateTime? lastAt;
  final bool lastDeleted;
  final int unread;

  bool get isEveryone => teamId == null;
}

/// A photo, PDF or voice note uploaded with a message.
@immutable
class ChatAttachment {
  const ChatAttachment({
    required this.path,
    required this.mime,
    this.bytes,
    this.durationMs,
  });

  factory ChatAttachment.fromJson(Map<String, dynamic> json) => ChatAttachment(
    path: json['storage_path'] as String,
    mime: json['mime'] as String,
    bytes: (json['bytes'] as num?)?.toInt(),
    durationMs: (json['duration_ms'] as num?)?.toInt(),
  );

  final String path;
  final String mime;
  final int? bytes;
  final int? durationMs;

  bool get isImage => mime.startsWith('image/');
}

/// The message a reply quotes.
@immutable
class ChatReply {
  const ChatReply({
    required this.id,
    required this.kind,
    this.authorName,
    this.body,
    this.deleted = false,
  });

  factory ChatReply.fromJson(Map<String, dynamic> json) => ChatReply(
    id: json['id'] as String,
    kind: ChatKind.fromJson(json['kind']),
    authorName: _name(json['author']),
    body: json['body'] as String?,
    deleted: json['deleted_at'] != null,
  );

  final String id;
  final ChatKind kind;
  final String? authorName;
  final String? body;
  final bool deleted;
}

/// One message in a thread. A deleted one keeps its author and time, but
/// no text.
@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.threadId,
    required this.kind,
    required this.createdAt,
    this.authorId,
    this.authorName,
    this.body,
    this.reply,
    this.workItemId,
    this.eventKind,
    this.deletedAt,
    this.attachments = const [],
    this.file,
    this.reportWeek,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final parent = json['parent'];
    final event = json['event'];
    // A PDF posted here went to the Library too ("docs"); a shared Library
    // file is linked ("shared").
    final docs = json['docs'];
    final shared = json['shared'];
    final file = shared is Map<String, dynamic>
        ? LibraryFile.fromJson(shared)
        : docs is List && docs.isNotEmpty
        ? LibraryFile.fromJson(docs.first as Map<String, dynamic>)
        : null;
    return ChatMessage(
      id: json['id'] as String,
      threadId: json['thread_id'] as String,
      kind: ChatKind.fromJson(json['kind']),
      createdAt: DateTime.parse(json['created_at'] as String),
      authorId: json['author_id'] as String?,
      authorName: _name(json['author']),
      body: json['body'] as String?,
      reply: parent is Map<String, dynamic> ? ChatReply.fromJson(parent) : null,
      workItemId: json['work_item_id'] as String?,
      eventKind: event is Map ? WorkEventKind.fromJson(event['kind']) : null,
      deletedAt: _time(json['deleted_at']),
      attachments: [
        for (final a in (json['attachments'] as List?) ?? const [])
          ChatAttachment.fromJson(a as Map<String, dynamic>),
      ],
      file: file,
      reportWeek: json['report_week'] == null
          ? null
          : DateTime.parse(json['report_week'] as String),
    );
  }

  final String id;
  final String threadId;
  final ChatKind kind;
  final DateTime createdAt;

  /// Null when the account was deleted.
  final String? authorId;
  final String? authorName;
  final String? body;
  final ChatReply? reply;

  /// Cards: the item and the step that posted it.
  final String? workItemId;
  final WorkEventKind? eventKind;
  final DateTime? deletedAt;

  /// Photos (and the PDF) uploaded with it, in order.
  final List<ChatAttachment> attachments;

  /// The Library file it shows: a PDF posted here, or a file shared from
  /// the Library. Opens in F1.
  final LibraryFile? file;

  /// A shared week report: the first day of its week.
  final DateTime? reportWeek;

  bool get deleted => deletedAt != null;

  List<ChatAttachment> get photos => [
    for (final a in attachments)
      if (a.isImage) a,
  ];
}
