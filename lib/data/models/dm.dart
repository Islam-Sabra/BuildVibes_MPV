import 'package:flutter/foundation.dart';

import 'chat.dart' show ChatKind;

DateTime? _time(Object? value) =>
    value == null ? null : DateTime.parse(value as String);

/// The other person of a direct message thread (dm_person). [former]: a
/// purged or hidden account, or one across a block: "Former member".
@immutable
class DmPerson {
  const DmPerson({
    required this.id,
    this.name,
    this.photoPath,
    this.headline,
    this.company,
    this.former = false,
  });

  factory DmPerson.fromJson(Map<String, dynamic> json) => DmPerson(
    id: json['id'] as String,
    name: json['name'] as String?,
    photoPath: json['photo_path'] as String?,
    headline: json['headline'] as String?,
    company: json['company'] as String?,
    former: json['former'] as bool? ?? false,
  );

  final String id;
  final String? name;
  final String? photoPath;

  /// What they do ("Site Engineer"), as they wrote it.
  final String? headline;

  /// A registered company's name, or the words they typed (rule 4: plain
  /// text either way).
  final String? company;
  final bool former;
}

/// The last message of a thread, for its row (dm_preview).
@immutable
class DmPreview {
  const DmPreview({
    required this.fromMe,
    required this.kind,
    required this.at,
    this.text,
    this.deleted = false,
    this.fileName,
    this.durationMs,
  });

  factory DmPreview.fromJson(Map<String, dynamic> json) => DmPreview(
    fromMe: json['from_me'] as bool? ?? false,
    kind: ChatKind.fromJson(json['kind']),
    at: _time(json['at'])!,
    text: json['text'] as String?,
    deleted: json['deleted'] as bool? ?? false,
    fileName: json['file_name'] as String?,
    durationMs: (json['duration_ms'] as num?)?.toInt(),
  );

  final bool fromMe;
  final ChatKind kind;
  final DateTime at;
  final String? text;
  final bool deleted;
  final String? fileName;
  final int? durationMs;
}

/// One row of the Messages list (dm_list_row): the person, the last
/// message, and a dot when something is unread (never a number, rule 3).
@immutable
class DmRow {
  const DmRow({
    required this.threadId,
    required this.person,
    required this.lastMessageAt,
    this.muted = false,
    this.unread = false,
    this.last,
  });

  factory DmRow.fromJson(Map<String, dynamic> json) => DmRow(
    threadId: json['thread'] as String,
    person: DmPerson.fromJson(json['person'] as Map<String, dynamic>),
    lastMessageAt: _time(json['last_message_at'])!,
    muted: json['muted'] as bool? ?? false,
    unread: json['unread'] as bool? ?? false,
    last: json['last'] == null
        ? null
        : DmPreview.fromJson(json['last'] as Map<String, dynamic>),
  );

  final String threadId;
  final DmPerson person;
  final DateTime lastMessageAt;
  final bool muted;
  final bool unread;
  final DmPreview? last;
}

/// The Messages list (my_dm_threads): open threads newest first, and on
/// the first page the newest Message request, if any (never a count).
@immutable
class DmInbox {
  const DmInbox({this.threads = const [], this.newestRequest});

  factory DmInbox.fromJson(Map<String, dynamic> json) {
    final requests = json['requests'] as Map<String, dynamic>?;
    return DmInbox(
      threads: [
        for (final r in json['threads'] as List? ?? const [])
          DmRow.fromJson(r as Map<String, dynamic>),
      ],
      newestRequest: requests?['newest'] == null
          ? null
          : DmRow.fromJson(requests!['newest'] as Map<String, dynamic>),
    );
  }

  final List<DmRow> threads;
  final DmRow? newestRequest;

  bool get anyUnread =>
      threads.any((t) => t.unread && !t.muted) || newestRequest != null;
}

/// Where the caller stands in a thread: open, a Message request (no work
/// link, not answered yet), or declined.
enum DmState {
  open,
  request,
  declined;

  static DmState fromJson(Object? value) => switch (value) {
    'request' => DmState.request,
    'declined' => DmState.declined,
    _ => DmState.open,
  };
}

/// A photo, PDF or voice note on a message, in `dm-files`.
@immutable
class DmFile {
  const DmFile({
    required this.path,
    required this.mime,
    this.name,
    this.bytes,
    this.durationMs,
  });

  factory DmFile.fromJson(Map<String, dynamic> json) => DmFile(
    path: json['path'] as String,
    mime: json['mime'] as String? ?? 'application/octet-stream',
    name: json['name'] as String?,
    bytes: (json['bytes'] as num?)?.toInt(),
    durationMs: (json['duration_ms'] as num?)?.toInt(),
  );

