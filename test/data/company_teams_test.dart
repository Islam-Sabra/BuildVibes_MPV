// Review 111: what company_team_preview returns and create_company_teams
// takes, and the sheet's plan between them (TM2): every company ticked,
// No company not; a look-alike spelling folded under the larger one and
// merged only when asked.
import 'package:buildvibes/data/models/company_teams.dart';
import 'package:buildvibes/data/models/space.dart';
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
      'people': [_p('omar', 'lead'), _p('a')],
    },
    {
      'key': 'a.b.c',
      'name': 'A.B.C Contracting',
      'admin_id': 'b',
      'people': [_p('b')],
    },
    {
      'key': 'gulf',
      'name': 'Gulf MEP',
      'team_id': 't-gulf',
      'team_name': 'Gulf MEP Team',
      'people': [_p('c'), _p('d')],
    },
  ],
  'similar': [
    {'a': 'a.b.c', 'b': 'abc contracting'},
  ],
  'no_company': [_p('e')],
});

void main() {
  test('reads the preview, the pass and a Team already made', () {
    final p = _preview();
    expect(p.groups.first.people.first.pass, SpacePass.lead);
    expect(p.groups.last.teamId, 't-gulf');
    expect(p.groups.last.shownName, 'Gulf MEP Team');
    expect(p.noCompany.single.id, 'e');
  });

  test('waiting: companies of 2 or more with no Team', () {
    expect(_preview().waiting.map((g) => g.key), ['abc contracting']);
  });

  test('an empty answer is an empty preview', () {
    final p = CompanyTeamPreview.fromJson(const {});
    expect(p.groups, isEmpty);
    expect(p.noCompany, isEmpty);
  });

  test('the look-alike folds under the larger; nothing merges on its own; '
      'No company comes last, unticked', () {
    final plan = CompanyTeamPlan.of(_preview());
    expect(plan.rows.map((r) => r.group.key), [
      'abc contracting',
      'gulf',
      noCompanyKey,
    ]);
    final abc = plan.rows.first;
    expect(abc.lookAlikes.single.key, 'a.b.c');
    expect(abc.merged, isEmpty);
    expect(plan.ticked, 2);
    final sent = plan.groups('No company');
    expect(sent.first.people, ['omar', 'a']);
    expect(sent.last.teamId, 't-gulf');
  });

  test('merging joins the people under the one name, once; undoing parts '
      'them again', () {
    final plan = CompanyTeamPlan.of(_preview());
    final abc = plan.rows.first;
    plan.merge(abc, 'a.b.c');
    expect(abc.people.map((p) => p.id), ['omar', 'a', 'b']);
    expect(plan.groups('x').first.toJson(), {
      'name': 'ABC Contracting',
      'people': ['omar', 'a', 'b'],
      'admin_id': 'omar',
    });
    plan.merge(abc, 'a.b.c');
    expect(abc.people.map((p) => p.id), ['omar', 'a']);
  });

  test('undoing a merge moves the Team admin off a person who left', () {
    final plan = CompanyTeamPlan.of(_preview());
    final abc = plan.rows.first;
    plan.merge(abc, 'a.b.c');
    abc.adminId = 'b';
    plan.merge(abc, 'a.b.c');
    expect(abc.adminId, 'omar');
  });

  test('the group with a Team stays the name when spellings merge', () {
    final plan = CompanyTeamPlan.of(
      CompanyTeamPreview.fromJson({
        'groups': [
          {
            'key': 'big',
            'name': 'Big',
            'people': [_p('a'), _p('b'), _p('c')],
          },
          {
            'key': 'small',
            'name': 'Smal',
            'team_id': 't',
            'team_name': 'Smal',
            'people': [_p('d')],
          },
        ],
        'similar': [
          {'a': 'big', 'b': 'small'},
        ],
      }),
    );
    expect(plan.rows.single.group.key, 'small');
    expect(plan.rows.single.lookAlikes.single.key, 'big');
  });

  test('two Teams already made are never folded', () {
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
    expect(plan.rows.length, 2);
    expect(plan.rows.first.lookAlikes, isEmpty);
  });

  test('only: the one company, with no other rows (the Teams line)', () {
    final plan = CompanyTeamPlan.of(_preview(), only: 'abc contracting');
    expect(plan.rows.single.group.key, 'abc contracting');
    expect(plan.ticked, 1);
  });

  test('No company ticked goes under the name it is given, no Team admin', () {
    final plan = CompanyTeamPlan.of(_preview());
    plan.rows.last.ticked = true;
    expect(plan.groups('No company').last.toJson(), {
      'name': 'No company',
      'people': ['e'],
    });
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
}
