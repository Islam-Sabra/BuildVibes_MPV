// Review 122, in English and Arabic: the way in while Who to call is empty
// (KP0), why Teams from companies aren't offered yet (TM0), and KP3's line
// for a key person who shares no number.
import 'package:buildvibes/data/models/company_teams.dart';
import 'package:buildvibes/data/models/key_people.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/spaces/key_people.dart' show KeyRoleTag;
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/key_people_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

Finder _key(String k) => find.byKey(Key(k));

const _space = 'space-1';

const _khalid = SpacePerson(
  id: 'p-khalid',
  firstName: 'Khalid',
  lastName: 'Al-Mansour',
  headline: 'Safety',
);
const _tariq = SpacePerson(
  id: 'p-tariq',
  firstName: 'Tariq',
  lastName: 'Rahman',
  headline: 'Safety',
);

const _civil = SpaceTeam(
  id: 't-civil',
  name: 'Civil',
  memberIds: {'p-khalid'},
  adminId: 'p-khalid',
  adminName: 'Khalid Al-Mansour',
);

SpaceMember _m(String id, String first, {bool admin = false}) => SpaceMember(
  person: SpacePerson(id: id, firstName: first, lastName: 'Test'),
  pass: admin ? SpacePass.lead : SpacePass.crew,
  isAdmin: admin,
  confirmedAt: testNow,
);

CompanyPerson _c(String id) =>
    CompanyPerson(id: id, name: 'Name $id', pass: SpacePass.crew);

FakeSpaceRepository _spaces({bool admin = true, CompanyTeamPreview? preview}) {
  final spaces = FakeSpaceRepository(now: testNow);
  final pass = admin ? SpacePass.lead : SpacePass.crew;
  spaces.details[_space] = SpaceDetail(
    id: _space,
    name: 'NBKCH Site',
    myPass: pass,
    iAmAdmin: admin,
    myRights: MemberRights(invite: admin, createItems: admin),
    marketId: 'kw',
  );
  spaces.spaces.add(
    SpaceSummary(id: _space, name: 'NBKCH Site', pass: pass, isAdmin: admin),
  );
  spaces.spacePeople[_space] = SpacePeople(
    members: [
      _m('user-1', 'Me', admin: admin),
      _m('p-khalid', 'Khalid'),
      _m('p-tariq', 'Tariq'),
    ],
    teams: const [_civil],
  );
  if (preview != null) spaces.previews[_space] = preview;
  return spaces;
}

FakeKeyPeopleRepository _keys([KeyPeople who = const KeyPeople()]) =>
    FakeKeyPeopleRepository()..spaces[_space] = who;

