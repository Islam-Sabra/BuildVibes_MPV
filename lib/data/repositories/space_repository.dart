import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/widgets/bv_text_field.dart';
import '../models/market.dart';
import '../models/space.dart';
import '../supabase/supabase_provider.dart';

/// Spaces (migration 6). Every change is a database function; the app only
/// reads the tables. Failures arrive as [SpaceException].
abstract class SpaceRepository {
  Future<List<SpaceSummary>> mySpaces();

  /// Your waiting requests, and declined ones from the last 30 days.
  Future<List<MyJoinRequest>> myJoinRequests();

  /// What [code] opens. Null for a wrong or expired code, and after too many
  /// wrong tries (the server doesn't say which).
  Future<InvitePreview?> invitePreview(String code);

  Future<JoinResult> requestJoin(String code);

  Future<void> cancelJoinRequest(String requestId);

  /// A private work Space with you as its admin. Returns its id.
  Future<String> createSpace({
    required String name,
    String? about,
    String? projectId,
  });

  /// Null when the Space is gone or you are not a member.
  Future<SpaceDetail?> fetchSpace(String spaceId);

  /// The live code, made on first use. Needs the invite right.
  Future<SpaceInvite> currentInvite(String spaceId);

  /// A new code; the old one stops working. Admins only.
  Future<SpaceInvite> renewInvite(String spaceId);

  /// Members, Teams and, for admins, the requests waiting to be confirmed.
  Future<SpacePeople> people(String spaceId);

  Future<void> confirmJoin(
    String requestId,
    SpacePass pass, {
    List<String> teamIds = const [],
  });

  /// The person isn't told why.
  Future<void> declineJoin(String requestId);

  Future<void> undoDecline(String requestId);

  /// What [profileId] may do, decided by the server.
  Future<MemberRights> memberRights(String spaceId, String profileId);

  /// The pass and the rights changed from it. The server keeps only the
  /// differences from the pass.
  Future<void> setMemberPass(
    String spaceId,
    String profileId,
    SpacePass pass, {
    Map<String, bool> custom = const {},
  });

  Future<void> setMemberTeams(
    String spaceId,
    String profileId,
    List<String> teamIds,
  );

  /// Fails with [SpaceFailure.rule] when it would leave no admin.
  Future<void> setMemberAdmin(String spaceId, String profileId, bool admin);

  /// Through the handover (review 105B L1): fails with
  /// [SpaceFailure.openWork] while they own open work.
  Future<void> removeMember(String spaceId, String profileId);

  /// Name, About and who can invite. Admins only.
  Future<void> updateSpace(
    String spaceId, {
    required String name,
    String? about,
    required SpaceInviters whoCanInvite,
  });

  /// [until]: how long a level other than All holds (F102); null with
  /// one = always. All clears it.
  Future<void> setNotifications(
    String spaceId,
    SpaceNotify level, {
    DateTime? until,
  });

  /// "On site since": the daybook's day 1. A Space admin only; null clears
  /// it (set_site_start_date, migration 23).
  Future<void> setSiteStartDate(String spaceId, DateTime? day);

  /// [profileId] becomes an admin; you stay as a member.
  Future<void> transferOwnership(String spaceId, String profileId);

  /// Gone for everyone (kept on the server for the record).
  Future<void> deleteSpace(String spaceId);

  /// Fails with [SpaceFailure.rule] for the last admin, and with
  /// [SpaceFailure.openWork] while I own open work (review 105B L1).
  Future<void> leaveSpace(String spaceId);

  /// Returns the new Team's id. A taken name fails with
  /// [SpaceFailure.duplicate].
  Future<String> createTeam(
    String spaceId, {
    required String name,
    List<String> memberIds = const [],
  });

  Future<void> renameTeam(String teamId, String name);

  Future<void> deleteTeam(String teamId);

  /// The Team's members become exactly [memberIds].
  Future<void> setTeamMembers(String teamId, List<String> memberIds);
}

