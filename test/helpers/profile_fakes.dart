import 'dart:typed_data';

import 'package:buildvibes/data/models/market.dart';
import 'package:buildvibes/data/models/profile.dart';
import 'package:buildvibes/data/models/project.dart';
import 'package:buildvibes/data/repositories/profile_page_repository.dart';
import 'package:buildvibes/data/repositories/project_repository.dart';

import 'fakes.dart';

LocalizedText _l(String en, String ar) => LocalizedText(en: en, ar: ar);

final testProjectTypes = [
  RefOption(id: 'commercial', name: _l('Commercial', 'تجاري')),
  RefOption(id: 'residential', name: _l('Residential', 'سكني')),
  RefOption(id: 'mixed_use', name: _l('Mixed use', 'متعدد الاستخدامات')),
];

final testPlaces = [
  (id: 'kw-capital', name: _l('Capital', 'العاصمة'), isCity: true),
  (id: 'kw-fahaheel', name: _l('Fahaheel', 'الفحيحيل'), isCity: false),
];

/// In-memory profile pages built on [FakeProfileRepository]'s profiles.
class FakeProfilePageRepository implements ProfilePageRepository {
  FakeProfilePageRepository(this.people);

  final FakeProfileRepository people;
  final about = <String, String>{};
  final headline = <String, String>{};
  final photo = <String, String>{};
  final place = <String, String>{};
  final experience = <String, List<ExperienceEntry>>{};
  final openTo = <String, OpenTo>{};
  final cv = <String, List<CvProjectEntry>>{};
  final blocked = <String>{};
  final followerCounts = <String, int>{};
  var _ids = 0;

  @override
  Future<ProfileView?> fetch(String profileId) async {
    final p = people.profiles[profileId];
    if (p == null || blocked.contains(profileId)) return null;
    final placeId = place[profileId] ?? p.placeId;
    return ProfileView(
      id: p.id,
      firstName: p.firstName,
      lastName: p.lastName,
      followerCount: followerCounts[profileId] ?? 0,
      followingCount: 0,
      headline: headline[profileId] ?? p.headline,
      tradeId: p.tradeId,
      tradeName: testRolePicker.byId(p.tradeId)?.name ?? p.tradeName,
      placeId: placeId,
      placeName: testPlaces.where((x) => x.id == placeId).firstOrNull?.name,
      homeMarketId: p.homeMarketId,
      companyId: p.companyId,
      companyName: p.companyName,
      companyNameText: p.companyNameText,
      photoPath: photo[profileId],
      about: about[profileId],
      openTo: openTo[profileId],
      experience: experience[profileId] ?? const [],
      projects: cv[profileId] ?? const [],
    );
  }

  @override
  Future<bool> isFollowing(String me, String other) async =>
      people.follows.contains(other);

  @override
  Future<void> saveBasics(String me, BasicsInput input) async {
    final p = people.profiles[me]!;
    people.profiles[me] = p.copyWithNames(
      input.firstName.trim(),
      input.lastName.trim(),
      tradeId: input.tradeId ?? p.tradeId,
    );
    if ((input.headline ?? '').isNotEmpty) headline[me] = input.headline!;
    if (input.placeId != null) place[me] = input.placeId!;
  }

  @override
  Future<void> saveAbout(String me, String text) async => about[me] = text;

  @override
  Future<String> savePhoto(
    String me,
    Uint8List bytes,
    String extension,
  ) async => photo[me] = '$me/photo.$extension';

  @override
  Future<void> removePhoto(String me, String path) async => photo.remove(me);

  @override
  Future<void> addExperience(String me, ExperienceInput input) async {
    (experience[me] ??= []).add(
      ExperienceEntry(
        id: 'exp-${_ids++}',
        title: input.title.trim(),
        start: input.start,
        end: input.end,
        companyLabel: input.companyNameText,
        visibility: input.visibility,
      ),
    );
  }

  @override
  Future<void> updateExperience(String id, ExperienceInput input) async {
    for (final list in experience.values) {
      final i = list.indexWhere((e) => e.id == id);
      if (i >= 0) {
        list[i] = ExperienceEntry(
          id: id,
          title: input.title.trim(),
          start: input.start,
          end: input.end,
          companyLabel: input.companyNameText,
          visibility: input.visibility,
        );
      }
    }
  }

