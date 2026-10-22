import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/models/week_report.dart';
import 'package:buildvibes/data/repositories/week_report_repository.dart';

/// Meeting notes and the week report with no network (slice 9). [offline]
/// fails every call as a lost signal.
class FakeWeekReportRepository implements WeekReportRepository {
  FakeWeekReportRepository({this.reports = const {}});

  /// The week report for each week's first day.
  Map<DateTime, WeekReport> reports;
  bool offline = false;

  /// Each meeting sent: the parent's id, title and lines.
  final List<
    ({String parentId, String messageId, String title, List<MeetingLine> lines})
  >
  meetings = [];

  /// Each week report shared: its id, thread and week start.
  final List<({String id, String threadId, DateTime weekStart})> shared = [];

  /// Each week read: its first day.
  final List<DateTime> read = [];

  void _check() {
    if (offline) throw const SpaceException(SpaceFailure.network);
  }

  @override
  Future<void> createFromMessage({
    required String spaceId,
    required String messageId,
    required String parentId,
    required String title,
    required List<MeetingLine> lines,
  }) async {
    _check();
    // The same parent again is the same batch.
    if (meetings.any((m) => m.parentId == parentId)) return;
    meetings.add((
      parentId: parentId,
      messageId: messageId,
      title: title,
      lines: lines,
    ));
  }

  @override
  Future<WeekReport> weekReport(
    String spaceId, {
    required DateTime from,
    required DateTime to,
    required DateTime today,
  }) async {
    _check();
    read.add(from);
    return reports[DateTime(from.year, from.month, from.day)] ??
        const WeekReport();
  }

  @override
  Future<void> share({
    required String id,
    required String threadId,
    required DateTime weekStart,
  }) async {
    _check();
    if (shared.any((s) => s.id == id)) return;
    shared.add((id: id, threadId: threadId, weekStart: weekStart));
  }
}
