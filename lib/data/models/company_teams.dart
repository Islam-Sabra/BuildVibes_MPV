import 'package:flutter/foundation.dart';

import 'space.dart';

/// Stands for the people with no company in a [CompanyPlanRow].
const noCompanyKey = '';

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
/// (rule 4). [adminId] is the server's suggested Team admin; [teamId] the
/// Team of the same name, when there is one.
@immutable
class CompanyGroup {
  const CompanyGroup({
    required this.key,
    required this.name,
    required this.people,
    this.teamId,
    this.teamName,
    this.adminId,
  });

  factory CompanyGroup.fromJson(Map<String, dynamic> json) => CompanyGroup(
    key: json['key'] as String,
    name: json['name'] as String,
    teamId: json['team_id'] as String?,
    teamName: json['team_name'] as String?,
    adminId: json['admin_id'] as String?,
    people: _people(json['people']),
  );

  final String key;
  final String name;
  final String? teamId;
  final String? teamName;
  final String? adminId;
  final List<CompanyPerson> people;

  String get shownName => teamName ?? name;
}

List<CompanyPerson> _people(Object? value) => [
  for (final p in (value as List? ?? const []).cast<Map<String, dynamic>>())
    CompanyPerson.fromJson(p),
];

/// company_team_preview: the companies in a Space, the spellings that look
/// alike and the people with no company. Space admins only.
@immutable
class CompanyTeamPreview {
  const CompanyTeamPreview({
    this.groups = const [],
    this.similar = const [],
    this.noCompany = const [],
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
        noCompany: _people(json['no_company']),
      );

  final List<CompanyGroup> groups;
  final List<({String a, String b})> similar;
  final List<CompanyPerson> noCompany;

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
  CompanyPlanRow(this.group, {required this.ticked}) : adminId = group.adminId;

  final CompanyGroup group;

  /// The spellings offered for merging into this row.
  final lookAlikes = <CompanyGroup>[];

  /// The keys of the [lookAlikes] merged in.
  final merged = <String>{};
  bool ticked;
  String? adminId;

  List<CompanyPerson> get people => [
    ...group.people,
    for (final g in lookAlikes)
      if (merged.contains(g.key)) ...g.people,
  ];
}

/// TM2's sheet between the preview and Create. A look-alike spelling folds
/// under the row it would join: the one with a Team, otherwise the larger.
/// It joins only when the Space admin taps merge, and until then it makes
/// no Team of its own (the Teams tab offers it again later).
class CompanyTeamPlan {
  CompanyTeamPlan._(this.rows);

  /// [only]: one company, from the Teams line; its look-alikes stay out.
  factory CompanyTeamPlan.of(CompanyTeamPreview preview, {String? only}) {
    if (only != null) {
      return CompanyTeamPlan._([
        for (final g in preview.groups)
          if (g.key == only) CompanyPlanRow(g, ticked: true),
      ]);
    }
    final byKey = {for (final g in preview.groups) g.key: g};
    final folded = <String, String>{};
    for (final pair in preview.similar) {
      final a = byKey[pair.a];
      final b = byKey[pair.b];
      if (a == null || b == null) continue;
      if (a.teamId != null && b.teamId != null) continue;
      final host = _host(a, b);
      final guest = host == a ? b : a;
      final taken =
          folded.containsKey(host.key) ||
          folded.containsKey(guest.key) ||
          folded.containsValue(guest.key);
      if (!taken) folded[guest.key] = host.key;
    }
    final rows = <CompanyPlanRow>[
      for (final g in preview.groups)
        if (!folded.containsKey(g.key)) CompanyPlanRow(g, ticked: true),
    ];
    for (final row in rows) {
      row.lookAlikes.addAll([
        for (final e in folded.entries)
          if (e.value == row.group.key) byKey[e.key]!,
      ]);
    }
    return CompanyTeamPlan._([
      ...rows,
      if (preview.noCompany.isNotEmpty)
        CompanyPlanRow(
          CompanyGroup(key: noCompanyKey, name: '', people: preview.noCompany),
          ticked: false,
        ),
    ]);
  }

  static CompanyGroup _host(CompanyGroup a, CompanyGroup b) {
    if (a.teamId != null) return a;
    if (b.teamId != null) return b;
    return b.people.length > a.people.length ? b : a;
  }

  final List<CompanyPlanRow> rows;

  int get ticked => rows.where((r) => r.ticked).length;

  /// Merges [key] into [row], or parts it again. A Team admin who left with
  /// the parted spelling goes back to the row's own suggestion.
  void merge(CompanyPlanRow row, String key) {
    if (!row.merged.remove(key)) {
      row.merged.add(key);
      return;
    }
    if (!row.people.any((p) => p.id == row.adminId)) {
      row.adminId = row.group.adminId;
    }
  }

  /// What Create sends; [noCompanyName] names the No company row.
  List<CompanyTeamGroup> groups(String noCompanyName) => [
    for (final r in rows)
      if (r.ticked)
        CompanyTeamGroup(
          name: r.group.key == noCompanyKey ? noCompanyName : r.group.shownName,
          teamId: r.group.teamId,
          people: [for (final p in r.people) p.id],
          adminId: r.adminId,
        ),
  ];
}
