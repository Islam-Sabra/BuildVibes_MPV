import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/space.dart';
import '../models/template.dart';
import '../supabase/supabase_provider.dart';
import 'space_repository.dart';

/// Templates and the daily report (slice 7, review 78; migrations 20 and
/// 30). Every rule is the server's: a Lead or a Space admin saves and
/// deletes a Space's templates, at most 50 ([SpaceFailure.limit] past
/// that); a Team's template is for that Team and the admins; the report's
/// lines are only what all its readers may see.
abstract class TemplateRepository {
  /// space_templates: the built-ins first, then the Space's own, newest
  /// first, as the caller may use them.
  Future<List<PostTemplate>> templates(String spaceId);

  /// save_template: [fromPostId]'s words as the template [name], under the
  /// id the app chose (a retry is the same template).
  Future<void> save({
    required String id,
    required String spaceId,
    required String fromPostId,
    required String name,
  });

  /// delete_template: a Space's own; built-ins stay.
  Future<void> delete(String id);

  /// daily_report_fill: what was checked from [from] to [to] (the phone's
  /// day), for a report to [teamId] (null: Everyone), in order.
  Future<List<ReportRef>> checked(
    String spaceId, {
    String? teamId,
    required DateTime from,
    required DateTime to,
  });

  /// daily_report_notes (migration 30): the day's notes, for "On site".
  Future<List<ReportRef>> notes(
    String spaceId, {
    String? teamId,
    required DateTime from,
    required DateTime to,
  });
}

class SupabaseTemplateRepository implements TemplateRepository {
  const SupabaseTemplateRepository(this._client);

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
  Future<List<PostTemplate>> templates(String spaceId) => _guard(() async {
    final rows = _rows(
      await _client.rpc<List<dynamic>>(
        'space_templates',
        params: {'p_space': spaceId},
      ),
    );
    return [
      for (final r in rows)
        if (PostTemplate.kinds.contains(r['kind'])) PostTemplate.fromJson(r),
    ];
  });

  @override
  Future<void> save({
    required String id,
    required String spaceId,
    required String fromPostId,
    required String name,
  }) => _guard(
    () => _client.rpc<String>(
      'save_template',
      params: {
        'p_id': id,
        'p_space': spaceId,
        'p_from_post': fromPostId,
        'p_name': name.trim(),
      },
    ),
  );

  @override
  Future<void> delete(String id) =>
      _guard(() => _client.rpc<void>('delete_template', params: {'p_id': id}));

  Map<String, Object?> _day(
    String spaceId,
    String? teamId,
    DateTime from,
    DateTime to,
  ) => {
    'p_space': spaceId,
    'p_team': teamId,
    'p_from': from.toUtc().toIso8601String(),
    'p_to': to.toUtc().toIso8601String(),
  };

  @override
  Future<List<ReportRef>> checked(
    String spaceId, {
    String? teamId,
    required DateTime from,
    required DateTime to,
  }) => _guard(() async {
    final rows = _rows(
      await _client.rpc<List<dynamic>>(
        'daily_report_fill',
        params: _day(spaceId, teamId, from, to),
      ),
    );
    return [for (final r in rows) ReportRef.checked(r)];
  });

  @override
  Future<List<ReportRef>> notes(
    String spaceId, {
    String? teamId,
    required DateTime from,
    required DateTime to,
  }) => _guard(() async {
    final rows = _rows(
      await _client.rpc<List<dynamic>>(
        'daily_report_notes',
        params: _day(spaceId, teamId, from, to),
      ),
    );
    return [for (final r in rows) ReportRef.note(r)];
  });
}

final templateRepositoryProvider = Provider<TemplateRepository>(
  (ref) => SupabaseTemplateRepository(ref.watch(supabaseClientProvider)),
);

/// The templates the reader may use in a Space, read again after a save
/// or a delete.
final spaceTemplatesProvider = FutureProvider.autoDispose
    .family<List<PostTemplate>, String>(
      (ref, spaceId) => ref.watch(templateRepositoryProvider).templates(spaceId),
    );
