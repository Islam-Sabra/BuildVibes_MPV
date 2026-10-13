import 'package:buildvibes/data/models/people.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/repositories/account_repository.dart';

import 'fakes.dart';

/// In-memory account state (migration 16), with the calls made.
class FakeAccountRepository implements AccountRepository {
  FakeAccountRepository({
    this.profiles,
    List<DeletionBlocker>? blockers,
    this.request,
  }) : blockers = blockers ?? [];

  /// Where the scheduled flag lives, so the gate sees it.
  FakeProfileRepository? profiles;
  final List<DeletionBlocker> blockers;
  DataRequest? request;
  DateTime? goneOn;
  final calls = <String>[];

  /// The server refuses without a fresh code (S13).
  bool freshCode = true;

  @override
  Future<List<DeletionBlocker>> deletionBlockers() async => [...blockers];

  @override
  Future<DateTime> requestDeletion() async {
    if (!freshCode) {
      throw const SpaceException(SpaceFailure.notAllowed, 'code first');
    }
    calls.add('delete');
    goneOn = DateTime(2026, 11, 10);
    _setScheduled(true);
    return goneOn!;
  }

  @override
  Future<DateTime?> deletionDate() async => goneOn;

  @override
  Future<void> restore() async {
    calls.add('restore');
    goneOn = null;
    _setScheduled(false);
  }

  void _setScheduled(bool on) {
    final p = profiles;
    if (p == null) return;
    for (final e in p.profiles.entries.toList()) {
      final m = e.value;
      p.profiles[e.key] = MyProfile(
        id: m.id,
        firstName: m.firstName,
        lastName: m.lastName,
        locale: m.locale,
        tradeId: m.tradeId,
        tradeName: m.tradeName,
        headline: m.headline,
        homeMarketId: m.homeMarketId,
        placeId: m.placeId,
        companyId: m.companyId,
        companyName: m.companyName,
        companyNameText: m.companyNameText,
        deletionScheduled: on,
      );
    }
  }

  @override
  Future<DataRequest?> latestDataRequest() async => request;

  @override
  Future<void> requestMyData() async {
    calls.add('data');
    request = DataRequest(
      status: DataRequestStatus.open,
      createdAt: DateTime(2026, 10, 11),
    );
  }

  @override
  Future<void> setHomeMarket(String userId, String marketId) async {
    calls.add('market $marketId');
  }
}
