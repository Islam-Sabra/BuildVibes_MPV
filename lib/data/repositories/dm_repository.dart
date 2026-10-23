import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/dm.dart';
import '../models/library.dart';
import '../models/space.dart';
import '../supabase/supabase_provider.dart';
import 'space_repository.dart';
import 'work_repository.dart' show newUuid;

/// Direct messages between two people (migration 22). Every write is a
/// function call; the server decides who may read a thread (only its two
/// people, never across a block).
abstract class DmRepository {
  /// The Messages list (DM1): open threads newest first, and the newest
  /// Message request.
  Future<DmInbox> inbox();

  /// Every Message request, newest first.
  Future<List<DmRow>> requests();

  /// A thread with its newest messages, or those before [before]. Null
  /// when it can't be read (a block, or not yours).
  Future<DmThreadPage?> page(
    String threadId, {
    DateTime? before,
    String? beforeId,
  });

  /// Starts a thread with [to] with its first message (or finds the pair's
  /// thread). The app chose [threadId] and [messageId].
  Future<DmStart> start({
    required String threadId,
    required String to,
    required String messageId,
    String? body,
    List<DmUpload> attachments = const [],
  });

  /// [id] is chosen by the app: a retry never sends twice.
  Future<void> send({
    required String id,
    required String threadId,
    String? body,
    String? replyTo,
    List<DmUpload> attachments = const [],
  });

  /// Uploads [file] for message [messageId] into my own folder; returns its
  /// path.
  Future<String> upload(String messageId, PhoneFile file);

  /// A short-lived link to a file of a message I may read.
  Future<String> fileUrl(String path);

  Future<void> markRead(String threadId);
  Future<void> decline(String threadId);
  Future<void> mute(String threadId, {required bool on});

  /// My own message; it stays as "Message deleted".
  Future<void> delete(String id);

  /// [threadId] live, on its private `dm:` channel (migration 31): joined,
  /// then each message added or changed. When the channel closes, errors or
  /// times out, the stream ends with a [DmLiveLost] error; the caller opens
  /// it again (F100).
  Stream<DmLiveEvent> changes(String threadId);
}

/// What a thread's live channel says (F100).
@immutable
sealed class DmLiveEvent {
  const DmLiveEvent();
}

/// The channel is joined: what happens now arrives live.
class DmLiveJoined extends DmLiveEvent {
  const DmLiveJoined();
}

/// A message added ([inserted]) or changed (a delete, an edit).
class DmLiveRow extends DmLiveEvent {
  const DmLiveRow({
    required this.id,
    this.inserted = false,
    this.authorId,
    this.kind,
    this.body,
    this.deleted = false,
  });

  final String id;
  final bool inserted;
  final String? authorId;
  final String? kind;
  final String? body;
  final bool deleted;
}

/// The channel closed, errored or timed out.
class DmLiveLost implements Exception {
  const DmLiveLost(this.status, [this.error]);

  final String status;
  final Object? error;

  @override
  String toString() => 'DmLiveLost($status${error == null ? '' : ', $error'})';
}

class SupabaseDmRepository implements DmRepository {
  const SupabaseDmRepository(this._client);

  final SupabaseClient _client;

  static const bucket = 'dm-files';

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
  Future<DmInbox> inbox() => _guard(() async {
    final json = await _client.rpc('my_dm_threads');
    return DmInbox.fromJson(json as Map<String, dynamic>);
  });

  @override
  Future<List<DmRow>> requests() => _guard(() async {
    final rows = await _client.rpc('my_dm_requests');
    return [
      for (final r in rows as List) DmRow.fromJson(r as Map<String, dynamic>),
    ];
  });

  @override
  Future<DmThreadPage?> page(
    String threadId, {
    DateTime? before,
    String? beforeId,
  }) => _guard(() async {
    final json = await _client.rpc(
      'dm_thread_page',
      params: {
        'p_thread': threadId,
        'p_before': before?.toUtc().toIso8601String(),
        'p_before_id': beforeId,
      },
    );
    return json == null
        ? null
        : DmThreadPage.fromJson(json as Map<String, dynamic>);
  });

