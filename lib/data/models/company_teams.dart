import 'package:flutter/foundation.dart';

import 'space.dart';

/// A person in a company group (company_team_preview, review 111).
@immutable
class CompanyPerson {
  const CompanyPerson({
    required this.id,
    required this.name,
    required this.pass,
  });

  factory CompanyPerson.fromJson(Map<String, dynamic> json) => CompanyPerson(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    pass: SpacePass.fromJson(json['pass']),
  );

  final String id;
  final String name;
  final SpacePass pass;
}

/// One company found in a Space: registered, or typed and still plain text
/// (rule 4). [adminId] is whoever Create sets as Team admin, and
/// [adminName] their name (V6); [teamId] the Team of the same name, when
/// there is one.
@immutable
class CompanyGroup {
  const CompanyGroup({
    required this.key,
    required this.name,
    required this.people,
    this.teamId,
    this.teamName,
    this.adminId,
    this.adminName,
  });

  factory CompanyGroup.fromJson(Map<String, dynamic> json) => CompanyGroup(
    key: json['key'] as String,
    name: json['name'] as String,
    teamId: json['team_id'] as String?,
    teamName: json['team_name'] as String?,
    adminId: json['admin_id'] as String?,
    adminName: json['admin_name'] as String?,
    people: _people(json['people']),
  );

  final String key;
  final String name;
  final String? teamId;
  final String? teamName;
  final String? adminId;
  final String? adminName;
  final List<CompanyPerson> people;

  String get shownName => teamName ?? name;
}

List<CompanyPerson> _people(Object? value) => [
  for (final p in (value as List? ?? const []).cast<Map<String, dynamic>>())
    CompanyPerson.fromJson(p),
];

/// A company whose name looks like an existing Team's (V4).
typedef SimilarTeam = ({String key, String teamId, String teamName});

/// company_team_preview: the companies in a Space, the spellings that look
/// alike, and the companies that look like a Team already made. Space
/// admins only. People with no company are left out (V5).
@immutable
class CompanyTeamPreview {
  const CompanyTeamPreview({
    this.groups = const [],
    this.similar = const [],
    this.similarTeams = const [],
  });

  factory CompanyTeamPreview.fromJson(Map<String, dynamic> json) =>
      CompanyTeamPreview(
        groups: [
          for (final g
              in (json['groups'] as List? ?? const [])
                  .cast<Map<String, dynamic>>())
            CompanyGroup.fromJson(g),
        ],
        similar: [
          for (final s
              in (json['similar'] as List? ?? const [])
                  .cast<Map<String, dynamic>>())
            (a: s['a'] as String, b: s['b'] as String),
        ],
        similarTeams: [
          for (final s
              in (json['similar_teams'] as List? ?? const [])
                  .cast<Map<String, dynamic>>())
            (
              key: s['key'] as String,
              teamId: s['team_id'] as String,
              teamName: s['team_name'] as String,
            ),
        ],
      );

  final List<CompanyGroup> groups;
  final List<({String a, String b})> similar;
  final List<SimilarTeam> similarTeams;

  /// Companies of 2 or more people with no Team yet: what TM1 offers.
  List<CompanyGroup> get waiting => [
    for (final g in groups)
      if (g.teamId == null && g.people.length >= 2) g,
  ];
}

/// One Team for create_company_teams to make or add to.
@immutable
class CompanyTeamGroup {
  const CompanyTeamGroup({
    required this.name,
    required this.people,
    this.teamId,
    this.adminId,
  });

  final String name;
  final String? teamId;
  final List<String> people;
  final String? adminId;

  Map<String, dynamic> toJson() => {
    'name': name,
    'team_id': ?teamId,
    'people': people,
    'admin_id': ?adminId,
  };
}

/// The Team a person's company matches (company_team_for, TM4).
@immutable
class CompanyTeamMatch {
  const CompanyTeamMatch({
    required this.teamId,
    required this.teamName,
    required this.company,
  });

  factory CompanyTeamMatch.fromJson(Map<String, dynamic> json) =>
      CompanyTeamMatch(
        teamId: json['team_id'] as String,
        teamName: json['team_name'] as String,
        company: json['company'] as String,
      );

  final String teamId;
  final String teamName;
  final String company;
}

/// A row of TM2 as the Space admin changes it.
class CompanyPlanRow {
  CompanyPlanRow(this.group) : adminId = group.adminId;

  final CompanyGroup group;

  /// Look-alike spellings offered for merging into this row. Each is also
  /// a row of its own until merged (V4).
  final lookAlikes = <CompanyGroup>[];

  /// The keys of the [lookAlikes] merged in.
  final merged = <String>{};

  /// Existing Teams this company looks like (V4), and the one it goes into.
  final similarTeams = <SimilarTeam>[];
  SimilarTeam? intoTeam;

  var ticked = true;

  /// Whoever this row makes Team admin; [picked] when the Space admin chose.
  String? adminId;
  var picked = false;

  /// The row this one was merged into: it isn't shown on its own.
  CompanyPlanRow? mergedInto;

  List<CompanyPerson> get people => [
    ...group.people,
    for (final g in lookAlikes)
      if (merged.contains(g.key)) ...g.people,
  ];
}