  @override
  Future<void> deleteExperience(String id) async {
    for (final list in experience.values) {
      list.removeWhere((e) => e.id == id);
    }
  }

  @override
  Future<void> saveOpenTo(String me, OpenTo value) async => openTo[me] = value;

  @override
  Future<void> setCvVisibility(String cvProjectId, bool show) async {
    for (final list in cv.values) {
      final i = list.indexWhere((e) => e.id == cvProjectId);
      if (i >= 0) list[i] = list[i].withShow(show);
    }
  }

  @override
  Future<void> block(String me, String other) async => blocked.add(other);

  @override
  Future<List<({String id, LocalizedText name, bool isCity})>> places(
    String marketId,
  ) async => testPlaces;
}

/// In-memory project records. CV entries go into the page repository so
/// profiles show them.
class FakeProjectRepository implements ProjectRepository {
  FakeProjectRepository(this.pages, {required this.me});

  final FakeProfilePageRepository pages;
  final String me;
  final records = <String, ProjectRecord>{};
  final suggestions = <(String, EditField, String)>[];
  final others = <String, List<ProjectPerson>>{};
  var _ids = 0;

  ProjectRecord add(
    String name, {
    String typeId = 'commercial',
    String? placeId,
  }) {
    final id = 'project-${_ids++}';
    return records[id] = ProjectRecord(
      id: id,
      name: name,
      typeId: typeId,
      marketId: 'kw',
      typeName: testProjectTypes.firstWhere((t) => t.id == typeId).name,
      placeId: placeId,
      placeName: testPlaces.where((p) => p.id == placeId).firstOrNull?.name,
    );
  }

  @override
  Future<List<ProjectMatch>> findSimilar(String name, {String? placeId}) async {
    final q = name.toLowerCase();
    return [
      for (final r in records.values)
        if (r.name.toLowerCase().contains(q) ||
            q.contains(r.name.toLowerCase()))
          ProjectMatch(project: r, reason: MatchReason.sameName),
    ];
  }

  @override
  Future<ProjectRecord?> fetch(String id) async => records[id];

  @override
  Future<String> create(NewProjectInput input, {required DateTime now}) async {
    final r = add(
      input.name.trim(),
      typeId: input.typeId,
      placeId: input.placeId,
    );
    return r.id;
  }

  @override
  Future<List<RefOption>> projectTypes() async => testProjectTypes;

  @override
  Future<List<ProjectPerson>> people(
    String projectId, {
    required String me,
  }) async => others[projectId] ?? const [];

  @override
  Future<MyCvEntry?> myCvEntry(String projectId, String me) async {
    final e = (pages.cv[me] ?? const <CvProjectEntry>[])
        .where((c) => c.projectId == projectId)
        .firstOrNull;
    return e == null
        ? null
        : MyCvEntry(
            id: e.id,
            role: e.role,
            confirmed: e.confirmed,
            start: e.start,
            end: e.end,
          );
  }

  @override
  Future<Set<String>> myProjectIds(String me) async => {
    for (final c in pages.cv[me] ?? const <CvProjectEntry>[]) c.projectId,
  };

  @override
  Future<void> addToCv(String projectId, CvEntryInput input) async {
    final r = records[projectId]!;
    (pages.cv[me] ??= []).add(
      CvProjectEntry(
        id: 'cv-${_ids++}',
        projectId: projectId,
        projectName: r.name,
        role: input.role.trim(),
        showOnProfile: input.showOnProfile,
        confirmed: false,
        projectType: r.typeName,
        placeName: r.placeName,
        start: input.start,
        end: input.end,
      ),
    );
  }

  @override
  Future<void> suggestEdit(
    String projectId,
    EditField field,
    String value,
  ) async => suggestions.add((projectId, field, value));
}

extension CvCopy on CvProjectEntry {
  CvProjectEntry withShow(bool show) => CvProjectEntry(
    id: id,
    projectId: projectId,
    projectName: projectName,
    role: role,
    showOnProfile: show,
    confirmed: confirmed,
    projectType: projectType,
    placeName: placeName,
    start: start,
    end: end,
  );
}
