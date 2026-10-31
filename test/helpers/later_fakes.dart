import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/repositories/schedule_repository.dart';
import 'package:buildvibes/data/repositories/work_reminder_repository.dart';

/// Reminders for someone else (review 108 RM1, RM2), with no network.
class FakeWorkReminderRepository implements WorkReminderRepository {
  /// Waiting reminders, by post.
  final byPost = <String, List<WorkReminder>>{};

  /// Each set_work_reminder, in order.
  final sets = <({String id, String postId, List<String> people, DateTime at, String? note})>[];
  final removed = <String>[];

  /// The next call fails this way.
  SpaceFailure? failure;

  void _check() {
    final f = failure;
    if (f != null) throw SpaceException(f);
  }

  @override
  Future<void> set({
    required String id,
    required String postId,
    required List<String> people,
    required DateTime at,
    String? note,
  }) async {
    _check();
    sets.add((id: id, postId: postId, people: people, at: at, note: note));
    (byPost[postId] ??= []).add(
      WorkReminder(
        id: id,
        remindAt: at,
        note: note,
        people: [for (final p in people) (id: p, name: p)],
        canRemove: true,
      ),
    );
  }

  @override
  Future<void> remove(String id) async {
    _check();
    removed.add(id);
    for (final list in byPost.values) {
      list.removeWhere((r) => r.id == id);
    }
  }

  @override
  Future<List<WorkReminder>> forPost(String postId) async =>
      List.of(byPost[postId] ?? const []);
}

/// Post later (review 108 PL1, PL2), with no network.
class FakeScheduleRepository implements ScheduleRepository {
  final posts = <ScheduledPost>[];

  /// Each schedule_post, with its call and arguments.
  final scheduled = <({String id, String call, Map<String, dynamic> params, DateTime at})>[];
  final cancelled = <String>[];
  final postedNow = <String>[];

  /// The next call fails this way.
  SpaceFailure? failure;

  void _check() {
    final f = failure;
    if (f != null) throw SpaceException(f);
  }

  @override
  Future<void> schedule({
    required String id,
    required String call,
    required Map<String, dynamic> params,
    required DateTime at,
    required String title,
  }) async {
    _check();
    scheduled.add((id: id, call: call, params: params, at: at));
    posts.add(
      ScheduledPost(
        id: id,
        title: title,
        publishAt: at,
        spaceId: params['p_space'] as String?,
      ),
    );
  }

  @override
  Future<void> reschedule(String id, DateTime at) async {
    _check();
    final i = posts.indexWhere((p) => p.id == id);
    final p = posts[i];
    posts[i] = ScheduledPost(
      id: p.id,
      title: p.title,
      publishAt: at,
      spaceId: p.spaceId,
      spaceName: p.spaceName,
    );
  }

  @override
  Future<void> cancel(String id) async {
    _check();
    cancelled.add(id);
    posts.removeWhere((p) => p.id == id);
  }

  @override
  Future<bool> postNow(String id) async {
    _check();
    postedNow.add(id);
    posts.removeWhere((p) => p.id == id);
    return true;
  }

  @override
  Future<List<ScheduledPost>> mine() async => List.of(posts)
    ..sort((a, b) => a.publishAt.compareTo(b.publishAt));
}
