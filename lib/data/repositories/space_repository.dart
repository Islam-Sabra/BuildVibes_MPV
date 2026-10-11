import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/widgets/bv_text_field.dart';
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
}

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
        .select('id, name, about, project_id, project:projects(name)')
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
    final project = space['project'] as Map<String, dynamic>?;
    return SpaceDetail(
      id: space['id'] as String,
      name: space['name'] as String,
      about: space['about'] as String?,
      projectId: space['project_id'] as String?,
      projectName: project?['name'] as String?,
      myPass: SpacePass.fromJson(member['pass']),
      iAmAdmin: member['is_admin'] as bool? ?? false,
      myRights: MemberRights.fromJson(rights),
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
}

/// Postgres error code → what the app says.
SpaceFailure spaceFailureFor(String? code) => switch (code) {
  '42501' => SpaceFailure.notAllowed,
  'P0001' => SpaceFailure.rule,
  '22023' || '23514' || '22001' => SpaceFailure.badInput,
  '23505' => SpaceFailure.duplicate,
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
