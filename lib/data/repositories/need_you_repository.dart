import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/need_you.dart';
import '../models/space.dart';
import '../supabase/supabase_provider.dart';
import 'space_repository.dart' show spaceFailureFor;

/// Review 113 (18): Need you now. Who may call whom is the server's
/// (send_need_you); failures arrive as [SpaceException].
abstract class NeedYouRepository {
  /// [id] is the app's, so sending again is the same call.
  Future<void> send({
    required String id,
    required String spaceId,
    required String toId,
    String? reason,
    String? place,
  });

  Future<void> answer(String callId, NeedYouAnswer answer);

  /// Calls I sent or got in the last 24 hours; every Space when
  /// [spaceId] is null.
  Future<List<NeedYouCall>> calls({String? spaceId});
}

class SupabaseNeedYouRepository implements NeedYouRepository {
  const SupabaseNeedYouRepository(this._client);

  final SupabaseClient _client;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on PostgrestException catch (e) {
      throw SpaceException(spaceFailureFor(e.code), e.message);
    } on Exception catch (e) {
      final network = e is SocketException || '$e'.contains('SocketException');
      throw SpaceException(
        network ? SpaceFailure.network : SpaceFailure.unknown,
        '$e',
      );
    }
  }

  static String? _text(String? t) {
    final v = t?.trim();
    return v == null || v.isEmpty ? null : v;
  }

  @override
  Future<void> send({
    required String id,
    required String spaceId,
    required String toId,
    String? reason,
    String? place,
  }) => _guard(
    () => _client.rpc(
      'send_need_you',
      params: {
        'p_id': id,
        'p_space': spaceId,
        'p_to': toId,
        'p_reason': _text(reason),
        'p_place': _text(place),
      },
    ),
  );

  @override
  Future<void> answer(String callId, NeedYouAnswer answer) => _guard(
    () => _client.rpc(
      'answer_need_you',
      params: {'p_call': callId, 'p_answer': answer.json},
    ),
  );

  @override
  Future<List<NeedYouCall>> calls({String? spaceId}) => _guard(() async {
    final rows = await _client.rpc<List<dynamic>>(
      'my_need_you_calls',
      params: {'p_space': spaceId},
    );
    return [
      for (final r in rows) NeedYouCall.fromJson(r as Map<String, dynamic>),
    ];
  });
}

final needYouRepositoryProvider = Provider<NeedYouRepository>(
  (ref) => SupabaseNeedYouRepository(ref.watch(supabaseClientProvider)),
);

/// The calls that show in a Space.
final needYouCallsProvider = FutureProvider.autoDispose
    .family<List<NeedYouCall>, String>(
      (ref, spaceId) =>
          ref.watch(needYouRepositoryProvider).calls(spaceId: spaceId),
    );
