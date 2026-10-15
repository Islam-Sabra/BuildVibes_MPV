import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/repositories/space_repository.dart';

/// A live invite code in the fake: what it opens and for which Space.
class FakeInvite {
  const FakeInvite({
    required this.spaceId,
    required this.spaceName,
    this.invitedBy,
  });

  final String spaceId;
  final String spaceName;
  final String? invitedBy;
}

/// Spaces with no network. Codes in [invites] are valid; anything else is
/// "not valid", like the server.
class FakeSpaceRepository implements SpaceRepository {
  FakeSpaceRepository({DateTime? now}) : now = now ?? DateTime(2026, 10, 11);

  final DateTime now;
  final spaces = <SpaceSummary>[];
  final requests = <MyJoinRequest>[];
  final invites = <String, FakeInvite>{};
  final details = <String, SpaceDetail>{};
  final codes = <String, SpaceInvite>{};
  final created = <({String name, String? about, String? projectId})>[];
  final cancelled = <String>[];

  /// Overrides what request_join answers ("declined", "too many tries").
  JoinStatus? joinStatus;
  SpaceFailure? createFailure;

  static const newSpaceId = 'space-new';

  @override
  Future<List<SpaceSummary>> mySpaces() async => List.of(spaces);

  @override
  Future<List<MyJoinRequest>> myJoinRequests() async => List.of(requests);

  @override
  Future<InvitePreview?> invitePreview(String code) async {
    final invite = invites[normalizeInviteCode(code)];
    return invite == null
        ? null
        : InvitePreview(
            spaceName: invite.spaceName,
            invitedByName: invite.invitedBy,
            expiresAt: now.add(const Duration(days: 7)),
          );
  }

  @override
  Future<JoinResult> requestJoin(String code) async {
    final invite = invites[normalizeInviteCode(code)];
    final forced = joinStatus;
    if (forced != null) {
      return JoinResult(
        status: forced,
        spaceId: invite?.spaceId,
        spaceName: invite?.spaceName,
      );
    }
    if (invite == null) return const JoinResult(status: JoinStatus.notValid);
    requests.add(
      MyJoinRequest(
        id: 'request-${requests.length + 1}',
        spaceId: invite.spaceId,
        spaceName: invite.spaceName,
        status: JoinRequestStatus.pending,
        createdAt: now,
      ),
    );
    return JoinResult(
      status: JoinStatus.requested,
      spaceId: invite.spaceId,
      spaceName: invite.spaceName,
    );
  }

  @override
  Future<void> cancelJoinRequest(String requestId) async {
    cancelled.add(requestId);
    requests.removeWhere((r) => r.id == requestId);
  }

  @override
  Future<String> createSpace({
    required String name,
    String? about,
    String? projectId,
  }) async {
    final failure = createFailure;
    if (failure != null) throw SpaceException(failure);
    created.add((name: name.trim(), about: about, projectId: projectId));
    spaces.add(
      SpaceSummary(
        id: newSpaceId,
        name: name.trim(),
        pass: SpacePass.lead,
        isAdmin: true,
        projectId: projectId,
      ),
    );
    details[newSpaceId] = SpaceDetail(
      id: newSpaceId,
      name: name.trim(),
      about: about,
      projectId: projectId,
      myPass: SpacePass.lead,
      iAmAdmin: true,
      myRights: const MemberRights(
        createItems: true,
        addFiles: true,
        invite: true,
        markDone: true,
      ),
    );
    return newSpaceId;
  }

  @override
  Future<SpaceDetail?> fetchSpace(String spaceId) async => details[spaceId];

  @override
  Future<SpaceInvite> currentInvite(String spaceId) async {
    if (!(details[spaceId]?.canInvite ?? false)) {
      throw const SpaceException(SpaceFailure.notAllowed);
    }
    return codes[spaceId] ??= SpaceInvite(
      code: 'K7Q4MD',
      expiresAt: now.add(const Duration(days: 7)),
    );
  }

  @override
  Future<SpaceInvite> renewInvite(String spaceId) async {
    if (!(details[spaceId]?.iAmAdmin ?? false)) {
      throw const SpaceException(SpaceFailure.notAllowed);
    }
    return codes[spaceId] = SpaceInvite(
      code: 'P2X9RT',
      expiresAt: now.add(const Duration(days: 7)),
    );
  }

  // People (part 2) ---------------------------------------------------------

  /// Members, Teams and pending requests per Space.
  final spacePeople = <String, SpacePeople>{};
  final declined = <String, SpaceJoinRequest>{};
  final calls = <String>[];

  /// Who is signed in, for "Confirmed by you".
  String me = 'user-1';

  SpacePeople _of(String spaceId) =>
      spacePeople[spaceId] ?? const SpacePeople();

  String? _spaceOfRequest(String requestId) => spacePeople.entries
      .where((e) => e.value.requests.any((r) => r.id == requestId))
      .firstOrNull
      ?.key;