  final String path;
  final String mime;
  final String? name;
  final int? bytes;
  final int? durationMs;

  bool get isPhoto => mime.startsWith('image/');
  bool get isVoice => mime.startsWith('audio/');
}

/// The message a reply answers.
@immutable
class DmReply {
  const DmReply({
    required this.id,
    required this.fromMe,
    this.text,
    this.deleted = false,
  });

  factory DmReply.fromJson(Map<String, dynamic> json) => DmReply(
    id: json['id'] as String,
    fromMe: json['from_me'] as bool? ?? false,
    text: json['text'] as String?,
    deleted: json['deleted'] as bool? ?? false,
  );

  final String id;
  final bool fromMe;
  final String? text;
  final bool deleted;
}

/// One message (dm_thread_page). [tapToShow]: its photos and files come
/// from someone you haven't answered, blurred until tapped (DM6).
@immutable
class DmMessage {
  const DmMessage({
    required this.id,
    required this.fromMe,
    required this.kind,
    required this.createdAt,
    this.body,
    this.deleted = false,
    this.replyTo,
    this.tapToShow = false,
    this.files = const [],
  });

  factory DmMessage.fromJson(Map<String, dynamic> json) => DmMessage(
    id: json['id'] as String,
    fromMe: json['from_me'] as bool? ?? false,
    kind: ChatKind.fromJson(json['kind']),
    createdAt: _time(json['created_at'])!,
    body: json['body'] as String?,
    deleted: json['deleted'] as bool? ?? false,
    replyTo: json['reply_to'] == null
        ? null
        : DmReply.fromJson(json['reply_to'] as Map<String, dynamic>),
    tapToShow: json['tap_to_show'] as bool? ?? false,
    files: [
      for (final f in json['files'] as List? ?? const [])
        DmFile.fromJson(f as Map<String, dynamic>),
    ],
  );

  final String id;
  final bool fromMe;
  final ChatKind kind;
  final DateTime createdAt;
  final String? body;
  final bool deleted;
  final DmReply? replyTo;
  final bool tapToShow;
  final List<DmFile> files;
}

/// A thread as dm_thread_page gives it: the person, my state, the first
/// Space both are in ("Both in …", never a count) and the messages,
/// newest first.
@immutable
class DmThreadPage {
  const DmThreadPage({
    required this.threadId,
    required this.person,
    this.state = DmState.open,
    this.muted = false,
    this.sharedSpaceId,
    this.sharedSpaceName,
    this.messages = const [],
  });

  factory DmThreadPage.fromJson(Map<String, dynamic> json) {
    final space = json['shared_space'] as Map<String, dynamic>?;
    return DmThreadPage(
      threadId: json['thread'] as String,
      person: DmPerson.fromJson(json['person'] as Map<String, dynamic>),
      state: DmState.fromJson(json['state']),
      muted: json['muted'] as bool? ?? false,
      sharedSpaceId: space?['space_id'] as String?,
      sharedSpaceName: space?['name'] as String?,
      messages: [
        for (final m in json['messages'] as List? ?? const [])
          DmMessage.fromJson(m as Map<String, dynamic>),
      ],
    );
  }

  final String threadId;
  final DmPerson person;
  final DmState state;
  final bool muted;
  final String? sharedSpaceId;
  final String? sharedSpaceName;
  final List<DmMessage> messages;
}

/// What start_dm answers: the thread (null when paused), whether it opened
/// as a thread or a request, and the spam guard's warning or pause.
@immutable
class DmStart {
  const DmStart({
    required this.threadId,
    required this.state,
    this.warning = false,
    this.until,
  });

  factory DmStart.fromJson(Map<String, dynamic> json) => DmStart(
    threadId: json['thread'] as String?,
    state: json['state'] as String? ?? 'open',
    warning: json['warning'] as bool? ?? false,
    until: _time(json['until']),
  );

  final String? threadId;

  /// 'open', 'request' or 'paused'.
  final String state;
  final bool warning;

  /// Paused: the day writing to new people opens again.
  final DateTime? until;

  bool get paused => state == 'paused';
}

/// A file on a message being sent, already uploaded to `dm-files`.
@immutable
class DmUpload {
  const DmUpload({required this.path, this.name, this.bytes, this.durationMs});

  final String path;
  final String? name;
  final int? bytes;
  final int? durationMs;

  Map<String, dynamic> toJson() => {
    'path': path,
    'name': ?name,
    'bytes': ?bytes,
    'duration_ms': ?durationMs,
  };
}