Future<void> _go(
  WidgetTester tester,
  String lang,
  String path, {
  required FakeSpaceRepository spaces,
  required FakeKeyPeopleRepository keys,
}) async {
  await pumpApp(tester, language: lang, spaces: spaces, keyPeople: keys);
  GoRouter.of(tester.element(find.byType(Navigator).first)).push(path);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    String t(String en, String ar) => lang == 'ar' ? ar : en;
    final people = '/spaces/$_space/people';

    group('KP0 Set who to call [$lang]', () {
      testWidgets('the Space admin, no key roles: the card on top, then '
          'Everyone', (tester) async {
        await _go(tester, lang, people, spaces: _spaces(), keys: _keys());
        expect(_key('kp0-set-who-to-call'), findsOneWidget);
        expect(
          find.text(t('Set who to call', 'حدّد بمن يتصل الناس')),
          findsOneWidget,
        );
        expect(find.text(l10n.keyPeopleEveryone), findsOneWidget);
        expect(
          tester.getTopLeft(_key('kp0-set-who-to-call')).dy,
          lessThan(tester.getTopLeft(find.text(l10n.keyPeopleEveryone)).dy),
        );
      });

      testWidgets('a tap opens Key people (KP3)', (tester) async {
        await _go(tester, lang, people, spaces: _spaces(), keys: _keys());
        await _tap(tester, _key('kp0-set-who-to-call'));
        expect(_key('key-people-add'), findsOneWidget);
      });

      testWidgets('a Crew member sees nothing there', (tester) async {
        await _go(
          tester,
          lang,
          people,
          spaces: _spaces(admin: false),
          keys: _keys(),
        );
        expect(_key('kp0-set-who-to-call'), findsNothing);
        expect(find.text(l10n.peopleInThisSpace), findsOneWidget);
      });

      testWidgets('gone once a role is saved', (tester) async {
        final keys = _keys();
        await _go(tester, lang, people, spaces: _spaces(), keys: keys);
        await _tap(tester, _key('kp0-set-who-to-call'));
        await _tap(tester, _key('key-people-add'));
        await _tap(tester, find.text(t('Safety officer', 'ضابط السلامة')));
        await _tap(tester, _key('key-role-add-person'));
        await _tap(tester, _key('key-pick-p-khalid'));
        keys.spaces[_space] = const KeyPeople(
          roles: [
            KeyRole(
              id: 'r-safety',
              name: 'Safety officer',
              holders: [KeyHolder(person: _khalid)],
            ),
          ],
        );
        await _tap(tester, _key('key-role-save'));
        expect(keys.saved, hasLength(1));
        GoRouter.of(tester.element(_key('key-people-add'))).pop();
        await tester.pumpAndSettle();
        expect(_key('kp0-set-who-to-call'), findsNothing);
        expect(find.text(l10n.keyPeopleWhoToCall), findsOneWidget);
      });

      testWidgets('a role with no one yet still counts: no card', (
        tester,
      ) async {
        await _go(
          tester,
          lang,
          people,
          spaces: _spaces(),
          keys: _keys(
            const KeyPeople(
              roles: [KeyRole(id: 'r-safety', name: 'Safety officer')],
            ),
          ),
        );
        expect(_key('kp0-set-who-to-call'), findsNothing);
      });
    });

    group('TM0 why no Teams from companies [$lang]', () {
      // Review 122c: one short line.
      final hint = t(
        'Company Teams need 2 people from one company.',
        'فرق الشركات تحتاج شخصين من نفس الشركة.',
      );

      Future<void> teams(
        WidgetTester tester, {
        bool admin = true,
        CompanyTeamPreview preview = const CompanyTeamPreview(),
      }) async {
        await _go(
          tester,
          lang,
          people,
          spaces: _spaces(admin: admin, preview: preview),
          keys: _keys(),
        );
        await _tap(tester, _key('people-view-teams'));
      }

      testWidgets('no company of 2 or more: the line under Teams, above the '
          'Team cards', (tester) async {
        await teams(
          tester,
          preview: CompanyTeamPreview(
            groups: [
              CompanyGroup(key: 'a', name: 'AECOX', people: [_c('1')]),
            ],
          ),
        );
        expect(_key('teams-company-hint'), findsOneWidget);
        expect(find.text(hint), findsOneWidget);
        final line = tester.getTopLeft(_key('teams-company-hint')).dy;
        expect(
          tester.getTopLeft(find.text(l10n.spacesTeams).last).dy,
          lessThan(line),
        );
        expect(line, lessThan(tester.getTopLeft(_key('team-row-t-civil')).dy));
      });

      testWidgets('a company already made into a Team doesn\'t count', (
        tester,
      ) async {
        await teams(
          tester,
          preview: CompanyTeamPreview(
            groups: [
              CompanyGroup(
                key: 'g',
                name: 'Gulf MEP',
                teamId: 't-civil',
                people: [_c('1'), _c('2')],
              ),
            ],
          ),
        );
        expect(_key('teams-company-hint'), findsOneWidget);
      });

      testWidgets('gone while the offer card shows', (tester) async {
        await teams(
          tester,
          preview: CompanyTeamPreview(
            groups: [
              CompanyGroup(key: 'x', name: 'X', people: [_c('1'), _c('2')]),
              CompanyGroup(key: 'y', name: 'Y', people: [_c('3'), _c('4')]),
            ],
          ),
        );
        expect(_key('teams-make-card'), findsOneWidget);
        expect(_key('teams-company-hint'), findsNothing);
      });

      testWidgets('gone while the one-company line shows', (tester) async {
        await teams(
          tester,
          preview: CompanyTeamPreview(
            groups: [
              CompanyGroup(key: 'x', name: 'X', people: [_c('1'), _c('2')]),
            ],
          ),
        );
        expect(_key('teams-new-line'), findsOneWidget);
        expect(_key('teams-company-hint'), findsNothing);
      });

      testWidgets('a Crew member never sees it', (tester) async {
        await _go(
          tester,
          lang,
          people,
          spaces: _spaces(admin: false, preview: const CompanyTeamPreview()),
          keys: _keys(),
        );
        await _tap(tester, _key('people-view-teams'));
        expect(_key('teams-company-hint'), findsNothing);
      });
    });

    group('KP3 a holder with no number [$lang]', () {
      testWidgets('"No number shared · Message only" under that holder only', (
        tester,
      ) async {
        await _go(
          tester,
          lang,
          '/spaces/$_space/key-people',
          spaces: _spaces(),
          keys: _keys(
            const KeyPeople(
              roles: [
                KeyRole(
                  id: 'r-safety',
                  name: 'Safety officer',
                  holders: [
                    KeyHolder(person: _khalid, canCall: true),
                    KeyHolder(person: _tariq),
                  ],
                ),
              ],
            ),
          ),
        );
        final line = t(
          'No number shared · Message only',
          'لم يشارك رقمه · رسالة فقط',
        );
        expect(find.text(line), findsOneWidget);
        expect(
          find.descendant(
            of: _key('key-role-holder-r-safety-p-tariq'),
            matching: find.text(line),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: _key('key-role-holder-r-safety-p-khalid'),
            matching: find.text(line),
          ),
          findsNothing,
        );
      });

      // Review 122 F1: tag → Call them for → each person.
      testWidgets('Call them for sits under the role tag, above the people', (
        tester,
      ) async {
        await _go(
          tester,
          lang,
          '/spaces/$_space/key-people',
          spaces: _spaces(),
          keys: _keys(
            const KeyPeople(
              roles: [
                KeyRole(
                  id: 'r-safety',
                  name: 'Safety officer',
                  callFor: 'hazards, accidents, work permits',
                  holders: [
                    KeyHolder(person: _khalid, canCall: true),
                    KeyHolder(person: _tariq),
                  ],
                ),
              ],
            ),
          ),
        );
        final tag = tester.getRect(find.byType(KeyRoleTag));
        final callFor = tester.getRect(
          find.textContaining('hazards, accidents, work permits'),
        );
        final first = tester.getRect(_key('key-role-holder-r-safety-p-khalid'));
        expect(tag.bottom, lessThanOrEqualTo(callFor.top));
        expect(callFor.bottom, lessThanOrEqualTo(first.top));
      });
    });
  }
}
