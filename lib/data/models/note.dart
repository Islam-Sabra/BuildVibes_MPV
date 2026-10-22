import 'package:flutter/foundation.dart';

/// The four kinds of note in My notebook (migration 21).
enum NoteKind {
  text('text'),
  checklist('checklist'),
  todo('todo'),
  voice('voice');

  const NoteKind(this.json);

  final String json;

  static NoteKind fromJson(Object? value) => switch (value) {
    'checklist' => checklist,
    'todo' => todo,
    'voice' => voice,
    _ => text,
  };
}

/// One point of a checklist note.
@immutable
class NotePoint {
  const NotePoint(this.text, {this.done = false});

  factory NotePoint.fromJson(Map<String, dynamic> json) => NotePoint(
    json['text'] as String? ?? '',
    done: json['done'] as bool? ?? false,
  );

  final String text;
  final bool done;

  NotePoint toggled() => NotePoint(text, done: !done);

  Map<String, dynamic> toJson() => {'text': text, 'done': done};
}

/// A voice note's one recording: in `notebook-files` once sent
/// ([path]), on the phone until then ([local]).
@immutable
class NoteRecording {
  const NoteRecording({
    this.path,
    this.local,
    this.mime = 'audio/mp4',
    this.bytes,
    this.durationMs = 0,
  });

  factory NoteRecording.fromJson(Map<String, dynamic> json) => NoteRecording(
    path: json['storage_path'] as String? ?? json['path'] as String?,
    local: json['local'] as String?,
    mime: json['mime'] as String? ?? 'audio/mp4',
    bytes: json['bytes'] as int?,
    durationMs: json['duration_ms'] as int? ?? 0,
  );

  final String? path;
  final String? local;
  final String mime;
  final int? bytes;
  final int durationMs;

  Duration get duration => Duration(milliseconds: durationMs);

  NoteRecording uploaded(String path) => NoteRecording(
    path: path,
    local: local,
    mime: mime,
    bytes: bytes,
    durationMs: durationMs,
  );

  /// As save_note takes it.
  Map<String, dynamic> toServer() => {
    'path': path,
    'mime': mime,
    'bytes': ?bytes,
    'duration_ms': durationMs,
  };

  Map<String, dynamic> toJson() => {
    'path': path,
    'local': local,
    'mime': mime,
    'bytes': bytes,
    'duration_ms': durationMs,
  };
}

/// A note in My notebook (migration 21): only its owner ever reads it.
/// The app chose its [id], so saving it again is the same note.
@immutable
class Note {
  const Note({
    required this.id,
    required this.kind,
    required this.createdAt,
    this.body = '',
    this.points = const [],
    this.dueAt,
    this.doneAt,
    this.pinned = false,
    this.remindAt,
    this.putInPostId,
    this.recording,
    this.waiting = false,
  });

  /// A row of `notes`, with its `note_files` embedded.
  factory Note.fromJson(Map<String, dynamic> json) {
    final files =
        [
          for (final f in json['note_files'] as List? ?? const [])
            f as Map<String, dynamic>,
        ]..sort(
          (a, b) => (a['sort'] as int? ?? 0).compareTo(b['sort'] as int? ?? 0),
        );
    final voice = files.where((f) => f['kind'] == 'voice').firstOrNull;
    return Note(
      id: json['id'] as String,
      kind: NoteKind.fromJson(json['kind']),
      body: json['body'] as String? ?? '',
      points: [
        for (final p in json['points'] as List? ?? const [])
          NotePoint.fromJson(p as Map<String, dynamic>),
      ],
      dueAt: _time(json['due_at']),
      doneAt: _time(json['done_at']),
      pinned: json['pinned'] as bool? ?? false,
      remindAt: _time(json['remind_at']),
      putInPostId: json['put_in_post_id'] as String?,
      createdAt: _time(json['created_at'])!,
      recording: voice == null
          ? (json['recording'] == null
                ? null
                : NoteRecording.fromJson(
                    json['recording'] as Map<String, dynamic>,
                  ))
          : NoteRecording.fromJson(voice),
      waiting: json['waiting'] as bool? ?? false,
    );
  }

  static DateTime? _time(Object? value) =>
      value == null ? null : DateTime.parse(value as String).toLocal();

  /// The server's limits (save_note).
  static const bodyMax = 5000;
  static const pointsMax = 50;
  static const pointMax = 300;

  final String id;
  final NoteKind kind;

  /// A note's words, a checklist's title, a to-do's words.
  final String body;
  final List<NotePoint> points;

