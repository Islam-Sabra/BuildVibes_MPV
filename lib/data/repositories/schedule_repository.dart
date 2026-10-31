import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/space.dart';
import '../supabase/supabase_provider.dart';
import 'space_repository.dart' show spaceFailureFor;

enum ScheduledState {
  waiting,
  posted,
  failed,
  cancelled;

  static ScheduledState fromJson(Object? v) =>
      values.where((s) => s.name == v).firstOrNull ?? waiting;
}

/// A post of mine that goes out later (review 108 PL2): what it says, when,
/// and where (a Space, or the Feed when [spaceId] is null).
@immutable
class ScheduledPost {
  const ScheduledPost({
    required this.id,
    required this.title,
    required this.publishAt,
    this.state = ScheduledState.waiting,
    this.error,
    this.spaceId,
    this.spaceName,
  });

  factory ScheduledPost.fromJson(Map<String, dynamic> json) => ScheduledPost(
    id: json['id'] as String,
    title: json['title'] as String,
    publishAt: DateTime.parse(json['publish_at'] as String).toLocal(),
    state: ScheduledState.fromJson(json['state']),
    error: json['error'] as String?,
    spaceId: json['space_id'] as String?,
    spaceName: (json['space'] as Map?)?['name'] as String?,
  );

  final String id;
  final String title;
  final DateTime publishAt;
  final ScheduledState state;

  /// Why it couldn't go: not_allowed, not_valid or other.
  final String? error;
  final String? spaceId;
  final String? spaceName;
}

/// The create calls that can go out later (scheduled_posts.fn).
abstract final class ScheduledCall {
  static const spacePost = 'create_space_post';
  static const workItem = 'create_work_item';
  static const feedPost = 'create_post';
  static const noteToFeed = 'share_note_to_feed';
  static const noteToSpace = 'share_note_to_space';
}

/// Post later (review 108 PL1, PL2). The server keeps the create call and
/// makes it as me at the time, with every rule checked again then.
abstract class ScheduleRepository {
  /// schedule_post: [call] with [params] at [at]; [title] is what Scheduled
  /// shows. [id] is the post's own. [noteId]: the note in My notebook it
  /// was put in from, marked once it goes (review 108 V8).
  Future<void> schedule({
    required String id,
    required String call,
    required Map<String, dynamic> params,
    required DateTime at,
    required String title,
    String? noteId,
  });

  /// update_scheduled_post: another time.
  Future<void> reschedule(String id, DateTime at);

  /// cancel_scheduled_post.
  Future<void> cancel(String id);

  /// post_scheduled_now: true when it went.
  Future<bool> postNow(String id);

  /// Mine still waiting, and the ones that couldn't go, soonest first.
  Future<List<ScheduledPost>> mine();
}

class SupabaseScheduleRepository implements ScheduleRepository {
  const SupabaseScheduleRepository(this._client);

  final SupabaseClient _client;

  /// As the Space repository's: the server's refusal by its code; no
  /// connection is SpaceFailure.network.
  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on PostgrestException catch (e) {
      throw SpaceException(spaceFailureFor(e.code), e.message);
    } on SpaceException {
      rethrow;
    } on Exception catch (e) {
      final network = e is SocketException || '$e'.contains('SocketException');
      throw SpaceException(
        network ? SpaceFailure.network : SpaceFailure.unknown,
        '$e',
      );
    }
  }

  @override
  Future<void> schedule({
    required String id,
    required String call,
    required Map<String, dynamic> params,
    required DateTime at,
    required String title,
    String? noteId,
  }) => _guard(
    () => _client.rpc<void>(
      'schedule_post',
      params: {
        'p_id': id,
        'p_fn': call,
        'p_params': params,
        'p_at': at.toUtc().toIso8601String(),
        'p_title': title,
        'p_note': ?noteId,
      },
    ),
  );

  @override
  Future<void> reschedule(String id, DateTime at) => _guard(
    () => _client.rpc<void>(
      'update_scheduled_post',
      params: {'p_id': id, 'p_at': at.toUtc().toIso8601String()},
    ),
  );

  @override
  Future<void> cancel(String id) => _guard(
    () => _client.rpc<void>('cancel_scheduled_post', params: {'p_id': id}),
  );

  @override
  Future<bool> postNow(String id) => _guard(
    () => _client.rpc<bool>('post_scheduled_now', params: {'p_id': id}),
  );

  @override
  Future<List<ScheduledPost>> mine() => _guard(() async {
    final rows = await _client
        .from('scheduled_posts')
        .select(
          'id, title, publish_at, state, error, space_id, space:spaces(name)',
        )
        .inFilter('state', ['waiting', 'failed'])
        .order('publish_at');
    return [for (final r in rows) ScheduledPost.fromJson(r)];
  });
}

final scheduleRepositoryProvider = Provider<ScheduleRepository>(
  (ref) => SupabaseScheduleRepository(ref.watch(supabaseClientProvider)),
);

/// My posts that go out later, and the ones that couldn't (PL2).
final myScheduledProvider = FutureProvider.autoDispose<List<ScheduledPost>>(
  (ref) => ref.watch(scheduleRepositoryProvider).mine(),
);
