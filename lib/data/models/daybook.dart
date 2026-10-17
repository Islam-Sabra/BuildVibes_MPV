import 'package:flutter/foundation.dart';

import 'work_item.dart';

DateTime? _time(Object? value) =>
    value == null ? null : DateTime.parse(value as String);

/// A date with no time ("2026-10-15"), as the phone's own calendar day.
DateTime? _day(Object? value) {
  if (value == null) return null;
  final d = DateTime.parse(value as String);
  return DateTime(d.year, d.month, d.day);
}

/// The phone's calendar day of [t].
DateTime dayOf(DateTime t) {
  final local = t.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// The latest stamp on a slip (space_post_json "stamp").
enum DaybookStampKind {
  done,
  checked,
  sentBack,
  cancelled,
  newVersion;

  static DaybookStampKind? fromJson(Object? value) => switch (value) {
    'done' => done,
    'checked' => checked,
    'sent_back' => sentBack,
    'cancelled' => cancelled,
    'new_version' => newVersion,
    _ => null,
  };
}

@immutable
class DaybookStamp {
  const DaybookStamp({required this.kind, this.at, this.byName});

  static DaybookStamp? fromJson(Map<String, dynamic>? json) {
    final kind = DaybookStampKind.fromJson(json?['kind']);
    if (json == null || kind == null) return null;
    return DaybookStamp(
      kind: kind,
      at: _time(json['at']),
      byName: json['by_name'] as String?,
    );
  }

  final DaybookStampKind kind;
  final DateTime? at;
  final String? byName;
}

/// The work item behind a post (space_post_json "item").
@immutable
class DaybookItem {
  const DaybookItem({
    required this.status,
    this.ownerId,
    this.ownerName,
    this.ref,
  });

  factory DaybookItem.fromJson(Map<String, dynamic> json) => DaybookItem(
    status: WorkStatus.fromJson(json['status']),
    ownerId: json['owner_id'] as String?,
    ownerName: json['owner_name'] as String?,
    ref: json['ref'] as String?,
  );

  final WorkStatus status;

  /// "KCT-021".
  final String? ref;
  final String? ownerId;

  /// Null across a block or for a hidden account: "Former member".
  final String? ownerName;
}

/// A change of due in the latest edit ("Edited: due moved from Thu to
/// today", or "Edited: due removed" when [to] is null). A time-only change
/// has the same [from] and [to] days.
@immutable
class DaybookDueEdit {
  const DaybookDueEdit({this.from, this.to, this.fromAt, this.toAt});

  final DateTime? from;
  final DateTime? to;
  final DateTime? fromAt;
  final DateTime? toAt;

  /// The edit's `changes.due`, or null when the due didn't change.
  static DaybookDueEdit? fromEdits(Object? edits) {
    final list = edits as List?;
    if (list == null || list.isEmpty) return null;
    // Newest first.
    final changes =
        (list.first as Map<String, dynamic>)['changes']
            as Map<String, dynamic>?;
    final due = changes?['due'] as Map<String, dynamic>?;
    if (due == null) return null;
    return DaybookDueEdit(
      from: _day(due['from']),
      to: _day(due['to']),
      fromAt: _time(due['from_at']),
      toAt: _time(due['to_at']),
    );
  }

  bool get timeOnly =>
      from != null && from == to && (fromAt != null || toAt != null);

  /// The due was taken off.
  bool get removed => from != null && to == null;
}

/// One entry on a Space's daybook (daybook_page, review 45 M1): a post,
/// a sign-off or an update, each at its own time. [id] and [at] are the
/// page's cursor.
@immutable
sealed class DaybookRecord {
  const DaybookRecord();

  /// daybook_page's row: `kind` is 'post', 'sign_off' or 'update'; null
  /// for a kind this version doesn't know.
  static DaybookRecord? fromRow(Map<String, dynamic> row) {
    final entry = row['entry'] as Map<String, dynamic>?;
    if (entry == null) return null;
    return switch (row['kind']) {
      'post' => DaybookPost.fromJson(entry),
      'sign_off' => DaybookSignOff.fromJson(entry),
      'update' => DaybookUpdate.fromJson(entry),
      _ => null,
    };
  }

  String get id;
  DateTime get at;

  /// The work item a sign-off or update belongs to, or the post itself.
  String get postId;
}

/// A Library file on a work item's slip ("M-201 Rev C").
@immutable
class DaybookAttachment {
  const DaybookAttachment({required this.name, this.revLabel});

  final String name;
  final String? revLabel;
}

/// The last time a work item was given to someone else.
@immutable
class DaybookGivenTo {
  const DaybookGivenTo({required this.at, this.fromName, this.toName});

  final DateTime at;

  /// Null across a block or for a hidden account: "Former member".
  final String? fromName;
  final String? toName;
}

/// One post on a Space's daybook, from daybook_page (space_post_json).
@immutable
class DaybookPost extends DaybookRecord {
  const DaybookPost({
    required this.id,
    required this.kind,
    required this.createdAt,
    required this.title,
    this.body,
    this.cancelled = false,
    this.authorId,
    this.authorName,
    this.place,
    this.dueDate,
    this.dueAt,
    this.item,
    this.stamp,
    this.needsMe = false,
    this.pointsTotal = 0,
    this.coverPath,
    this.dueEdit,
    this.attachments = const [],
    this.attachmentsMore = false,
    this.givenTo,
  });

  factory DaybookPost.fromJson(Map<String, dynamic> json) {
    final item = json['item'] as Map<String, dynamic>?;
    final points = json['points'] as Map<String, dynamic>?;
    final given = json['given_to'] as Map<String, dynamic>?;
    return DaybookPost(
      id: json['id'] as String,
      kind: json['kind'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      title: json['title'] as String? ?? '',
      body: json['body'] as String?,
      cancelled: json['status'] == 'cancelled',
      authorId: json['author_id'] as String?,
      authorName: json['author_name'] as String?,
      place: json['place'] as String?,
      dueDate: _day(json['due_date']),
      dueAt: _time(json['due_at']),
      item: item == null ? null : DaybookItem.fromJson(item),
      stamp: DaybookStamp.fromJson(json['stamp'] as Map<String, dynamic>?),
      needsMe: json['needs_me'] as bool? ?? false,
      pointsTotal: (points?['total'] as num?)?.toInt() ?? 0,
      coverPath: json['cover_path'] as String?,
      dueEdit: DaybookDueEdit.fromEdits(json['edits']),
      attachments: [
        for (final a in json['attachments'] as List? ?? const [])
          DaybookAttachment(
            name: (a as Map<String, dynamic>)['name'] as String? ?? '',
            revLabel: a['rev_label'] as String?,
          ),
      ],
      attachmentsMore: json['attachments_more'] as bool? ?? false,
      givenTo: given == null || given['at'] == null
          ? null
          : DaybookGivenTo(
              at: DateTime.parse(given['at'] as String),
              fromName: given['from_name'] as String?,
              toName: given['to_name'] as String?,
            ),
    );
  }

  static const workItemKind = 'work_item';

  @override
  final String id;

  /// 'work_item', 'checklist', 'announcement', 'activity', 'file' or
  /// 'report'. Slice 1 shows work items only.
  final String kind;
  final DateTime createdAt;
  final String title;

  /// The text under the title, as written.
  final String? body;
  final bool cancelled;
  final String? authorId;

  /// Null across a block or for a hidden account: "Former member".
  final String? authorName;
  final String? place;

  /// The due day, and its time when it has one.
  final DateTime? dueDate;
  final DateTime? dueAt;
  final DaybookItem? item;
  final DaybookStamp? stamp;

  /// The paper clip: this post needs the signed-in person.
  final bool needsMe;

  /// Checklist points on the work item.
  final int pointsTotal;

  /// The first photo of the post, in the Space's files.
  final String? coverPath;
  final DaybookDueEdit? dueEdit;

  /// The work item's first Library files, and whether it has more.
  final List<DaybookAttachment> attachments;
  final bool attachmentsMore;
  final DaybookGivenTo? givenTo;

  @override
  DateTime get at => createdAt;

  @override
  String get postId => id;

  bool get isWorkItem => kind == workItemKind;

  bool get isOpen => !cancelled && item?.status == WorkStatus.open;

  /// The slip as the phone shows it while something it did waits to be
  /// sent: signed, checked or cancelled here.
  DaybookPost shownAs({
    required DaybookStamp stamp,
    WorkStatus? status,
    bool cancelled = false,
  }) => DaybookPost(
    id: id,
    kind: kind,
    createdAt: createdAt,
    title: title,
    body: body,
    cancelled: cancelled || this.cancelled,
    authorId: authorId,
    authorName: authorName,
    place: place,
    dueDate: dueDate,
    dueAt: dueAt,
    item: item == null
        ? null
        : DaybookItem(
            status: status ?? item!.status,
            ownerId: item!.ownerId,
            ownerName: item!.ownerName,
            ref: item!.ref,
          ),
    stamp: stamp,
    pointsTotal: pointsTotal,
    coverPath: coverPath,
    dueEdit: dueEdit,
    attachments: attachments,
    attachmentsMore: attachmentsMore,
    givenTo: givenTo,
  );

  /// Late (review 44, answer 3): an open, live item past its time, or, with
  /// no time, from the day after its date.
  bool isLate(DateTime now) {
    if (cancelled || item?.status != WorkStatus.open || dueDate == null) {
      return false;
    }
    if (dueAt != null) return now.isAfter(dueAt!);
    return dayOf(now).isAfter(dueDate!);
  }

  /// Whole calendar days past the due date; 0 on the due day itself.
  int lateDays(DateTime now) => dayOf(now).difference(dueDate!).inDays;
}

List<WorkPhoto> _photos(Object? value) => [
  for (final p in value as List? ?? const [])
    if ((p as Map<String, dynamic>)['path'] != null)
      WorkPhoto(
        path: p['path'] as String,
        takenAt: _time(p['taken_at']),
        place: p['place'] as String?,
      ),
];

/// What came after a sign-off (review 45 M1).
enum DaybookOutcomeKind {
  done,
  checked,
  sentBack,
  cancelled;

  static DaybookOutcomeKind fromJson(Object? value) => switch (value) {
    'checked' => checked,
    'sent_back' => sentBack,
    'cancelled' => cancelled,
    _ => done,
  };
}

@immutable
class DaybookOutcome {
  const DaybookOutcome({
    required this.kind,
    this.at,
    this.byId,
    this.byName,
    this.reason,
    this.note,
  });

  factory DaybookOutcome.fromJson(Map<String, dynamic>? json) => DaybookOutcome(
    kind: DaybookOutcomeKind.fromJson(json?['kind']),
    at: _time(json?['at']),
    byId: json?['by_id'] as String?,
    byName: json?['by_name'] as String?,
    reason: SendBackReason.fromJson(json?['reason']),
    note: json?['note'] as String?,
  );

  final DaybookOutcomeKind kind;
  final DateTime? at;

  /// Who checked it or sent it back.
  final String? byId;
  final String? byName;

  /// A send-back's reason and note.
  final SendBackReason? reason;
  final String? note;
}

/// A sign-off on the daybook: the owner's proof at its own time, quoting
/// the work item.
@immutable
class DaybookSignOff extends DaybookRecord {
  const DaybookSignOff({
    required this.id,
    required this.at,
    required this.postId,
    required this.title,
    required this.outcome,
    this.ref,
    this.actorId,
    this.actorName,
    this.note,
    this.photos = const [],
    this.needsMe = false,
  });

  factory DaybookSignOff.fromJson(Map<String, dynamic> json) => DaybookSignOff(
    id: json['id'] as String,
    at: DateTime.parse(json['at'] as String),
    postId: json['post_id'] as String,
    title: json['title'] as String? ?? '',
    ref: json['ref'] as String?,
    actorId: json['actor_id'] as String?,
    actorName: json['actor_name'] as String?,
    note: json['note'] as String?,
    photos: _photos(json['photos']),
    outcome: DaybookOutcome.fromJson(json['outcome'] as Map<String, dynamic>?),
    needsMe: json['needs_me'] as bool? ?? false,
  );

  @override
  final String id;
  @override
  final DateTime at;
  @override
  final String postId;

  /// The work item's title, shown as the quote.
  final String title;
  final String? ref;
  final String? actorId;

  /// Null across a block or for a hidden account: "Former member".
  final String? actorName;
  final String? note;
  final List<WorkPhoto> photos;
  final DaybookOutcome outcome;

  /// The paper clip: the latest sign-off of a Done item, for whoever may
  /// check it (review 45 M2).
  final bool needsMe;

  /// The proof as the phone shows it while a check made here waits for its
  /// undo bar, or for a signal.
  DaybookSignOff checkedBy({
    required String? id,
    required String? name,
    required DateTime at,
  }) => DaybookSignOff(
    id: this.id,
    at: this.at,
    postId: postId,
    title: title,
    ref: ref,
    actorId: actorId,
    actorName: actorName,
    note: note,
    photos: photos,
    outcome: DaybookOutcome(
      kind: DaybookOutcomeKind.checked,
      at: at,
      byId: id,
      byName: name,
    ),
  );
}

/// An update on the daybook: a small note quoting its work item.
@immutable
class DaybookUpdate extends DaybookRecord {
  const DaybookUpdate({
    required this.id,
    required this.at,
    required this.postId,
    required this.title,
    this.actorId,
    this.actorName,
    this.note,
    this.photos = const [],
  });

  factory DaybookUpdate.fromJson(Map<String, dynamic> json) => DaybookUpdate(
    id: json['id'] as String,
    at: DateTime.parse(json['at'] as String),
    postId: json['post_id'] as String,
    title: json['title'] as String? ?? '',
    actorId: json['actor_id'] as String?,
    actorName: json['actor_name'] as String?,
    note: json['note'] as String?,
    photos: _photos(json['photos']),
  );

  @override
  final String id;
  @override
  final DateTime at;
  @override
  final String postId;
  final String title;
  final String? actorId;

  /// Null across a block or for a hidden account: "Former member".
  final String? actorName;
  final String? note;
  final List<WorkPhoto> photos;
}

/// What the month drop-down marks (daybook_month), in the phone's days.
@immutable
class DaybookMonth {
  const DaybookMonth({this.postDays = const {}, this.dueDays = const {}});

  /// 'posts' rows are quarter hours with posts, which the phone puts in its
  /// own days; 'due' rows are days.
  factory DaybookMonth.fromRows(List<Map<String, dynamic>> rows) {
    final posts = <DateTime>{};
    final due = <DateTime>{};
    for (final r in rows) {
      if (r['kind'] == 'posts' && r['at'] != null) {
        posts.add(dayOf(DateTime.parse(r['at'] as String)));
      } else if (r['kind'] == 'due' && r['day'] != null) {
        due.add(_day(r['day'])!);
      }
    }
    return DaybookMonth(postDays: posts, dueDays: due);
  }

  final Set<DateTime> postDays;
  final Set<DateTime> dueDays;
}

/// A work item from my_calendar: due on a day, mine to sign or written by
/// me.
@immutable
class CalendarWorkItem {
  const CalendarWorkItem({
    required this.spaceId,
    required this.title,
    required this.day,
    required this.status,
    this.dueAt,
  });

  /// A my_calendar row of kind 'work_item'; null for other kinds.
  static CalendarWorkItem? fromJson(Map<String, dynamic> json) {
    if (json['kind'] != DaybookPost.workItemKind) return null;
    return CalendarWorkItem(
      spaceId: json['space_id'] as String,
      title: json['title'] as String? ?? '',
      day: _day(json['day'])!,
      status: WorkStatus.fromJson(json['status']),
      dueAt: _time(json['starts_at']),
    );
  }

  final String spaceId;
  final String title;
  final DateTime day;
  final WorkStatus status;
  final DateTime? dueAt;
}