/// How Space lists select a person: name, and role · company.
const _person =
    'id, first_name, last_name, headline, trade_id, company_name_text, '
    'trade:trades(name), company:companies!profiles_company_fk(name)';

/// What people type: spaces and dashes go, letters go upper case, Arabic
/// and Persian digits become 0-9. The server does the same.
String normalizeInviteCode(String typed) => BvWesternDigitsFormatter.normalise(
  typed,
).toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');

class SupabaseSpaceRepository implements SpaceRepository {
  const SupabaseSpaceRepository(this._client);

  final SupabaseClient _client;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on PostgrestException catch (e) {
      throw SpaceException(spaceFailureFor(e.code), e.message);
    } on SpaceException {
      rethrow;
    } on Exception catch (e) {
      // No connection arrives as a SocketException, or wrapped in the http
      // package's ClientException.
      final network = e is SocketException || '$e'.contains('SocketException');
      throw SpaceException(
        network ? SpaceFailure.network : SpaceFailure.unknown,
        '$e',
      );
    }
  }

  List<Map<String, dynamic>> _rows(Object? result) =>
      (result as List? ?? const []).cast<Map<String, dynamic>>();

  @override
  Future<List<SpaceSummary>> mySpaces() => _guard(() async {
    final rows = _rows(await _client.rpc<List<dynamic>>('my_spaces'));
    return [for (final r in rows) SpaceSummary.fromJson(r)];
  });

  @override
  Future<List<MyJoinRequest>> myJoinRequests() => _guard(() async {
    final rows = _rows(await _client.rpc<List<dynamic>>('my_join_requests'));
    return [for (final r in rows) MyJoinRequest.fromJson(r)];
  });

  @override
  Future<InvitePreview?> invitePreview(String code) => _guard(() async {
    final rows = _rows(
      await _client.rpc<List<dynamic>>(
        'invite_preview',
        params: {'p_code': normalizeInviteCode(code)},
      ),
    );
    return rows.isEmpty ? null : InvitePreview.fromJson(rows.first);
  });

  @override
  Future<JoinResult> requestJoin(String code) => _guard(() async {
    final result = await _client.rpc<Map<String, dynamic>>(
      'request_join',
      params: {'p_code': normalizeInviteCode(code)},
    );
    return JoinResult.fromJson(result);
  });

  @override
  Future<void> cancelJoinRequest(String requestId) => _guard(
    () => _client.rpc<void>(
      'cancel_join_request',
      params: {'p_request': requestId},
    ),
  );

  @override
  Future<String> createSpace({
    required String name,
    String? about,
    String? projectId,
  }) => _guard(
    () => _client.rpc<String>(
      'create_space',
      params: {
        'p_name': name.trim(),
        'p_about': about?.trim(),
        'p_project_id': projectId,
      },
    ),
  );

  @override
  Future<SpaceDetail?> fetchSpace(String spaceId) => _guard(() async {
    final me = _client.auth.currentUser?.id;
    if (me == null) return null;
    final space = await _client
        .from('spaces')
        .select(
          'id, name, about, project_id, who_can_invite, site_start_date, '
          'time_zone, '
          'project:projects(name, location_text, place:places(name))',
        )
        .eq('id', spaceId)
        .maybeSingle();
    if (space == null) return null;
    final member = await _client
        .from('space_members')
        .select('pass, is_admin')
        .eq('space_id', spaceId)
        .eq('profile_id', me)
        .isFilter('left_at', null)
        .maybeSingle();
    if (member == null) return null;
    final rights = await _client.rpc<Map<String, dynamic>?>(
      'member_rights',
      params: {'p_space': spaceId, 'p_profile': me},
    );
    // Review 89 M1: my level is mine alone; the table doesn't show it.
    final notify = _rows(
      await _client.rpc<List<dynamic>>(
        'my_space_notify',
        params: {'p_space': spaceId},
      ),
    ).firstOrNull;
    final project = space['project'] as Map<String, dynamic>?;
    final place = project?['place'] as Map<String, dynamic>?;
    return SpaceDetail(
      id: space['id'] as String,
      name: space['name'] as String,
      about: space['about'] as String?,
      projectId: space['project_id'] as String?,
      projectName: project?['name'] as String?,
      projectPlace: place == null
          ? null
          : LocalizedText.fromJson(place['name'] as Map<String, dynamic>),
      projectLocation: project?['location_text'] as String?,
      myPass: SpacePass.fromJson(member['pass']),
      iAmAdmin: member['is_admin'] as bool? ?? false,
      myRights: MemberRights.fromJson(rights),
      whoCanInvite: SpaceInviters.fromJson(space['who_can_invite']),
      // In force now: a passed time is already All (migration 41).
      myNotify: SpaceNotify.fromJson(notify?['notify']),
      siteStartDate: switch (space['site_start_date']) {
        final String day => DateTime.parse(day),
        _ => null,
      },
      timeZone: space['time_zone'] as String?,
    );
  });

  @override
  Future<SpaceInvite> currentInvite(String spaceId) => _guard(() async {
    final rows = _rows(
      await _client.rpc<List<dynamic>>(
        'current_invite',
        params: {'p_space': spaceId},
      ),
    );
    return SpaceInvite.fromJson(rows.single);
  });

  @override
  Future<SpaceInvite> renewInvite(String spaceId) => _guard(() async {
    final rows = _rows(
      await _client.rpc<List<dynamic>>(
        'renew_invite',
        params: {'p_space': spaceId},
      ),
    );
    return SpaceInvite.fromJson(rows.single);
  });

  @override
  Future<SpacePeople> people(String spaceId) => _guard(() async {
    // Each table has several links to profiles: name the one meant.
    final members = await _client
        .from('space_members')
        .select(
          'pass, is_admin, custom, confirmed_by, confirmed_at, '
          'person:profiles!space_members_profile_id_fkey($_person), '
          'confirmer:profiles!space_members_confirmed_by_fkey('
          'first_name, last_name)',
        )
        .eq('space_id', spaceId)
        .isFilter('left_at', null)
        .order('confirmed_at', ascending: true);
    // Admins only; for everyone else row-level security returns nothing.
    final requests = await _client
        .from('space_join_requests')
        .select(
          'id, created_at, '
          'person:profiles!space_join_requests_profile_id_fkey($_person), '
          'inviter:profiles!space_join_requests_invited_by_fkey('
          'first_name, last_name)',
        )
        .eq('space_id', spaceId)
        .eq('status', 'pending')
        .order('created_at', ascending: true);
    final teams = await _client
        .from('teams')
        .select('id, name, members:team_members(profile_id)')
        .eq('space_id', spaceId)
        .order('name', ascending: true);

    return SpacePeople(
      members: [
        for (final m in members)
          if (m['person'] != null)
            SpaceMember(
              person: SpacePerson.fromJson(m['person'] as Map<String, dynamic>),
              pass: SpacePass.fromJson(m['pass']),
              isAdmin: m['is_admin'] as bool? ?? false,
              custom: {
                for (final e
                    in (m['custom'] as Map<String, dynamic>? ?? const {})
                        .entries)
                  if (e.value is bool) e.key: e.value as bool,
              },
              confirmedById: m['confirmed_by'] as String?,
              confirmedByName: _nameOf(m['confirmer']),
              confirmedAt: DateTime.parse(m['confirmed_at'] as String),
            ),
      ],
      requests: [
        for (final r in requests)
          if (r['person'] != null)
            SpaceJoinRequest(
              id: r['id'] as String,
              person: SpacePerson.fromJson(r['person'] as Map<String, dynamic>),
              createdAt: DateTime.parse(r['created_at'] as String),
              invitedByName: _nameOf(r['inviter']),
            ),
      ],
      teams: [
        for (final t in teams)
          SpaceTeam(
            id: t['id'] as String,
            name: t['name'] as String,
            memberIds: {
              for (final m in (t['members'] as List? ?? const []))
                (m as Map<String, dynamic>)['profile_id'] as String,
            },
          ),
      ],
    );
  });

  /// "First Last" from an embedded profile, or null.
  static String? _nameOf(Object? row) {
    if (row is! Map<String, dynamic>) return null;
    final name = '${row['first_name'] ?? ''} ${row['last_name'] ?? ''}'.trim();
    return name.isEmpty ? null : name;
  }

  @override
  Future<void> confirmJoin(
    String requestId,
    SpacePass pass, {
    List<String> teamIds = const [],
  }) => _guard(
    () => _client.rpc<void>(
      'confirm_join',
      params: {
        'p_request': requestId,
        'p_pass': pass.toJson(),
        'p_team_ids': teamIds,
      },
    ),
  );

  @override
  Future<void> declineJoin(String requestId) => _guard(
    () => _client.rpc<void>('decline_join', params: {'p_request': requestId}),
  );

  @override
  Future<void> undoDecline(String requestId) => _guard(
    () => _client.rpc<void>('undo_decline', params: {'p_request': requestId}),
  );

  @override
  Future<MemberRights> memberRights(String spaceId, String profileId) =>
      _guard(() async {
        final rights = await _client.rpc<Map<String, dynamic>?>(
          'member_rights',
          params: {'p_space': spaceId, 'p_profile': profileId},
        );
        return MemberRights.fromJson(rights);
      });

  @override
  Future<void> setMemberPass(
    String spaceId,
    String profileId,
    SpacePass pass, {
    Map<String, bool> custom = const {},
  }) => _guard(
    () => _client.rpc<void>(
      'set_member_pass',
      params: {
        'p_space': spaceId,
        'p_profile': profileId,
        'p_pass': pass.toJson(),
        'p_custom': custom,
      },
    ),
  );

  @override
  Future<void> setMemberTeams(
    String spaceId,
    String profileId,
    List<String> teamIds,
  ) => _guard(
    () => _client.rpc<void>(
      'set_member_teams',
      params: {
        'p_space': spaceId,
        'p_profile': profileId,
        'p_team_ids': teamIds,
      },
    ),
  );

  @override
  Future<void> setMemberAdmin(String spaceId, String profileId, bool admin) =>
      _guard(
        () => _client.rpc<void>(
          'set_member_admin',
          params: {
            'p_space': spaceId,
            'p_profile': profileId,
            'p_admin': admin,
          },
        ),
      );

  @override
  Future<void> removeMember(String spaceId, String profileId) => _guard(
    () => _client.rpc<void>(
      // Review 105B L1: the handover's way; whom the open work goes to is
      // chosen on 105C's sheet.
      'remove_member_with_handover',
      params: {
        'p_space': spaceId,
        'p_member': profileId,
        'p_assignments': const <Object>[],
      },
    ),
  );

  @override
  Future<void> updateSpace(
    String spaceId, {
    required String name,
    String? about,
    required SpaceInviters whoCanInvite,
  }) => _guard(
    () => _client.rpc<void>(
      'update_space',
      params: {
        'p_space': spaceId,
        'p_name': name.trim(),
        'p_about': about?.trim(),
        'p_who_can_invite': whoCanInvite.json,
      },
    ),
  );

  @override
  Future<void> setNotifications(
    String spaceId,
    SpaceNotify level, {
    DateTime? until,
  }) => _guard(
    () => _client.rpc<void>(
      'set_space_notifications',
      params: {
        'p_space': spaceId,
        'p_level': level.json,
        'p_until': level == SpaceNotify.all
            ? null
            : until?.toUtc().toIso8601String(),
      },
    ),
  );

  @override
  Future<void> setSiteStartDate(String spaceId, DateTime? day) => _guard(
    () => _client.rpc<void>(
      'set_site_start_date',
      params: {
        'p_space': spaceId,
        // The phone's own day, as a date with no time.
        'p_day': day == null
            ? null
            : '${day.year.toString().padLeft(4, '0')}-'
                  '${day.month.toString().padLeft(2, '0')}-'
                  '${day.day.toString().padLeft(2, '0')}',
      },
    ),
  );

  @override
  Future<void> transferOwnership(String spaceId, String profileId) => _guard(
    () => _client.rpc<void>(
      'transfer_ownership',
      params: {'p_space': spaceId, 'p_profile': profileId},
    ),
  );

  @override
  Future<void> deleteSpace(String spaceId) => _guard(
    () => _client.rpc<void>('delete_space', params: {'p_space': spaceId}),
  );

  @override
  Future<void> leaveSpace(String spaceId) => _guard(
    () => _client.rpc<void>(
      // Review 105B L1, as removeMember.
      'leave_space_with_handover',
      params: {'p_space': spaceId, 'p_assignments': const <Object>[]},
    ),
  );

  @override
  Future<String> createTeam(
    String spaceId, {
    required String name,
    List<String> memberIds = const [],
  }) => _guard(
    () => _client.rpc<String>(
      'create_team',
      params: {
        'p_space': spaceId,
        'p_name': name.trim(),
        'p_members': memberIds,
      },
    ),
  );

  @override
  Future<void> renameTeam(String teamId, String name) => _guard(
    () => _client.rpc<void>(
      'rename_team',
      params: {'p_team': teamId, 'p_name': name.trim()},
    ),
  );

  @override
  Future<void> deleteTeam(String teamId) => _guard(
    () => _client.rpc<void>('delete_team', params: {'p_team': teamId}),
  );

  @override
  Future<void> setTeamMembers(String teamId, List<String> memberIds) => _guard(
    () => _client.rpc<void>(
      'set_team_members',
      params: {'p_team': teamId, 'p_members': memberIds},
    ),
  );
}

