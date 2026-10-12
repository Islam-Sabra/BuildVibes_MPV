import 'package:flutter/foundation.dart';

import 'market.dart';
import 'people.dart';

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
    int? needsYou,
  }) : needsYou = needsYou ?? pendingRequests;

  factory SpaceSummary.fromJson(Map<String, dynamic> json) => SpaceSummary(
    id: json['space_id'] as String,
    name: json['name'] as String,
    pass: SpacePass.fromJson(json['pass']),
    isAdmin: json['is_admin'] as bool? ?? false,
    projectId: json['project_id'] as String?,
    projectName: json['project_name'] as String?,
    projectTypeId: json['project_type_id'] as String?,
    pendingRequests: (json['pending_requests'] as num?)?.toInt() ?? 0,
    needsYou: (json['needs_you'] as num?)?.toInt(),
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

  /// Everything that needs you here (S1 badge): join requests, Open items
  /// you own and Done items you may check. Decided by the server.
  final int needsYou;
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
    this.whoCanInvite = SpaceInviters.admins,
    this.myNotify = SpaceNotify.all,
  });

  final String id;
  final String name;
  final String? about;
  final String? projectId;
  final String? projectName;
  final SpacePass myPass;
  final bool iAmAdmin;
  final MemberRights myRights;
  final SpaceInviters whoCanInvite;

  /// The signed-in person's notifications for this Space (S15k-N).
  final SpaceNotify myNotify;

  bool get canInvite => myRights.invite;
}

/// Who may share the invite code (S15k-I). One single choice.
enum SpaceInviters {
  admins('admins'),
  adminsAndLeads('admins_leads'),
  everyone('everyone');

  const SpaceInviters(this.json);
  final String json;

  static SpaceInviters fromJson(Object? value) =>
      values.where((v) => v.json == value).firstOrNull ?? admins;
}

/// Notifications for one Space (S15k-N). One single choice.
enum SpaceNotify {
  all('all'),
  needsYou('needs_you'),
  off('off');

  const SpaceNotify(this.json);
  final String json;

  static SpaceNotify fromJson(Object? value) =>
      values.where((v) => v.json == value).firstOrNull ?? all;
}

/// A person as Space lists show them: name, and role · company.
@immutable
class SpacePerson {
  const SpacePerson({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.headline,
    this.tradeId,
    this.tradeName,
    this.companyLabel,
  });

  /// The embed `profiles(id, first_name, last_name, headline, trade_id,
  /// company_name_text, trade:trades(name), company:companies(name))`.
  factory SpacePerson.fromJson(Map<String, dynamic> json) {
    final trade = json['trade'] as Map<String, dynamic>?;
    final company = json['company'] as Map<String, dynamic>?;
    return SpacePerson(
      id: json['id'] as String,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      headline: json['headline'] as String?,
      tradeId: json['trade_id'] as String?,
      tradeName: trade == null
          ? null
          : LocalizedText.fromJson(trade['name'] as Map<String, dynamic>),
      companyLabel:
          company?['name'] as String? ?? json['company_name_text'] as String?,
    );
  }

  final String id;
  final String firstName;
  final String lastName;
  final String? headline;
  final String? tradeId;
  final LocalizedText? tradeName;
  final String? companyLabel;

  String get fullName => '$firstName $lastName'.trim();

  String? roleLabel(String languageCode) {
    // The headline when set ("BIM Manager"), otherwise the trade.
    if ((headline ?? '').trim().isNotEmpty) return headline;
    if (tradeId == Trade.otherId) return null;
    final name = tradeName;
    if (name == null) return headline;
    return languageCode == 'ar' ? name.ar : name.en;
  }
}

/// A request waiting for the Space admins (S10k "Requests to join").
@immutable
class SpaceJoinRequest {
  const SpaceJoinRequest({
    required this.id,
    required this.person,
    required this.createdAt,
    this.invitedByName,
  });

  final String id;
  final SpacePerson person;
  final DateTime createdAt;

  /// Who shared the code, when known.
  final String? invitedByName;
}

/// A current member of a Space (S10k Owners and Members, S17k).
@immutable
class SpaceMember {
  const SpaceMember({
    required this.person,
    required this.pass,
    required this.isAdmin,
    required this.confirmedAt,
    this.custom = const {},
    this.confirmedById,
    this.confirmedByName,
  });

  final SpacePerson person;
  final SpacePass pass;
  final bool isAdmin;

  /// Rights the admin changed from the pass (create_items, check_items,
  /// add_files, invite).
  final Map<String, bool> custom;
  final String? confirmedById;
  final String? confirmedByName;
  final DateTime confirmedAt;

  bool get isCustom => custom.isNotEmpty;
}

@immutable
class SpaceTeam {
  const SpaceTeam({
    required this.id,
    required this.name,
    this.memberIds = const {},
  });

  final String id;
  final String name;
  final Set<String> memberIds;
}

/// Everything the People tab shows. [requests] is empty for members who
/// are not admins (they can't read them).
@immutable
class SpacePeople {
  const SpacePeople({
    this.requests = const [],
    this.members = const [],
    this.teams = const [],
  });

  final List<SpaceJoinRequest> requests;
  final List<SpaceMember> members;
  final List<SpaceTeam> teams;

  SpaceMember? member(String profileId) =>
      members.where((m) => m.person.id == profileId).firstOrNull;

  List<SpaceTeam> teamsOf(String profileId) => [
    for (final t in teams)
      if (t.memberIds.contains(profileId)) t,
  ];
}

/// The custom rights keys (S17k switches). Chat is always on and
/// mark_done is set by the pass.
abstract final class SpaceRight {
  static const createItems = 'create_items';
  static const checkItems = 'check_items';
  static const addFiles = 'add_files';
  static const invite = 'invite';
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