  /// A to-do's time, and when it was done.
  final DateTime? dueAt;
  final DateTime? doneAt;
  final bool pinned;

  /// Remind me (slice 10): when this phone reminds its owner, kept on the
  /// server so a reinstall or a new phone sets it again.
  final DateTime? remindAt;

  /// The post it was put in (mark_note_put); the note stays here.
  final String? putInPostId;
  final DateTime createdAt;
  final NoteRecording? recording;

  /// Still on the phone: not yet taken by the server.
  final bool waiting;

  bool get done => doneAt != null;

  /// Words a Space post can take: a voice note has none.
  bool get canPut => kind != NoteKind.voice && body.trim().isNotEmpty;

  Note copyWith({
    NoteKind? kind,
    String? body,
    List<NotePoint>? points,
    DateTime? Function()? dueAt,
    DateTime? Function()? doneAt,
    bool? pinned,
    DateTime? Function()? remindAt,
    String? putInPostId,
    NoteRecording? recording,
    bool? waiting,
  }) => Note(
    id: id,
    kind: kind ?? this.kind,
    createdAt: createdAt,
    body: body ?? this.body,
    points: points ?? this.points,
    dueAt: dueAt == null ? this.dueAt : dueAt(),
    doneAt: doneAt == null ? this.doneAt : doneAt(),
    pinned: pinned ?? this.pinned,
    remindAt: remindAt == null ? this.remindAt : remindAt(),
    putInPostId: putInPostId ?? this.putInPostId,
    recording: recording ?? this.recording,
    waiting: waiting ?? this.waiting,
  );

  /// As this phone keeps it while it waits to be sent.
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.json,
    'body': body,
    'points': [for (final p in points) p.toJson()],
    'due_at': dueAt?.toUtc().toIso8601String(),
    'done_at': doneAt?.toUtc().toIso8601String(),
    'pinned': pinned,
    'remind_at': remindAt?.toUtc().toIso8601String(),
    'put_in_post_id': putInPostId,
    'created_at': createdAt.toUtc().toIso8601String(),
    'recording': recording?.toJson(),
    'waiting': waiting,
  };
}

/// What a row of My calendar is (my_calendar).
enum CalendarKind {
  workItem('work_item'),
  checklist('checklist'),
  activity('activity'),
  todo('todo');

  const CalendarKind(this.json);

  final String json;

  static CalendarKind? fromJson(Object? value) =>
      values.where((k) => k.json == value).firstOrNull;
}

/// A row of My calendar: something from a Space I'm in, or a to-do of
/// mine. The app gives it its colour (the Space's).
@immutable
class CalendarRow {
  const CalendarRow({
    required this.kind,
    required this.title,
    required this.day,
    this.spaceId,
    this.spaceName,
    this.teamId,
    this.postId,
    this.noteId,
    this.place,
    this.startsAt,
    this.endsAt,
    this.status,
    this.needsMe = false,
  });

  /// A my_calendar row; null for a kind this version doesn't know.
  static CalendarRow? fromJson(Map<String, dynamic> json) {
    final kind = CalendarKind.fromJson(json['kind']);
    if (kind == null) return null;
    final starts = _time(json['starts_at']);
    final date = json['day'] == null
        ? null
        : DateTime.parse(json['day'] as String);
    // A work item or a checklist has its due date; an activity and a
    // to-do only their time, on the phone's own day.
    final day = date ?? starts;
    if (day == null) return null;
    return CalendarRow(
      kind: kind,
      title: json['title'] as String? ?? '',
      day: DateTime(day.year, day.month, day.day),
      spaceId: json['space_id'] as String?,
      spaceName: json['space_name'] as String?,
      teamId: json['team_id'] as String?,
      postId: json['post_id'] as String?,
      noteId: json['note_id'] as String?,
      place: json['place'] as String?,
      startsAt: starts,
      endsAt: _time(json['ends_at']),
      status: json['status'] as String?,
      needsMe: json['needs_me'] as bool? ?? false,
    );
  }

  static DateTime? _time(Object? value) =>
      value == null ? null : DateTime.parse(value as String).toLocal();

  final CalendarKind kind;
  final String title;

  /// The phone's day it falls on.
  final DateTime day;
  final String? spaceId;
  final String? spaceName;
  final String? teamId;
  final String? postId;
  final String? noteId;
  final String? place;

  /// Its time; null: all day (a due date with no time).
  final DateTime? startsAt;
  final DateTime? endsAt;

  /// A work item's 'open' or 'done'; a to-do's 'open' or 'done'.
  final String? status;
  final bool needsMe;

  bool get done => status == 'done';
}
