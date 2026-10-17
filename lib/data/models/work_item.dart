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

/// A work item as a chat card names it: its reference and title. The
/// daybook reads work items as posts (DaybookPost).
@immutable
class WorkItem {
  const WorkItem({
    required this.id,
    required this.spaceId,
    required this.ref,
    required this.title,
  });

  factory WorkItem.fromJson(Map<String, dynamic> json) => WorkItem(
    id: json['id'] as String,
    spaceId: json['space_id'] as String,
    ref: json['ref'] as String,
    title: json['title'] as String,
  );

  final String id;
  final String spaceId;

  /// "KCT-021": Latin, always left to right.
  final String ref;
  final String title;
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

/// Why an item was sent back. One single choice (rule 6).
enum SendBackReason {
  photoMissing('photo_missing'),
  notAsAsked('not_as_asked'),
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

/// A Checked item the owner may show on their profile (RE2), or one shown
/// to everyone (RE1). Only these fields ever leave the Space.
@immutable
class DeliveredWork {
  const DeliveredWork({
    required this.id,
    required this.title,
    this.place,
    this.projectName,
    this.checkedByName,
    this.checkedAt,
    this.shown = false,
    this.photoPath,
  });

  factory DeliveredWork.fromJson(Map<String, dynamic> json) => DeliveredWork(
    id: json['work_item_id'] as String,
    title: json['title'] as String,
    place: json['place_text'] as String?,
    projectName: json['project_name'] as String?,
    checkedByName: json['checked_by_name'] as String?,
    checkedAt: json['checked_at'] == null
        ? null
        : DateTime.parse(json['checked_at'] as String),
    shown: json['shown'] as bool? ?? true,
    photoPath: json['photo_path'] as String?,
  );

  final String id;
  final String title;
  final String? place;
  final String? projectName;
  final String? checkedByName;
  final DateTime? checkedAt;
  final bool shown;
  final String? photoPath;
}
