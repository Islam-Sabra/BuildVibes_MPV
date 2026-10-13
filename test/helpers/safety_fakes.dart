import 'package:buildvibes/data/repositories/safety_repository.dart';

import 'post_fakes.dart';

/// Report, block and appeal, in memory. Calls are recorded in [calls].
class FakeSafetyRepository implements SafetyRepository {
  FakeSafetyRepository({
    List<BlockedPerson>? blocked,
    Map<String, Removal>? removals,
    this.posts,
  }) : blockedPeople = blocked ?? [],
       removals = removals ?? {};

  /// When given, reports and blocks hide posts there, as the server does.
  final FakePostRepository? posts;

  final calls = <String>[];
  List<BlockedPerson> blockedPeople;
  Map<String, Removal> removals;

  @override
  Future<void> report(
    ReportKind kind,
    String id,
    ReportReason reason, {
    String? note,
  }) async {
    calls.add(
      'report ${kind.json} $id ${reason.json}${note == null ? '' : ' $note'}',
    );
    if (kind == ReportKind.post) posts?.reported.add(id);
  }

  @override
  Future<void> block(String personId, bool on) async {
    calls.add('block $personId $on');
    if (on) {
      posts?.blocked.add(personId);
    } else {
      posts?.blocked.remove(personId);
      blockedPeople.removeWhere((p) => p.id == personId);
    }
  }

  @override
  Future<List<BlockedPerson>> blocked() async => List.of(blockedPeople);

  @override
  Future<Removal?> removal(String id) async => removals[id];

  @override
  Future<void> appeal(String removalId, String note) async {
    calls.add('appeal $removalId $note');
    final r = removals[removalId];
    if (r != null) {
      removals[removalId] = Removal(
        id: r.id,
        kind: r.kind,
        reason: r.reason,
        removedAt: r.removedAt,
        appealStatus: AppealStatus.open,
        canAppeal: false,
        excerpt: r.excerpt,
        appealAt: DateTime(2026, 10, 11),
      );
    }
  }
}
