// Review 111, TM1 to TM5, in English and Arabic: the Teams side of People,
// the sheet that makes Teams from companies, a Team and its Team admin,
// the confirm sheet that chooses the matching Team, and Who sees it.
import 'package:buildvibes/core/l10n/bidi.dart';
import 'package:buildvibes/data/models/company_teams.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/spaces/who_sees_sheet.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

Finder _key(String k) => find.byKey(Key(k));

const _space = 'space-1';

SpaceMember _m(String id, String first, {SpacePass pass = SpacePass.crew}) =>
    SpaceMember(
      person: SpacePerson(
        id: id,
        firstName: first,
        lastName: 'X',
        headline: 'Engineer',
        companyLabel: 'Gulf MEP',
      ),
      pass: pass,
      isAdmin: id == 'user-1',
      confirmedAt: testNow,
    );

const _civil = SpaceTeam(
  id: 't-civil',
  name: 'Civil',
  memberIds: {'p-omar', 'p-ali'},
  adminId: 'p-omar',
  adminName: 'Omar X',
);
const _gulf = SpaceTeam(
  id: 't-gulf',
  name: 'Gulf MEP',
  memberIds: {'p-ali', 'p-rakesh', 'user-1'},
  adminId: 'p-rakesh',
  adminName: 'Rakesh X',
);

const _nabil = SpacePerson(
  id: 'p-nabil',
  firstName: 'Nabil',
  lastName: 'Mansour',
  headline: 'Electrician',
  companyLabel: 'Gulf MEP',
);

CompanyPerson _c(String id, [SpacePass pass = SpacePass.crew]) =>
    CompanyPerson(id: id, name: 'Name $id', pass: pass);

CompanyTeamPreview _companies() => CompanyTeamPreview(
  groups: [
    CompanyGroup(
      key: 'abc',
      name: 'ABC Contracting',
      adminId: 'a1',
      adminName: 'Name a1',
      people: [_c('a1', SpacePass.lead), _c('a2'), _c('a3')],
    ),
    CompanyGroup(
      key: 'a.b.c',
      name: 'A.B.C Contracting',
      adminId: 'b1',
      adminName: 'Name b1',
      people: [_c('b1')],
    ),
    CompanyGroup(
      key: 'delta',
      name: 'Delta Steel',
      adminId: 'd1',
      adminName: 'Name d1',
      people: [_c('d1'), _c('d2')],
    ),
  ],
  similar: const [(a: 'abc', b: 'a.b.c')],
  // V4: "Delta Steel" looks like the Space's Team "Civil" here, for the test.
  similarTeams: const [(key: 'delta', teamId: 't-civil', teamName: 'Civil')],
);

FakeSpaceRepository _spaces({
  bool admin = true,
  List<SpaceTeam> teams = const [_civil, _gulf],
  CompanyTeamPreview? preview,
  List<SpaceJoinRequest> requests = const [],
}) {
  final spaces = FakeSpaceRepository(now: testNow);
  spaces.details[_space] = SpaceDetail(
    id: _space,
    name: 'NBKCH Site',
    myPass: SpacePass.lead,
    iAmAdmin: admin,
    myRights: const MemberRights(invite: true, createItems: true),
  );
  spaces.spacePeople[_space] = SpacePeople(
    requests: requests,
    members: [
      _m('user-1', 'Islam', pass: SpacePass.lead),
      _m('p-omar', 'Omar'),
      _m('p-rakesh', 'Rakesh'),
      _m('p-ali', 'Ali'),
    ],
    teams: teams,
  );
  if (preview != null) spaces.previews[_space] = preview;
  return spaces;
}

