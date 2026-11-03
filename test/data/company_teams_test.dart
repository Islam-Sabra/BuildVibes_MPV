// Review 111: what company_team_preview returns and create_company_teams
// takes, and the sheet's plan between them (TM2): every company ticked; a
// look-alike spelling its own row until merged (V4), people with no company
// left out (V5), and the row naming whoever Create sets (V6).
import 'package:buildvibes/data/models/company_teams.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/repositories/space_repository.dart';
import 'package:buildvibes/features/spaces/space_errors.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _p(String id, [String pass = 'crew']) => {
  'id': id,
  'name': 'N $id',
  'pass': pass,
};

CompanyTeamPreview _preview() => CompanyTeamPreview.fromJson({
  'groups': [
    {
      'key': 'abc contracting',
      'name': 'ABC Contracting',
      'admin_id': 'omar',
      'admin_name': 'Omar Haddad',
      'people': [_p('omar', 'lead'), _p('a')],
    },
    {
      'key': 'a.b.c',
      'name': 'A.B.C Contracting',
      'admin_id': 'b',
      'admin_name': 'N b',
      'people': [_p('b')],
    },
    {
      'key': 'gulf',
      'name': 'Gulf MEP',
      'team_id': 't-gulf',
      'team_name': 'Gulf MEP Team',
      // V6: the Team's admin is already in it, not among its new people.
      'admin_id': 'rakesh',
      'admin_name': 'Rakesh Nair',
      'people': [_p('c'), _p('d')],
    },
    {
      'key': 'delta steal',
      'name': 'Delta Steal',
      'admin_id': 'e',
      'admin_name': 'N e',
      'people': [_p('e'), _p('f')],
    },
  ],
  'similar': [
    {'a': 'a.b.c', 'b': 'abc contracting'},
  ],
  'similar_teams': [
    {'key': 'delta steal', 'team_id': 't-delta', 'team_name': 'Delta Steel'},
  ],
  'no_company': [_p('n')],
});

const _teams = [
  SpaceTeam(
    id: 't-delta',
    name: 'Delta Steel',
    adminId: 'khalid',
    adminName: 'Khalid Al-Mansour',
  ),
  SpaceTeam(id: 't-empty', name: 'Empty'),
];

