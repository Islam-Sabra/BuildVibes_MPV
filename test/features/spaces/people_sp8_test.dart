// Review 105 Part 8 (SP8 2670:38796, AR 2670:39073; the lead's rulings):
// People from the Space's header. Each row: the name; title · company (a
// registered company in ink, medium; a typed one plain grey, rule 4); the
// pass and the person's Teams as chips. Join requests on top under "Needs
// you", with Decline · Confirm; Confirm asks for the pass, as before.
// Search in the header (SP8's icon). In English and Arabic.
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

Finder _key(String k) => find.byKey(Key(k));

const _space = 'space-1';
const _islam = SpacePerson(
  id: 'user-1',
  firstName: 'Islam',
  lastName: 'Sabra',
  headline: 'BIM Manager',
  companyLabel: 'AECOX',
  companyRegistered: true,
);
const _omar = SpacePerson(
  id: 'p-omar',
  firstName: 'Omar',
  lastName: 'Haddad',
  headline: 'MEP Supervisor',
  companyLabel: 'Al-Bahar MEP',
  companyRegistered: true,
);
const _rakesh = SpacePerson(
  id: 'p-rakesh',
  firstName: 'Rakesh',
  lastName: 'Nair',
  headline: 'Tiling Foreman',
  companyLabel: 'Star Tiling',
);
const _anil = SpacePerson(
  id: 'p-anil',
  firstName: 'Anil',
  lastName: 'Menon',
  headline: 'Electrician',
  companyLabel: 'Gulf Power Co.',
);

FakeSpaceRepository _spaces() {
  final spaces = FakeSpaceRepository(now: testNow);
  spaces.details[_space] = const SpaceDetail(
    id: _space,
    name: 'Kuwait City Tower',
    myPass: SpacePass.lead,
    iAmAdmin: true,
    myRights: MemberRights(invite: true, createItems: true),
  );
  spaces.spacePeople[_space] = SpacePeople(
    requests: [
      SpaceJoinRequest(id: 'req-1', person: _anil, createdAt: testNow),
    ],
    members: [
      for (final (p, pass) in [
        (_islam, SpacePass.lead),
        (_omar, SpacePass.crew),
        (_rakesh, SpacePass.crew),
      ])
        SpaceMember(
          person: p,
          pass: pass,
          isAdmin: p == _islam,
          confirmedAt: testNow,
        ),
    ],
    teams: const [
      SpaceTeam(id: 't-mep', name: 'MEP', memberIds: {'p-omar'}),
    ],
  );
  return spaces;
}

Future<FakeSpaceRepository> _open(WidgetTester tester, String lang) async {
  final spaces = _spaces();
  await pumpApp(tester, language: lang, spaces: spaces);
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/$_space/people');
  await tester.pumpAndSettle();
  return spaces;
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

    group('Part 8 People [$lang]', () {
      testWidgets('one list, "In this Space": name; title · company; the '
          'pass and the Teams as chips', (tester) async {
        await _open(tester, lang);
        expect(find.text(l10n.peopleInThisSpace), findsOneWidget);
        // No Leads · Crew · Viewers groups (Crew is also the pass's word).
        for (final group in [l10n.peopleLeads, l10n.peopleViewers]) {
          expect(find.text(group), findsNothing, reason: group);
        }
        final omar = _key('member-p-omar');
        expect(
          find.descendant(of: omar, matching: find.text('Omar Haddad')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: omar, matching: find.text('MEP Supervisor')),
          findsOneWidget,
        );
        expect(_key('member-pass-p-omar'), findsOneWidget);
        expect(_key('member-team-p-omar-t-mep'), findsOneWidget);
        expect(_key('member-team-p-rakesh-t-mep'), findsNothing);
      });

      testWidgets('a registered company in ink, medium; a typed one plain '
          'grey (rule 4)', (tester) async {
        await _open(tester, lang);
        final registered = tester.widget<Text>(
          find.descendant(
            of: _key('member-p-omar'),
            matching: find.text('Al-Bahar MEP'),
          ),
        );
        expect(registered.style?.color, BvColors.textPrimary);
        expect(registered.style?.fontWeight, FontWeight.w500);
        final typed = tester.widget<Text>(
          find.descendant(
            of: _key('member-p-rakesh'),
            matching: find.text('Star Tiling'),
          ),
        );
        expect(typed.style?.color, BvColors.textSecondary);
      });

      testWidgets('join requests on top under "Needs you", with Decline · '
          'Confirm; Confirm asks for the pass', (tester) async {
        final spaces = await _open(tester, lang);
        final needs = tester.getRect(find.text(l10n.peopleNeedsYouRequests));
        final request = tester.getRect(_key('request-req-1'));
        final members = tester.getRect(find.text(l10n.peopleInThisSpace));
        expect(needs.top, lessThan(request.top));
        expect(request.bottom, lessThanOrEqualTo(members.top));
        expect(
          find.descendant(
            of: _key('request-req-1'),
            matching: find.text(l10n.spacesDecline),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: _key('request-req-1'),
            matching: find.text(l10n.peopleConfirm),
          ),
          findsOneWidget,
        );
        await _tap(tester, _key('request-let-in-req-1'));
        expect(_key('request-pass-crew'), findsOneWidget);
        await _tap(tester, _key('request-pass-crew'));
        await _tap(tester, _key('request-confirm-req-1'));
        expect(spaces.calls.last, contains('req-1'));
      });

      testWidgets('search in the header finds people by name', (tester) async {
        await _open(tester, lang);
        await _tap(tester, _key('people-search'));
        await tester.enterText(_key('people-search-field'), 'rak');
        await tester.pumpAndSettle();
        expect(_key('member-p-rakesh'), findsOneWidget);
        expect(_key('member-p-omar'), findsNothing);
        expect(_key('member-user-1'), findsNothing);
      });
    });
  }
}
