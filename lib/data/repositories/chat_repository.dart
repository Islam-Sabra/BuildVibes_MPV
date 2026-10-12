import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat.dart';
import '../models/space.dart';
import '../supabase/supabase_provider.dart';
import 'space_repository.dart';

/// Space chat (migration 9). Every write is a function call; the server
/// decides who may read each thread.
abstract class ChatRepository {
  /// Everyone first, then the Teams you may see (S7k).
  Future<List<ChatThread>> threads(String spaceId);

  /// The newest [limit] messages, or those before [before], newest first.
  Future<List<ChatMessage>> messages(
    String threadId, {
    DateTime? before,
    int limit = 50,
  });

  /// One message, after a live change. Null when you can't see it.
  Future<ChatMessage?> message(String id);

  /// [id] is chosen by the app: a retry never posts twice.
  Future<void> post({
    required String id,
    required String threadId,
    required String body,
    String? replyTo,
  });

  /// Its author or a Space admin. It stays as "Message deleted".
  Future<void> delete(String id);

  Future<void> markRead(String threadId);

  /// The ids of messages added or changed in [threadId], live.
  Stream<String> changes(String threadId);
}

class SupabaseChatRepository implements ChatRepository {
  const SupabaseChatRepository(this._client);

  final SupabaseClient _client;

  // messages links to profiles twice (author, deleted_by): name the one.
  // The quoted message is a link to messages itself: PostgREST finds it by
  // the column (reply_to), not by the constraint's name.
  static const _message =
      'id, thread_id, kind, body, author_id, work_item_id, created_at, '
      'deleted_at, '
      'author:profiles!messages_author_id_fkey(first_name, last_name), '
      'event:work_item_events(kind), '
      'parent:reply_to(id, kind, body, deleted_at, '
      'author:profiles!messages_author_id_fkey(first_name, last_name))';

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

  @override
  Future<List<ChatThread>> threads(String spaceId) => _guard(() async {
    final rows = await _client.rpc(
      'space_threads',
      params: {'p_space': spaceId},
    );
    return [
      for (final r in rows as List)
        ChatThread.fromJson(r as Map<String, dynamic>),
    ];
  });

  @override
  Future<List<ChatMessage>> messages(
    String threadId, {
    DateTime? before,
    int limit = 50,
  }) => _guard(() async {
    var query = _client
        .from('messages')
        .select(_message)
        .eq('thread_id', threadId);
    if (before != null) {
      query = query.lt('created_at', before.toUtc().toIso8601String());
    }
    final rows = await query.order('created_at', ascending: false).limit(limit);
    return [for (final r in rows) ChatMessage.fromJson(r)];
  });

  @override
  Future<ChatMessage?> message(String id) => _guard(() async {
    final row = await _client
        .from('messages')
        .select(_message)
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : ChatMessage.fromJson(row);
  });

  @override
  Future<void> post({
    required String id,
    required String threadId,
    required String body,
    String? replyTo,
  }) => _guard(
    () => _client.rpc(
      'post_message',
      params: {
        'p_id': id,
        'p_thread': threadId,
        'p_body': body,
        'p_reply_to': replyTo,
      },
    ),
  );

  @override
  Future<void> delete(String id) =>
      _guard(() => _client.rpc('delete_message', params: {'p_id': id}));

  @override
  Future<void> markRead(String threadId) => _guard(
    () => _client.rpc('mark_thread_read', params: {'p_thread': threadId}),
  );

  @override
  Stream<String> changes(String threadId) {
    late final RealtimeChannel channel;
    final controller = StreamController<String>(
      onCancel: () => _client.removeChannel(channel),
    );
    channel = _client
        .channel('thread:$threadId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'thread_id',
            value: threadId,
          ),
          callback: (payload) {
            final id = payload.newRecord['id'] ?? payload.oldRecord['id'];
            if (id is String && !controller.isClosed) controller.add(id);
          },
        )
        .subscribe();
    return controller.stream;
  }
}

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => SupabaseChatRepository(ref.watch(supabaseClientProvider)),
);

/// One message, for example a thread's last one when it is a card.
final chatMessageProvider = FutureProvider.autoDispose
    .family<ChatMessage?, String>(
      (ref, id) => ref.watch(chatRepositoryProvider).message(id),
    );

final spaceThreadsProvider = FutureProvider.autoDispose
    .family<List<ChatThread>, String>(
      (ref, spaceId) => ref.watch(chatRepositoryProvider).threads(spaceId),
    );
