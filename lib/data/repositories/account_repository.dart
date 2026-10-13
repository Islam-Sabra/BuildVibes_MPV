import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/space.dart';
import '../supabase/supabase_provider.dart';
import 'space_repository.dart';

/// S12b: a Space you are the only admin of, with others still in it.
@immutable
class DeletionBlocker {
  const DeletionBlocker({required this.spaceId, required this.spaceName});

  final String spaceId;
  final String spaceName;
}

enum DataRequestStatus { open, sent }

/// Your latest Download my data request (S10, S11).
@immutable
class DataRequest {
  const DataRequest({required this.status, required this.createdAt});

  factory DataRequest.fromJson(Map<String, dynamic> j) => DataRequest(
    status: DataRequestStatus.values.byName(j['status'] as String),
    createdAt: DateTime.parse(j['created_at'] as String),
  );

  final DataRequestStatus status;
  final DateTime createdAt;
}

/// Delete account, Download my data and the home market (migration 16).
abstract class AccountRepository {
  Future<List<DeletionBlocker>> deletionBlockers();

  /// Hides the account now; returns when it goes for good. Needs a code
  /// entered in the last 10 minutes.
  Future<DateTime> requestDeletion();

  /// S14: when it goes for good, or null when nothing is scheduled.
  Future<DateTime?> deletionDate();
  Future<void> restore();

  Future<DataRequest?> latestDataRequest();
  Future<void> requestMyData();

  /// S8 Country. The place is cleared: it belongs to the old market.
  Future<void> setHomeMarket(String userId, String marketId);
}

class SupabaseAccountRepository implements AccountRepository {
  const SupabaseAccountRepository(this._client);

  final SupabaseClient _client;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on PostgrestException catch (e) {
      throw SpaceException(spaceFailureFor(e.code), e.message);
    } on Exception catch (e) {
      final network = e is SocketException || '$e'.contains('SocketException');
      throw SpaceException(
        network ? SpaceFailure.network : SpaceFailure.unknown,
        '$e',
      );
    }
  }

  @override
  Future<List<DeletionBlocker>> deletionBlockers() => _guard(() async {
    final rows = (await _client.rpc<List<dynamic>>(
      'account_deletion_blockers',
    )).cast<Map<String, dynamic>>();
    return [
      for (final r in rows)
        DeletionBlocker(
          spaceId: r['space_id'] as String,
          spaceName: r['space_name'] as String,
        ),
    ];
  });

  @override
  Future<DateTime> requestDeletion() => _guard(() async {
    final at = await _client.rpc<String>('request_account_deletion');
    return DateTime.parse(at).toLocal();
  });

  @override
  Future<DateTime?> deletionDate() => _guard(() async {
    final at = await _client.rpc<String?>('my_account_deletion');
    return at == null ? null : DateTime.parse(at).toLocal();
  });

  @override
  Future<void> restore() => _guard(() => _client.rpc('restore_account'));

  @override
  Future<DataRequest?> latestDataRequest() => _guard(() async {
    final row = await _client
        .from('data_requests')
        .select('status, created_at')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : DataRequest.fromJson(row);
  });

  @override
  Future<void> requestMyData() => _guard(() => _client.rpc('request_my_data'));

  @override
  Future<void> setHomeMarket(String userId, String marketId) => _guard(
    () => _client
        .from('profiles')
        .update({'home_market_id': marketId, 'place_id': null})
        .eq('id', userId),
  );
}

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => SupabaseAccountRepository(ref.watch(supabaseClientProvider)),
);

final deletionBlockersProvider =
    FutureProvider.autoDispose<List<DeletionBlocker>>(
      (ref) => ref.watch(accountRepositoryProvider).deletionBlockers(),
    );

final deletionDateProvider = FutureProvider.autoDispose<DateTime?>(
  (ref) => ref.watch(accountRepositoryProvider).deletionDate(),
);

final dataRequestProvider = FutureProvider.autoDispose<DataRequest?>(
  (ref) => ref.watch(accountRepositoryProvider).latestDataRequest(),
);