/// TM2's sheet between the preview and Create. Every company is a ticked
/// row. A look-alike spelling is offered as a merge on the row it would
/// join (the one with a Team, otherwise the larger) and stays its own row
/// until merged, so nobody is left out (V4). A company like an existing
/// Team is offered to go into it.
class CompanyTeamPlan {
  CompanyTeamPlan._(this.rows, this._teams);

  /// [only]: one company, from the Teams line, with nothing offered.
  /// [teams]: the Space's Teams, for the admin of one merged into.
  factory CompanyTeamPlan.of(
    CompanyTeamPreview preview, {
    String? only,
    List<SpaceTeam> teams = const [],
  }) {
    final byTeam = {for (final t in teams) t.id: t};
    if (only != null) {
      return CompanyTeamPlan._([
        for (final g in preview.groups)
          if (g.key == only) CompanyPlanRow(g),
      ], byTeam);
    }
    final rows = {for (final g in preview.groups) g.key: CompanyPlanRow(g)};
    final guests = <String>{};
    final hosts = <String>{};
    for (final pair in preview.similar) {
      final a = rows[pair.a];
      final b = rows[pair.b];
      if (a == null || b == null) continue;
      if (a.group.teamId != null && b.group.teamId != null) continue;
      final host = _host(a.group, b.group) == a.group ? a : b;
      final guest = host == a ? b : a;
      // One step deep: a guest takes none in, a host goes into none.
      if (guests.contains(host.group.key) ||
          guests.contains(guest.group.key) ||
          hosts.contains(guest.group.key)) {
        continue;
      }
      host.lookAlikes.add(guest.group);
      guests.add(guest.group.key);
      hosts.add(host.group.key);
    }
    for (final t in preview.similarTeams) {
      rows[t.key]?.similarTeams.add(t);
    }
    return CompanyTeamPlan._([...rows.values], byTeam);
  }

  static CompanyGroup _host(CompanyGroup a, CompanyGroup b) {
    if (a.teamId != null) return a;
    if (b.teamId != null) return b;
    return b.people.length > a.people.length ? b : a;
  }

  final List<CompanyPlanRow> rows;
  final Map<String, SpaceTeam> _teams;

  /// The rows on the sheet: none merged into another.
  List<CompanyPlanRow> get shown => [
    for (final r in rows)
      if (r.mergedInto == null) r,
  ];

  int get ticked => shown.where((r) => r.ticked).length;

  /// Create may go: something ticked, and no new Team without people (the
  /// server refuses one).
  bool get ready =>
      ticked > 0 &&
      shown.every(
        (r) => !r.ticked || _teamId(r) != null || r.people.isNotEmpty,
      );

  CompanyPlanRow? _row(String key) =>
      rows.where((r) => r.group.key == key).firstOrNull;

  /// Merges the look-alike [key] into [row], or parts it again. A picked
  /// Team admin who left with the parted spelling goes back to the row's
  /// own suggestion.
  void merge(CompanyPlanRow row, String key) {
    final guest = _row(key);
    if (row.merged.add(key)) {
      guest?.mergedInto = row;
      return;
    }
    row.merged.remove(key);
    guest?.mergedInto = null;
    if (row.picked && !row.people.any((p) => p.id == row.adminId)) {
      row.adminId = row.group.adminId;
      row.picked = false;
    }
  }

  /// [row] goes into the existing Team [teamId], or not any more.
  void mergeTeam(CompanyPlanRow row, String teamId) {
    row.intoTeam = row.intoTeam?.teamId == teamId
        ? null
        : row.similarTeams.where((t) => t.teamId == teamId).firstOrNull;
  }

  void pickAdmin(CompanyPlanRow row, String profileId) {
    row.adminId = profileId;
    row.picked = true;
  }

  /// Who may be picked as the row's Team admin: never a Viewer (V3).
  List<CompanyPerson> adminChoices(CompanyPlanRow row) => [
    for (final p in row.people)
      if (p.pass != SpacePass.viewer) p,
  ];

  String? _teamId(CompanyPlanRow r) => r.intoTeam?.teamId ?? r.group.teamId;

  /// The Team admin Create sends for [r]: into an existing Team that has
  /// an admin, none (that admin stays) unless one was picked.
  String? _adminSent(CompanyPlanRow r) {
    final into = r.intoTeam;
    if (into != null && !r.picked && _teams[into.teamId]?.adminId != null) {
      return null;
    }
    return r.adminId;
  }

  /// The name on [r]'s row: whoever is Team admin once Create is done (V6).
  String? adminName(CompanyPlanRow r) {
    final into = r.intoTeam;
    final sent = _adminSent(r);
    if (into != null && sent == null) return _teams[into.teamId]?.adminName;
    if (sent == null) return null;
    if (sent == r.group.adminId && r.group.adminName != null) {
      return r.group.adminName;
    }
    return r.people.where((p) => p.id == sent).firstOrNull?.name;
  }

  /// What Create sends.
  List<CompanyTeamGroup> groups() => [
    for (final r in shown)
      if (r.ticked)
        CompanyTeamGroup(
          name: r.intoTeam?.teamName ?? r.group.shownName,
          teamId: _teamId(r),
          people: [for (final p in r.people) p.id],
          adminId: _adminSent(r),
        ),
  ];
}
