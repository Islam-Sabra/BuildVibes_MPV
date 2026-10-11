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
        checkItems: true,
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
}
