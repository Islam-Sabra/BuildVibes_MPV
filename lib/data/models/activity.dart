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
  postUseful('post_useful'),
  contentRemoved('content_removed'),
  appealDecided('appeal_decided'),
  // Daybook posts (migration 19): a change or a cancel of something for
  // you, and the post kinds' own rows. Their row opens the post's card.
  itemEdited('item_edited'),
  itemCancelled('item_cancelled'),
  announcementNew('announcement_new'),
  checklistForYou('checklist_for_you'),
  activityInvited('activity_invited'),
  fileNewVersion('file_new_version');

  const ActivityKind(this.json);

  final String json;

  static ActivityKind? fromJson(Object? value) =>
      values.where((k) => k.json == value).firstOrNull;
}

/// One row of my_activity(): the last 7 days.
@immutable
class ActivityRow {
  const ActivityRow({
    required this.id,
    required this.kind,
    required this.createdAt,
    this.spaceId,
    this.spaceName,
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
    this.removalId,
    this.targetKind,
    this.result,
    this.eventId,
    this.spacePostId,
    this.postKind,
  });

  factory ActivityRow.fromJson(Map<String, dynamic> j) => ActivityRow(
    id: j['id'] as String,
    kind: ActivityKind.fromJson(j['kind'])!,
    createdAt: DateTime.parse(j['created_at'] as String),
    spaceId: j['space_id'] as String?,
    spaceName: j['space_name'] as String?,
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
    removalId: (j['payload'] as Map?)?['removal_id'] as String?,
    eventId: (j['payload'] as Map?)?['event_id'] as String?,
    targetKind: (j['payload'] as Map?)?['target_kind'] as String?,
    result: (j['payload'] as Map?)?['result'] as String?,
    spacePostId: j['space_post_id'] as String?,
    postKind: j['post_kind'] as String?,
  );

  final String id;
  final ActivityKind kind;
  final DateTime createdAt;

  final String? spaceId;
  final String? spaceName;
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

  /// A removal of yours (R3) and its appeal's result: 'reversed' or
  /// 'upheld'. targetKind: post, reply or message.
  final String? removalId;
  final String? targetKind;
  final String? result;

  /// The work item event a row is about (its history line), when the
  /// server says (F20).
  final String? eventId;

  /// The daybook post a row is about when it isn't a work item (an
  /// announcement, a checklist, a scheduled activity, a file), and its kind.
  final String? spacePostId;
  final String? postKind;

  /// The card the row opens in its Space's daybook.
  String? get cardId => workItemId ?? spacePostId;
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

/// What a Needs-you card asks of you. [checklist]: a checklist given to
/// you with points still to tick (needs_you's checklist_for_you).
enum NeedsKind { forYou, youCheck, sentBack, ownerLeft, joinRequest, checklist }

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
    this.dueAt,
    this.photoPath,
    this.postId,
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

  /// The due time, when the item has one.
  final DateTime? dueAt;

  /// The row's photo (Needs you, 2544:35068): the proof to check, or the
  /// work item's cover.
  final String? photoPath;

  /// A checklist's post, when the card isn't about a work item.
  final String? postId;

  /// The card the row opens in its Space's daybook.
  String? get cardId => workItemId ?? postId;
}
