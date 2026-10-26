import 'package:flutter/foundation.dart';

/// A page's icon (review 99 A1): one of a fixed twelve Phosphor line icons;
/// no emoji and no upload. [json] is notebook_pages.icon.
enum PageIcon {
  folder('folder'),
  hardHat('hard_hat'),
  building('building'),
  phone('phone'),
  list('list'),
  calendar('calendar'),
  camera('camera'),
  warning('warning'),
  star('star'),
  wrench('wrench'),
  ruler('ruler'),
  notebook('notebook');

  const PageIcon(this.json);

  final String json;

  static PageIcon fromJson(Object? value) =>
      values.where((i) => i.json == value).firstOrNull ?? notebook;
}

/// A page of My notebook (review 99A, migration 47): a person's own, as
/// deep as they like ([parentId]). Only its owner reads it.
@immutable
class NotebookPage {
  const NotebookPage({
    required this.id,
    required this.createdAt,
    required this.lastActivityAt,
    this.parentId,
    this.title = '',
    this.myNotes = false,
    this.icon = PageIcon.notebook,
    this.pinned = false,
    this.isNew = false,
  });

  factory NotebookPage.fromJson(Map<String, dynamic> json) => NotebookPage(
    id: json['id'] as String,
    parentId: json['parent_id'] as String?,
    title: json['title'] as String? ?? '',
    myNotes: json['named'] == 'my_notes',
    icon: PageIcon.fromJson(json['icon']),
    pinned: json['pinned'] as bool? ?? false,
    isNew: json['is_new'] as bool? ?? false,
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    lastActivityAt: DateTime.parse(
      json['last_activity_at'] as String,
    ).toLocal(),
  );

  /// The server's limit on a title.
  static const titleMax = 120;

  final String id;
  final String? parentId;

  /// Empty: the app names it ([myNotes]: "My notes"; else "Untitled").
  final String title;

  /// The page every older note went into (A6), named in the app's language.
  final bool myNotes;
  final PageIcon icon;
  final bool pinned;

  /// Made with an entry and titled from it, until opened, renamed or
  /// merged (A2).
  final bool isNew;
  final DateTime createdAt;
  final DateTime lastActivityAt;

  NotebookPage copyWith({
    String? Function()? parentId,
    String? title,
    PageIcon? icon,
    bool? pinned,
    bool? isNew,
    DateTime? lastActivityAt,
  }) => NotebookPage(
    id: id,
    parentId: parentId == null ? this.parentId : parentId(),
    title: title ?? this.title,
    myNotes: myNotes,
    icon: icon ?? this.icon,
    pinned: pinned ?? this.pinned,
    isNew: isNew ?? this.isNew,
    createdAt: createdAt,
    lastActivityAt: lastActivityAt ?? this.lastActivityAt,
  );

  /// As this phone keeps it while it waits to be sent.
  Map<String, dynamic> toJson() => {
    'id': id,
    'parent_id': parentId,
    'title': title,
    if (myNotes) 'named': 'my_notes',
    'icon': icon.json,
    'pinned': pinned,
    'is_new': isNew,
    'created_at': createdAt.toUtc().toIso8601String(),
    'last_activity_at': lastActivityAt.toUtc().toIso8601String(),
  };
}

/// A hit of search_notebook (A5): a page by its title, or an entry by its
/// title or words, with the page it is in.
@immutable
class NotebookHit {
  const NotebookHit({
    required this.pageId,
    required this.at,
    this.noteId,
    this.title = '',
    this.snippet,
  });

  factory NotebookHit.fromJson(Map<String, dynamic> json) => NotebookHit(
    pageId: json['page_id'] as String,
    noteId: json['note_id'] as String?,
    title: json['title'] as String? ?? '',
    snippet: json['snippet'] as String?,
    at: DateTime.parse(json['created_at'] as String).toLocal(),
  );

  final String pageId;

  /// Null: the hit is the page itself.
  final String? noteId;
  final String title;
  final String? snippet;

  /// The entry's date; a page's latest activity.
  final DateTime at;

  bool get isPage => noteId == null;
}