  @override
  Future<DmStart> start({
    required String threadId,
    required String to,
    required String messageId,
    String? body,
    List<DmUpload> attachments = const [],
  }) => _guard(() async {
    final json = await _client.rpc(
      'start_dm',
      params: {
        'p_thread': threadId,
        'p_to': to,
        'p_message': messageId,
        'p_body': body,
        'p_attachments': [for (final a in attachments) a.toJson()],
      },
    );
    return DmStart.fromJson(json as Map<String, dynamic>);
  });

  @override
  Future<void> send({
    required String id,
    required String threadId,
    String? body,
    String? replyTo,
    List<DmUpload> attachments = const [],
  }) => _guard(
    () => _client.rpc(
      'send_dm',
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
  Future<String> upload(String messageId, PhoneFile file) => _guard(() async {
    final me = _client.auth.currentUser!.id;
    final path = '$me/$messageId/${newUuid()}.${file.extension}';
    await _client.storage
        .from(bucket)
        .upload(
          path,
          File(file.local),
          fileOptions: FileOptions(contentType: file.mime),
        );
    return path;
  });

  @override
  Future<String> fileUrl(String path) => _guard(
    () => _client.storage.from(bucket).createSignedUrl(path, _linkSeconds),
  );

  /// How long a file link lasts.
  static const _linkSeconds = 600;

  @override
  Future<void> markRead(String threadId) =>
      _guard(() => _client.rpc('mark_dm_read', params: {'p_thread': threadId}));

  @override
  Future<void> decline(String threadId) =>
      _guard(() => _client.rpc('decline_dm', params: {'p_thread': threadId}));

  @override
  Future<void> mute(String threadId, {required bool on}) => _guard(
    () => _client.rpc('mute_dm', params: {'p_thread': threadId, 'p_on': on}),
  );

  @override
  Future<void> delete(String id) =>
      _guard(() => _client.rpc('delete_dm', params: {'p_id': id}));

  @override
  Stream<DmLiveEvent> changes(String threadId) {
    late final RealtimeChannel channel;
    var cancelled = false;
    final controller = StreamController<DmLiveEvent>(
      onCancel: () async {
        cancelled = true;
        await _client.removeChannel(channel);
      },
    );
    channel = _client
        // Private (migration 31): only the thread's two people join.
        .channel(
          'dm:$threadId',
          opts: const RealtimeChannelConfig(private: true),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'dm_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'thread_id',
            value: threadId,
          ),
          callback: (payload) {
            final row = payload.newRecord;
            final id = row['id'] ?? payload.oldRecord['id'];
            if (id is! String || cancelled) return;
            controller.add(
              DmLiveRow(
                id: id,
                inserted: payload.eventType == PostgresChangeEvent.insert,
                authorId: row['author_id'] as String?,
                kind: row['kind'] as String?,
                body: row['body'] as String?,
                deleted: row['deleted_at'] != null,
              ),
            );
          },
        )
        .subscribe((status, [error]) {
          // F100: one line per status change, for adb.
          debugPrint(
            'BV-LIVE status dm:$threadId ${status.name}'
            '${error == null ? '' : ' error=$error'}',
          );
          if (cancelled) return;
          switch (status) {
            case RealtimeSubscribeStatus.subscribed:
              controller.add(const DmLiveJoined());
            case RealtimeSubscribeStatus.channelError ||
                RealtimeSubscribeStatus.timedOut ||
                RealtimeSubscribeStatus.closed:
              cancelled = true;
              controller.addError(DmLiveLost(status.name, error));
              unawaited(controller.close());
          }
        });
    return controller.stream;
  }
}

final dmRepositoryProvider = Provider<DmRepository>(
  (ref) => SupabaseDmRepository(ref.watch(supabaseClientProvider)),
);

/// The Messages list.
final dmInboxProvider = FutureProvider.autoDispose<DmInbox>(
  (ref) => ref.watch(dmRepositoryProvider).inbox(),
);

/// Every Message request.
final dmRequestsProvider = FutureProvider.autoDispose<List<DmRow>>(
  (ref) => ref.watch(dmRepositoryProvider).requests(),
);