void main() {
  test('reads the preview: the pass, a Team already made, the admin name '
      'and the look-alike Teams', () {
    final p = _preview();
    expect(p.groups.first.people.first.pass, SpacePass.lead);
    expect(p.groups[2].teamId, 't-gulf');
    expect(p.groups[2].shownName, 'Gulf MEP Team');
    expect(p.groups[2].adminName, 'Rakesh Nair');
    expect(p.similarTeams.single.teamName, 'Delta Steel');
  });

  test('waiting: companies of 2 or more with no Team', () {
    expect(_preview().waiting.map((g) => g.key), [
      'abc contracting',
      'delta steal',
    ]);
  });

  test('an empty answer is an empty preview', () {
    final p = CompanyTeamPreview.fromJson(const {});
    expect(p.groups, isEmpty);
    expect(p.similarTeams, isEmpty);
  });

  test('V5: people with no company are left out; no row, nothing sent', () {
    final plan = CompanyTeamPlan.of(_preview());
    expect(plan.rows.map((r) => r.group.key), [
      'abc contracting',
      'a.b.c',
      'gulf',
      'delta steal',
    ]);
    expect(plan.groups().expand((g) => g.people), isNot(contains('n')));
  });

  test('V4: an unmerged look-alike is its own ticked row, offered on the '
      'larger one; nobody is left out', () {
    final plan = CompanyTeamPlan.of(_preview());
    final abc = plan.rows.first;
    expect(abc.lookAlikes.single.key, 'a.b.c');
    expect(plan.shown.map((r) => r.group.key), contains('a.b.c'));
    expect(plan.ticked, 4);
    expect(plan.groups().map((g) => g.name), contains('A.B.C Contracting'));
  });

  test('V4: merging joins the people under the one name and hides the '
      'look-alike; undoing brings its row back', () {
    final plan = CompanyTeamPlan.of(_preview());
    final abc = plan.rows.first;
    plan.merge(abc, 'a.b.c');
    expect(plan.shown.map((r) => r.group.key), isNot(contains('a.b.c')));
    expect(plan.ticked, 3);
    expect(plan.groups().first.toJson(), {
      'name': 'ABC Contracting',
      'people': ['omar', 'a', 'b'],
      'admin_id': 'omar',
    });
    plan.merge(abc, 'a.b.c');
    expect(abc.people.map((p) => p.id), ['omar', 'a']);
    expect(plan.shown.map((r) => r.group.key), contains('a.b.c'));
  });

  test('undoing a merge moves the Team admin off a person who left', () {
    final plan = CompanyTeamPlan.of(_preview());
    final abc = plan.rows.first;
    plan.merge(abc, 'a.b.c');
    plan.pickAdmin(abc, 'b');
    plan.merge(abc, 'a.b.c');
    expect(plan.adminName(abc), 'Omar Haddad');
    expect(plan.groups().first.adminId, 'omar');
  });

  test('V4: a look-alike of an existing Team merges into it; that Team '
      'keeps its admin, shown on the row', () {
    final plan = CompanyTeamPlan.of(_preview(), teams: _teams);
    final delta = plan.rows.last;
    expect(delta.similarTeams.single.teamId, 't-delta');
    expect(plan.groups().last.toJson(), {
      'name': 'Delta Steal',
      'people': ['e', 'f'],
      'admin_id': 'e',
    });
    plan.mergeTeam(delta, 't-delta');
    expect(plan.groups().last.toJson(), {
      'name': 'Delta Steel',
      'team_id': 't-delta',
      'people': ['e', 'f'],
    });
    expect(plan.adminName(delta), 'Khalid Al-Mansour');
    plan.mergeTeam(delta, 't-delta');
    expect(plan.groups().last.teamId, isNull);
  });

  test('V4: into an existing Team with no admin, the suggestion is set', () {
    final plan = CompanyTeamPlan.of(
      CompanyTeamPreview.fromJson({
        'groups': [
          {
            'key': 'x',
            'name': 'Emptyy',
            'admin_id': 'e',
            'admin_name': 'N e',
            'people': [_p('e')],
          },
        ],
        'similar_teams': [
          {'key': 'x', 'team_id': 't-empty', 'team_name': 'Empty'},
        ],
      }),
      teams: _teams,
    );
    final row = plan.rows.single;
    plan.mergeTeam(row, 't-empty');
    expect(plan.groups().single.adminId, 'e');
    expect(plan.adminName(row), 'N e');
  });

  test('V6: the row names whoever Create sets, even someone already in '
      'the Team', () {
    final plan = CompanyTeamPlan.of(_preview());
    final gulf = plan.rows[2];
    expect(plan.adminName(gulf), 'Rakesh Nair');
    expect(plan.groups()[2].adminId, 'rakesh');
    plan.pickAdmin(gulf, 'c');
    expect(plan.adminName(gulf), 'N c');
    expect(plan.groups()[2].adminId, 'c');
  });

  test('V6: no suggestion, no name and nothing sent', () {
    final plan = CompanyTeamPlan.of(
      CompanyTeamPreview.fromJson({
        'groups': [
          {
            'key': 'v',
            'name': 'V',
            'people': [_p('v', 'viewer')],
          },
        ],
      }),
    );
    expect(plan.adminName(plan.rows.single), isNull);
    expect(plan.groups().single.adminId, isNull);
  });

  test('a Team admin is picked from the row people, never a Viewer', () {
    final plan = CompanyTeamPlan.of(
      CompanyTeamPreview.fromJson({
        'groups': [
          {
            'key': 'v',
            'name': 'V',
            'people': [_p('v', 'viewer'), _p('c')],
          },
        ],
      }),
    );
    expect(plan.adminChoices(plan.rows.single).map((p) => p.id), ['c']);
  });

  test('two Teams already made are never offered as one', () {
    final plan = CompanyTeamPlan.of(
      CompanyTeamPreview.fromJson({
        'groups': [
          {
            'key': 'x',
            'name': 'X',
            'team_id': 't1',
            'people': [_p('a')],
          },
          {
            'key': 'y',
            'name': 'Y',
            'team_id': 't2',
            'people': [_p('b')],
          },
        ],
        'similar': [
          {'a': 'x', 'b': 'y'},
        ],
      }),
    );
    expect(plan.shown.length, 2);
    expect(plan.rows.first.lookAlikes, isEmpty);
    expect(plan.rows.last.lookAlikes, isEmpty);
  });

  test('only: the one company, with no other rows (the Teams line)', () {
    final plan = CompanyTeamPlan.of(_preview(), only: 'abc contracting');
    expect(plan.rows.single.group.key, 'abc contracting');
    expect(plan.rows.single.lookAlikes, isEmpty);
    expect(plan.ticked, 1);
  });

  test('a ticked new Team with no people keeps Create off', () {
    final plan = CompanyTeamPlan.of(
      CompanyTeamPreview.fromJson(const {
        'groups': [
          {'key': 'empty', 'name': 'Empty', 'people': <Object>[]},
        ],
      }),
    );
    expect(plan.ticked, 1);
    expect(plan.ready, isFalse);
    plan.rows.single.ticked = false;
    expect(plan.ready, isFalse);
  });

  test('a Team with its own id and nobody new can still be sent', () {
    final plan = CompanyTeamPlan.of(
      CompanyTeamPreview.fromJson(const {
        'groups': [
          {'key': 'made', 'name': 'Made', 'team_id': 't', 'people': <Object>[]},
        ],
      }),
    );
    expect(plan.ready, isTrue);
  });

  for (final lang in ['en', 'ar']) {
    test('BV002 says it in plain words [$lang]', () {
      final l10n = lookupAppLocalizations(Locale(lang));
      expect(spaceFailureFor('BV002'), SpaceFailure.teamAdminStays);
      expect(
        spaceErrorText(l10n, const SpaceException(SpaceFailure.teamAdminStays)),
        l10n.spacesTeamAdminStays,
      );
      expect(l10n.spacesTeamAdminStays, isNot(l10n.errorGeneric));
    });
  }

  test('a Viewer is offered no Team, even as a Team admin or Space admin', () {
    final people = SpacePeople(
      members: [
        SpaceMember(
          person: const SpacePerson(id: 'v', firstName: 'V', lastName: 'V'),
          pass: SpacePass.viewer,
          isAdmin: false,
          confirmedAt: DateTime(2026),
        ),
      ],
      teams: const [
        SpaceTeam(id: 'a', name: 'A', memberIds: {'v'}, adminId: 'v'),
      ],
    );
    expect(people.mayPostTo('v', admin: false), isEmpty);
    expect(people.mayPostTo('v', admin: true), isEmpty);
  });

  test('a Team admin of any Team may post to every Team; a member to '
      'their own', () {
    const people = SpacePeople(
      teams: [
        SpaceTeam(id: 'a', name: 'A', memberIds: {'me'}, adminId: 'lead'),
        SpaceTeam(id: 'b', name: 'B', memberIds: {'lead'}),
      ],
    );
    expect(people.isTeamAdmin('lead'), isTrue);
    expect(people.isTeamAdmin('me'), isFalse);
    expect(people.mayPostTo('me', admin: false).map((t) => t.id), ['a']);
    expect(people.mayPostTo('lead', admin: false).map((t) => t.id), ['a', 'b']);
    expect(people.mayPostTo('me', admin: true).map((t) => t.id), ['a', 'b']);
  });

  test('V10: Team admin is «مشرف الفريق» in Arabic, never the Lead pass '
      'word', () {
    final ar =
        jsonDecode(File('lib/l10n/app_ar.arb').readAsStringSync())
            as Map<String, dynamic>;
    final values = [
      for (final e in ar.entries)
        if (!e.key.startsWith('@') && e.value is String) e.value as String,
    ];
    expect(values.where((v) => v.contains('مسؤول الفريق')), isEmpty);
    expect(values.where((v) => v.contains('مسؤول فريق')), isEmpty);
    final l10n = lookupAppLocalizations(const Locale('ar'));
    expect(l10n.teamAdminBadge, 'مشرف الفريق');
    expect(l10n.teamsMakeCardLine, contains('بضغطة واحدة، وراجِعها قبل الحفظ'));
  });

  for (final lang in ['en', 'ar']) {
    test('V12: the Team page line ends as a sentence, no placeholder '
        '[$lang]', () {
      final note = lookupAppLocalizations(Locale(lang)).teamAdminNote;
      expect(note, isNot(contains('(')));
      expect(note, isNot(contains('…')));
      expect(note.trim(), endsWith('.'));
    });
  }
}
