import 'package:flutter/foundation.dart';

import 'work_item.dart';

DateTime? _time(Object? value) =>
    value == null ? null : DateTime.parse(value as String).toLocal();

DateTime? _day(Object? value) {
  if (value == null) return null;
  final d = DateTime.parse(value as String);
  return DateTime(d.year, d.month, d.day);
}

List<Map<String, dynamic>> _rows(Object? value) =>
    (value as List? ?? const []).cast<Map<String, dynamic>>();

/// Why a work item needs a decision this week (week_report).
enum DecisionState {
  late('late'),
  sentBack('sent_back'),
  done('done');

  const DecisionState(this.json);

  final String json;

  static DecisionState fromJson(Object? value) =>
      values.where((s) => s.json == value).firstOrNull ?? late;
}

/// A row of "Needs a decision": late, sent back, or done and waiting for
/// a check. Never a target.
@immutable
class DecisionRow {
  const DecisionRow({
    required this.postId,
    required this.title,
    required this.state,
    this.ref,
    this.ownerName,
    this.reason,
    this.dueDate,
    this.dueAt,
    this.doneAt,
    this.needsMe = false,
  });

  factory DecisionRow.fromJson(Map<String, dynamic> json) => DecisionRow(
    postId: json['post_id'] as String,
    title: json['title'] as String? ?? '',
    state: DecisionState.fromJson(json['state']),
    ref: json['ref'] as String?,
    ownerName: json['owner_name'] as String?,
    reason: SendBackReason.fromJson(json['reason']),
    dueDate: _day(json['due_date']),
    dueAt: _time(json['due_at']),
    doneAt: _time(json['done_at']),
    needsMe: json['needs_me'] as bool? ?? false,
  );

  final String postId;
  final String title;
  final DecisionState state;
  final String? ref;

  /// Null across a block, or for an account that's gone.
  final String? ownerName;
  final SendBackReason? reason;
  final DateTime? dueDate;
  final DateTime? dueAt;
  final DateTime? doneAt;
  final bool needsMe;
}

/// A work item checked this week, with its Done photo and who checked it.
@immutable
class CheckedRow {
  const CheckedRow({
    required this.postId,
    required this.title,
    required this.checkedAt,
    this.ref,
    this.photoPath,
    this.checkerName,
  });

  factory CheckedRow.fromJson(Map<String, dynamic> json) => CheckedRow(
    postId: json['post_id'] as String,
    title: json['title'] as String? ?? '',
    checkedAt: _time(json['checked_at'])!,
    ref: json['ref'] as String?,
    photoPath: json['done_photo_path'] as String?,
    checkerName: json['checker_name'] as String?,
  );

  final String postId;
  final String title;
  final DateTime checkedAt;
  final String? ref;
  final String? photoPath;
  final String? checkerName;
}

/// A target: a work item with work items under it still to check, and how
/// many of them are checked (its own progress, not a quality signal).
@immutable
class TargetRow {
  const TargetRow({
    required this.postId,
    required this.title,
    required this.checked,
    required this.total,
    this.ref,
    this.dueDate,
    this.dueAt,
  });

  factory TargetRow.fromJson(Map<String, dynamic> json) {
    final children = json['children'] as Map<String, dynamic>? ?? const {};
    return TargetRow(
      postId: json['post_id'] as String,
      title: json['title'] as String? ?? '',
      checked: (children['checked'] as num?)?.toInt() ?? 0,
      total: (children['total'] as num?)?.toInt() ?? 0,
      ref: json['ref'] as String?,
      dueDate: _day(json['due_date']),
      dueAt: _time(json['due_at']),
    );
  }

  final String postId;
  final String title;
  final int checked;
  final int total;
  final String? ref;
  final DateTime? dueDate;
  final DateTime? dueAt;
}

/// Coming up in the next 7 days: an activity, or a work item's due.
@immutable
class ComingRow {
  const ComingRow({
    required this.postId,
    required this.title,
    required this.activity,
    this.startsAt,
    this.endsAt,
    this.place,
    this.dueDate,
    this.dueAt,
    this.ownerName,
  });

  factory ComingRow.fromJson(Map<String, dynamic> json) => ComingRow(
    postId: json['post_id'] as String,
    title: json['title'] as String? ?? '',
    activity: json['kind'] == 'activity',
    startsAt: _time(json['starts_at']),
    endsAt: _time(json['ends_at']),
    place: json['place'] as String?,
    dueDate: _day(json['due_date']),
    dueAt: _time(json['due_at']),
    ownerName: json['owner_name'] as String?,
  );

  final String postId;
  final String title;
  final bool activity;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? place;
  final DateTime? dueDate;
  final DateTime? dueAt;
  final String? ownerName;

  /// The phone's day it falls on.
  DateTime? get day {
    final at = startsAt ?? dueAt;
    if (at != null) return DateTime(at.year, at.month, at.day);
    return dueDate;
  }
}

/// The week report (MR1, week_report): four sections, each as the reader
/// may read it, at most 30 rows each. Names on rows, never totals per
/// person (rule 3).
@immutable
class WeekReport {
  const WeekReport({
    this.needsDecision = const [],
    this.checked = const [],
    this.targets = const [],
    this.comingUp = const [],
  });

  factory WeekReport.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const WeekReport();
    return WeekReport(
      needsDecision: [
        for (final r in _rows(json['needs_decision'])) DecisionRow.fromJson(r),
      ],
      checked: [for (final r in _rows(json['checked'])) CheckedRow.fromJson(r)],
      targets: [for (final r in _rows(json['targets'])) TargetRow.fromJson(r)],
      comingUp: [
        for (final r in _rows(json['coming_up'])) ComingRow.fromJson(r),
      ],
    );
  }

  final List<DecisionRow> needsDecision;
  final List<CheckedRow> checked;
  final List<TargetRow> targets;
  final List<ComingRow> comingUp;

  bool get isEmpty =>
      needsDecision.isEmpty &&
      checked.isEmpty &&
      targets.isEmpty &&
      comingUp.isEmpty;
}

/// A line of meeting notes going in as a work item under the meeting's
/// one (create_from_message): its id, chosen on the phone, its words and
/// its owner.
typedef MeetingLine = ({String id, String text, String ownerId});
