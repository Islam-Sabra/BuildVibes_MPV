import 'package:flutter/foundation.dart';

import '../repositories/work_repository.dart' show newUuid;
import 'post_page.dart';

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
  /// What the phone records a voice note as.
  static const voiceMime = 'audio/mp4';

  const NoteRecording({
    this.path,
    this.local,
    this.mime = voiceMime,
    this.bytes,
    this.durationMs = 0,
  });

  factory NoteRecording.fromJson(Map<String, dynamic> json) => NoteRecording(
    path: json['storage_path'] as String? ?? json['path'] as String?,
    local: json['local'] as String?,
    mime: json['mime'] as String? ?? voiceMime,
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

/// A photo on a note (F106): in `notebook-files` once sent ([path]), on
/// the phone until then ([local]). At most [Note.photosMax]
/// (set_note_files).
@immutable
class NotePhoto {
  const NotePhoto({
    this.path,
    this.local,
    this.mime = 'image/jpeg',
    this.bytes,
  });

  factory NotePhoto.fromJson(Map<String, dynamic> json) => NotePhoto(
    path: json['storage_path'] as String? ?? json['path'] as String?,
    local: json['local'] as String?,
    mime: json['mime'] as String? ?? 'image/jpeg',
    bytes: json['bytes'] as int?,
  );

  final String? path;
  final String? local;
  final String mime;
  final int? bytes;

  NotePhoto uploaded(String path) =>
      NotePhoto(path: path, local: local, mime: mime, bytes: bytes);

  /// As set_note_files takes it.
  Map<String, dynamic> toServer() => {
    'path': path,
    'mime': mime,
    'bytes': ?bytes,
  };

  Map<String, dynamic> toJson() => {
    'path': path,
    'local': local,
    'mime': mime,
    'bytes': bytes,
  };
}

/// A PDF on a note (F107, migration 44): in `notebook-files` once sent
/// ([path]), on the phone until then ([local]). At most [Note.filesMax].
@immutable
class NoteFile {
  const NoteFile({
    this.path,
    this.local,
    required this.name,
    this.mime = 'application/pdf',
    this.bytes,
  });

  factory NoteFile.fromJson(Map<String, dynamic> json) => NoteFile(
    path: json['storage_path'] as String? ?? json['path'] as String?,
    local: json['local'] as String?,
    name: json['name'] as String? ?? '',
    mime: json['mime'] as String? ?? 'application/pdf',
    bytes: (json['bytes'] as num?)?.toInt(),
  );

  final String? path;
  final String? local;
  final String name;
  final String mime;
  final int? bytes;

  NoteFile uploaded(String path) =>
      NoteFile(path: path, local: local, name: name, mime: mime, bytes: bytes);

  /// As set_note_files takes it.
  Map<String, dynamic> toServer() => {
    'path': path,
    'mime': mime,
    'name': name,
    'bytes': ?bytes,
  };

  Map<String, dynamic> toJson() => {
    'path': path,
    'local': local,
    'name': name,
    'mime': mime,
    'bytes': bytes,
  };
}

/// Where a note was written (F107 NBX4): typed ([text]), the phone's GPS
/// ([lat], [lng], within [accuracyM] metres), or both. Private to the
/// note: Put in a Space carries only the words unless the person says so.
@immutable
class NoteLocation {
  const NoteLocation({this.text, this.lat, this.lng, this.accuracyM});

  factory NoteLocation.fromJson(Map<String, dynamic> json) => NoteLocation(
    text: json['text'] as String?,
    lat: (json['lat'] as num?)?.toDouble(),
    lng: (json['lng'] as num?)?.toDouble(),
    accuracyM: (json['accuracy_m'] as num?)?.toDouble(),
  );

  /// From a `notes` row, or null when it has none.
  static NoteLocation? fromRow(Map<String, dynamic> json) {
    final l = NoteLocation(
      text: json['location_text'] as String?,
      lat: _number(json['location_lat']),
      lng: _number(json['location_lng']),
      accuracyM: _number(json['location_accuracy_m']),
    );
    return l.isEmpty ? null : l;
  }

  /// PostgREST sends a numeric as a number or a string.
  static double? _number(Object? v) => switch (v) {
    num n => n.toDouble(),
    String t => double.tryParse(t),
    _ => null,
  };

  /// The typed place, at most (save_note).
  static const textMax = 120;

  final String? text;
  final double? lat;
  final double? lng;
  final double? accuracyM;

  bool get hasGps => lat != null && lng != null;
  bool get hasText => (text ?? '').trim().isNotEmpty;
  bool get isEmpty => !hasGps && !hasText;

  /// The same place, typed again.
  NoteLocation withText(String? typed) => NoteLocation(
    text: (typed ?? '').trim().isEmpty ? null : typed!.trim(),
    lat: lat,
    lng: lng,
    accuracyM: accuracyM,
  );

  NoteLocation withoutGps() => NoteLocation(text: text);

  /// As save_note takes it, and as the phone keeps it.
  Map<String, dynamic> toJson() => {
    if (hasText) 'text': text!.trim(),
    if (hasGps) ...{'lat': lat, 'lng': lng, 'accuracy_m': ?accuracyM},
  };

  @override
  bool operator ==(Object other) =>
      other is NoteLocation &&
      other.text == text &&
      other.lat == lat &&
      other.lng == lng &&
      other.accuracyM == accuracyM;

  @override
  int get hashCode => Object.hash(text, lat, lng, accuracyM);
}

/// An entry's lines as plain text (review 100 Part 6, as the server's
/// note_words writes them): an open to-do, a ticked one, a bullet. J2:
/// characters every phone's font has (no ☐ or ☑).
const noteTodoOpenMark = '[ ]';
const noteTodoDoneMark = '[x]';
const noteBulletMark = '•';

/// Where an entry was shared (review 100 Part 6, note_shares).
enum NoteShareTarget {
  feed,
  space,
  message;

  static NoteShareTarget fromJson(Object? v) => switch (v) {
    'space' => space,
    'message' => message,
    _ => feed,
  };

  String get json => name;
}

/// One share of an entry: where to (a Space's or a person's name as it
/// was) and when. The entry stays; this is its mark.
@immutable
class NoteShare {
  const NoteShare({required this.target, required this.at, this.name});

  factory NoteShare.fromJson(Map<String, dynamic> json) => NoteShare(
    target: NoteShareTarget.fromJson(json['target']),
    name: json['target_name'] as String?,
    at: DateTime.parse(json['created_at'] as String).toLocal(),
  );

  final NoteShareTarget target;
  final String? name;
  final DateTime at;

  Map<String, dynamic> toJson() => {
    'target': target.json,
    'target_name': name,
    'created_at': at.toUtc().toIso8601String(),
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
    this.photos = const [],
    this.waiting = false,
    this.title = '',
    this.blocks,
    this.location,
    this.files = const [],
    this.pageId,
    this.deletedAt,
    this.archivedAt,
    this.version = 1,
    this.shares = const [],
    this.dayPosition,
    this.collapsed = false,
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
    final blocks = json['blocks'] as List?;
    final kept = json['location'] as Map<String, dynamic>?;
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
      recording: blocks != null
          ? null
          : voice == null
          ? (json['recording'] == null
                ? null
                : NoteRecording.fromJson(
                    json['recording'] as Map<String, dynamic>,
                  ))
          : NoteRecording.fromJson(voice),
      photos: [
        for (final f in files)
          if (f['kind'] == 'photo') NotePhoto.fromJson(f),
        if (files.isEmpty)
          for (final p in json['photos'] as List? ?? const [])
            NotePhoto.fromJson(p as Map<String, dynamic>),
      ],
      waiting: json['waiting'] as bool? ?? false,
      title: json['title'] as String? ?? '',
      blocks: blocks == null
          ? null
          : [
              for (final b in blocks)
                PageBlock.fromJson(b as Map<String, dynamic>),
            ],
      location: kept != null
          ? NoteLocation.fromJson(kept)
          : NoteLocation.fromRow(json),
      files: [
        for (final f in files)
          if (f['kind'] == 'file') NoteFile.fromJson(f),
        if (files.isEmpty)
          for (final f in json['files'] as List? ?? const [])
            NoteFile.fromJson(f as Map<String, dynamic>),
      ],
      pageId: json['page_id'] as String?,
      deletedAt: _time(json['deleted_at']),
      archivedAt: _time(json['archived_at']),
      version: json['version'] as int? ?? 1,
      dayPosition: json['day_position'] as int?,
      collapsed: json['collapsed'] as bool? ?? false,
      shares: [
        for (final s in json['note_shares'] as List? ?? const [])
          NoteShare.fromJson(s as Map<String, dynamic>),
      ]..sort((a, b) => a.at.compareTo(b.at)),
    );
  }

  static DateTime? _time(Object? value) =>
      value == null ? null : DateTime.parse(value as String).toLocal();

  /// The server's limits (save_note).
  static const bodyMax = 5000;
  static const pointsMax = 50;
  static const pointMax = 300;
  static const photosMax = 10;

  /// F107 (migration 44): a page's blocks, a block's words, the title and
  /// the PDFs.
  static const blocksMax = 200;
  static const lineMax = PageLine.max;
  static const titleMax = 200;
  static const filesMax = 10;

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

  /// A note's, a checklist's or a to-do's photos (F106).
  final List<NotePhoto> photos;

  /// Still on the phone: not yet taken by the server.
  final bool waiting;

  /// F107 (review 92): a page note's bold first line, its blocks (null: an
  /// older note, read through [pageBlocks]), where it was written and its
  /// PDFs. A page's [body] is its words as plain text ([pageDigest]), for
  /// My calendar and the reminders.
  final String title;
  final List<PageBlock>? blocks;
  final NoteLocation? location;
  final List<NoteFile> files;

  /// The page it is in (review 99A, migration 47). Null only on an entry
  /// kept on the phone by an older version: it goes into the latest page.
  final String? pageId;

  /// In Deleted items since (99B B3), or archived since (review 100 Part
  /// 3b): either way it leaves every list, count, calendar and reminder.
  final DateTime? deletedAt;
  final DateTime? archivedAt;

  /// Its place in its day, arranged by hand (review 102 N3, migration 49):
  /// 1 at the top newest first; null keeps the time order.
  final int? dayPosition;

  /// Folded in its page (review 106 T2, migration 50): its head and
  /// "3 lines hidden" only. The same on every phone.
  final bool collapsed;

  /// The server's version of it (migration 48): an edit says which one it
  /// started from, so an older one is refused.
  final int version;

  /// Where it was shared, oldest first (review 100 Part 6).
  final List<NoteShare> shares;

  /// In the page's list: not deleted, not archived.
  bool get shown => deletedAt == null && archivedAt == null;

  bool get done => doneAt != null;

  /// Written as a page (F107); an older note opens as one ([pageBlocks]).
  bool get isPage => blocks != null;

  /// Words a Space post can take: a voice note has none.
  bool get canPut =>
      kind != NoteKind.voice &&
      (body.trim().isNotEmpty || title.trim().isNotEmpty);

  /// The title an older note opens with: a note's first line, a
  /// checklist's title; a to-do and a voice note have none.
  String get pageTitle {
    if (isPage) return title;
    final words = body.trim();
    return switch (kind) {
      NoteKind.text => words.split('\n').first.trim(),
      NoteKind.checklist => words,
      _ => '',
    };
  }

  /// The note as blocks: its own, or an older one's words made into them
  /// (migrated on read, review 92): a note's other lines as text, a
  /// checklist's points and a to-do as to-dos, a voice note's recording
  /// as a voice block. Saving writes them.
  List<PageBlock> get pageBlocks {
    final own = blocks;
    if (own != null) return own;
    final words = body.trim();
    return switch (kind) {
      NoteKind.text => [
        for (final line in words.split('\n').skip(1))
          if (line.trim().isNotEmpty) PageText(newUuid(), line.trim()),
      ],
      NoteKind.checklist => [
        for (final p in points) PageTodo(newUuid(), p.text, done: p.done),
      ],
      NoteKind.todo => [PageTodo(newUuid(), words, done: done)],
      NoteKind.voice => [
        if (recording case final r?)
          PageVoice(
            newUuid(),
            path: r.path,
            local: r.local,
            durationMs: r.durationMs,
          ),
      ],
    };
  }

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
    List<NotePhoto>? photos,
    bool? waiting,
    String? title,
    List<PageBlock>? blocks,
    NoteLocation? Function()? location,
    List<NoteFile>? files,
    String? pageId,
    DateTime? Function()? deletedAt,
    DateTime? Function()? archivedAt,
    int? version,
    List<NoteShare>? shares,
    int? Function()? dayPosition,
    bool? collapsed,
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
    photos: photos ?? this.photos,
    waiting: waiting ?? this.waiting,
    title: title ?? this.title,
    blocks: blocks ?? this.blocks,
    location: location == null ? this.location : location(),
    files: files ?? this.files,
    pageId: pageId ?? this.pageId,
    deletedAt: deletedAt == null ? this.deletedAt : deletedAt(),
    archivedAt: archivedAt == null ? this.archivedAt : archivedAt(),
    version: version ?? this.version,
    shares: shares ?? this.shares,
    dayPosition: dayPosition == null ? this.dayPosition : dayPosition(),
    collapsed: collapsed ?? this.collapsed,
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
    'photos': [for (final p in photos) p.toJson()],
    'waiting': waiting,
    'title': title,
    if (blocks != null) 'blocks': [for (final b in blocks!) b.toJson()],
    'location': location?.toJson(),
    'files': [for (final f in files) f.toJson()],
    'page_id': pageId,
    'deleted_at': deletedAt?.toUtc().toIso8601String(),
    'archived_at': archivedAt?.toUtc().toIso8601String(),
    'version': version,
    'note_shares': [for (final s in shares) s.toJson()],
    'day_position': dayPosition,
    'collapsed': collapsed,
  };

  /// Its to-dos not yet ticked: a to-do note's one, a page's to-do lines
  /// (inside toggles too).
  int get openTodos {
    if (kind == NoteKind.todo) return done ? 0 : 1;
    int open(List<PageBlock> blocks) => blocks.fold(
      0,
      (n, b) => switch (b) {
        PageTodo(:final done) => n + (done ? 0 : 1),
        PageToggle(:final children) => n + open(children),
        _ => n,
      },
    );
    return open(blocks ?? const []);
  }
}

/// A page's words as plain text, a line a block, the title first: a
/// note's body (My calendar, reminders, Put in a Space), at most
/// [Note.bodyMax].
String pageDigest(String title, List<PageBlock> blocks) {
  final lines = <String>[
    if (title.trim().isNotEmpty) title.trim(),
    for (final b in blocks) ...blockWords(b),
  ];
  final text = lines.join('\n');
  return text.length <= Note.bodyMax ? text : text.substring(0, Note.bodyMax);
}

/// The words a block holds, a line each: a table's rows, a toggle's own
/// and its lines'.
List<String> blockWords(PageBlock b) => switch (b) {
  PageText(:final text) ||
  PageHeading(:final text) ||
  PageLine(:final text) => [if (text.trim().isNotEmpty) text.trim()],
  PageToggle(:final text, :final children) => [
    if (text.trim().isNotEmpty) text.trim(),
    for (final c in children) ...blockWords(c),
  ],
  PageTable(:final rows) => [
    for (final row in rows)
      if (row.any((c) => c.trim().isNotEmpty))
        row.map((c) => c.trim()).join(' · '),
  ],
  _ => const [],
};

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
