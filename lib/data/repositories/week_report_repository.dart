import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/space.dart';
import '../models/week_report.dart';
import '../supabase/supabase_provider.dart';
import 'space_repository.dart';

/// Slice 9 (review 85; migrations 20 and 23): meeting notes into work
/// items, and the week report and its message in the chat. Every rule is
/// the server's: Lead and Crew turn notes into work; every member reads
/// the week report, each only what they may read.
abstract class WeekReportRepository {
  /// create_from_message: the meeting's work item [parentId] titled
  /// [title], owned by me, and one work item per line under it, all
  /// recording [messageId]. The ids are the phone's: a retry is the same
  /// batch.
  Future<void> createFromMessage({
    required String spaceId,
    required String messageId,
    required String parentId,
    required String title,
    required List<MeetingLine> lines,
  });

  /// week_report for the phone's days [from] to [to] (both in, at most 7),
  /// [today] the phone's day.
  Future<WeekReport> weekReport(
    String spaceId, {
    required DateTime from,
    required DateTime to,
    required DateTime today,
  });

  /// share_week_report: a message in [threadId] that opens the week from
  /// [weekStart], under the id the app chose.
  Future<void> share({
    required String id,
    required String threadId,
    required DateTime weekStart,
  });
}

String _date(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

class SupabaseWeekReportRepository implements WeekReportRepository {
  const SupabaseWeekReportRepository(this._client);

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
  Future<void> createFromMessage({
    required String spaceId,
    required String messageId,
    required String parentId,
    required String title,
    required List<MeetingLine> lines,
  }) => _guard(
    () => _client.rpc<String>(
      'create_from_message',
      params: {
        'p_space': spaceId,
        'p_message': messageId,
        'p_parent': parentId,
        'p_title': title,
        'p_lines': [
          for (final l in lines)
            {'id': l.id, 'text': l.text, 'owner': l.ownerId},
        ],
      },
    ),
  );

  @override
  Future<WeekReport> weekReport(
    String spaceId, {
    required DateTime from,
    required DateTime to,
    required DateTime today,
  }) => _guard(() async {
    final first = DateTime(from.year, from.month, from.day);
    final next = DateTime(to.year, to.month, to.day + 1);
    final json = await _client.rpc<Map<String, dynamic>?>(
      'week_report',
      params: {
        'p_space': spaceId,
        'p_today': _date(today),
        'p_from': first.toUtc().toIso8601String(),
        'p_to': next.toUtc().toIso8601String(),
      },
    );
    return WeekReport.fromJson(json);
  });

  @override
  Future<void> share({
    required String id,
    required String threadId,
    required DateTime weekStart,
  }) => _guard(
    () => _client.rpc<String>(
      'share_week_report',
      params: {
        'p_id': id,
        'p_thread': threadId,
        'p_week_start': _date(weekStart),
      },
    ),
  );
}

final weekReportRepositoryProvider = Provider<WeekReportRepository>(
  (ref) => SupabaseWeekReportRepository(ref.watch(supabaseClientProvider)),
);
