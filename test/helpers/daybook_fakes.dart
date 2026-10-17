import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/repositories/daybook_repository.dart';

/// A Space's daybook with no network. [posts] are each Space's posts in any
/// order; pages come back newest first, as daybook_page sends them.
class FakeDaybookRepository implements DaybookRepository {
  final posts = <String, List<DaybookPost>>{};
  final months = <String, DaybookMonth>{};

  /// my_calendar's work items, every Space.
  final calendar = <CalendarWorkItem>[];

  /// The months asked for, as "space yyyy-mm".
  final monthCalls = <String>[];
  final pageCalls = <String>[];
  bool failPages = false;

  @override
  Future<List<DaybookPost>> page(
    String spaceId, {
    DateTime? before,
    String? beforeId,
    int limit = 30,
  }) async {
    pageCalls.add('$spaceId ${before?.toIso8601String()}');
    if (failPages) throw const SpaceException(SpaceFailure.network);
    final all = [...?posts[spaceId]]
      ..sort((a, b) {
        final t = b.createdAt.compareTo(a.createdAt);
        return t != 0 ? t : b.id.compareTo(a.id);
      });
    return all
        .where((p) {
          if (before == null) return true;
          final t = p.createdAt.compareTo(before);
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
}
