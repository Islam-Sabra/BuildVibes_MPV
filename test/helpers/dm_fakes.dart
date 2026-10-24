import 'dart:async';

import 'package:buildvibes/data/models/dm.dart';
import 'package:buildvibes/data/models/library.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/repositories/dm_repository.dart';

/// Direct messages in memory: what the server would answer, and every
/// call the app made, in order ([calls]).
class FakeDmRepository implements DmRepository {
  DmInbox inboxValue = const DmInbox();
  List<DmRow> requestsValue = const [];

  /// Thread id → its page, as the server gives it (messages newest first).
  final pages = <String, DmThreadPage>{};

  /// What start_dm answers; by default the new thread opens.
  DmStart Function(String threadId)? startAnswer;

  final calls = <String>[];
  bool offline = false;

  /// How many times each thread's page was read.
  final pageReads = <String, int>{};

  /// Each thread's open channels, as the app opened them.
  final _live = <String, List<StreamController<DmLiveEvent>>>{};

  /// How many times each thread's channel was opened.
  final opens = <String, int>{};

  /// The next opens of a thread's channel fail at once (a refused join, a
  /// timeout).
  final failOpens = <String, int>{};

  void _check() {
    if (offline) throw const SpaceException(SpaceFailure.network);
  }

  Iterable<StreamController<DmLiveEvent>> _open(String threadId) =>
      (_live[threadId] ?? const []).where((c) => c.hasListener && !c.isClosed);

  /// Someone else's change to [threadId] arrives live.
  void push(String threadId, String messageId) {
    for (final c in _open(threadId)) {
      c.add(DmLiveRow(id: messageId));
    }
  }

  /// Message id → what it says, as liveText reads it (null: can't be read).
  final texts = <String, DmLiveText?>{};

  /// A new message arrives live, by [authorId]: the broadcast's ids, and
  /// its words kept for liveText (migration 40).
  void arrive(
    String threadId,
    String messageId, {
    required String authorId,
    String body = '',
    String kind = 'text',
  }) {
    texts[messageId] = DmLiveText(kind: kind, body: body);
    for (final c in _open(threadId)) {
      c.add(DmLiveRow(id: messageId, inserted: true, authorId: authorId));
    }
  }

  /// [messageId] by [authorId] was deleted, live.
  void deleted(String threadId, String messageId, {required String authorId}) {
    texts[messageId] = null;
    for (final c in _open(threadId)) {
      c.add(DmLiveRow(id: messageId, deleted: true, authorId: authorId));
    }
  }

  /// [threadId]'s channels close (the socket dropped, a timeout).
  void drop(String threadId) {
    for (final c in _open(threadId).toList()) {
      c.addError(const DmLiveLost('closed'));
      unawaited(c.close());
    }
  }

  @override
  Future<DmInbox> inbox() async {
    _check();
    return inboxValue;
  }

  @override
  Future<List<DmRow>> requests() async {
    _check();
    return requestsValue;
  }

  @override
  Future<DmThreadPage?> page(
    String threadId, {
    DateTime? before,
    String? beforeId,
  }) async {
    _check();
    pageReads[threadId] = (pageReads[threadId] ?? 0) + 1;
    return pages[threadId];
  }

  @override
  Future<DmStart> start({
    required String threadId,
    required String to,
    required String messageId,
    String? body,
    List<DmUpload> attachments = const [],
  }) async {
    _check();
    calls.add('start $to $body');
    return startAnswer?.call(threadId) ??
        DmStart(threadId: threadId, state: 'open');
  }

  @override
  Future<void> send({
    required String id,
    required String threadId,
    String? body,
    String? replyTo,
    List<DmUpload> attachments = const [],
  }) async {
    _check();
    calls.add(
      'send $threadId $body${replyTo == null ? '' : ' reply $replyTo'}'
      '${attachments.isEmpty ? '' : ' files ${attachments.length}'}',
    );
  }

  @override
  Future<String> upload(String messageId, PhoneFile file) async {
    _check();
    return 'me/$messageId/${file.name}';
  }

  @override
  Future<String> fileUrl(String path) async => 'https://files.example/$path';

  @override
  Future<void> markRead(String threadId) async => calls.add('read $threadId');

  @override
  Future<void> decline(String threadId) async {
    _check();
    calls.add('decline $threadId');
  }

  @override
  Future<void> mute(
    String threadId, {
    required bool on,
    DateTime? until,
  }) async {
    _check();
    calls.add(
      until == null
          ? 'mute $threadId $on'
          : 'mute $threadId $on until ${until.toIso8601String()}',
    );
  }

  @override
  Future<void> delete(String id) async {
    _check();
    calls.add('delete $id');
  }

  /// The threads someone listens to live, now.
  Set<String> get listened => {
    for (final e in _live.keys)
      if (_open(e).isNotEmpty) e,
  };

  @override
  Future<DmLiveText?> liveText(String messageId) async {
    _check();
    calls.add('liveText $messageId');
    return texts[messageId];
  }

  @override
  Stream<DmLiveEvent> changes(String threadId) {
    opens[threadId] = (opens[threadId] ?? 0) + 1;
    late final StreamController<DmLiveEvent> c;
    c = StreamController<DmLiveEvent>(
      onListen: () {
        final fail = failOpens[threadId] ?? 0;
        if (fail > 0) {
          failOpens[threadId] = fail - 1;
          c.addError(const DmLiveLost('channelError'));
          unawaited(c.close());
        } else {
          c.add(const DmLiveJoined());
        }
      },
    );
    _live.putIfAbsent(threadId, () => []).add(c);
    return c.stream;
  }
}