  void _put(
    String spaceId, {
    List<SpaceJoinRequest>? requests,
    List<SpaceMember>? members,
    List<SpaceTeam>? teams,
  }) {
    final p = _of(spaceId);
    spacePeople[spaceId] = SpacePeople(
      requests: requests ?? p.requests,
      members: members ?? p.members,
      teams: teams ?? p.teams,
    );
  }

  SpaceMember _copy(
    SpaceMember m, {
    SpacePass? pass,
    bool? isAdmin,
    Map<String, bool>? custom,
  }) => SpaceMember(
    person: m.person,
    pass: pass ?? m.pass,
    isAdmin: isAdmin ?? m.isAdmin,
    custom: custom ?? m.custom,
    confirmedAt: m.confirmedAt,
    confirmedById: m.confirmedById,
    confirmedByName: m.confirmedByName,
  );

  @override
  Future<SpacePeople> people(String spaceId) async => _of(spaceId);

  @override
  Future<void> confirmJoin(
    String requestId,
    SpacePass pass, {
    List<String> teamIds = const [],
  }) async {
    calls.add('confirm $requestId ${pass.name}');
    final spaceId = _spaceOfRequest(requestId);
    if (spaceId == null) throw const SpaceException(SpaceFailure.rule);
    final p = _of(spaceId);
    final request = p.requests.firstWhere((r) => r.id == requestId);
    _put(
      spaceId,
      requests: [
        for (final r in p.requests)
          if (r.id != requestId) r,
      ],
      members: [
        ...p.members,
        SpaceMember(
          person: request.person,
          pass: pass,
          isAdmin: false,
          confirmedAt: now,
          confirmedById: me,
        ),
      ],
    );
  }

  @override
  Future<void> declineJoin(String requestId) async {
    calls.add('decline $requestId');
    final spaceId = _spaceOfRequest(requestId);
    if (spaceId == null) throw const SpaceException(SpaceFailure.rule);
    final p = _of(spaceId);
    declined[requestId] = p.requests.firstWhere((r) => r.id == requestId);
    _put(
      spaceId,
      requests: [
        for (final r in p.requests)
          if (r.id != requestId) r,
      ],
    );
  }

  @override
  Future<void> undoDecline(String requestId) async {
    calls.add('undo $requestId');
    final request = declined.remove(requestId);
    if (request == null) throw const SpaceException(SpaceFailure.rule);
    final spaceId = spacePeople.keys.first;
    _put(spaceId, requests: [..._of(spaceId).requests, request]);
  }

  /// The server's presets, for the fake only (the app never has them).
  static const _presets = {
    SpacePass.lead: {
      SpaceRight.createItems: true,
      SpaceRight.addFiles: true,
      SpaceRight.invite: true,
    },
    SpacePass.crew: {
      SpaceRight.createItems: true,
      SpaceRight.addFiles: true,
      SpaceRight.invite: false,
    },
    SpacePass.viewer: {
      SpaceRight.createItems: false,
      SpaceRight.addFiles: false,
      SpaceRight.invite: false,
    },
  };

  @override
  Future<MemberRights> memberRights(String spaceId, String profileId) async {
    final m = _of(spaceId).member(profileId);
    if (m == null) return const MemberRights();
    bool has(String right) =>
        m.isAdmin || (m.custom[right] ?? _presets[m.pass]![right]!);
    return MemberRights(
      createItems: has(SpaceRight.createItems),
      addFiles: has(SpaceRight.addFiles),
      invite: has(SpaceRight.invite),
      markDone: m.pass != SpacePass.viewer,
      isCustom: m.custom.isNotEmpty,
    );
  }

  @override
  Future<void> setMemberPass(
    String spaceId,
    String profileId,
    SpacePass pass, {
    Map<String, bool> custom = const {},
  }) async {
    calls.add('pass $profileId ${pass.name} $custom');
    // Like the server: keep only the differences from the pass.
    final kept = {
      for (final e in custom.entries)
        if (_presets[pass]![e.key] != e.value) e.key: e.value,
    };
    _put(
      spaceId,
      members: [
        for (final m in _of(spaceId).members)
          m.person.id == profileId ? _copy(m, pass: pass, custom: kept) : m,
      ],
    );
  }

  @override
  Future<void> setMemberTeams(
    String spaceId,
    String profileId,
    List<String> teamIds,
  ) async {
    calls.add('teams $profileId $teamIds');
    _put(
      spaceId,
      teams: [
        for (final t in _of(spaceId).teams)
          SpaceTeam(
            id: t.id,
            name: t.name,
            memberIds: teamIds.contains(t.id)
                ? {...t.memberIds, profileId}
                : ({...t.memberIds}..remove(profileId)),
          ),
      ],
    );
  }

  @override
  Future<void> setMemberAdmin(
    String spaceId,
    String profileId,
    bool admin,
  ) async {
    calls.add('admin $profileId $admin');
    final others = _of(
      spaceId,
    ).members.where((m) => m.isAdmin && m.person.id != profileId);
    if (!admin && others.isEmpty) {
      throw const SpaceException(SpaceFailure.rule);
    }
    _put(
      spaceId,
      members: [
        for (final m in _of(spaceId).members)
          m.person.id == profileId ? _copy(m, isAdmin: admin) : m,
      ],
    );
  }

