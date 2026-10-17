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
  const DaybookItem({required this.status, this.ownerId, this.ownerName});

  factory DaybookItem.fromJson(Map<String, dynamic> json) => DaybookItem(
    status: WorkStatus.fromJson(json['status']),
    ownerId: json['owner_id'] as String?,
    ownerName: json['owner_name'] as String?,
  );

  final WorkStatus status;
  final String? ownerId;

  /// Null across a block or for a hidden account: "Former member".
  final String? ownerName;
}

/// A change of due in the latest edit ("Edited: due moved from Thu to
/// today"). A time-only change has the same [from] and [to] days.
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
}

/// One post on a Space's daybook, from daybook_page (space_post_json).
@immutable
class DaybookPost {
  const DaybookPost({
    required this.id,
    required this.kind,
    required this.createdAt,
    required this.title,
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
  });

  factory DaybookPost.fromJson(Map<String, dynamic> json) {
    final item = json['item'] as Map<String, dynamic>?;
    final points = json['points'] as Map<String, dynamic>?;
    return DaybookPost(
      id: json['id'] as String,
      kind: json['kind'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      title: json['title'] as String? ?? '',
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
    );
  }

  static const workItemKind = 'work_item';

  final String id;

  /// 'work_item', 'checklist', 'announcement', 'activity', 'file' or
  /// 'report'. Slice 1 shows work items only.
  final String kind;
  final DateTime createdAt;
  final String title;
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

  bool get isWorkItem => kind == workItemKind;

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
