import 'package:buildvibes/core/design/bv_icons.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/spaces/member_pass_screen.dart';
import 'package:buildvibes/features/spaces/space_screen.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)).first);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)).first);
  await tester.pumpAndSettle();
}

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Navigator).first));

const _space = 'space-1';
const _omar = SpacePerson(
  id: 'user-1',
  firstName: 'Omar',
  lastName: 'Haddad',
  headline: 'Site Engineer',
  companyLabel: 'Al Hamra Contracting',
);
const _ahmed = SpacePerson(
  id: 'p-ahmed',
  firstName: 'Ahmed',
  lastName: 'Saeed',
  headline: 'Steel fixer foreman',
  companyLabel: 'Al Hamra Contracting',
);
const _rakesh = SpacePerson(
  id: 'p-rakesh',
  firstName: 'Rakesh',
  lastName: 'Nair',
  headline: 'MEP Foreman',
);

/// Omar (signed in) runs the Space; Rakesh is Crew in the MEP Team; Ahmed
/// asked to join two hours ago with Omar's code.
FakeSpaceRepository _spaces({
  bool iAmAdmin = true,
  SpacePass rakeshPass = SpacePass.crew,
}) {
  final spaces = FakeSpaceRepository(now: testNow);
  spaces.details[_space] = SpaceDetail(
    id: _space,
    name: 'Tower B — Site team',
    projectId: 'proj-1',
    myPass: iAmAdmin ? SpacePass.lead : SpacePass.crew,
    iAmAdmin: iAmAdmin,
    myRights: MemberRights(invite: iAmAdmin),
  );
  spaces.spacePeople[_space] = SpacePeople(
    requests: [
      if (iAmAdmin)
        SpaceJoinRequest(
          id: 'req-1',
          person: _ahmed,
          createdAt: testNow.subtract(const Duration(hours: 2)),
          invitedByName: 'Omar Haddad',
        ),
    ],
    members: [
      SpaceMember(
        person: _omar,
        pass: SpacePass.lead,
        isAdmin: true,
        confirmedAt: testNow,
        confirmedById: 'user-1',
      ),
      SpaceMember(
        person: _rakesh,
        pass: rakeshPass,
        isAdmin: false,
        confirmedAt: testNow,
        confirmedById: 'user-1',
      ),
    ],
    teams: const [
      SpaceTeam(id: 'team-mep', name: 'MEP Team', memberIds: {'p-rakesh'}),
    ],
  );
  return spaces;
}

Future<void> _openPeople(WidgetTester tester) async {
  _router(tester).push('/spaces/$_space', extra: SpaceOpen.people);
  await tester.pumpAndSettle();
}

