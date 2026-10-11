import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/l10n/months.dart';
import '../models/project.dart';
import '../supabase/supabase_provider.dart';

/// Shared project records (PJ1, P13, P14). A record has no owner: it is
/// created once through create_project and never edited from the app.
abstract class ProjectRepository {
  /// "Is it already here?": similar names, or the same site.
  Future<List<ProjectMatch>> findSimilar(String name, {String? placeId});

  Future<ProjectRecord?> fetch(String id);

  /// Creates the record and returns its id.
  Future<String> create(NewProjectInput input, {required DateTime now});

  Future<List<RefOption>> projectTypes();

  /// People who put the project on their CV and show it, without [me].
  Future<List<ProjectPerson>> people(String projectId, {required String me});

  /// The signed-in person's CV entry for the project, if any.
  Future<MyCvEntry?> myCvEntry(String projectId, String me);

  /// Ids of projects already on the person's CV.
  Future<Set<String>> myProjectIds(String me);

  Future<void> addToCv(String projectId, CvEntryInput input);

  Future<void> suggestEdit(String projectId, EditField field, String value);
}

class SupabaseProjectRepository implements ProjectRepository {
  const SupabaseProjectRepository(this._client);

  final SupabaseClient _client;

  static const _record =
      'id, name, type_id, market_id, place_id, location_text, start_month, '
      'end_month, end_expected, type:project_types(name), place:places(name)';

  @override
  Future<List<ProjectMatch>> findSimilar(String name, {String? placeId}) async {
    final rows = await _client.rpc<List<dynamic>>(
      'find_similar_projects',
      params: {'p_name': name, 'p_place_id': placeId},
    );
    if (rows.isEmpty) return const [];
    final reasons = {
      for (final r in rows.cast<Map<String, dynamic>>())
        r['id'] as String: r['reason'] == 'same_site'
            ? MatchReason.sameSite
            : MatchReason.sameName,
    };
    final records = await _client
        .from('projects')
        .select(_record)
        .inFilter('id', reasons.keys.toList());
    final byId = {
      for (final r in records) r['id'] as String: ProjectRecord.fromJson(r),
    };
    // Keep the server's order (best match first).
    return [
      for (final id in reasons.keys)
        if (byId[id] != null)
          ProjectMatch(project: byId[id]!, reason: reasons[id]!),
    ];
  }

  @override
  Future<ProjectRecord?> fetch(String id) async {
    final row = await _client
        .from('projects')
        .select(_record)
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : ProjectRecord.fromJson(row);
  }

  @override
  Future<String> create(NewProjectInput input, {required DateTime now}) async {
    final id = await _client.rpc<String>(
      'create_project',
      params: {
        'p_name': input.name.trim(),
        'p_type_id': input.typeId,
        'p_market_id': input.marketId,
        'p_place_id': input.placeId,
        'p_start_month': monthToJson(input.start),
        'p_end_month': monthToJson(input.end),
        'p_end_expected': input.endExpectedAt(now),
      },
    );
    return id;
  }

  @override
  Future<List<RefOption>> projectTypes() async {
    final rows = await _client
        .from('project_types')
        .select('id, name, sort')
        .order('sort', ascending: true);
    return [for (final r in rows) RefOption.fromJson(r)];
  }

  @override
  Future<List<ProjectPerson>> people(
    String projectId, {
    required String me,
  }) async {
    final rows = await _client
        .from('cv_projects')
        .select(
          'profile_id, role_title, start_month, end_month, '
          // Two links to profiles (owner, and confirmers through confirmations);
          // name the owner one.
          'profile:profiles!cv_projects_profile_id_fkey(first_name, last_name)',
        )
        .eq('project_id', projectId)
        .eq('show_on_profile', true)
        .neq('profile_id', me)
        .order('start_month', ascending: true);
    return [
      for (final r in rows)
        if (r['profile'] != null)
          ProjectPerson(
            profileId: r['profile_id'] as String,
            firstName:
                (r['profile'] as Map<String, dynamic>)['first_name'] as String,
            lastName:
                (r['profile'] as Map<String, dynamic>)['last_name'] as String,
            role: r['role_title'] as String,
            start: parseMonth(r['start_month']),
            end: parseMonth(r['end_month']),
          ),
    ];
  }

  @override
  Future<MyCvEntry?> myCvEntry(String projectId, String me) async {
    final row = await _client
        .from('cv_projects')
        .select(
          'id, role_title, start_month, end_month, '
          'confirmations:cv_project_confirmations(confirmed_by)',
        )
        .eq('project_id', projectId)
        .eq('profile_id', me)
        .maybeSingle();
    return row == null ? null : MyCvEntry.fromJson(row);
  }

  @override
  Future<Set<String>> myProjectIds(String me) async {
    final rows = await _client
        .from('cv_projects')
        .select('project_id')
        .eq('profile_id', me);
    return {for (final r in rows) r['project_id'] as String};
  }

  @override
  Future<void> addToCv(String projectId, CvEntryInput input) => _client
      .from('cv_projects')
      .insert({...input.toJson(), 'project_id': projectId});

  @override
  Future<void> suggestEdit(String projectId, EditField field, String value) =>
      _client.from('project_edit_suggestions').insert({
        'project_id': projectId,
        'field': field.name,
        'correct_value': value.trim(),
      });
}

final projectRepositoryProvider = Provider<ProjectRepository>(
  (ref) => SupabaseProjectRepository(ref.watch(supabaseClientProvider)),
);

final projectProvider = FutureProvider.autoDispose
    .family<ProjectRecord?, String>(
      (ref, id) => ref.watch(projectRepositoryProvider).fetch(id),
    );

final projectTypesProvider = FutureProvider<List<RefOption>>(
  (ref) => ref.watch(projectRepositoryProvider).projectTypes(),
);
