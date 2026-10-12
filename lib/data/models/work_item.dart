import 'package:flutter/foundation.dart';

/// Open → Done (the owner signs) → Checked. Sent back means Open again.
enum WorkStatus {
  open,
  done,
  checked;

  static WorkStatus fromJson(Object? value) => switch (value) {
    'done' => WorkStatus.done,
    'checked' => WorkStatus.checked,
    _ => WorkStatus.open,
  };
}

/// A work item as lists show it (S20), with what the item page needs
/// first. Rules (who signs, who checks) are decided on the server.
@immutable
class WorkItem {
  const WorkItem({
    required this.id,
    required this.spaceId,
    required this.ref,
    required this.title,
    required this.status,
    required this.createdAt,
    this.ownerId,
    this.ownerName,
    this.createdById,
    this.createdByName,
    this.teamId,
    this.teamName,
    this.place,
    this.due,
    this.doneAt,
    this.checkedById,
    this.checkedByName,
    this.checkedAt,
    this.shown = false,
    this.doneNote,
    this.photoPaths = const [],
  });

  factory WorkItem.fromJson(Map<String, dynamic> json) {
    String? nameOf(Object? row) {
      if (row is! Map<String, dynamic>) return null;
      final name = '${row['first_name'] ?? ''} ${row['last_name'] ?? ''}'
          .trim();
      return name.isEmpty ? null : name;
    }

    DateTime? time(Object? value) =>
        value == null ? null : DateTime.parse(value as String);

    // The note of the latest Done sign-off.
    final events = [
      for (final e in json['events'] as List? ?? const [])
        e as Map<String, dynamic>,
    ]..sort((a, b) => (a['created_at'] as String).compareTo(b['created_at']));
    final lastDone = events.lastWhere(
      (e) => e['kind'] == 'done',
      orElse: () => const {},
    );
    // Photos, newest sign-off first.
    final evidence = [
      for (final e in json['evidence'] as List? ?? const [])
        e as Map<String, dynamic>,
    ]..sort((a, b) => (b['created_at'] as String).compareTo(a['created_at']));
    final team = json['team'] as Map<String, dynamic>?;

    return WorkItem(
      id: json['id'] as String,
      spaceId: json['space_id'] as String,
      ref: json['ref'] as String,
      title: json['title'] as String,
      status: WorkStatus.fromJson(json['status']),
      createdAt: DateTime.parse(json['created_at'] as String),
      ownerId: json['owner_id'] as String?,
      ownerName: nameOf(json['owner']),
      createdById: json['created_by'] as String?,
      createdByName: nameOf(json['creator']),
      teamId: json['team_id'] as String?,
      teamName: team?['name'] as String?,
      place: json['place_text'] as String?,
      due: json['due_date'] == null
          ? null
          : DateTime.parse(json['due_date'] as String),
      doneAt: time(json['done_at']),
      checkedById: json['checked_by'] as String?,
      checkedByName: nameOf(json['checker']),
      checkedAt: time(json['checked_at']),
      shown: json['shown'] as bool? ?? false,
      doneNote: lastDone['note'] as String?,
      photoPaths: [for (final e in evidence) e['storage_path'] as String],
    );
  }

  final String id;
  final String spaceId;

  /// "KCT-021": Latin, always left to right.
  final String ref;
  final String title;
  final WorkStatus status;
  final DateTime createdAt;
  final String? ownerId;
  final String? ownerName;
  final String? createdById;
  final String? createdByName;
  final String? teamId;
  final String? teamName;

  /// Where on site, as typed ("Level 2 · Grid C7").
  final String? place;
  final DateTime? due;
  final DateTime? doneAt;
  final String? checkedById;
  final String? checkedByName;
  final DateTime? checkedAt;
  final bool shown;
  final String? doneNote;

  /// Storage paths in the private bucket, newest first.
  final List<String> photoPaths;

  bool overdue(DateTime today) {
    final d = due;
    if (d == null || status != WorkStatus.open) return false;
    return d.isBefore(DateTime(today.year, today.month, today.day));
  }
}

/// What needs the signed-in person in a Space, from needs_you(): Open items
/// they own, Done items they may check, and items whose owner left. The
/// server decides all three.
@immutable
class WorkNeeds {
  const WorkNeeds({
    this.toSign = const {},
    this.toCheck = const {},
    this.toReassign = const {},
  });

  final Set<String> toSign;
  final Set<String> toCheck;

  /// Open items you raised whose owner left the Space ("Owner left ·
  /// reassign").
  final Set<String> toReassign;

  bool needs(String itemId) =>
      toSign.contains(itemId) ||
      toCheck.contains(itemId) ||
      toReassign.contains(itemId);
}

enum WorkEventKind {
  raised,
  done,
  checked,
  sentBack,
  comment,
  reassigned;

  static WorkEventKind fromJson(Object? value) => switch (value) {
    'done' => WorkEventKind.done,
    'checked' => WorkEventKind.checked,
    'sent_back' => WorkEventKind.sentBack,
    'comment' => WorkEventKind.comment,
    'reassigned' => WorkEventKind.reassigned,
    _ => WorkEventKind.raised,
  };
}

/// Why an item was sent back (W5). One single choice.
enum SendBackReason {
  photoMissing('photo_missing'),
  notAsDrawing('not_as_drawing'),
  notFinished('not_finished'),
  other('other');

  const SendBackReason(this.json);
  final String json;

  static SendBackReason? fromJson(Object? value) =>
      values.where((r) => r.json == value).firstOrNull;
}

/// A photo on a sign-off, in the private bucket.
@immutable
class WorkPhoto {
  const WorkPhoto({required this.path, this.takenAt, this.place});

  final String path;
  final DateTime? takenAt;
  final String? place;
}

/// One line of the record (append-only on the server).
@immutable
class WorkEvent {
  const WorkEvent({
    required this.id,
    required this.kind,
    required this.at,
    this.actorId,
    this.actorName,
    this.note,
    this.reason,
    this.photos = const [],
  });

  final String id;
  final WorkEventKind kind;
  final DateTime at;
  final String? actorId;
  final String? actorName;
  final String? note;
  final SendBackReason? reason;
  final List<WorkPhoto> photos;
}

/// The item page (W3): the item and its whole record, oldest first.
@immutable
class WorkItemDetail {
  const WorkItemDetail({required this.item, required this.events});

  final WorkItem item;
  final List<WorkEvent> events;

  WorkEvent? last(WorkEventKind kind) =>
      events.where((e) => e.kind == kind).lastOrNull;

  /// Photos taken when the item was raised.
  List<WorkPhoto> get raisedPhotos => last(WorkEventKind.raised)?.photos ?? [];

  /// The latest Done sign-off (its note and photos are the evidence).
  WorkEvent? get lastDone => last(WorkEventKind.done);

  /// The latest event that changed the status, when it was a send-back.
  WorkEvent? get sentBack {
    final steps = [
      for (final e in events)
        if (e.kind != WorkEventKind.comment &&
            e.kind != WorkEventKind.reassigned)
          e,
    ];
    final last = steps.lastOrNull;
    return last?.kind == WorkEventKind.sentBack ? last : null;
  }

  List<WorkEvent> get comments => [
    for (final e in events)
      if (e.kind == WorkEventKind.comment) e,
  ];
}
