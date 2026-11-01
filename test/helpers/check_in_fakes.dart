import 'package:buildvibes/data/models/check_in.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/repositories/check_in_repository.dart';
import 'package:buildvibes/features/work/check_in_notice.dart';

/// Review 109's notifications in tests: what was shown, in order.
class FakeCheckInNotifier implements CheckInNotifier {
  final shown = <CheckInNotice>[];
  var channels = 0;

  @override
  Future<void> ensureChannel() async => channels++;

  @override
  Future<void> show(CheckInNotice notice) async => shown.add(notice);
}

/// Review 109's server calls in tests.
class FakeCheckInRepository implements CheckInRepository {
  FakeCheckInRepository({this.now});

  final DateTime Function()? now;

  final posted = <NewCheckIn>[];
  final marks =
      <({String postId, CheckInMarkKind kind, double? lat, double? lng})>[];
  final stopped = <String>[];

  /// What mark_check_in says: on time, and on site when a point came.
  CheckInResult Function(CheckInMarkKind kind, bool shared)? answer;

  /// mark_check_in refuses with this.
  SpaceException? refuseMark;
  SpaceException? refusePost;

  /// check_in_list by day ("2026-10-15").
  final lines = <String, List<CheckInLine>>{};
  List<DateTime> dayList = const [];

  @override
  Future<void> post(NewCheckIn checkIn) async {
    if (refusePost case final e?) throw e;
    posted.add(checkIn);
  }

  @override
  Future<CheckInResult> mark(
    String postId,
    CheckInMarkKind kind, {
    double? lat,
    double? lng,
  }) async {
    if (refuseMark case final e?) throw e;
    marks.add((postId: postId, kind: kind, lat: lat, lng: lng));
    final shared = lat != null && lng != null;
    final at = now?.call() ?? DateTime.utc(2026, 10, 15, 6, 58);
    return answer?.call(kind, shared) ??
        CheckInResult(
          day: DateTime(at.year, at.month, at.day),
          kind: kind,
          mark: CheckInMark(
            at: at,
            onTime: true,
            place: shared ? CheckInPlace.onSite : CheckInPlace.notShared,
          ),
        );
  }

  @override
  Future<void> stop(String postId) async => stopped.add(postId);

  @override
  Future<List<CheckInLine>> list(String postId, DateTime day) async =>
      lines[checkInDayJson(day)] ?? const [];

  @override
  Future<List<DateTime>> days(String postId) async => dayList;
}
