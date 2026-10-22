import 'dart:async';

import 'package:buildvibes/data/models/chat.dart';
import 'package:buildvibes/data/models/library.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/repositories/chat_repository.dart';

/// Space chat with no network. Tests fill [threadsBySpace] and
/// [messagesByThread] (newest first) and push live changes with [live].
class FakeChatRepository implements ChatRepository {
  FakeChatRepository({DateTime? now}) : now = now ?? DateTime(2026, 10, 11);

  final DateTime now;
  final threadsBySpace = <String, List<ChatThread>>{};
  final messagesByThread = <String, List<ChatMessage>>{};
  final calls = <String>[];
  final _live = <String, StreamController<String>>{};

  /// The next posts fail as if the signal dropped.
  int failNext = 0;

  /// The next uploads fail as if the signal dropped.
  int failUploadNext = 0;
  final uploads = <String>[];
  final posted = <List<ChatUpload>>[];

  /// The next post is refused with this failure.
  SpaceFailure? refuseNext;

  StreamController<String> _controller(String threadId) =>
      _live.putIfAbsent(threadId, StreamController<String>.broadcast);

  /// Someone else's message arrives (or changes) while the thread is open.
  void live(ChatMessage m) {
    final list = messagesByThread.putIfAbsent(m.threadId, () => []);
    list
      ..removeWhere((x) => x.id == m.id)
      ..insert(0, m);
    _controller(m.threadId).add(m.id);
  }

  ChatMessage? _find(String id) {
    for (final list in messagesByThread.values) {
      for (final m in list) {
        if (m.id == id) return m;
      }
    }
    return null;
  }

  @override
  Future<List<ChatThread>> threads(String spaceId) async =>
      List.of(threadsBySpace[spaceId] ?? const []);

  @override
  Future<List<ChatMessage>> messages(
    String threadId, {
    DateTime? before,
    int limit = 50,
  }) async {
    final all = messagesByThread[threadId] ?? const <ChatMessage>[];
    return [
      for (final m in all)
        if (before == null || m.createdAt.isBefore(before)) m,
    ].take(limit).toList();
  }

  @override
  Future<ChatMessage?> message(String id) async => _find(id);

  @override
  Future<void> post({
    required String id,
    required String threadId,
    required String body,
    String? replyTo,
    List<ChatUpload> attachments = const [],
  }) async {
    if (failNext > 0) {
      failNext--;
      throw const SpaceException(SpaceFailure.network);
    }
    final refuse = refuseNext;
    if (refuse != null) {
      refuseNext = null;
      throw SpaceException(refuse);
    }
    calls.add(
      'post $threadId $body${replyTo == null ? '' : ' re $replyTo'}'
      '${attachments.isEmpty ? '' : ' files ${attachments.map((a) => a.mime).join(',')}'}',
    );
    posted.add(attachments);
    final parent = replyTo == null ? null : _find(replyTo);
    messagesByThread
        .putIfAbsent(threadId, () => [])
        .insert(
          0,
          ChatMessage(
            id: id,
            threadId: threadId,
            kind: ChatKind.text,
            createdAt: now,
            authorId: 'user-1',
            authorName: 'Omar Haddad',
            body: body,
            attachments: [
              for (final a in attachments)
                ChatAttachment(path: a.path, mime: a.mime, bytes: a.bytes),
            ],
            reply: parent == null
                ? null
                : ChatReply(
                    id: parent.id,
                    kind: parent.kind,
                    authorName: parent.authorName,
                    body: parent.body,
                  ),
          ),
        );
  }

  @override
  Future<String> upload(
    String spaceId,
    String messageId,
    PhoneFile file,
  ) async {
    if (failUploadNext > 0) {
      failUploadNext--;
      throw const SpaceException(SpaceFailure.network);
    }
    final path =
        '$spaceId/chat/$messageId/file-${uploads.length + 1}.${file.extension}';
    uploads.add(path);
    return path;
  }

  @override
  Future<void> shareFile({
    required String id,
    required String threadId,
    required String fileId,
    String? body,
  }) async {
    calls.add('share $threadId $fileId${body == null ? '' : ' "$body"'}');
  }

  @override
  Future<void> delete(String id) async {
    calls.add('delete $id');
    for (final list in messagesByThread.values) {
      final i = list.indexWhere((m) => m.id == id);
      if (i >= 0) {
        final m = list[i];
        list[i] = ChatMessage(
          id: m.id,
          threadId: m.threadId,
          kind: m.kind,
          createdAt: m.createdAt,
          authorId: m.authorId,
          authorName: m.authorName,
          deletedAt: now,
        );
      }
    }
  }

  @override
  Future<void> markRead(String threadId) async => calls.add('read $threadId');

  @override
  Stream<String> changes(String threadId) => _controller(threadId).stream;
}
