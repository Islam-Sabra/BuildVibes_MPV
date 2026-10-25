import 'package:flutter/foundation.dart';

import 'work_item.dart';

/// What a search row found (search_space): a post, a checklist point
/// (shown under its post), a chat message or a Library file in use.
enum SpaceSearchKind {
  post,
  point,
  message,
  file;

  static SpaceSearchKind? fromJson(Object? value) =>
      values.where((k) => k.name == value).firstOrNull;
}

/// One row of search_space, newest first. [title] is the post's title or
/// the file's name; [snippet] the words around the match (a message's or
/// a point's text, or a post's body when the title didn't match; a file's
/// revision). [status] is a work item's, read with it (DONE, CHECKED).
@immutable
class SpaceSearchHit {
  const SpaceSearchHit({
    required this.kind,
    required this.id,
    required this.createdAt,
    this.postId,
    this.threadId,
    this.teamId,
    this.postKind,
    this.cancelled = false,
    this.ref,
    this.title,
    this.snippet,
    this.authorName,
    this.mine = false,
    this.status,
    this.exact = false,
  });

  /// A row, or null for a kind this app doesn't know yet.
  static SpaceSearchHit? fromJson(Map<String, dynamic> json) {
    final kind = SpaceSearchKind.fromJson(json['kind']);
    if (kind == null) return null;
    return SpaceSearchHit(
      kind: kind,
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      postId: json['post_id'] as String?,
      threadId: json['thread_id'] as String?,
      teamId: json['team_id'] as String?,
      postKind: json['post_kind'] as String?,
      cancelled: json['post_status'] == 'cancelled',
      ref: json['ref'] as String?,
      title: json['title'] as String?,
      snippet: json['snippet'] as String?,
      authorName: json['author_name'] as String?,
      mine: json['mine'] as bool? ?? false,
      exact: json['exact'] as bool? ?? false,
    );
  }

  final SpaceSearchKind kind;
  final String id;
  final DateTime createdAt;
  final String? postId;
  final String? threadId;
  final String? teamId;
  final String? postKind;
  final bool cancelled;
  final String? ref;
  final String? title;
  final String? snippet;
  final String? authorName;

  /// The reader wrote it: "You", never their own name (review 80).
  final bool mine;
  final WorkStatus? status;

  /// The post with the number searched for (review 95): first, and said so.
  final bool exact;

  /// A post of any kind, or one of its points: the Posts group (review 96).
  bool get isWork =>
      kind == SpaceSearchKind.post || kind == SpaceSearchKind.point;

  SpaceSearchHit withStatus(WorkStatus? status) => SpaceSearchHit(
    kind: kind,
    id: id,
    createdAt: createdAt,
    postId: postId,
    threadId: threadId,
    teamId: teamId,
    postKind: postKind,
    cancelled: cancelled,
    ref: ref,
    title: title,
    snippet: snippet,
    authorName: authorName,
    mine: mine,
    status: status,
    exact: exact,
  );
}
