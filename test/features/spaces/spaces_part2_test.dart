import 'package:buildvibes/core/l10n/bidi.dart';
import 'package:buildvibes/core/design/bv_icons.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/spaces/member_pass_screen.dart';
import 'package:buildvibes/features/spaces/space_screen.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/hold.dart';
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

    testWidgets('P1, review 105 SP8: the request under Needs you, then one '
        'list with the pass tags [$lang]', (tester) async {
      await pumpApp(tester, language: lang, spaces: _spaces());
      await _openPeople(tester);
      // Under "Needs you": the name, role · company; Decline · Confirm.
      expect(find.text(l10n.peopleNeedsYouRequests), findsOneWidget);
      expect(find.text('Ahmed Saeed'), findsOneWidget);
      expect(find.byKey(const Key('request-let-in-req-1')), findsOneWidget);
      expect(find.text(l10n.peopleConfirm), findsOneWidget);
      // No Invite people button (review 67).
      expect(find.byKey(const Key('space-invite')), findsNothing);
      // One list (SP8), no sections by pass; the admin as a tag.
      expect(find.text(l10n.peopleInThisSpace), findsOneWidget);
      expect(find.text(l10n.peopleLeads), findsNothing);
      expect(find.text(l10n.peopleViewers), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('member-user-1')),
          matching: find.text('Site Engineer'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('member-admin-user-1')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('member-pass-p-rakesh')),
          matching: find.text(l10n.spacesPassCrew),
        ),
        findsOneWidget,
      );
      // Teams as chips, + New team for the admin.
      expect(find.byKey(const Key('team-chip-team-mep')), findsOneWidget);
      expect(find.byKey(const Key('people-new-team')), findsOneWidget);
      // No member count anywhere (rule 3).
      expect(find.textContaining(RegExp(r'\b2\b')), findsNothing);
    });

    testWidgets('members see no requests and no New team [$lang]', (
      tester,
    ) async {
      await pumpApp(tester, language: lang, spaces: _spaces(iAmAdmin: false));
      await _openPeople(tester);
      expect(find.byKey(const Key('request-req-1')), findsNothing);
      expect(find.byKey(const Key('people-new-team')), findsNothing);
      // May not invite: no code row.
      expect(find.byKey(const Key('people-invite-code')), findsNothing);
      expect(find.textContaining('Omar Haddad'), findsWidgets);
    });

    testWidgets('the invite code row copies the code [$lang]', (tester) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final spaces = _spaces();
      await pumpApp(tester, language: lang, spaces: spaces);
      await _openPeople(tester);
      await _tap(tester, 'people-invite-code');
      // As the server writes it, without the reading space.
      expect(copied, ['K7Q4MD']);
      expect(find.text(l10n.spacesCodeCopied), findsOneWidget);
    });

    testWidgets('P2: Let in opens the passes in place, nothing chosen; '
        'Let in as Crew [$lang]', (tester) async {
      final spaces = _spaces();
      await pumpApp(tester, language: lang, spaces: spaces);
      await _openPeople(tester);
      await _tap(tester, 'request-let-in-req-1');
      expect(find.byKey(const Key('request-pass-lead')), findsOneWidget);
      expect(find.byKey(const Key('request-pass-crew')), findsOneWidget);
      expect(find.byKey(const Key('request-pass-viewer')), findsOneWidget);

      // Nothing is chosen first: the pill is grey and does nothing.
      expect(find.text(l10n.peopleChoosePass), findsOneWidget);
      await _tap(tester, 'request-confirm-req-1');
      expect(spaces.calls, isEmpty);

      await _tap(tester, 'request-pass-crew');
      expect(
        find.text(l10n.peopleLetInAs(l10n.spacesPassCrew)),
        findsOneWidget,
      );
      // One single choice: Viewer replaces Crew.
      await _tap(tester, 'request-pass-viewer');
      expect(
        find.text(l10n.peopleLetInAs(l10n.spacesPassViewer)),
        findsOneWidget,
      );
      await _tap(tester, 'request-pass-crew');
      await _tap(tester, 'request-confirm-req-1');
      expect(spaces.calls, ['confirm req-1 crew']);

      // No jump to the pass screen: Ahmed is in Crew, highlighted.
      expect(find.byType(MemberPassScreen), findsNothing);
      expect(find.byKey(const Key('request-req-1')), findsNothing);
      expect(find.byKey(const Key('member-p-ahmed')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('member-pass-p-ahmed')),
          matching: find.text(l10n.spacesPassCrew),
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          l10n.peopleLetInDone(
            inOwnDirection('Ahmed Saeed'),
            l10n.spacesPassCrew,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('decline: no reason given, and Undo brings it back [$lang]', (
      tester,
    ) async {
      final spaces = _spaces();
      await pumpApp(tester, language: lang, spaces: spaces);
      await _openPeople(tester);
      await _tap(tester, 'request-decline-req-1');
      expect(spaces.calls, ['decline req-1']);
      expect(
        find.text(l10n.spacesDeclined(inOwnDirection('Ahmed'))),
        findsOneWidget,
      );
      expect(find.byKey(const Key('request-req-1')), findsNothing);

      await tester.tap(find.byKey(const Key('decline-undo')));
      await tester.pumpAndSettle();
      expect(spaces.calls, ['decline req-1', 'undo req-1']);
      expect(find.byKey(const Key('request-req-1')), findsOneWidget);
    });

    testWidgets('member pass: Lock create items makes it Custom [$lang]', (
      tester,
    ) async {
      final spaces = _spaces();
      await pumpApp(tester, language: lang, spaces: spaces);
      await _openMember(tester, 'p-rakesh');
      expect(find.text(l10n.passCrew), findsOneWidget);
      // Crew: files and create open; invite locked.
      expect(find.byKey(const Key('right-add_files-on')), findsOneWidget);
      expect(find.byKey(const Key('right-create_items-on')), findsOneWidget);
      expect(find.byKey(const Key('right-invite-off')), findsOneWidget);
      expect(find.text(l10n.spacesAlways), findsOneWidget);

      await _tap(tester, 'right-toggle-create_items');
      expect(spaces.calls.single, 'pass p-rakesh crew {create_items: false}');
      expect(find.byKey(const Key('right-create_items-off')), findsOneWidget);
      expect(find.text(l10n.spacesPassCustom(l10n.passCrew)), findsOneWidget);
      expect(
        find.text(
          l10n.spacesRightLocked(
            l10n.spacesRightCreate,
            inOwnDirection('Rakesh'),
          ),
        ),
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
        'invite',
      ]) {
        expect(find.byKey(Key('right-$right-off')), findsOneWidget);
      }
      expect(find.byIcon(BvIcons.lock), findsNWidgets(4));
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
      expect(
        find.text(l10n.spacesAdminOn(inOwnDirection('Rakesh'))),
        findsOneWidget,
      );
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

    testWidgets('remove asks first and is held (review 94); it goes when '
        'the undo bar has; closed work stays [$lang]', (tester) async {
      final spaces = _spaces();
      await pumpApp(tester, language: lang, spaces: spaces);
      await _openMember(tester, 'p-rakesh');
      await _tap(tester, 'member-remove');
      expect(
        find.text(l10n.spacesRemoveTitle(inOwnDirection('Rakesh Nair'))),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('hold-sheet')),
          matching: find.text(l10n.spacesRemoveBody),
        ),
        findsOneWidget,
      );
      expect(find.text(l10n.holdToRemove), findsOneWidget);
      // A tap does nothing.
      await tester.tap(holdOnSheet);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('hold-sheet')), findsOneWidget);
      await hold(tester, holdOnSheet);
      expect(find.byType(MemberPassScreen), findsNothing);
      expect(find.text(l10n.spacesRemovedUndo), findsOneWidget);
      expect(spaces.calls, isNot(contains('remove p-rakesh')));
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(spaces.calls.last, 'remove p-rakesh');
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
