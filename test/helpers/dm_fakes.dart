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
  final _live = <String, StreamController<String>>{};

  void _check() {
    if (offline) throw const SpaceException(SpaceFailure.network);
  }

  /// Someone else's change to [threadId] arrives live.
  void push(String threadId, String messageId) =>
      _live[threadId]?.add(messageId);

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
  Future<void> mute(String threadId, {required bool on}) async {
    _check();
    calls.add('mute $threadId $on');
  }

  @override
  Future<void> delete(String id) async {
    _check();
    calls.add('delete $id');
  }

  @override
  Stream<String> changes(String threadId) {
    final c = StreamController<String>();
    _live[threadId] = c;
    return c.stream;
  }
}
