import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/check_in.dart';
import '../models/space.dart';
import '../supabase/supabase_provider.dart';
import 'space_repository.dart' show spaceFailureFor;

/// Review 109: Check-in's server calls. Failures arrive as
/// [SpaceException]; [CheckInRefusal.of] says which.
///
/// The person's point goes to [mark] and nowhere else: it is never kept
/// on the phone, logged, or put in an error.
abstract class CheckInRepository {
  /// post_check_in: Leads and the Space admin only. The app chose
  /// [NewCheckIn.id], so sending it again is the same post.
  Future<void> post(NewCheckIn checkIn);

  /// mark_check_in: In or Out for today. With no [lat] and [lng], the
  /// mark says "location not shared".
  Future<CheckInResult> mark(
    String postId,
    CheckInMarkKind kind, {
    double? lat,
    double? lng,
  });

  /// stop_check_in: the creator stops a repeating one.
  Future<void> stop(String postId);

  /// check_in_list: one line per person asked, on [day].
  Future<List<CheckInLine>> list(String postId, DateTime day);

  /// check_in_days: the days it ran, newest first.
  Future<List<DateTime>> days(String postId);
}

/// A Check-in as post_check_in takes it (the contract's names).
@immutable
class NewCheckIn {
  const NewCheckIn({
    required this.id,
    required this.spaceId,
    required this.title,
    required this.siteLat,
    required this.siteLng,
    required this.inTime,
    required this.inAllow,
    this.body,
    this.teamIds,
    this.outTime,
    this.outAllow,
    this.daily = false,
  });

  final String id;
  final String spaceId;
  final String title;
  final String? body;

  /// The Teams asked; null or empty: the whole Space.
  final List<String>? teamIds;

  /// The post's site: where the Lead stood when they tapped Set place
  /// here. A site, never a person's track.
  final double siteLat;
  final double siteLng;
  final DayTime inTime;
  final int inAllow;
  final DayTime? outTime;
  final int? outAllow;
  final bool daily;

  Map<String, Object?> toParams() {
    final body = this.body?.trim() ?? '';
    final teams = teamIds;
    return {
      'p_id': id,
      'p_space': spaceId,
      'p_title': title.trim(),
      'p_body': body.isEmpty ? null : body,
      'p_teams': teams == null || teams.isEmpty ? null : teams,
      'p_site_lat': siteLat,
      'p_site_lng': siteLng,
      'p_in_time': inTime.json,
      'p_in_allow': inAllow,
      'p_out_time': outTime?.json,
      'p_out_allow': outTime == null ? null : outAllow,
      'p_daily': daily,
    };
  }
}

class SupabaseCheckInRepository implements CheckInRepository {
  const SupabaseCheckInRepository(this._client);

  final SupabaseClient _client;

  /// As the daybook's: the server's refusal by its code; no connection is
  /// [SpaceFailure.network]. Only the server's message is kept, never the
  /// call's params.
  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on PostgrestException catch (e) {
      throw SpaceException(spaceFailureFor(e.code), e.message);
    } on Exception catch (e) {
      final network = e is SocketException || '$e'.contains('SocketException');
      throw SpaceException(
        network ? SpaceFailure.network : SpaceFailure.unknown,
        network ? null : e.runtimeType.toString(),
      );
    }
  }

  @override
  Future<void> post(NewCheckIn checkIn) => _guard(
    () => _client.rpc<String>('post_check_in', params: checkIn.toParams()),
  );

  @override
  Future<CheckInResult> mark(
    String postId,
    CheckInMarkKind kind, {
    double? lat,
    double? lng,
  }) => _guard(() async {
    final shared = lat != null && lng != null;
    final result = await _client.rpc<Map<String, dynamic>>(
      'mark_check_in',
      params: {
        'p_post': postId,
        'p_kind': kind.json,
        'p_lat': shared ? lat : null,
        'p_lng': shared ? lng : null,
      },
    );
    return CheckInResult.fromJson(result);
  });

  @override
  Future<void> stop(String postId) => _guard(
    () => _client.rpc<void>('stop_check_in', params: {'p_post': postId}),
  );

  @override
  Future<List<CheckInLine>> list(String postId, DateTime day) =>
      _guard(() async {
        final rows = await _client.rpc<List<dynamic>>(
          'check_in_list',
          params: {'p_post': postId, 'p_day': checkInDayJson(day)},
        );
        return [
          for (final r in rows) CheckInLine.fromJson(r as Map<String, dynamic>),
        ];
      });

  @override
  Future<List<DateTime>> days(String postId) => _guard(() async {
    final rows = await _client.rpc<List<dynamic>?>(
      'check_in_days',
      params: {'p_post': postId},
    );
    return [for (final d in rows ?? const []) ?checkInDayOf('$d')];
  });
}

final checkInRepositoryProvider = Provider<CheckInRepository>(
  (ref) => SupabaseCheckInRepository(ref.watch(supabaseClientProvider)),
);

/// The days a check-in ran (CI5's day picker), newest first.
final checkInDaysProvider = FutureProvider.autoDispose
    .family<List<DateTime>, String>(
      (ref, postId) => ref.watch(checkInRepositoryProvider).days(postId),
    );

/// The creator's list for one day (CI5).
final checkInListProvider = FutureProvider.autoDispose
    .family<List<CheckInLine>, ({String postId, DateTime day})>(
      (ref, key) =>
          ref.watch(checkInRepositoryProvider).list(key.postId, key.day),
    );
