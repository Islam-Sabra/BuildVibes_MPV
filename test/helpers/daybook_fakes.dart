import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/repositories/daybook_live.dart';
import 'package:buildvibes/data/repositories/daybook_repository.dart';

/// A Space's daybook with no network. [posts] are each Space's cards in
/// any order; pages come back newest activity first, as daybook_cards
/// sends them.
class FakeDaybookRepository implements DaybookRepository {
  final posts = <String, List<DaybookCard>>{};
  final months = <String, DaybookMonth>{};

  /// post_history past each card's own lines, by post, newest first.
  final earlier = <String, List<DaybookEvent>>{};

  /// my_calendar's work items, every Space.
  final calendar = <CalendarWorkItem>[];

  /// The months asked for, as "space yyyy-mm".
  final monthCalls = <String>[];
  final pageCalls = <String>[];

  /// "Show earlier" past the first lines: the post ids asked for.
  final historyCalls = <String>[];
  bool failPages = false;

  /// Writing: what was uploaded and created, in order. While [offline],
  /// both fail as a lost signal; [refuse] makes the server say no.
  final uploads = <String>[];
  final created = <NewWorkItem>[];

  /// Edits and cancels, as `edit <id> <json>` and `cancel <id>`.
  final calls = <String>[];
  bool offline = false;
  bool refuse = false;

  /// How a created work item reads back on the page; null leaves the page
  /// as it was.
  DaybookCard Function(NewWorkItem item)? asPosted;

  /// Posts of the other kinds, as create_space_post got them.
  final createdPosts = <NewSpacePost>[];

  /// What sits above each Space's daybook (daybook_extras).
  final extrasBySpace = <String, DaybookExtras>{};

  /// Each checklist's points and each post's faces (post_acks_for).
  final pointsByPost = <String, List<DaybookPoint>>{};
  final acksByPost = <String, List<DaybookAckFace>>{};

  /// Ticks, acks and attachments, as `tick <point> <on>`,
  /// `ack <post> <kind> <on>` and `attach <item> <file>`.
  final marks = <String>[];

  /// While set, ticks and acks wait for it: what the card shows meanwhile.
  Completer<void>? holdMarks;

  /// [card] replaces the card with its id (new activity), or joins.
  void put(String spaceId, DaybookCard card) => posts[spaceId] = [
    for (final c in posts[spaceId] ?? const <DaybookCard>[])
      if (c.id != card.id) c,
    card,
  ];

  static bool _before(DateTime at, String id, DateTime before, String? cursor) {
    final t = at.compareTo(before);
    return t < 0 || (t == 0 && cursor != null && id.compareTo(cursor) < 0);
  }

  /// Cards the daybook doesn't list (a target's work items), by id.
  final cardsById = <String, DaybookCard>{};

  @override
  Future<DaybookCard?> card(String postId) async {
    if (failPages) throw const SpaceException(SpaceFailure.network);
    return cardsById[postId] ??
        [
          for (final list in posts.values) ...list,
        ].where((c) => c.id == postId).firstOrNull;
  }

  @override
  Future<DaybookCardsPage> cards(
    String spaceId, {
    DateTime? before,
    String? beforeId,
    int limit = 30,
  }) async {
    pageCalls.add('$spaceId ${before?.toIso8601String()}');
    if (failPages) throw const SpaceException(SpaceFailure.network);
    final all = <DaybookCard>[...?posts[spaceId]]
      ..sort((a, b) {
        final t = b.lastActivityAt.compareTo(a.lastActivityAt);
        return t != 0 ? t : b.id.compareTo(a.id);
      });
    return DaybookCardsPage(
      all
          .where(
            (c) =>
                before == null ||
                _before(c.lastActivityAt, c.id, before, beforeId),
          )
          .take(limit)
          .toList(),
    );
  }

  @override
  Future<DaybookHistoryPage> history(
    String postId, {
    DateTime? before,
    String? beforeId,
    int limit = DaybookRepository.historyPage,
  }) async {
    historyCalls.add(postId);
    if (failPages) throw const SpaceException(SpaceFailure.network);
    // From the newest: the card's own lines, then the earlier ones; none
    // for a post that is gone (post_history).
    final List<DaybookEvent> all;
    if (before == null) {
      final card = posts.values
          .expand((cards) => cards)
          .where((c) => c.id == postId)
          .firstOrNull;
      if (card == null) return (lines: const <DaybookEvent>[], more: false);
      all = [...card.history, ...?earlier[postId]];
    } else {
      all = [
        for (final e in earlier[postId] ?? const <DaybookEvent>[])
          if (_before(e.at, e.id, before, beforeId)) e,
      ];
    }
    return (lines: all.take(limit).toList(), more: all.length > limit);
  }