Future<void> _openMember(WidgetTester tester, String profileId) async {
  _router(tester).push('/spaces/$_space/members/$profileId');
  await tester.pumpAndSettle();
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);

    testWidgets('admins see requests: who, when, whose code [$lang]', (
      tester,
    ) async {
      await pumpApp(tester, language: lang, spaces: _spaces());
      await _openPeople(tester);
      expect(find.text(l10n.spacesRequestsTitle), findsOneWidget);
      expect(find.text('Ahmed Saeed'), findsOneWidget);
      expect(
        find.textContaining(l10n.spacesViaCodeFrom('Omar Haddad')),
        findsOneWidget,
      );
      expect(
        find.textContaining(l10n.spacesAsked(l10n.timeHoursAgo(2))),
        findsOneWidget,
      );
      // Owners, then Members with their pass and Teams.
      expect(find.text(l10n.spacesOwners), findsOneWidget);
      expect(find.text(l10n.spacesOwnerTag), findsOneWidget);
      expect(find.text(l10n.spacesMembers), findsOneWidget);
      expect(
        find.textContaining(l10n.spacesPassLine(l10n.spacesPassCrew)),
        findsOneWidget,
      );
      expect(find.textContaining('MEP Team'), findsOneWidget);
    });

    testWidgets('members see no requests [$lang]', (tester) async {
      await pumpApp(tester, language: lang, spaces: _spaces(iAmAdmin: false));
      await _openPeople(tester);
      expect(find.text(l10n.spacesRequestsTitle), findsNothing);
      expect(find.textContaining('Omar Haddad'), findsWidgets);
    });

    testWidgets('search filters the lists [$lang]', (tester) async {
      await pumpApp(tester, language: lang, spaces: _spaces());
      await _openPeople(tester);
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('people-search')),
          matching: find.byType(TextField),
        ),
        'rakesh',
      );
      await tester.pumpAndSettle();
      expect(find.text('Rakesh Nair'), findsOneWidget);
      expect(find.text('Ahmed Saeed'), findsNothing);
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('people-search')),
          matching: find.byType(TextField),
        ),
        'nobody here',
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.spacesNoMatch), findsOneWidget);
    });

    testWidgets('confirm: choose a pass first, then Confirm as Crew [$lang]', (
      tester,
    ) async {
      final spaces = _spaces();
      await pumpApp(tester, language: lang, spaces: spaces);
      await _openPeople(tester);
      await _tap(tester, 'request-confirm-req-1');
      expect(find.byKey(const Key('confirm-sheet')), findsOneWidget);
      expect(find.text(l10n.spacesGivePass), findsOneWidget);

      // Nothing is chosen first, so Confirm does nothing yet.
      await _tap(tester, 'confirm-sheet-confirm');
      expect(spaces.calls, isEmpty);

      await _tap(tester, 'confirm-pass-crew');
      expect(
        find.text(l10n.spacesConfirmAs(l10n.spacesPassCrew)),
        findsOneWidget,
      );
      await _tap(tester, 'confirm-sheet-confirm');
      expect(spaces.calls, ['confirm req-1 crew']);

      // The new member's pass opens, with the banner.
      expect(find.byType(MemberPassScreen), findsOneWidget);
      expect(
        find.text(l10n.spacesJoinedAs('Ahmed Saeed', l10n.spacesPassCrew)),
        findsOneWidget,
      );
      expect(find.text(l10n.passCrew), findsOneWidget);
      expect(find.textContaining(l10n.spacesConfirmedByYou), findsOneWidget);
    });

    testWidgets('decline: no reason given, and Undo brings it back [$lang]', (
      tester,
    ) async {
      final spaces = _spaces();
      await pumpApp(tester, language: lang, spaces: spaces);
      await _openPeople(tester);
      await _tap(tester, 'request-decline-req-1');
      expect(spaces.calls, ['decline req-1']);
      expect(find.text(l10n.spacesDeclined('Ahmed')), findsOneWidget);
      expect(find.byKey(const Key('request-req-1')), findsNothing);

      await tester.tap(find.byKey(const Key('decline-undo')));
      await tester.pumpAndSettle();
      expect(spaces.calls, ['decline req-1', 'undo req-1']);
      expect(find.byKey(const Key('request-req-1')), findsOneWidget);
    });

    testWidgets('member pass: Open create items makes it Custom [$lang]', (
      tester,
    ) async {
      final spaces = _spaces();
      await pumpApp(tester, language: lang, spaces: spaces);
      await _openMember(tester, 'p-rakesh');
      expect(find.text(l10n.passCrew), findsOneWidget);
      // Crew: files open; create, check and invite locked.
      expect(find.byKey(const Key('right-add_files-on')), findsOneWidget);
      expect(find.byKey(const Key('right-create_items-off')), findsOneWidget);
      expect(find.text(l10n.spacesAlways), findsOneWidget);

      await _tap(tester, 'right-toggle-create_items');
      expect(spaces.calls.single, 'pass p-rakesh crew {create_items: true}');
      expect(find.byKey(const Key('right-create_items-on')), findsOneWidget);
      expect(find.text(l10n.spacesPassCustom(l10n.passCrew)), findsOneWidget);
      expect(
        find.text(l10n.spacesRightOpened(l10n.spacesRightCreate, 'Rakesh')),
        findsOneWidget,
      );
    });

    testWidgets('a Viewer: everything but chat is locked [$lang]', (
      tester,
    ) async {
      await pumpApp(
        tester,
        language: lang,
        spaces: _spaces(rakeshPass: SpacePass.viewer),
      );
      await _openMember(tester, 'p-rakesh');
      expect(find.text(l10n.passViewer), findsOneWidget);
      for (final right in [
        'mark_done',
        'add_files',
        'create_items',
        'check_items',
        'invite',
      ]) {
        expect(find.byKey(Key('right-$right-off')), findsOneWidget);
      }
      expect(find.byIcon(BvIcons.lock), findsNWidgets(5));
    });

    testWidgets('change pass, Teams and Make admin [$lang]', (tester) async {
      final spaces = _spaces();
      await pumpApp(tester, language: lang, spaces: spaces);
      await _openMember(tester, 'p-rakesh');

      await _tap(tester, 'pass-chip-lead');
      expect(spaces.calls.last, 'pass p-rakesh lead {}');
      expect(
        find.text(l10n.spacesPassChanged('Rakesh', l10n.spacesPassLead)),
        findsOneWidget,
      );

      await _tap(tester, 'team-chip-team-mep');
      expect(spaces.calls.last, 'teams p-rakesh []');

      await _tap(tester, 'member-make-admin');
      expect(spaces.calls.last, 'admin p-rakesh true');
      expect(find.text(l10n.spacesAdminOn('Rakesh')), findsOneWidget);
    });

    testWidgets('the last admin stays an admin [$lang]', (tester) async {
      final spaces = _spaces();
      await pumpApp(tester, language: lang, spaces: spaces);
      await _openMember(tester, 'user-1');
      // Your own pass: no Remove (you leave from Space info instead).
      expect(find.byKey(const Key('member-remove')), findsNothing);
      await _tap(tester, 'member-make-admin');
      expect(find.text(l10n.spacesNeedsAdmin), findsOneWidget);
    });

    testWidgets('remove asks first; closed work stays [$lang]', (tester) async {
      final spaces = _spaces();
      await pumpApp(tester, language: lang, spaces: spaces);
      await _openMember(tester, 'p-rakesh');
      await _tap(tester, 'member-remove');
      expect(find.text(l10n.spacesRemoveTitle('Rakesh Nair')), findsOneWidget);
      await _tap(tester, 'bv-sheet-confirm');
      expect(spaces.calls.last, 'remove p-rakesh');
      expect(find.byType(MemberPassScreen), findsNothing);
      expect(find.text(l10n.spacesRemoved('Rakesh Nair')), findsOneWidget);
    });

    testWidgets('members see a pass read-only [$lang]', (tester) async {
      await pumpApp(tester, language: lang, spaces: _spaces(iAmAdmin: false));
      await _openMember(tester, 'p-rakesh');
      expect(find.byKey(const Key('right-toggle-create_items')), findsNothing);
      expect(find.byKey(const Key('member-make-admin')), findsNothing);
      expect(find.byKey(const Key('member-remove')), findsNothing);
    });
  }
}
