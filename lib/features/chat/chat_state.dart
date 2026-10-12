import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/l10n/locale_controller.dart';
import '../../data/models/chat.dart';
import '../../data/models/library.dart';
import '../../data/models/space.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/work_repository.dart' show newUuid;
import '../work/work_outbox.dart' show outboxRetryDelaysProvider;

/// A photo or PDF kept on the phone until its message is sent. [remote] is
/// its path in the Space once uploaded.
@immutable
class PendingFile {
  const PendingFile({required this.file, this.remote});

  factory PendingFile.fromJson(Map<String, dynamic> json) => PendingFile(
    file: PhoneFile(
      local: json['local'] as String,
      name: json['name'] as String,
      mime: json['mime'] as String,
      bytes: (json['bytes'] as num?)?.toInt(),
      durationMs: (json['duration_ms'] as num?)?.toInt(),
    ),
    remote: json['remote'] as String?,
  );

  final PhoneFile file;
  final String? remote;

  PendingFile uploaded(String path) => PendingFile(file: file, remote: path);

  Map<String, dynamic> toJson() => {
    'local': file.local,
    'name': file.name,
    'mime': file.mime,
    'bytes': file.bytes,
    'duration_ms': file.durationMs,
    'remote': remote,
  };
}

/// A message written on this phone that isn't on the server yet. Shown in
/// its thread as "Sending…", or "Not sent · Retry" after a weak signal.
@immutable
class PendingMessage {
  const PendingMessage({
    required this.id,
    required this.threadId,
    required this.body,
    required this.createdAt,
    this.spaceId = '',
    this.reply,
    this.files = const [],
    this.failed = false,
  });

  factory PendingMessage.fromJson(Map<String, dynamic> json) {
    final reply = json['reply'] as Map<String, dynamic>?;
    return PendingMessage(
      id: json['id'] as String,
      threadId: json['thread_id'] as String,
      spaceId: json['space_id'] as String? ?? '',
      body: json['body'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      files: [
        for (final f in (json['files'] as List?) ?? const [])
          PendingFile.fromJson(f as Map<String, dynamic>),
      ],
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

  /// Where its files upload (`<space>/chat/<id>/`).
  final String spaceId;
  final String body;
  final DateTime createdAt;

  /// The message it answers, as it looked when the reply was written.
  final ChatReply? reply;

  /// Photos and a PDF, kept on the phone until sent.
  final List<PendingFile> files;
  final bool failed;

  PendingMessage copyWith({bool? failed, List<PendingFile>? files}) =>
      PendingMessage(
        id: id,
        threadId: threadId,
        spaceId: spaceId,
        body: body,
        createdAt: createdAt,
        reply: reply,
        files: files ?? this.files,
        failed: failed ?? this.failed,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'thread_id': threadId,
    'space_id': spaceId,
    'body': body,
    'files': [for (final f in files) f.toJson()],
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

/// Copies a picked file into the app's own folder, so it outlives the
/// picker's cache until its message is sent. Returns the kept path.
typedef KeepFile = Future<String> Function(String path, String extension);

final keepFileProvider = Provider<KeepFile>(
  (ref) => (path, extension) async {
    final dir = Directory(
      '${(await getApplicationDocumentsDirectory()).path}/chat_outbox',
    );
    await dir.create(recursive: true);
    final kept = '${dir.path}/${newUuid()}.$extension';
    await File(path).copy(kept);
    return kept;
  },
);

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
    var current = m.copyWith(failed: false);
    await _put(current);

    Future<T> withRetries<T>(Future<T> Function() run) async {
      for (var attempt = 0; ; attempt++) {
        try {
          return await run();
        } on SpaceException catch (e) {
          if (e.failure != SpaceFailure.network || attempt >= delays.length) {
            rethrow;
          }
          await Future<void>.delayed(delays[attempt]);
        }
      }
    }

    try {
      // Upload what isn't up yet, keeping each path as it lands.
      final files = <PendingFile>[];
      for (final f in current.files) {
        if (f.remote != null) {
          files.add(f);
          continue;
        }
        final path = await withRetries(
          () => repo.upload(current.spaceId, current.id, f.file),
        );
        files.add(f.uploaded(path));
        current = current.copyWith(
          files: [...files, ...current.files.skip(files.length)],
        );
        await _put(current);
      }
      await withRetries(
        () => repo.post(
          id: current.id,
          threadId: current.threadId,
          body: current.body,
          replyTo: current.reply?.id,
          attachments: [
            for (final f in files)
              ChatUpload(
                path: f.remote!,
                mime: f.file.mime,
                bytes: f.file.bytes,
                name: f.file.name,
                durationMs: f.file.durationMs,
              ),
          ],
        ),
      );
    } on SpaceException catch (e) {
      await _put(current.copyWith(failed: true));
      if (e.failure == SpaceFailure.network) return false;
      rethrow;
    }
    await _save([
      for (final i in state)
        if (i.id != m.id) i,
    ]);
    // Sent: the kept copies can go.
    for (final f in m.files) {
      unawaited(_deleteKept(f.file.local));
    }
    // Shown at once in an open thread, even before the live update.
    final thread = threadMessagesProvider(m.threadId);
    if (ref.exists(thread)) await ref.read(thread.notifier).refresh(m.id);
    return true;
  }

  static Future<void> _deleteKept(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      // Already gone.
    }
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
