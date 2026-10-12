import 'package:flutter/foundation.dart';

/// What happened (migration 13). Each goes to one person, never the actor.
enum ActivityKind {
  itemAssigned('item_assigned'),
  itemDone('item_done'),
  itemChecked('item_checked'),
  itemSentBack('item_sent_back'),
  itemComment('item_comment'),
  joinRequest('join_request'),
  joinConfirmed('join_confirmed'),
  roleConfirmed('role_confirmed'),
  follow('follow'),
  postReply('post_reply'),
  postUseful('post_useful');

  const ActivityKind(this.json);

  final String json;

  static ActivityKind? fromJson(Object? value) =>
      values.where((k) => k.json == value).firstOrNull;
}

/// The Activity groups: one per Space, then Your record, Your network and
/// Your posts.
enum ActivityGroupKind {
  space,
  record,
  network,
  posts;

  static ActivityGroupKind fromJson(Object? value) => switch (value) {
    'record' => record,
    'network' => network,
    'posts' => posts,
    _ => space,
  };
}

/// One row of my_activity(): the last 7 days.
@immutable
class ActivityRow {
  const ActivityRow({
    required this.id,
    required this.kind,
    required this.group,
    required this.createdAt,
    required this.seq,
    this.spaceId,
    this.spaceName,
    this.myPass,
    this.workItemId,
    this.workItemRef,
    this.workItemTitle,
    this.postId,
    this.context,
    this.requestStatus,
    this.projectName,
    this.actorId,
    this.actorName,
    this.read = false,
    this.usefulNames = const [],
    this.toReply = false,
  });

  factory ActivityRow.fromJson(Map<String, dynamic> j) => ActivityRow(
    id: j['id'] as String,
    kind: ActivityKind.fromJson(j['kind'])!,
    group: ActivityGroupKind.fromJson(j['group_kind']),
    createdAt: DateTime.parse(j['created_at'] as String),
    seq: (j['seq'] as num).toInt(),
    spaceId: j['space_id'] as String?,
    spaceName: j['space_name'] as String?,
    myPass: j['my_pass'] as String?,
    workItemId: j['work_item_id'] as String?,
    workItemRef: j['work_item_ref'] as String?,
    workItemTitle: j['work_item_title'] as String?,
    postId: j['post_id'] as String?,
    context: j['context'] as String?,
    requestStatus: j['request_status'] as String?,
    projectName: j['project_name'] as String?,
    actorId: j['actor_id'] as String?,
    actorName: j['actor_name'] as String?,
    read: j['read_at'] != null,
    usefulNames: [
      for (final n in (j['useful_names'] as List? ?? const [])) n as String,
    ],
    toReply: (j['payload'] as Map?)?['to'] == 'reply',
  );

  final String id;
  final ActivityKind kind;
  final ActivityGroupKind group;
  final DateTime createdAt;

  /// Its place in its group: 1 is the oldest in the window (letter A).
  final int seq;
  final String? spaceId;
  final String? spaceName;
  final String? myPass;
  final String? workItemId;
  final String? workItemRef;
  final String? workItemTitle;
  final String? postId;

  /// The reply's or the post's text: the row's one line of context.
  final String? context;
  final String? requestStatus;
  final String? projectName;
  final String? actorId;
  final String? actorName;
  final bool read;

  /// Useful only: at most two people you follow who marked it.
  final List<String> usefulNames;

  /// A reply to your reply, not to your post.
  final bool toReply;

  /// Groups rows: a Space's id, or the group's name.
  String get groupKey =>
      group == ActivityGroupKind.space ? 'space:${spaceId ?? ''}' : group.name;
}

/// "A", "B" … "Z", then "AA", "AB" …: REV letters, always Latin.
String revLetter(int seq) {
  var n = seq;
  var out = '';
  while (n > 0) {
    final r = (n - 1) % 26;
    out = String.fromCharCode(0x41 + r) + out;
    n = (n - 1) ~/ 26;
  }
  return out;
}

/// The H1b header counts: each your own.
@immutable
class HomeDay {
  const HomeDay({this.needsYou = 0, this.activeSpaces = 0, this.replies = 0});

  factory HomeDay.fromJson(Map<String, dynamic> j) => HomeDay(
    needsYou: (j['needs_you'] as num?)?.toInt() ?? 0,
    activeSpaces: (j['active_spaces'] as num?)?.toInt() ?? 0,
    replies: (j['replies'] as num?)?.toInt() ?? 0,
  );

  final int needsYou;
  final int activeSpaces;
  final int replies;
}

/// Which Space tab a "Today in your Spaces" row opens.
enum SpaceChange {
  workItem,
  library,
  chat;

  static SpaceChange fromJson(Object? value) => switch (value) {
    'library' => library,
    'chat' => chat,
    _ => workItem,
  };
}

/// One row of today_in_spaces(): a Space's most important change today.
@immutable
class SpaceToday {
  const SpaceToday({
    required this.spaceId,
    required this.spaceName,
    required this.change,
    required this.at,
    this.projectName,
    this.workItemId,
    this.workItemRef,
    this.workItemTitle,
    this.eventKind,
    this.fileId,
    this.fileName,
    this.threadId,
    this.messageKind,
    this.messageBody,
    this.actorName,
  });

  factory SpaceToday.fromJson(Map<String, dynamic> j) => SpaceToday(
    spaceId: j['space_id'] as String,
    spaceName: j['space_name'] as String,
    change: SpaceChange.fromJson(j['change']),
    at: DateTime.parse(j['at'] as String),
    projectName: j['project_name'] as String?,
    workItemId: j['work_item_id'] as String?,
    workItemRef: j['work_item_ref'] as String?,
    workItemTitle: j['work_item_title'] as String?,
    eventKind: j['event_kind'] as String?,
    fileId: j['file_id'] as String?,
    fileName: j['file_name'] as String?,
    threadId: j['thread_id'] as String?,
    messageKind: j['message_kind'] as String?,
    messageBody: j['message_body'] as String?,
    actorName: j['actor_name'] as String?,
  );

  final String spaceId;
  final String spaceName;
  final SpaceChange change;
  final DateTime at;
  final String? projectName;
  final String? workItemId;
  final String? workItemRef;
  final String? workItemTitle;

  /// raised, done, checked, sent_back, comment or reassigned.
  final String? eventKind;
  final String? fileId;
  final String? fileName;
  final String? threadId;

  /// text, photo, file, voice or work_item.
  final String? messageKind;
  final String? messageBody;
  final String? actorName;
}

/// What a Needs-you card asks of you.
enum NeedsKind { forYou, youCheck, sentBack, ownerLeft, joinRequest }

/// One Needs-you card (Home H1b and Activity A1), from needs_you().
@immutable
class NeedsCard {
  const NeedsCard({
    required this.kind,
    required this.spaceId,
    required this.spaceName,
    required this.at,
    this.workItemId,
    this.workItemRef,
    this.workItemTitle,
    this.due,
    this.requestId,
    this.actorName,
  });

  final NeedsKind kind;
  final String spaceId;
  final String spaceName;
  final DateTime at;
  final String? workItemId;
  final String? workItemRef;
  final String? workItemTitle;
  final DateTime? due;
  final String? requestId;

  /// Who gave, signed, sent back, or asked; null when it was you.
  final String? actorName;
}