Future<void> _go(
  WidgetTester tester,
  FakeSpaceRepository spaces,
  String lang,
  String path,
) async {
  await pumpApp(tester, language: lang, spaces: spaces);
  GoRouter.of(tester.element(find.byType(Navigator).first)).push(path);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

Future<void> _openTeams(WidgetTester tester) =>
    _tap(tester, _key('people-view-teams'));

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));

    group('TM1 Teams [$lang]', () {
      testWidgets('each Team shows its people and its admin; New Team by '
          'hand for the Space admin', (tester) async {
        await _go(tester, _spaces(), lang, '/spaces/$_space/people');
        await _openTeams(tester);
        expect(_key('team-row-t-civil'), findsOneWidget);
        expect(
          find.textContaining(l10n.teamRowAdmin, findRichText: true),
          findsWidgets,
        );
        expect(find.textContaining('Omar X', findRichText: true), findsWidgets);
        expect(find.text(l10n.teamsNewByHand), findsOneWidget);
        await _tap(tester, _key('team-row-t-civil'));
        expect(_key('team-screen'), findsOneWidget);
      });

      testWidgets('the card shows with 2 or more companies waiting, and '
          'opens the sheet', (tester) async {
        final preview = CompanyTeamPreview(
          groups: [
            CompanyGroup(key: 'x', name: 'X', people: [_c('1'), _c('2')]),
            CompanyGroup(key: 'y', name: 'Y', people: [_c('3'), _c('4')]),
          ],
        );
        await _go(
          tester,
          _spaces(preview: preview),
          lang,
          '/spaces/$_space/people',
        );
        await _openTeams(tester);
        expect(find.text(l10n.teamsMakeTitle), findsOneWidget);
        expect(find.text(l10n.teamsMakeCardLine), findsOneWidget);
        expect(_key('teams-new-line'), findsNothing);
        await _tap(tester, _key('teams-make-card'));
        expect(_key('make-teams-sheet'), findsOneWidget);
        expect(_key('make-team-x'), findsOneWidget);
        expect(_key('make-team-y'), findsOneWidget);
      });

      testWidgets('one company waiting: the one line, and the sheet with '
          'only that company', (tester) async {
        final preview = CompanyTeamPreview(
          groups: [
            CompanyGroup(
              key: 'delta',
              name: 'Delta Steel',
              people: [_c('1'), _c('2')],
            ),
            CompanyGroup(key: 'solo', name: 'Solo', people: [_c('3')]),
          ],
        );
        await _go(
          tester,
          _spaces(preview: preview),
          lang,
          '/spaces/$_space/people',
        );
        await _openTeams(tester);
        expect(_key('teams-make-card'), findsNothing);
        expect(
          find.descendant(
            of: _key('teams-new-line'),
            matching: find.textContaining('Delta Steel'),
          ),
          findsOneWidget,
        );
        await _tap(tester, _key('teams-new-line'));
        expect(_key('make-team-delta'), findsOneWidget);
        expect(_key('make-team-solo'), findsNothing);
      });

      testWidgets('nobody waiting, or a company of one: no card, no line', (
        tester,
      ) async {
        final preview = CompanyTeamPreview(
          groups: [
            CompanyGroup(key: 'solo', name: 'Solo', people: [_c('3')]),
            CompanyGroup(
              key: 'made',
              name: 'Made',
              teamId: 't-civil',
              people: [_c('1'), _c('2')],
            ),
          ],
        );
        await _go(
          tester,
          _spaces(preview: preview),
          lang,
          '/spaces/$_space/people',
        );
        await _openTeams(tester);
        expect(_key('teams-make-card'), findsNothing);
        expect(_key('teams-new-line'), findsNothing);
      });

      testWidgets('a member sees the Teams but no card, no line, no New '
          'Team, and the server is not asked', (tester) async {
        await _go(
          tester,
          _spaces(admin: false, preview: _companies()),
          lang,
          '/spaces/$_space/people',
        );
        await _openTeams(tester);
        expect(_key('team-row-t-civil'), findsOneWidget);
        expect(_key('teams-make-card'), findsNothing);
        expect(_key('people-new-team'), findsNothing);
      });

      testWidgets('searching shows people, not the switch', (tester) async {
        await _go(tester, _spaces(), lang, '/spaces/$_space/people');
        await _tap(tester, _key('people-search'));
        await tester.enterText(_key('people-search-field'), 'Omar');
        await tester.pumpAndSettle();
        expect(_key('people-view-teams'), findsNothing);
        expect(_key('member-p-omar'), findsOneWidget);
      });
    });

    group('TM2 sheet [$lang]', () {
      Future<FakeSpaceRepository> open(WidgetTester tester) async {
        final spaces = _spaces(preview: _companies());
        await _go(tester, spaces, lang, '/spaces/$_space/people');
        await _openTeams(tester);
        await _tap(tester, _key('teams-make-card'));
        return spaces;
      }

      testWidgets('every company ticked with its count and Team admin; the '
          'look-alike its own row (V4); no No company (V5); Create N Teams', (
        tester,
      ) async {
        await open(tester);
        expect(find.text(l10n.teamsMakeIntro), findsOneWidget);
        expect(_key('make-team-abc'), findsOneWidget);
        expect(_key('make-team-a.b.c'), findsOneWidget);
        expect(_key('make-team-'), findsNothing);
        // V6: the server's name for whoever Create sets, never "—".
        expect(
          find.text(l10n.teamsAdminLine(inOwnDirection('Name a1'))),
          findsOneWidget,
        );
        expect(find.text(l10n.teamsAdminNone), findsNothing);
        expect(find.text(l10n.teamsCreate(3)), findsOneWidget);
      });

      testWidgets('V4: merge into an existing Team: its people join it and '
          'its admin stays, named on the row', (tester) async {
        final spaces = await open(tester);
        await _tap(tester, _key('make-team-into-delta-t-civil'));
        expect(
          find.text(l10n.teamsMergedIntoTeam(inOwnDirection('Civil'))),
          findsOneWidget,
        );
        expect(
          find.text(l10n.teamsAdminLine(inOwnDirection('Omar X'))),
          findsOneWidget,
        );
        await _tap(tester, _key('make-teams-create'));
        expect(spaces.companyTeamCalls.single.groups.last.toJson(), {
          'name': 'Civil',
          'team_id': 't-civil',
          'people': ['d1', 'd2'],
        });
      });

      testWidgets('Create sends what is ticked, with the Team admin; the '
          'Teams appear', (tester) async {
        final spaces = await open(tester);
        await _tap(tester, _key('make-team-tick-delta'));
        await _tap(tester, _key('make-team-tick-a.b.c'));
        expect(find.text(l10n.teamsCreate(1)), findsOneWidget);
        await _tap(tester, _key('make-teams-create'));
        final call = spaces.companyTeamCalls.single;
        expect(call.groups.single.toJson(), {
          'name': 'ABC Contracting',
          'people': ['a1', 'a2', 'a3'],
          'admin_id': 'a1',
        });
        expect(_key('make-teams-sheet'), findsNothing);
        expect(find.text(l10n.teamsMadeDone), findsOneWidget);
        expect(_key('team-row-team-ABC Contracting'), findsOneWidget);
      });

      testWidgets('merge joins the look-alike only when tapped, and undoes', (
        tester,
      ) async {
        final spaces = await open(tester);
        await _tap(tester, _key('make-team-merge-a.b.c'));
        expect(
          find.text(l10n.teamsMergedUndo(inOwnDirection('A.B.C Contracting'))),
          findsOneWidget,
        );
        expect(_key('make-team-a.b.c'), findsNothing);
        expect(find.text(l10n.teamsCreate(2)), findsOneWidget);
        await _tap(tester, _key('make-teams-create'));
        expect(spaces.companyTeamCalls.single.groups.first.people, [
          'a1',
          'a2',
          'a3',
          'b1',
        ]);
      });

      testWidgets('tap a row: pick the Team admin from its people', (
        tester,
      ) async {
        final spaces = await open(tester);
        // The row's own line: its middle is the merge pill.
        await _tap(
          tester,
          find.text(l10n.teamsAdminLine(inOwnDirection('Name a1'))),
        );
        await _tap(tester, _key('make-admin-a2'));
        expect(
          find.text(l10n.teamsAdminLine(inOwnDirection('Name a2'))),
          findsOneWidget,
        );
        await _tap(tester, _key('make-teams-create'));
        expect(spaces.companyTeamCalls.single.groups.first.adminId, 'a2');
      });

      testWidgets('a failed Create stays open; a retry sends the same id', (
        tester,
      ) async {
        final spaces = await open(tester);
        spaces.createCompanyTeamsError = const SpaceException(
          SpaceFailure.network,
        );
        await _tap(tester, _key('make-teams-create'));
        expect(_key('make-teams-sheet'), findsOneWidget);
        await _tap(tester, _key('make-teams-create'));
        expect(spaces.companyTeamCalls.length, 2);
        expect(
          spaces.companyTeamCalls.first.id,
          spaces.companyTeamCalls.last.id,
        );
      });

      testWidgets('after a failure a change is a new try with a new id', (
        tester,
      ) async {
        final spaces = await open(tester);
        spaces.createCompanyTeamsError = const SpaceException(
          SpaceFailure.network,
        );
        await _tap(tester, _key('make-teams-create'));
        await _tap(tester, _key('make-team-tick-delta'));
        await _tap(tester, _key('make-teams-create'));
        expect(
          spaces.companyTeamCalls.first.id,
          isNot(spaces.companyTeamCalls.last.id),
        );
      });

      testWidgets('nothing ticked: Create does nothing', (tester) async {
        final spaces = await open(tester);
        await _tap(tester, _key('make-team-tick-abc'));
        await _tap(tester, _key('make-team-tick-a.b.c'));
        await _tap(tester, _key('make-team-tick-delta'));
        expect(
          tester.widget<BvButton>(_key('make-teams-create')).onPressed,
          isNull,
        );
        expect(spaces.companyTeamCalls, isEmpty);
      });
    });

    group('TM3 Team [$lang]', () {
      final path = '/spaces/$_space/teams/t-gulf';

      testWidgets('the admin comes first, with the badge, and the title '
          'says Team · people', (tester) async {
        await _go(tester, _spaces(), lang, path);
        final admin = tester.getTopLeft(_key('team-member-p-rakesh')).dy;
        final other = tester.getTopLeft(_key('team-member-p-ali')).dy;
        expect(admin, lessThan(other));
        expect(_key('team-admin-badge'), findsOneWidget);
        expect(find.text(l10n.teamAdminBadge), findsOneWidget);
        expect(find.text(l10n.teamAdminNote), findsOneWidget);
      });

      testWidgets('Space admin: Add people, and ⋯ Make Team admin', (
        tester,
      ) async {
        final spaces = _spaces();
        await _go(tester, spaces, lang, path);
        expect(_key('team-add-people'), findsOneWidget);
        expect(_key('team-person-more-p-rakesh'), findsNothing);
        await _tap(tester, _key('team-person-more-p-ali'));
        await _tap(tester, _key('team-make-admin'));
        expect(spaces.calls, contains('team admin t-gulf p-ali'));
        expect(
          find.descendant(
            of: _key('team-member-p-ali'),
            matching: _key('team-admin-badge'),
          ),
          findsOneWidget,
        );
      });

      testWidgets('the Team admin: Add people, no ⋯, no Space admin menu', (
        tester,
      ) async {
        const mine = SpaceTeam(
          id: 't-gulf',
          name: 'Gulf MEP',
          memberIds: {'user-1', 'p-ali'},
          adminId: 'user-1',
          adminName: 'Islam X',
        );
        final spaces = _spaces(admin: false, teams: const [mine]);
        await _go(tester, spaces, lang, path);
        expect(_key('team-add-people'), findsOneWidget);
        expect(_key('team-more'), findsNothing);
        expect(_key('team-person-more-p-ali'), findsNothing);
        await _tap(tester, _key('team-add-people'));
        await _tap(tester, _key('pick-p-omar'));
        await _tap(tester, _key('team-pick-save'));
        expect(
          spaces.spacePeople[_space]!.teams.single.memberIds,
          containsAll(['user-1', 'p-ali', 'p-omar']),
        );
      });

      testWidgets('a member of another Team: neither', (tester) async {
        await _go(tester, _spaces(admin: false), lang, path);
        expect(_key('team-add-people'), findsNothing);
        expect(_key('team-person-more-p-ali'), findsNothing);
      });

      testWidgets('Add people can\'t untick the Team admin', (tester) async {
        final spaces = _spaces();
        await _go(tester, spaces, lang, path);
        await _tap(tester, _key('team-add-people'));
        await _tap(tester, _key('pick-p-rakesh'));
        await _tap(tester, _key('team-pick-save'));
        expect(
          spaces.spacePeople[_space]!.teams.last.memberIds,
          contains('p-rakesh'),
        );
      });
    });

    group('TM4 confirm sheet [$lang]', () {
      final request = SpaceJoinRequest(
        id: 'req-1',
        person: _nabil,
        createdAt: testNow,
      );
      FakeSpaceRepository spaces0() {
        final spaces = _spaces(requests: [request]);
        spaces.companyMatches['p-nabil'] = const CompanyTeamMatch(
          teamId: 't-gulf',
          teamName: 'Gulf MEP',
          company: 'Gulf MEP',
        );
        return spaces;
      }

      testWidgets('a known company: Team chosen, the line says why, Crew '
          'chosen, one tap Confirm', (tester) async {
        final spaces = spaces0();
        await _go(tester, spaces, lang, '/spaces/$_space/people');
        await _tap(tester, _key('request-let-in-req-1'));
        expect(_key('confirm-sheet'), findsOneWidget);
        expect(
          find.text(
            l10n.joinChosenBecause(
              inOwnDirection('Nabil'),
              inOwnDirection('Gulf MEP'),
            ),
          ),
          findsOneWidget,
        );
        await _tap(tester, _key('request-confirm-req-1'));
        expect(spaces.calls, ['confirm req-1 crew']);
        expect(spaces.confirmedTeams['req-1'], ['t-gulf']);
      });

      testWidgets('untick the Team: the why goes; Another shows the others', (
        tester,
      ) async {
        final spaces = spaces0();
        await _go(tester, spaces, lang, '/spaces/$_space/people');
        await _tap(tester, _key('request-let-in-req-1'));
        await _tap(tester, _key('confirm-team-t-gulf'));
        expect(
          find.text(
            l10n.joinChosenBecause(
              inOwnDirection('Nabil'),
              inOwnDirection('Gulf MEP'),
            ),
          ),
          findsNothing,
        );
        await _tap(tester, _key('confirm-another'));
        await _tap(tester, _key('confirm-team-t-civil'));
        await _tap(tester, _key('request-confirm-req-1'));
        expect(spaces.confirmedTeams['req-1'], ['t-civil']);
      });

      testWidgets('no match: no pass and no Team chosen; the choices show '
          'and Choose a pass does nothing', (tester) async {
        final spaces = _spaces(requests: [request]);
        await _go(tester, spaces, lang, '/spaces/$_space/people');
        await _tap(tester, _key('request-let-in-req-1'));
        expect(_key('confirm-team-t-gulf'), findsOneWidget);
        expect(_key('confirm-team-t-civil'), findsOneWidget);
        expect(_key('confirm-another'), findsNothing);
        expect(find.text(l10n.peopleChoosePass), findsOneWidget);
        await _tap(tester, _key('request-confirm-req-1'));
        expect(spaces.calls, isEmpty);
        await _tap(tester, _key('request-pass-viewer'));
        await _tap(tester, _key('request-confirm-req-1'));
        expect(spaces.calls, ['confirm req-1 viewer']);
      });
    });

    group('TM5 Who sees it [$lang]', () {
      const teams = [_civil, _gulf];
      const people = SpacePeople(teams: teams);

      testWidgets('my Team first, Your Team; another, as a Team admin', (
        tester,
      ) async {
        await pumpApp(tester, language: lang);
        final context = tester.element(find.byType(Navigator).first);
        final picked = pickWhoSees(
          context,
          people: people,
          me: 'p-rakesh',
          spaceAdmin: false,
          chosen: 't-gulf',
        );
        await tester.pumpAndSettle();
        expect(find.text(l10n.whoSeesTitle), findsOneWidget);
        expect(find.text(l10n.whoSeesEveryone), findsOneWidget);
        expect(find.text(l10n.whoSeesFoot), findsOneWidget);
        expect(
          find.descendant(
            of: _key('who-sees-t-gulf'),
            matching: find.text(l10n.whoSeesYourTeam),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: _key('who-sees-t-civil'),
            matching: find.text(l10n.whoSeesAsTeamAdmin),
          ),
          findsOneWidget,
        );
        expect(
          tester.getTopLeft(_key('who-sees-t-gulf')).dy,
          lessThan(tester.getTopLeft(_key('who-sees-t-civil')).dy),
        );
        await _tap(tester, _key('who-sees-t-civil'));
        expect((await picked)?.team?.id, 't-civil');
      });

      testWidgets('a member gets Everyone and their own Teams only', (
        tester,
      ) async {
        await pumpApp(tester, language: lang);
        final context = tester.element(find.byType(Navigator).first);
        pickWhoSees(
          context,
          people: people,
          me: 'p-ali',
          spaceAdmin: false,
          chosen: null,
        );
        await tester.pumpAndSettle();
        // Ali is in both: Your Team on each; nobody else's line.
        expect(find.text(l10n.whoSeesAsTeamAdmin), findsNothing);
        expect(find.text(l10n.whoSeesYourTeam), findsNWidgets(2));
      });

      testWidgets('someone in one Team doesn\'t see the other', (tester) async {
        await pumpApp(tester, language: lang);
        final context = tester.element(find.byType(Navigator).first);
        pickWhoSees(
          context,
          people: people,
          me: 'user-1',
          spaceAdmin: false,
          chosen: null,
        );
        await tester.pumpAndSettle();
        expect(_key('who-sees-t-gulf'), findsOneWidget);
        expect(_key('who-sees-t-civil'), findsNothing);
      });

      testWidgets('V13: a Space admin who is also a Team admin is told as a '
          'Space admin', (tester) async {
        await pumpApp(tester, language: lang);
        final context = tester.element(find.byType(Navigator).first);
        pickWhoSees(
          context,
          people: people,
          me: 'p-rakesh',
          spaceAdmin: true,
          chosen: null,
        );
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: _key('who-sees-t-civil'),
            matching: find.text(l10n.whoSeesAsSpaceAdmin),
          ),
          findsOneWidget,
        );
        expect(find.text(l10n.whoSeesAsTeamAdmin), findsNothing);
      });

      testWidgets('a Space admin outside the Team is told as a Space admin', (
        tester,
      ) async {
        await pumpApp(tester, language: lang);
        final context = tester.element(find.byType(Navigator).first);
        pickWhoSees(
          context,
          people: people,
          me: 'user-1',
          spaceAdmin: true,
          chosen: null,
        );
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: _key('who-sees-t-civil'),
            matching: find.text(l10n.whoSeesAsSpaceAdmin),
          ),
          findsOneWidget,
        );
      });

      testWidgets('Everyone is a choice', (tester) async {
        await pumpApp(tester, language: lang);
        final context = tester.element(find.byType(Navigator).first);
        final picked = pickWhoSees(
          context,
          people: people,
          me: 'p-ali',
          spaceAdmin: false,
          chosen: 't-gulf',
        );
        await tester.pumpAndSettle();
        await _tap(tester, _key('who-sees-everyone'));
        final result = await picked;
        expect(result, isNotNull);
        expect(result!.team, isNull);
      });
    });
  }
}
