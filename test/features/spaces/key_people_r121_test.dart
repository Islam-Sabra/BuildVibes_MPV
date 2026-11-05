// Review 121, in English and Arabic: Who to call on top of People (KP1),
// the Space as an organisation on the Teams side (OC1), Who to call once
// on joining (KP2), Key people in Space settings (KP3), a key role (KP4),
// the phone number and who sees it (NUM1), and one person in several
// Teams (P1, TM3, TM4).
import 'package:buildvibes/core/l10n/bidi.dart';
import 'package:buildvibes/data/models/key_people.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/messages/dm_thread_screen.dart';
import 'package:buildvibes/features/spaces/pass_words.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fakes.dart';
import '../../helpers/key_people_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

Finder _key(String k) => find.byKey(Key(k));

const _space = 'space-1';

SpaceMember _m(
  String id,
  String first,
  String last, {
  SpacePass pass = SpacePass.crew,
  bool admin = false,
  String? role,
}) => SpaceMember(
  person: SpacePerson(
    id: id,
    firstName: first,
    lastName: last,
    headline: role,
    companyLabel: 'Gulf MEP',
  ),
  pass: pass,
  isAdmin: admin,
  confirmedAt: testNow,
);

const _khalid = SpacePerson(
  id: 'p-khalid',
  firstName: 'Khalid',
  lastName: 'Al-Mansour',
  headline: 'Safety',
  companyLabel: 'NBKCH',
);
const _omar = SpacePerson(
  id: 'p-omar',
  firstName: 'Omar',
  lastName: 'Haddad',
  headline: 'Engineer',
);

KeyPeople _who({bool seen = true}) => KeyPeople(
  seen: seen,
  roles: const [
    KeyRole(
      id: 'r-safety',
      name: 'Safety officer',
      callFor: 'hazards, accidents, work permits',
      holders: [KeyHolder(person: _khalid, note: 'Day shift', canCall: true)],
    ),
    KeyRole(
      id: 'r-engineer',
      name: 'Project engineer',
      callFor: 'drawings, method statements, site changes',
      holders: [KeyHolder(person: _omar)],
    ),
  ],
);

FakeSpaceRepository _spaces({
  bool admin = false,
  List<SpaceTeam> teams = const [],
  List<SpaceJoinRequest> requests = const [],
  SpacePass pass = SpacePass.crew,
}) {
  final spaces = FakeSpaceRepository(now: testNow);
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
    requests: requests,
    members: [
      _m('p-islam', 'Islam', 'Sabra', admin: true, pass: SpacePass.lead),
      _m('user-1', 'Me', 'Myself', admin: admin, pass: pass),
      _m('p-khalid', 'Khalid', 'Al-Mansour'),
      _m('p-omar', 'Omar', 'Haddad'),
      _m('p-ali', 'Ali', 'Saleh', role: 'Electrician'),
      _m('p-hassan', 'Hassan', 'Karim'),
    ],
    teams: teams,
  );
  return spaces;
}

FakeKeyPeopleRepository _keys({KeyPeople? who}) {
  final keys = FakeKeyPeopleRepository();
  keys.spaces[_space] = who ?? _who();
  keys.phones['p-khalid'] = '+96555123456';
  return keys;
}

const _gulf = SpaceTeam(
  id: 't-gulf',
  name: 'Gulf MEP',
  memberIds: {'p-ali', 'p-hassan', 'p-omar'},
  adminId: 'p-omar',
  adminName: 'Omar Haddad',
);
const _night = SpaceTeam(
  id: 't-night',
  name: 'Night shift',
  memberIds: {'p-ali', 'p-hassan', 'p-khalid'},
  adminId: 'p-khalid',
  adminName: 'Khalid Al-Mansour',
);
const _civil = SpaceTeam(
  id: 't-civil',
  name: 'Civil',
  memberIds: {'p-ali'},
  adminId: 'p-ali',
  adminName: 'Ali Saleh',
);

