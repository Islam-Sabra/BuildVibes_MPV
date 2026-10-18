import 'dart:convert';
import 'dart:io';

import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/space.dart';
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
  Future<List<DaybookEvent>> history(
    String postId, {
    required DateTime before,
    required String beforeId,
    int limit = DaybookRepository.historyPage,
  }) async {
    historyCalls.add(postId);
    if (failPages) throw const SpaceException(SpaceFailure.network);
    return [
      for (final e in earlier[postId] ?? const <DaybookEvent>[])
        if (_before(e.at, e.id, before, beforeId)) e,
    ].take(limit).toList();
  }

  @override
  Future<DaybookMonth> month(String spaceId, DateTime month) async {
    monthCalls.add('$spaceId ${month.year}-${month.month}');
    return months['$spaceId ${month.year}-${month.month}'] ??
        const DaybookMonth();
  }

  @override
  Future<List<CalendarWorkItem>> dueOn(DateTime day) async => [
    for (final i in calendar)
      if (i.day == DateTime(day.year, day.month, day.day)) i,
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
