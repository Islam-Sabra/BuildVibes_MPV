import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat.dart';
import '../models/library.dart';
import '../models/space.dart';
import '../supabase/live_broadcast.dart';
import '../supabase/supabase_provider.dart';
import 'space_repository.dart';
import 'work_repository.dart' show newUuid;

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

  /// [id] is chosen by the app: a retry never posts twice. [attachments]
  /// are already uploaded to `<space>/chat/<id>/`.
  Future<void> post({
    required String id,
    required String threadId,
    required String body,
    String? replyTo,
    List<ChatUpload> attachments = const [],
  });

  /// Uploads a file for message [messageId]; returns its path. A new name
  /// on every call, so a retry never replaces a file.
  Future<String> upload(String spaceId, String messageId, PhoneFile file);

  /// F1 "Share in chat": a message that shows a Library file.
  Future<void> shareFile({
    required String id,
    required String threadId,
    required String fileId,
    String? body,
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
  static const _file =
      'id, space_id, team_id, name, storage_path, mime, bytes, rev_label, '
      'note, supersedes_id, source, uploaded_by, created_at';

  static const _message =
      'id, thread_id, kind, body, author_id, work_item_id, created_at, '
      'deleted_at, report_week, post_id, '
      'attachments:message_attachments(storage_path, mime, bytes, duration_ms, sort), '
      'docs:library_files!library_files_source_message_id_fkey($_file), '
      'shared:library_files!messages_library_file_id_fkey($_file), '
      'author:profiles!messages_author_id_fkey(first_name, last_name), '
      'event:work_item_events(kind), '
      'parent:reply_to(id, kind, body, deleted_at, '
      'author:profiles!messages_author_id_fkey(first_name, last_name))';

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on PostgrestException catch (e) {
      throw SpaceException(spaceFailureFor(e.code), e.message);
    } on StorageException catch (e) {
      throw SpaceException(SpaceFailure.unknown, e.message);
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
    List<ChatUpload> attachments = const [],
  }) => _guard(
    () => _client.rpc(
      'post_message',
      params: {
        'p_id': id,
        'p_thread': threadId,
        'p_body': body,
        'p_reply_to': replyTo,
        'p_attachments': [for (final a in attachments) a.toJson()],
      },
    ),
  );

  @override
  Future<String> upload(String spaceId, String messageId, PhoneFile file) =>
      _guard(() async {
        final path = '$spaceId/chat/$messageId/${newUuid()}.${file.extension}';
        await _client.storage
            .from('space-files')
            .upload(
              path,
              File(file.local),
              fileOptions: FileOptions(contentType: file.mime),
            );
        return path;
      });

  @override
  Future<void> shareFile({
    required String id,
    required String threadId,
    required String fileId,
    String? body,
  }) => _guard(
    () => _client.rpc(
      'share_library_file',
      params: {
        'p_id': id,
        'p_thread': threadId,
        'p_file': fileId,
        'p_body': body,
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

  /// F103 (migration 43): the database broadcasts each new or deleted
  /// message on the thread's private topic, with ids only; the thread
  /// reads the message again by id. Joined again by itself when lost.
  @override
  Stream<String> changes(String threadId) => privateBroadcasts(
    _client,
    'thread:$threadId',
    'chat',
    describe: (p) => 'message=${p['message_id']} op=${p['op']}',
  ).map(messageIdFromBroadcast).where((id) => id != null).cast<String>();

  /// The message id in migration 43's payload, `{thread_id, message_id,
  /// author_id, op}`.
  @visibleForTesting
  static String? messageIdFromBroadcast(Map<String, dynamic> payload) {
    final id = payload['message_id'];
    return id is String ? id : null;
  }
}

/// An uploaded attachment for post_message. [name] is the file's own name,
/// so a PDF reaches the Library with a proper title.
class ChatUpload {
  const ChatUpload({
    required this.path,
    required this.mime,
    this.bytes,
    this.name,
    this.durationMs,
  });

  final String path;
  final String mime;
  final int? bytes;
  final String? name;

  /// A voice note's length.
  final int? durationMs;

  Map<String, dynamic> toJson() => {
    'path': path,
    'mime': mime,
    'bytes': ?bytes,
    'name': ?name,
    'duration_ms': ?durationMs,
  };
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