Future<TestApp> _go(
  WidgetTester tester,
  String lang,
  String path, {
  FakeSpaceRepository? spaces,
  FakeKeyPeopleRepository? keys,
}) async {
  final app = await pumpApp(
    tester,
    language: lang,
    spaces: spaces ?? _spaces(),
    keyPeople: keys ?? _keys(),
  );
  GoRouter.of(tester.element(find.byType(Navigator).first)).push(path);
  await tester.pumpAndSettle();
  return app;
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
    final people = '/spaces/$_space/people';

    group('KP1 Who to call [$lang]', () {
      testWidgets('on top for every member, a card per person, then '
          'Everyone', (tester) async {
        await _go(tester, lang, people);
        expect(find.text(l10n.keyPeopleWhoToCall), findsOneWidget);
        expect(_key('key-person-r-safety-p-khalid'), findsOneWidget);
        expect(_key('key-person-r-engineer-p-omar'), findsOneWidget);
        expect(find.text(inOwnDirection('Safety officer')), findsOneWidget);
        expect(
          find.text(
            l10n.keyPeopleCallFor(
              inOwnDirection('hazards, accidents, work permits'),
            ),
          ),
          findsOneWidget,
        );
        expect(find.text(l10n.keyPeopleEveryone), findsOneWidget);
        final card = tester.getTopLeft(_key('key-person-r-safety-p-khalid'));
        final everyone = tester.getTopLeft(find.text(l10n.keyPeopleEveryone));
        expect(card.dy, lessThan(everyone.dy));
      });

      testWidgets('Call only for who shows their number; Message for '
          'everyone', (tester) async {
        await _go(tester, lang, people);
        expect(_key('key-call-r-safety-p-khalid'), findsOneWidget);
        expect(_key('key-call-r-engineer-p-omar'), findsNothing);
        expect(_key('key-message-r-safety-p-khalid'), findsOneWidget);
        expect(_key('key-message-r-engineer-p-omar'), findsOneWidget);
      });

      testWidgets('Call reads the number on the tap and opens the dialler', (
        tester,
      ) async {
        final keys = _keys();
        final app = await _go(tester, lang, people, keys: keys);
        expect(keys.asked, isEmpty);
        await _tap(tester, _key('key-call-r-safety-p-khalid'));
        expect(keys.asked, ['p-khalid']);
        expect(app.opened, [Uri(scheme: 'tel', path: '+96555123456')]);
      });

      testWidgets('a number taken back meanwhile: said, nothing opens', (
        tester,
      ) async {
        final keys = _keys();
        keys.phones.clear();
        final app = await _go(tester, lang, people, keys: keys);
        await _tap(tester, _key('key-call-r-safety-p-khalid'));
        expect(app.opened, isEmpty);
        expect(
          find.text(l10n.keyPeopleNoNumber(inOwnDirection('Khalid'))),
          findsOneWidget,
        );
      });

      testWidgets('30 numbers a day: said', (tester) async {
        final keys = _keys()..failure = SpaceFailure.limit;
        await _go(tester, lang, people, keys: keys);
        await _tap(tester, _key('key-call-r-safety-p-khalid'));
        expect(find.text(l10n.keyPeopleTooMany), findsOneWidget);
      });

      testWidgets('Message opens the direct message', (tester) async {
        await _go(tester, lang, people);
        await _tap(tester, _key('key-message-r-engineer-p-omar'));
        expect(find.byType(DmThreadScreen), findsOneWidget);
      });

      testWidgets('for a Space admin, under the requests to join', (
        tester,
      ) async {
        final spaces = _spaces(
          admin: true,
          pass: SpacePass.lead,
          requests: [
            SpaceJoinRequest(
              id: 'req-1',
              person: const SpacePerson(
                id: 'p-new',
                firstName: 'Nabil',
                lastName: 'New',
              ),
              createdAt: testNow,
            ),
          ],
        );
        await _go(tester, lang, people, spaces: spaces);
        final request = tester.getTopLeft(_key('request-req-1')).dy;
        final who = tester.getTopLeft(find.text(l10n.keyPeopleWhoToCall)).dy;
        expect(request, lessThan(who));
      });

      testWidgets('no key people: no block, the list as before', (
        tester,
      ) async {
        await _go(tester, lang, people, keys: _keys(who: const KeyPeople()));
        expect(find.text(l10n.keyPeopleWhoToCall), findsNothing);
        expect(find.text(l10n.peopleInThisSpace), findsOneWidget);
      });
    });

    group('P1 several Teams [$lang]', () {
      testWidgets('a row lists two Teams, then +1', (tester) async {
        await _go(
          tester,
          lang,
          people,
          spaces: _spaces(teams: const [_civil, _gulf, _night]),
          keys: _keys(who: const KeyPeople()),
        );
        final row = _key('member-p-ali');
        expect(
          find.descendant(of: row, matching: _key('member-team-p-ali-t-civil')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: row, matching: _key('member-team-p-ali-t-gulf')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: row, matching: _key('member-team-p-ali-t-night')),
          findsNothing,
        );
        expect(
          find.descendant(
            of: row,
            matching: find.text(l10n.peopleTeamsMore('1')),
          ),
          findsOneWidget,
        );
        // Two Teams only: no "+".
        expect(
          find.descendant(
            of: _key('member-p-hassan'),
            matching: find.text(l10n.peopleTeamsMore('1')),
          ),
          findsNothing,
        );
      });
    });

    group('OC1 the organisation [$lang]', () {
      Future<void> teams(WidgetTester tester, {bool admin = false}) async {
        await _go(
          tester,
          lang,
          people,
          spaces: _spaces(
            admin: admin,
            pass: admin ? SpacePass.lead : SpacePass.crew,
            teams: const [_gulf, _night],
          ),
        );
        await _tap(tester, _key('people-view-teams'));
      }

      testWidgets('who runs it, Who to call, then each Team with its admin '
          'and faces, no count', (tester) async {
        await teams(tester);
        expect(find.text(l10n.orgRunsThisSpace), findsOneWidget);
        expect(_key('org-admin-p-islam'), findsOneWidget);
        expect(find.text(l10n.spacesAdminRow), findsOneWidget);
        expect(_key('org-call-r-safety-p-khalid'), findsOneWidget);
        expect(_key('org-call-r-engineer-p-omar'), findsOneWidget);
        expect(_key('team-row-t-gulf'), findsOneWidget);
        expect(
          find.descendant(
            of: _key('team-row-t-gulf'),
            matching: find.text(l10n.teamAdminBadge),
          ),
          findsOneWidget,
        );
        // No people count anywhere (rule 3).
        expect(find.textContaining(RegExp(r'\b3\b')), findsNothing);
        final runs = tester.getTopLeft(find.text(l10n.orgRunsThisSpace)).dy;
        final call = tester.getTopLeft(_key('org-call-r-safety-p-khalid')).dy;
        final team = tester.getTopLeft(_key('team-row-t-gulf')).dy;
        expect(runs, lessThan(call));
        expect(call, lessThan(team));
      });

      testWidgets('a person in two Teams shows in both', (tester) async {
        await teams(tester);
        for (final t in ['t-gulf', 't-night']) {
          expect(
            find.descendant(
              of: _key('team-row-$t'),
              matching: _key('org-face-$t-p-ali'),
            ),
            findsOneWidget,
          );
        }
      });

      testWidgets('a chip opens the person with Call and Message', (
        tester,
      ) async {
        await teams(tester);
        await _tap(tester, _key('org-call-r-safety-p-khalid'));
        expect(_key('key-person-sheet'), findsOneWidget);
        expect(_key('key-call-r-safety-p-khalid'), findsOneWidget);
        expect(_key('key-message-r-safety-p-khalid'), findsOneWidget);
      });

      testWidgets('a Team card opens the Team', (tester) async {
        await teams(tester);
        await _tap(tester, _key('team-row-t-night'));
        expect(_key('team-screen'), findsOneWidget);
      });

      testWidgets('the Space admin keeps New Team by hand', (tester) async {
        await teams(tester, admin: true);
        expect(_key('people-new-team'), findsOneWidget);
      });
    });

    group('KP2 just joined [$lang]', () {
      testWidgets('shows once on opening the Space; Got it marks it seen', (
        tester,
      ) async {
        final keys = _keys(who: _who(seen: false));
        await _go(tester, lang, '/spaces/$_space', keys: keys);
        expect(_key('key-people-welcome'), findsOneWidget);
        expect(
          find.text(l10n.keyPeopleWelcome(inOwnDirection('NBKCH Site'))),
          findsOneWidget,
        );
        expect(
          find.text(
            l10n.keyPeopleJoined(passName(l10n, SpacePass.crew).toUpperCase()),
          ),
          findsOneWidget,
        );
        expect(_key('key-call-r-safety-p-khalid'), findsOneWidget);
        await _tap(tester, _key('key-people-got-it'));
        expect(_key('key-people-welcome'), findsNothing);
        expect(keys.seen, [_space]);
      });

      testWidgets('closing the sheet counts as seen', (tester) async {
        final keys = _keys(who: _who(seen: false));
        await _go(tester, lang, '/spaces/$_space', keys: keys);
        await tester.tapAt(const Offset(195, 60));
        await tester.pumpAndSettle();
        expect(_key('key-people-welcome'), findsNothing);
        expect(keys.seen, [_space]);
      });

      testWidgets('seen, or no key people: not shown', (tester) async {
        await _go(tester, lang, '/spaces/$_space', keys: _keys());
        expect(_key('key-people-welcome'), findsNothing);
        await _go(
          tester,
          lang,
          '/spaces/$_space',
          keys: _keys(
            who: const KeyPeople(
              seen: false,
              roles: [KeyRole(id: 'r', name: 'Site nurse')],
            ),
          ),
        );
        expect(_key('key-people-welcome'), findsNothing);
      });
    });

    group('KP3 Key people [$lang]', () {
      final info = '/spaces/$_space/info';

      testWidgets('a Space settings row for the Space admin only', (
        tester,
      ) async {
        await _go(tester, lang, info);
        expect(_key('info-key-people'), findsNothing);
        await _go(
          tester,
          lang,
          info,
          spaces: _spaces(admin: true, pass: SpacePass.lead),
        );
        await _tap(tester, _key('info-key-people'));
        expect(_key('key-people-screen'), findsOneWidget);
      });

      testWidgets('each role with its people and what to call them for; '
          'Add a role', (tester) async {
        final keys = _keys(
          who: const KeyPeople(
            roles: [
              KeyRole(
                id: 'r-safety',
                name: 'Safety officer',
                callFor: 'Hazards',
                holders: [
                  KeyHolder(person: _khalid),
                  KeyHolder(person: _omar),
                ],
              ),
              KeyRole(id: 'r-nurse', name: 'Site nurse'),
            ],
          ),
        );
        await _go(
          tester,
          lang,
          '/spaces/$_space/key-people',
          spaces: _spaces(admin: true, pass: SpacePass.lead),
          keys: keys,
        );
        expect(find.text(l10n.keyPeopleIntro), findsOneWidget);
        expect(find.text(l10n.keyPeopleFootnote), findsOneWidget);
        expect(_key('key-role-r-safety'), findsOneWidget);
        expect(
          find.descendant(
            of: _key('key-role-r-safety'),
            matching: find.textContaining('Khalid Al-Mansour'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: _key('key-role-r-nurse'),
            matching: find.text(l10n.keyPeopleNoOne),
          ),
          findsOneWidget,
        );
        await _tap(tester, _key('key-people-add'));
        expect(find.text(l10n.keyRoleNew), findsOneWidget);
      });

      testWidgets('six roles: Add a role is gone', (tester) async {
        final keys = _keys(
          who: KeyPeople(
            roles: [
              for (var i = 0; i < 6; i++) KeyRole(id: 'r$i', name: 'Role $i'),
            ],
          ),
        );
        await _go(
          tester,
          lang,
          '/spaces/$_space/key-people',
          spaces: _spaces(admin: true, pass: SpacePass.lead),
          keys: keys,
        );
        expect(_key('key-people-add'), findsNothing);
      });
    });

    group('KP4 a key role [$lang]', () {
      Future<FakeKeyPeopleRepository> open(
        WidgetTester tester, {
        KeyPeople who = const KeyPeople(),
      }) async {
        final keys = _keys(who: who);
        await _go(
          tester,
          lang,
          '/spaces/$_space/key-people',
          spaces: _spaces(admin: true, pass: SpacePass.lead),
          keys: keys,
        );
        return keys;
      }

      testWidgets('role names from the market pack; a tap fills the name', (
        tester,
      ) async {
        final keys = await open(tester);
        await _tap(tester, _key('key-people-add'));
        for (final s in kuwait.keyRoleSuggestions) {
          expect(find.text(lang == 'ar' ? s.ar : s.en), findsOneWidget);
        }
        final safety = lang == 'ar' ? 'ضابط السلامة' : 'Safety officer';
        await _tap(tester, find.text(safety));
        await tester.enterText(_key('key-role-call-for'), 'Hazards');
        await _tap(tester, _key('key-role-add-person'));
        await _tap(tester, _key('key-pick-p-khalid'));
        await _tap(tester, _key('key-holder-p-khalid'));
        await tester.enterText(_key('key-holder-note-field'), 'Day shift');
        await _tap(tester, _key('key-holder-note-save'));
        expect(
          find.descendant(
            of: _key('key-holder-p-khalid'),
            matching: find.textContaining('Day shift'),
          ),
          findsOneWidget,
        );
        await _tap(tester, _key('key-role-save'));
        expect(keys.saved.single.name, safety);
        expect(keys.saved.single.callFor, 'Hazards');
        expect(keys.saved.single.holders, ['p-khalid']);
      });

      testWidgets('up to 2 people, members of the Space only', (tester) async {
        await open(tester);
        await _tap(tester, _key('key-people-add'));
        await _tap(tester, _key('key-role-add-person'));
        // Members only: the people of this Space.
        expect(_key('key-pick-p-ali'), findsOneWidget);
        await _tap(tester, _key('key-pick-p-khalid'));
        await _tap(tester, _key('key-role-add-person'));
        expect(_key('key-pick-p-khalid'), findsNothing);
        await _tap(tester, _key('key-pick-p-ali'));
        expect(_key('key-role-add-person'), findsNothing);
        await _tap(tester, _key('key-holder-remove-p-ali'));
        expect(_key('key-role-add-person'), findsOneWidget);
      });

      testWidgets('a name is needed; the server\'s limit is said', (
        tester,
      ) async {
        final keys = await open(tester);
        await _tap(tester, _key('key-people-add'));
        await _tap(tester, _key('key-role-save'));
        expect(keys.saved, isEmpty);
        await tester.enterText(_key('key-role-name'), 'Crane');
        keys.failure = SpaceFailure.limit;
        await _tap(tester, _key('key-role-save'));
        expect(find.text(l10n.keyRoleTooMany), findsOneWidget);
      });

      testWidgets('a role is changed, or deleted after asking', (tester) async {
        final keys = await open(tester, who: _who());
        await _tap(tester, _key('key-role-edit-r-safety'));
        expect(find.text(l10n.keyRoleEdit), findsOneWidget);
        expect(_key('key-holder-p-khalid'), findsOneWidget);
        await _tap(tester, _key('key-role-save'));
        expect(keys.saved.single.roleId, 'r-safety');
        expect(keys.saved.single.holders, ['p-khalid']);
        await _tap(tester, _key('key-role-edit-r-safety'));
        await _tap(tester, _key('key-role-delete'));
        expect(keys.deleted, isEmpty);
        await _tap(tester, find.text(l10n.delete).last);
        expect(keys.deleted, ['r-safety']);
      });
    });

    group('NUM1 phone number [$lang]', () {
      testWidgets('Edit profile has the row; Nobody by default', (
        tester,
      ) async {
        await _go(tester, lang, '/profile/edit');
        expect(find.text(l10n.phoneNotAdded), findsOneWidget);
        await _tap(tester, _key('edit-phone'));
        expect(_key('phone-screen'), findsOneWidget);
        expect(
          tester.widget<BvRadio>(_key('phone-see-nobody-radio')).selected,
          isTrue,
        );
        expect(
          tester.widget<BvRadio>(_key('phone-see-spaces-radio')).selected,
          isFalse,
        );
        expect(find.text(l10n.phoneNever), findsOneWidget);
      });

      testWidgets('a number in the market\'s format, saved in E.164 with '
          'the choice', (tester) async {
        final keys = _keys();
        await _go(tester, lang, '/profile/edit/phone', keys: keys);
        await tester.enterText(_key('phone-field'), '5512 3456');
        await _tap(tester, _key('phone-see-spaces'));
        expect(keys.setPhones.last, (
          phone: '+96555123456',
          visibility: PhoneVisibility.spaces,
        ));
      });

      testWidgets('a number that doesn\'t fit is said, not saved', (
        tester,
      ) async {
        final keys = _keys();
        await _go(tester, lang, '/profile/edit/phone', keys: keys);
        await tester.enterText(_key('phone-field'), '1234');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(keys.setPhones, isEmpty);
        expect(
          find.text(l10n.phoneCheck(kuwait.phoneExample!)),
          findsOneWidget,
        );
      });

      testWidgets('the choice alone can change', (tester) async {
        final keys = _keys()
          ..mine = const MyPhone(
            phone: '+96555123456',
            visibility: PhoneVisibility.spaces,
          );
        await _go(tester, lang, '/profile/edit/phone', keys: keys);
        expect(find.text('5512 3456'), findsOneWidget);
        await _tap(tester, _key('phone-see-dms'));
        expect(keys.setPhones.last, (
          phone: '+96555123456',
          visibility: PhoneVisibility.dms,
        ));
      });
    });

    group('TM3 and TM4, several Teams [$lang]', () {
      testWidgets('TM3 Add people lists people already in other Teams', (
        tester,
      ) async {
        await _go(
          tester,
          lang,
          '/spaces/$_space/teams/t-civil',
          spaces: _spaces(
            admin: true,
            pass: SpacePass.lead,
            teams: const [_civil, _gulf, _night],
          ),
        );
        await _tap(tester, _key('team-add-people'));
        expect(_key('pick-p-hassan'), findsOneWidget);
        expect(_key('pick-p-khalid'), findsOneWidget);
      });

      testWidgets('TM4 two ticks', (tester) async {
        final spaces = _spaces(
          admin: true,
          pass: SpacePass.lead,
          teams: const [_gulf, _night],
          requests: [
            SpaceJoinRequest(
              id: 'req-1',
              person: const SpacePerson(
                id: 'p-new',
                firstName: 'Nabil',
                lastName: 'New',
              ),
              createdAt: testNow,
            ),
          ],
        );
        await _go(
          tester,
          lang,
          people,
          spaces: spaces,
          keys: _keys(who: const KeyPeople()),
        );
        await _tap(tester, _key('request-let-in-req-1'));
        await _tap(tester, _key('request-pass-crew'));
        await _tap(tester, _key('confirm-team-t-gulf'));
        await _tap(tester, _key('confirm-team-t-night'));
        await _tap(tester, _key('request-confirm-req-1'));
        expect(spaces.confirmedTeams['req-1'], ['t-gulf', 't-night']);
      });
    });
  }
}
