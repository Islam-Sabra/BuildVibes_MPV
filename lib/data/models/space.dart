import 'package:flutter/foundation.dart';

/// Lead / Crew / Viewer (مسؤول / فريق تنفيذ / مُطّلع). What each pass opens
/// is decided on the server (pass_rights, member_rights); the app never
/// copies the presets.
enum SpacePass {
  lead,
  crew,
  viewer;

  static SpacePass fromJson(Object? value) => switch (value) {
    'lead' => SpacePass.lead,
    'crew' => SpacePass.crew,
    _ => SpacePass.viewer,
  };

  String toJson() => name;
}

/// A row of My Spaces (S1 v2), from my_spaces().
@immutable
class SpaceSummary {
  const SpaceSummary({
    required this.id,
    required this.name,
    required this.pass,
    required this.isAdmin,
    this.projectId,
    this.projectName,
    this.projectTypeId,
    this.pendingRequests = 0,
  });

  factory SpaceSummary.fromJson(Map<String, dynamic> json) => SpaceSummary(
    id: json['space_id'] as String,
    name: json['name'] as String,
    pass: SpacePass.fromJson(json['pass']),
    isAdmin: json['is_admin'] as bool? ?? false,
    projectId: json['project_id'] as String?,
    projectName: json['project_name'] as String?,
    projectTypeId: json['project_type_id'] as String?,
    pendingRequests: (json['pending_requests'] as num?)?.toInt() ?? 0,
  );

  final String id;
  final String name;
  final SpacePass pass;
  final bool isAdmin;
  final String? projectId;
  final String? projectName;
  final String? projectTypeId;

  /// Join requests waiting for this admin. Always 0 for members.
  final int pendingRequests;
}

enum JoinRequestStatus { pending, declined }

/// Your own request to join a Space (waiting card), from my_join_requests().
/// Who declined is never shown.
@immutable
class MyJoinRequest {
  const MyJoinRequest({
    required this.id,
    required this.spaceId,
    required this.spaceName,
    required this.status,
    required this.createdAt,
    this.decidedAt,
  });

  factory MyJoinRequest.fromJson(Map<String, dynamic> json) => MyJoinRequest(
    id: json['request_id'] as String,
    spaceId: json['space_id'] as String,
    spaceName: json['space_name'] as String,
    status: json['status'] == 'declined'
        ? JoinRequestStatus.declined
        : JoinRequestStatus.pending,
    createdAt: DateTime.parse(json['created_at'] as String),
    decidedAt: json['decided_at'] == null
        ? null
        : DateTime.parse(json['decided_at'] as String),
  );

  final String id;
  final String spaceId;
  final String spaceName;
  final JoinRequestStatus status;
  final DateTime createdAt;
  final DateTime? decidedAt;
}

/// What an invite code opens, before asking to join (code sheet).
@immutable
class InvitePreview {
  const InvitePreview({
    required this.spaceName,
    required this.expiresAt,
    this.invitedByName,
  });

  factory InvitePreview.fromJson(Map<String, dynamic> json) => InvitePreview(
    spaceName: json['space_name'] as String,
    invitedByName: json['invited_by_name'] as String?,
    expiresAt: DateTime.parse(json['expires_at'] as String),
  );

  final String spaceName;
  final String? invitedByName;
  final DateTime expiresAt;
}

/// The answer to request_join(). A wrong code is an answer, not an error.
enum JoinStatus {
  requested,
  pending,
  member,
  declined,
  notValid,
  tooManyTries;

  static JoinStatus fromJson(Object? value) => switch (value) {
    'requested' => JoinStatus.requested,
    'pending' => JoinStatus.pending,
    'member' => JoinStatus.member,
    'declined' => JoinStatus.declined,
    'too_many_tries' => JoinStatus.tooManyTries,
    _ => JoinStatus.notValid,
  };
}

@immutable
class JoinResult {
  const JoinResult({required this.status, this.spaceId, this.spaceName});

  factory JoinResult.fromJson(Map<String, dynamic> json) => JoinResult(
    status: JoinStatus.fromJson(json['status']),
    spaceId: json['space_id'] as String?,
    spaceName: json['space_name'] as String?,
  );

  final JoinStatus status;
  final String? spaceId;
  final String? spaceName;
}

/// A Space's live invite code (S16).
@immutable
class SpaceInvite {
  const SpaceInvite({required this.code, required this.expiresAt});

  factory SpaceInvite.fromJson(Map<String, dynamic> json) => SpaceInvite(
    code: json['code'] as String,
    expiresAt: DateTime.parse(json['expires_at'] as String),
  );

  final String code;
  final DateTime expiresAt;

  /// "K7Q4MD" → "K7Q 4MD", easier to read out on site.
  String get grouped =>
      code.length == 6 ? '${code.substring(0, 3)} ${code.substring(3)}' : code;
}

/// The rights a member has in a Space, from member_rights().
@immutable
class MemberRights {
  const MemberRights({
    this.createItems = false,
    this.checkItems = false,
    this.addFiles = false,
    this.invite = false,
    this.markDone = false,
    this.isCustom = false,
  });

  factory MemberRights.fromJson(Map<String, dynamic>? json) => json == null
      ? const MemberRights()
      : MemberRights(
          createItems: json['create_items'] as bool? ?? false,
          checkItems: json['check_items'] as bool? ?? false,
          addFiles: json['add_files'] as bool? ?? false,
          invite: json['invite'] as bool? ?? false,
          markDone: json['mark_done'] as bool? ?? false,
          isCustom: json['is_custom'] as bool? ?? false,
        );

  final bool createItems;
  final bool checkItems;
  final bool addFiles;
  final bool invite;
  final bool markDone;

  /// The admin changed this member's rights from the pass preset.
  final bool isCustom;
}

/// A Space as its members see it (header, Space info), with the
/// signed-in person's own place in it.
@immutable
class SpaceDetail {
  const SpaceDetail({
    required this.id,
    required this.name,
    required this.myPass,
    required this.iAmAdmin,
    required this.myRights,
    this.about,
    this.projectId,
    this.projectName,
  });

  final String id;
  final String name;
  final String? about;
  final String? projectId;
  final String? projectName;
  final SpacePass myPass;
  final bool iAmAdmin;
  final MemberRights myRights;

  bool get canInvite => myRights.invite;
}

/// What a Space call can fail with, from the Postgres error code.
enum SpaceFailure {
  /// 42501
  notAllowed,

  /// P0001: a rule, such as "a Space needs an admin".
  rule,

  /// 22023 and check violations: bad input.
  badInput,

  /// 23505: a Team with that name already exists.
  duplicate,
  network,
  unknown,
}

class SpaceException implements Exception {
  const SpaceException(this.failure, [this.message]);

  final SpaceFailure failure;
  final String? message;

  @override
  String toString() => 'SpaceException($failure, $message)';
}
