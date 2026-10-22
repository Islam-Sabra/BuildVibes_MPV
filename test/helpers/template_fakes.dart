import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/models/template.dart';
import 'package:buildvibes/data/repositories/template_repository.dart';

/// The built-in Daily report, as migration 20 keeps it.
final dailyReportTemplate = PostTemplate(
  id: PostTemplate.dailyReportId,
  kind: 'report',
  builtinKey: PostTemplate.dailyReportKey,
  createdAt: DateTime(2026, 10, 16),
  blocks: const [
    {
      'id': '00000000-0000-4000-8000-0000000d0011',
      'type': 'heading',
      'key': PostTemplate.onSiteKey,
    },
    {
      'id': '00000000-0000-4000-8000-0000000d0012',
      'type': 'heading',
      'key': PostTemplate.doneTodayKey,
    },
    {
      'id': '00000000-0000-4000-8000-0000000d0013',
      'type': 'heading',
      'key': PostTemplate.problemsKey,
    },
  ],
);

/// Templates and the daily report's fill in memory, with the server's
/// rules that matter to the app: at most 50 of a Space's own, built-ins
/// can't be deleted.
class FakeTemplateRepository implements TemplateRepository {
  FakeTemplateRepository({List<PostTemplate>? kept})
    : kept = kept ?? [dailyReportTemplate];

  /// Every template, in the order they were made.
  final List<PostTemplate> kept;

  /// daily_report_fill's rows, by Team (null: Everyone).
  final checkedByTeam = <String?, List<ReportRef>>{};

  /// daily_report_notes' rows; [notesOffline] as when migration 30 isn't
  /// there.
  final notesByTeam = <String?, List<ReportRef>>{};
  bool notesOffline = false;

  final calls = <String>[];
  bool offline = false;

  /// The Space's own, as save_template counts them.
  int get own => kept.where((t) => !t.isBuiltin).length;

  @override
  Future<List<PostTemplate>> templates(String spaceId) async {
    if (offline) throw const SpaceException(SpaceFailure.network);
    // The built-ins first, then the Space's own, newest first.
    return [
      for (final t in kept)
        if (t.isBuiltin) t,
      ...[
        for (final t in kept)
          if (!t.isBuiltin) t,
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
    ];
  }

  @override
  Future<void> save({
    required String id,
    required String spaceId,
    required String fromPostId,
    required String name,
  }) async {
    calls.add('save $fromPostId $name');
    if (own >= PostTemplate.perSpace) {
      throw const SpaceException(SpaceFailure.limit);
    }
    kept.add(
      PostTemplate(
        id: id,
        kind: 'work_item',
        name: name,
        createdAt: DateTime(2026, 10, 15),
      ),
    );
  }

  @override
  Future<void> delete(String id) async {
    calls.add('delete $id');
    final t = kept.where((t) => t.id == id).firstOrNull;
    if (t == null || t.isBuiltin) {
      throw const SpaceException(SpaceFailure.notAllowed);
    }
    kept.remove(t);
  }

  @override
  Future<List<ReportRef>> checked(
    String spaceId, {
    String? teamId,
    required DateTime from,
    required DateTime to,
  }) async {
    calls.add('fill ${teamId ?? 'everyone'}');
    return [
      for (final r in checkedByTeam[teamId] ?? const <ReportRef>[])
        if (!r.at.isBefore(from) && r.at.isBefore(to)) r,
    ];
  }

  @override
  Future<List<ReportRef>> notes(
    String spaceId, {
    String? teamId,
    required DateTime from,
    required DateTime to,
  }) async {
    if (notesOffline) throw const SpaceException(SpaceFailure.unknown);
    return notesByTeam[teamId] ?? const [];
  }
}