/// Postgres error code → what the app says.
SpaceFailure spaceFailureFor(String? code) => switch (code) {
  '42501' => SpaceFailure.notAllowed,
  'P0001' => SpaceFailure.rule,
  '22023' || '23514' || '22001' => SpaceFailure.badInput,
  '23505' => SpaceFailure.duplicate,
  '54000' => SpaceFailure.limit,
  '40001' => SpaceFailure.conflict,
  'BV001' => SpaceFailure.openWork,
  _ => SpaceFailure.unknown,
};

final spaceRepositoryProvider = Provider<SpaceRepository>(
  (ref) => SupabaseSpaceRepository(ref.watch(supabaseClientProvider)),
);

final mySpacesProvider = FutureProvider.autoDispose<List<SpaceSummary>>(
  (ref) => ref.watch(spaceRepositoryProvider).mySpaces(),
);

final myJoinRequestsProvider = FutureProvider.autoDispose<List<MyJoinRequest>>(
  (ref) => ref.watch(spaceRepositoryProvider).myJoinRequests(),
);

final spaceDetailProvider = FutureProvider.autoDispose
    .family<SpaceDetail?, String>(
      (ref, id) => ref.watch(spaceRepositoryProvider).fetchSpace(id),
    );

final spaceInviteProvider = FutureProvider.autoDispose
    .family<SpaceInvite, String>(
      (ref, id) => ref.watch(spaceRepositoryProvider).currentInvite(id),
    );

final spacePeopleProvider = FutureProvider.autoDispose
    .family<SpacePeople, String>(
      (ref, id) => ref.watch(spaceRepositoryProvider).people(id),
    );

final memberRightsProvider = FutureProvider.autoDispose
    .family<MemberRights, ({String spaceId, String profileId})>(
      (ref, key) => ref
          .watch(spaceRepositoryProvider)
          .memberRights(key.spaceId, key.profileId),
    );
