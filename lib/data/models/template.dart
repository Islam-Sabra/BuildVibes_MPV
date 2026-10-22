import 'package:flutter/foundation.dart';

/// A template a post can start from (migration 20, space_templates): a
/// built-in ([builtinKey], the same in every Space, named by the app in
/// each language) or one of the Space's own, saved from a post. Words only:
/// the page's text, headings, toggles and tables, and the title, body and
/// points. A Team's own ([teamId]) is for that Team and the admins.
@immutable
class PostTemplate {
  const PostTemplate({
    required this.id,
    required this.kind,
    required this.createdAt,
    this.builtinKey,
    this.name,
    this.teamId,
    this.blocks = const [],
    this.title,
    this.body,
    this.points = const [],
  });

  factory PostTemplate.fromJson(Map<String, dynamic> json) {
    final fields = json['fields'] as Map<String, dynamic>? ?? const {};
    return PostTemplate(
      id: json['id'] as String,
      kind: json['kind'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      builtinKey: json['builtin_key'] as String?,
      name: json['name'] as String?,
      teamId: json['team_id'] as String?,
      blocks: [
        for (final b in json['blocks'] as List? ?? const [])
          Map<String, dynamic>.unmodifiable(b as Map<String, dynamic>),
      ],
      title: fields['title'] as String?,
      body: fields['body'] as String?,
      points: [for (final p in fields['points'] as List? ?? const []) '$p'],
    );
  }

  /// The built-in Daily report: three headings by key (R2).
  static const dailyReportKey = 'daily_report';

  /// Its id, the same in every database (migration 20).
  static const dailyReportId = '00000000-0000-4000-8000-0000000d0001';

  /// The Daily report's headings, by key.
  static const onSiteKey = 'on_site';
  static const doneTodayKey = 'done_today';
  static const problemsKey = 'problems';

  /// The kinds a template can be (post_templates.kind).
  static const kinds = {'work_item', 'checklist', 'announcement', 'report'};

  /// save_template: a name of 1 to 60 characters, at most 50 in a Space.
  static const nameMax = 60;
  static const perSpace = 50;

  final String id;

  /// 'work_item', 'checklist', 'announcement' or 'report'.
  final String kind;
  final DateTime createdAt;
  final String? builtinKey;

  /// A Space's own template's name, as typed; null for a built-in.
  final String? name;

  /// Null: for Everyone.
  final String? teamId;

  /// The page as the server keeps it; a built-in's headings may hold a
  /// `key` in place of words.
  final List<Map<String, dynamic>> blocks;
  final String? title;
  final String? body;

  /// A checklist's or a work item's points, in order.
  final List<String> points;

  bool get isBuiltin => builtinKey != null;
}

/// One line of a daily report's "Done today" or "On site", as the writing
/// card keeps it: a work item checked today (daily_report_fill) or a note
/// of the day (daily_report_notes). It goes as an `item_ref` block.
@immutable
class ReportRef {
  const ReportRef({
    required this.postId,
    required this.title,
    required this.at,
    this.isNote = false,
    this.ref,
    this.ownerName,
    this.checkerName,
    this.photoPath,
  });

  /// A daily_report_fill row.
  factory ReportRef.checked(Map<String, dynamic> json) => ReportRef(
    postId: json['post_id'] as String,
    title: json['title'] as String? ?? '',
    at: DateTime.parse(json['checked_at'] as String).toLocal(),
    ref: json['ref'] as String?,
    ownerName: json['owner_name'] as String?,
    checkerName: json['checker_name'] as String?,
    photoPath: json['done_photo_path'] as String?,
  );

  /// A daily_report_notes row.
  factory ReportRef.note(Map<String, dynamic> json) => ReportRef(
    postId: json['post_id'] as String,
    title: json['title'] as String? ?? '',
    at: DateTime.parse(json['created_at'] as String).toLocal(),
    isNote: true,
    ownerName: json['author_name'] as String?,
    photoPath: json['photo_path'] as String?,
  );

  factory ReportRef.fromJson(Map<String, dynamic> json) => ReportRef(
    postId: json['post_id'] as String,
    title: json['title'] as String? ?? '',
    at: DateTime.parse(json['at'] as String).toLocal(),
    isNote: json['note'] as bool? ?? false,
    ref: json['ref'] as String?,
    ownerName: json['owner_name'] as String?,
    checkerName: json['checker_name'] as String?,
    photoPath: json['photo_path'] as String?,
  );

  final String postId;
  final String title;

  /// When it was checked, or when the note was posted.
  final DateTime at;
  final bool isNote;
  final String? ref;

  /// The work item's owner, or the note's author.
  final String? ownerName;
  final String? checkerName;

  /// The Done photo, or the note's first photo.
  final String? photoPath;

  Map<String, dynamic> toJson() => {
    'post_id': postId,
    'title': title,
    'at': at.toUtc().toIso8601String(),
    if (isNote) 'note': true,
    'ref': ?ref,
    'owner_name': ?ownerName,
    'checker_name': ?checkerName,
    'photo_path': ?photoPath,
  };

  @override
  bool operator ==(Object other) =>
      other is ReportRef &&
      other.postId == postId &&
      other.title == title &&
      other.at == at &&
      other.isNote == isNote &&
      other.photoPath == photoPath;

  @override
  int get hashCode => Object.hash(postId, title, at, isNote, photoPath);
}
