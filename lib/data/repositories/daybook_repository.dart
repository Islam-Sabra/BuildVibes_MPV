import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/daybook.dart';
import '../models/space.dart';
import '../supabase/supabase_provider.dart';
import 'space_repository.dart';

/// A Space's daybook (migrations 18, 19 and 23): its posts, newest first,
/// the month's marks and what is due for you. Read only here; failures
/// arrive as [SpaceException].
///
/// Days come from the phone: each call sends the phone's own days and
/// midnights, so no time zone is typed in SQL.
abstract class DaybookRepository {
  /// The posts before [before] (with [beforeId], posts made at the same
  /// moment aren't skipped), newest first, at most [limit].
  Future<List<DaybookPost>> page(
    String spaceId, {
    DateTime? before,
    String? beforeId,
    int limit = 30,
  });

  /// The days of [month] with posts the caller can see, and with something
  /// due that isn't checked.
  Future<DaybookMonth> month(String spaceId, DateTime month);

  /// The work items due on [day] that are mine to sign or written by me,
  /// in every Space I'm in.
  Future<List<CalendarWorkItem>> dueOn(DateTime day);
}

String _date(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

String _instant(DateTime t) => t.toUtc().toIso8601String();

class SupabaseDaybookRepository implements DaybookRepository {
  const SupabaseDaybookRepository(this._client);

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

  List<Map<String, dynamic>> _rows(Object? result) =>
      (result as List? ?? const []).cast<Map<String, dynamic>>();

  @override
  Future<List<DaybookPost>> page(
    String spaceId, {
    DateTime? before,
    String? beforeId,
    int limit = 30,
  }) => _guard(() async {
    final rows = _rows(
      await _client.rpc<List<dynamic>>(
        'daybook_page',
        params: {
          'p_space': spaceId,
          'p_before': before == null ? null : _instant(before),
          'p_limit': limit,
          'p_before_id': beforeId,
        },
      ),
    );
    return [
      for (final r in rows)
        DaybookPost.fromJson(r['post'] as Map<String, dynamic>),
    ];
  });

  @override
  Future<DaybookMonth> month(String spaceId, DateTime month) =>
      _guard(() async {
        final first = DateTime(month.year, month.month);
        final next = DateTime(month.year, month.month + 1);
        final rows = _rows(
          await _client.rpc<List<dynamic>>(
            'daybook_month',
            params: {
              'p_space': spaceId,
              'p_from_day': _date(first),
              'p_to_day': _date(next.subtract(const Duration(days: 1))),
              'p_from': _instant(first),
              'p_to': _instant(next),
            },
          ),
        );
        return DaybookMonth.fromRows(rows);
      });

  @override
  Future<List<CalendarWorkItem>> dueOn(DateTime day) => _guard(() async {
    final start = DateTime(day.year, day.month, day.day);
    final rows = _rows(
      await _client.rpc<List<dynamic>>(
        'my_calendar',
        params: {
          'p_from_day': _date(start),
          'p_to_day': _date(start),
          'p_from': _instant(start),
          'p_to': _instant(DateTime(day.year, day.month, day.day + 1)),
        },
      ),
    );
    return [for (final r in rows) ?CalendarWorkItem.fromJson(r)];
  });
}

final daybookRepositoryProvider = Provider<DaybookRepository>(
  (ref) => SupabaseDaybookRepository(ref.watch(supabaseClientProvider)),
);
