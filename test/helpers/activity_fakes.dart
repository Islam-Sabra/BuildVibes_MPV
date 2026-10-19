import 'package:buildvibes/data/models/activity.dart';
import 'package:buildvibes/data/repositories/activity_repository.dart';

/// Activity and Home's day, in memory. Tests set the lists; marking read
/// and visits are recorded in [calls].
class FakeActivityRepository implements ActivityRepository {
  FakeActivityRepository({
    List<ActivityRow>? rows,
    List<NeedsCard>? cards,
    List<SpaceToday>? today,
  }) : rows = rows ?? [],
       cards = cards ?? [],
       todayRows = today ?? [];

  List<ActivityRow> rows;
  List<NeedsCard> cards;
  List<SpaceToday> todayRows;
  final calls = <String>[];

  /// The day start Home last asked with.
  DateTime? askedFrom;

  @override
  Future<List<ActivityRow>> activity() async => List.of(rows);

  @override
  Future<void> markRead() async {
    calls.add('mark-read');
    rows = [
      for (final r in rows)
        ActivityRow(
          id: r.id,
          kind: r.kind,
          createdAt: r.createdAt,
          spaceId: r.spaceId,
          spaceName: r.spaceName,
          workItemId: r.workItemId,
          workItemRef: r.workItemRef,
          workItemTitle: r.workItemTitle,
          postId: r.postId,
          context: r.context,
          requestStatus: r.requestStatus,
          projectName: r.projectName,
          actorId: r.actorId,
          actorName: r.actorName,
          read: true,
          usefulNames: r.usefulNames,
          toReply: r.toReply,
          removalId: r.removalId,
          targetKind: r.targetKind,
          result: r.result,
          eventId: r.eventId,
        ),
    ];
  }

  @override
  Future<bool> unread() async => rows.any((r) => !r.read);

  @override
  Future<List<SpaceToday>> today(DateTime dayStart) async {
    askedFrom = dayStart;
    return List.of(todayRows);
  }

  @override
  Future<List<NeedsCard>> needs() async => List.of(cards);

  @override
  Future<void> markSpaceSeen(String spaceId) async =>
      calls.add('seen $spaceId');
}
