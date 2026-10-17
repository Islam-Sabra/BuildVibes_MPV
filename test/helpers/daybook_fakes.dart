import 'dart:convert';
import 'dart:io';

import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/repositories/daybook_repository.dart';

/// A Space's daybook with no network. [posts] are each Space's entries
/// (posts, sign-offs, updates) in any order; pages come back newest first,
/// as daybook_page sends them.
class FakeDaybookRepository implements DaybookRepository {
  final posts = <String, List<DaybookRecord>>{};
  final months = <String, DaybookMonth>{};

  /// my_calendar's work items, every Space.
  final calendar = <CalendarWorkItem>[];

  /// The months asked for, as "space yyyy-mm".
  final monthCalls = <String>[];
  final pageCalls = <String>[];
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
  DaybookPost Function(NewWorkItem item)? asPosted;

  @override
  Future<List<DaybookRecord>> page(
    String spaceId, {
    DateTime? before,
    String? beforeId,
    int limit = 30,
  }) async {
    pageCalls.add('$spaceId ${before?.toIso8601String()}');
    if (failPages) throw const SpaceException(SpaceFailure.network);
    final all = <DaybookRecord>[...?posts[spaceId]]
      ..sort((a, b) {
        final t = b.at.compareTo(a.at);
        return t != 0 ? t : b.id.compareTo(a.id);
      });
    return all
        .where((p) {
          if (before == null) return true;
          final t = p.at.compareTo(before);
          return t < 0 ||
              (t == 0 && beforeId != null && p.id.compareTo(beforeId) < 0);
        })
        .take(limit)
        .toList();
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
    final post = asPosted?.call(item);
    if (post != null) posts[item.spaceId] = [...?posts[item.spaceId], post];
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
