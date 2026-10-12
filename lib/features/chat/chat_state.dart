import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/locale_controller.dart';
import '../../data/models/chat.dart';
import '../../data/models/space.dart';
import '../../data/repositories/chat_repository.dart';
import '../work/work_outbox.dart' show outboxRetryDelaysProvider;

/// A message written on this phone that isn't on the server yet. Shown in
/// its thread as "Sending…", or "Not sent · Retry" after a weak signal.
@immutable
class PendingMessage {
  const PendingMessage({
    required this.id,
    required this.threadId,
    required this.body,
    required this.createdAt,
    this.reply,
    this.failed = false,
  });

  factory PendingMessage.fromJson(Map<String, dynamic> json) {
    final reply = json['reply'] as Map<String, dynamic>?;
    return PendingMessage(
      id: json['id'] as String,
      threadId: json['thread_id'] as String,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      reply: reply == null
          ? null
          : ChatReply(
              id: reply['id'] as String,
              kind: ChatKind.fromJson(reply['kind']),
              authorName: reply['author'] as String?,
              body: reply['body'] as String?,
            ),
      failed: json['failed'] as bool? ?? false,
    );
  }

  final String id;
  final String threadId;
  final String body;
  final DateTime createdAt;

  /// The message it answers, as it looked when the reply was written.
  final ChatReply? reply;
  final bool failed;

  PendingMessage copyWith({bool? failed}) => PendingMessage(
    id: id,
    threadId: threadId,
    body: body,
    createdAt: createdAt,
    reply: reply,
    failed: failed ?? this.failed,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'thread_id': threadId,
    'body': body,
    'created_at': createdAt.toIso8601String(),
    'reply': reply == null
        ? null
        : {
            'id': reply!.id,
            'kind': switch (reply!.kind) {
              ChatKind.workItem => 'work_item',
              final k => k.name,
            },
            'author': reply!.authorName,
            'body': reply!.body,
          },
    'failed': failed,
  };
}

final chatOutboxProvider = NotifierProvider<ChatOutbox, List<PendingMessage>>(
  ChatOutbox.new,
);

/// Messages waiting to be sent, kept on the phone between app starts.
class ChatOutbox extends Notifier<List<PendingMessage>> {
  static const _key = 'chat_outbox';

  @override
  List<PendingMessage> build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(_key);
    if (raw == null) return const [];
    try {
      return [
        for (final j in jsonDecode(raw) as List)
          PendingMessage.fromJson(j as Map<String, dynamic>),
      ];
    } on FormatException {
      return const [];
    }
  }

  Future<void> _save(List<PendingMessage> items) async {
    state = items;
    await ref
        .read(sharedPreferencesProvider)
        .setString(_key, jsonEncode([for (final i in items) i.toJson()]));
  }

  Future<void> _put(PendingMessage m) => _save([
    for (final i in state)
      if (i.id != m.id) i,
    m,
  ]);

  List<PendingMessage> forThread(String threadId) => [
    for (final m in state)
      if (m.threadId == threadId) m,
  ];

  /// Keeps [m] and posts it, trying again on a weak signal. True when it
  /// reached the server. A refusal (not a lost signal) keeps it as "Not
  /// sent" and is rethrown, so the thread can say why.
  Future<bool> send(PendingMessage m) async {
    final repo = ref.read(chatRepositoryProvider);
    final delays = ref.read(outboxRetryDelaysProvider);
    await _put(m.copyWith(failed: false));
    for (var attempt = 0; ; attempt++) {
      try {
        await repo.post(
          id: m.id,
          threadId: m.threadId,
          body: m.body,
          replyTo: m.reply?.id,
        );
        break;
      } on SpaceException catch (e) {
        if (e.failure == SpaceFailure.network && attempt < delays.length) {
          await Future<void>.delayed(delays[attempt]);
          continue;
        }
        await _put(m.copyWith(failed: true));
        if (e.failure == SpaceFailure.network) return false;
        rethrow;
      }
    }
    await _save([
      for (final i in state)
        if (i.id != m.id) i,
    ]);
    // Shown at once in an open thread, even before the live update.
    final thread = threadMessagesProvider(m.threadId);
    if (ref.exists(thread)) await ref.read(thread.notifier).refresh(m.id);
    return true;
  }

  Future<bool> retry(String id) async {
    final m = state.where((i) => i.id == id).firstOrNull;
    return m == null ? false : send(m);
  }
}

final threadMessagesProvider = AsyncNotifierProvider.autoDispose
    .family<ThreadMessages, List<ChatMessage>, String>(ThreadMessages.new);

/// One thread's messages, newest first, kept up to date live.
class ThreadMessages extends AsyncNotifier<List<ChatMessage>> {
  ThreadMessages(this.threadId);

  final String threadId;

  static const pageSize = 50;
  var _loadingOlder = false;
  var _reachedStart = false;

  /// False once the first message of the thread is loaded.
  bool get hasOlder => !_reachedStart;

  @override
  Future<List<ChatMessage>> build() async {
    final repo = ref.watch(chatRepositoryProvider);
    final sub = repo.changes(threadId).listen((id) => unawaited(refresh(id)));
    ref.onDispose(sub.cancel);
    final page = await repo.messages(threadId, limit: pageSize);
    _reachedStart = page.length < pageSize;
    return page;
  }

  /// Fetches [id] again after a live change or a send, and puts it in place.
  Future<void> refresh(String id) async {
    final ChatMessage? m;
    try {
      m = await ref.read(chatRepositoryProvider).message(id);
    } on SpaceException {
      return;
    }
    final current = state.value;
    if (m == null || current == null || !ref.mounted) return;
    final next = [
      for (final x in current)
        if (x.id != m.id) x,
      m,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = AsyncData(next);
  }

  Future<void> loadOlder() async {
    final current = state.value;
    if (_loadingOlder || _reachedStart || current == null || current.isEmpty) {
      return;
    }
    _loadingOlder = true;
    try {
      final page = await ref
          .read(chatRepositoryProvider)
          .messages(threadId, before: current.last.createdAt, limit: pageSize);
      _reachedStart = page.length < pageSize;
      if (ref.mounted) state = AsyncData([...current, ...page]);
    } on SpaceException {
      // Try again on the next scroll.
    } finally {
      _loadingOlder = false;
    }
  }
}