  @override
  Future<void> removeMember(String spaceId, String profileId) async {
    calls.add('remove $profileId');
    _put(
      spaceId,
      members: [
        for (final m in _of(spaceId).members)
          if (m.person.id != profileId) m,
      ],
    );
  }

  // Space info and Teams (part 3) --------------------------------------------

  SpaceDetail _detail(
    SpaceDetail d, {
    String? name,
    String? about,
    bool? iAmAdmin,
    SpaceInviters? whoCanInvite,
    SpaceNotify? myNotify,
  }) => SpaceDetail(
    id: d.id,
    name: name ?? d.name,
    about: about ?? d.about,
    projectId: d.projectId,
    projectName: d.projectName,
    myPass: d.myPass,
    iAmAdmin: iAmAdmin ?? d.iAmAdmin,
    myRights: d.myRights,
    whoCanInvite: whoCanInvite ?? d.whoCanInvite,
    myNotify: myNotify ?? d.myNotify,
  );

  @override
  Future<void> updateSpace(
    String spaceId, {
    required String name,
    String? about,
    required SpaceInviters whoCanInvite,
  }) async {
    calls.add('update $name ${whoCanInvite.json}');
    details[spaceId] = _detail(
      details[spaceId]!,
      name: name,
      about: about,
      whoCanInvite: whoCanInvite,
    );
  }

  @override
  Future<void> setNotifications(String spaceId, SpaceNotify level) async {
    calls.add('notify ${level.json}');
    details[spaceId] = _detail(details[spaceId]!, myNotify: level);
  }

  @override
  Future<void> transferOwnership(String spaceId, String profileId) async {
    calls.add('transfer $profileId');
    _put(
      spaceId,
      members: [
        for (final m in _of(spaceId).members)
          if (m.person.id == profileId)
            _copy(m, isAdmin: true)
          else if (m.person.id == me)
            _copy(m, isAdmin: false)
          else
            m,
      ],
    );
    details[spaceId] = _detail(details[spaceId]!, iAmAdmin: false);
  }

  @override
  Future<void> deleteSpace(String spaceId) async {
    calls.add('delete $spaceId');
    details.remove(spaceId);
    spaces.removeWhere((s) => s.id == spaceId);
  }

  @override
  Future<void> leaveSpace(String spaceId) async {
    final mine = _of(spaceId).member(me);
    final otherAdmin = _of(
      spaceId,
    ).members.any((m) => m.isAdmin && m.person.id != me);
    if ((mine?.isAdmin ?? false) && !otherAdmin) {
      throw const SpaceException(SpaceFailure.rule);
    }
    calls.add('leave $spaceId');
    details.remove(spaceId);
    spaces.removeWhere((s) => s.id == spaceId);
  }

  @override
  Future<String> createTeam(
    String spaceId, {
    required String name,
    List<String> memberIds = const [],
  }) async {
    final taken = _of(
      spaceId,
    ).teams.any((t) => t.name.toLowerCase() == name.trim().toLowerCase());
    if (taken) throw const SpaceException(SpaceFailure.duplicate);
    calls.add('team ${name.trim()} $memberIds');
    final id = 'team-${_of(spaceId).teams.length + 1}';
    _put(
      spaceId,
      teams: [
        ..._of(spaceId).teams,
        SpaceTeam(id: id, name: name.trim(), memberIds: {...memberIds}),
      ],
    );
    return id;
  }

  String _spaceOfTeam(String teamId) => spacePeople.entries
      .firstWhere((e) => e.value.teams.any((t) => t.id == teamId))
      .key;

  @override
  Future<void> renameTeam(String teamId, String name) async {
    calls.add('rename $teamId $name');
    final spaceId = _spaceOfTeam(teamId);
    _put(
      spaceId,
      teams: [
        for (final t in _of(spaceId).teams)
          t.id == teamId
              ? SpaceTeam(id: t.id, name: name, memberIds: t.memberIds)
              : t,
      ],
    );
  }

  @override
  Future<void> deleteTeam(String teamId) async {
    calls.add('delete team $teamId');
    final spaceId = _spaceOfTeam(teamId);
    _put(
      spaceId,
      teams: [
        for (final t in _of(spaceId).teams)
          if (t.id != teamId) t,
      ],
    );
  }

  @override
  Future<void> setTeamMembers(String teamId, List<String> memberIds) async {
    calls.add('team members $teamId $memberIds');
    final spaceId = _spaceOfTeam(teamId);
    _put(
      spaceId,
      teams: [
        for (final t in _of(spaceId).teams)
          t.id == teamId
              ? SpaceTeam(id: t.id, name: t.name, memberIds: {...memberIds})
              : t,
      ],
    );
  }
}