  @override
  Future<DaybookMonth> month(String spaceId, DateTime month) async {
    monthCalls.add('$spaceId ${month.year}-${month.month}');
    return months['$spaceId ${month.year}-${month.month}'] ??
        const DaybookMonth();
  }

  @override
  Future<List<CalendarWorkItem>> dueUpTo(DateTime day) async => [
    for (final i in calendar)
      if (!i.day.isAfter(DateTime(day.year, day.month, day.day)) &&
          !i.day.isBefore(DateTime(day.year, day.month, day.day - dueBackDays)))
        i,
  ];

  void _check() {
    if (offline) throw const SpaceException(SpaceFailure.network);
    if (refuse) throw const SpaceException(SpaceFailure.badInput);
  }

  @override
  Future<String> uploadPostPhoto(
    String spaceId,
    String postId,
    File file,
  ) async {
    _check();
    final path = '$spaceId/posts/$postId/${uploads.length}.jpg';
    uploads.add(path);
    return path;
  }

  final createdWalks = <NewWalk>[];

  /// The server says no to a walk only (an owner left the Space).
  bool refuseWalk = false;

  @override
  Future<void> createWalk(NewWalk walk) async {
    _check();
    if (refuseWalk) throw const SpaceException(SpaceFailure.notAllowed);
    if (createdWalks.any((w) => w.id == walk.id)) return;
    createdWalks.add(walk);
  }

  @override
  Future<void> createWorkItem(NewWorkItem item) async {
    _check();
    // The same id again is the same post.
    if (created.any((c) => c.id == item.id)) return;
    created.add(item);
    final card = asPosted?.call(item);
    if (card != null) put(item.spaceId, card);
  }

  @override
  Future<DaybookExtras> extras(String spaceId, DateTime day) async =>
      extrasBySpace[spaceId] ?? const DaybookExtras();

  @override
  Future<List<DaybookPoint>> points(String postId) async =>
      pointsByPost[postId] ?? const [];

  /// Each post's own files (post_files).
  final filesByPost = <String, List<DaybookPostFile>>{};

  @override
  Future<List<DaybookPostFile>> postFiles(String postId) async =>
      filesByPost[postId] ?? const [];

  @override
  Future<List<DaybookAckFace>> acks(String postId) async =>
      acksByPost[postId] ?? const [];

  /// The next ticks and acknowledgements fail as if the signal dropped.
  int failMarks = 0;

  void _maybeFailMark() {
    if (failMarks > 0) {
      failMarks--;
      throw const SpaceException(SpaceFailure.network);
    }
  }

  @override
  Future<void> tickPoint(String pointId, {required bool on}) async {
    await holdMarks?.future;
    _check();
    _maybeFailMark();
    marks.add('tick $pointId $on');
  }

  @override
  Future<void> ack(String postId, DaybookAck kind, {required bool on}) async {
    await holdMarks?.future;
    _check();
    _maybeFailMark();
    marks.add('ack $postId ${kind.json} $on');
  }

  @override
  Future<void> createPost(NewSpacePost post) async {
    _check();
    if (createdPosts.any((p) => p.id == post.id)) return;
    createdPosts.add(post);
  }

  @override
  Future<void> attachFile(String itemId, String libraryFileId) async {
    _check();
    marks.add('attach $itemId $libraryFileId');
  }

  @override
  Future<void> editPost(String postId, PostEdit edit) async {
    _check();
    calls.add('edit $postId ${jsonEncode(edit.toJson())}');
  }

  @override
  Future<void> cancelPost(String postId) async {
    _check();
    calls.add('cancel $postId');
  }
}

/// The Space channel with no network: [push] plays a change by someone
/// else; [sent] lists the changes this phone told, as `space post`.
class FakeDaybookLive implements DaybookLive {
  final _streams = <String, StreamController<String>>{};
  final sent = <String>[];

  /// Someone else changed [postId] in [spaceId].
  void push(String spaceId, String postId) => _streams[spaceId]?.add(postId);

  @override
  Stream<String> changes(String spaceId) {
    final controller = StreamController<String>();
    _streams[spaceId] = controller;
    return controller.stream;
  }

  @override
  Future<void> changed(String spaceId, String postId) async =>
      sent.add('$spaceId $postId');
}
