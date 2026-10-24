import 'package:buildvibes/core/l10n/months.dart';
import 'package:buildvibes/data/models/profile.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/spaces/new_team_screen.dart';
import 'package:buildvibes/features/spaces/space_info_screen.dart';
import 'package:buildvibes/features/spaces/space_screen.dart';
import 'package:buildvibes/features/spaces/team_screen.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_segmented.dart';
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

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.enterText(
    find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField)),
    text,
  );
  await tester.pumpAndSettle();
}

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Navigator).first));

const _space = 'space-1';
const _spaceName = 'Tower B — Site team';
const _omar = SpacePerson(id: 'user-1', firstName: 'Omar', lastName: 'Haddad');
const _rakesh = SpacePerson(
  id: 'p-rakesh',
  firstName: 'Rakesh',
  lastName: 'Nair',
  headline: 'MEP Foreman',
);
const _sara = SpacePerson(id: 'p-sara', firstName: 'Sara', lastName: 'Ali');

/// Omar (signed in) is the only admin unless [saraAdmin]; Rakesh is Crew in
/// the MEP Team.
FakeSpaceRepository _spaces({bool iAmAdmin = true, bool saraAdmin = false}) {
  SpaceMember member(SpacePerson p, {bool admin = false}) => SpaceMember(
    person: p,
    pass: admin ? SpacePass.lead : SpacePass.crew,
    isAdmin: admin,
    confirmedAt: testNow,
    confirmedById: 'user-1',
  );
  final spaces = FakeSpaceRepository(now: testNow);
  spaces.details[_space] = SpaceDetail(
    id: _space,
    name: _spaceName,
    projectId: 'proj-1',
    projectName: 'Harbour Tower',
    myPass: iAmAdmin ? SpacePass.lead : SpacePass.crew,
    iAmAdmin: iAmAdmin,
    myRights: MemberRights(invite: iAmAdmin),
  );
  spaces.spaces.add(
    SpaceSummary(
      id: _space,
      name: _spaceName,
      pass: SpacePass.lead,
      isAdmin: iAmAdmin,
    ),
  );
  spaces.spacePeople[_space] = SpacePeople(
    members: [
      member(_omar, admin: iAmAdmin),
      member(_rakesh),
      member(_sara, admin: saraAdmin || !iAmAdmin),
    ],
    teams: const [
      SpaceTeam(id: 'team-mep', name: 'MEP Team', memberIds: {'p-rakesh'}),
    ],
  );
  return spaces;
}

Future<void> _openInfo(WidgetTester tester) async {
  _router(tester).push('/spaces/$_space');
  await tester.pumpAndSettle();
  await _tap(tester, 'space-header');
  expect(find.byType(SpaceInfoScreen), findsOneWidget);
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);

    testWidgets('Space info for an admin (SI1): You, Invite, Space; the '
        'project tag; the admins [$lang]', (tester) async {
      await pumpApp(tester, language: lang, spaces: _spaces(saraAdmin: true));
      await _openInfo(tester);
      expect(find.text(_spaceName), findsOneWidget);
      expect(find.textContaining('Harbour Tower'), findsOneWidget);
      expect(find.text(l10n.spacesInfoYou), findsOneWidget);
      expect(find.text(l10n.spacesInfoInvite), findsOneWidget);
      expect(find.text(l10n.spacesInfoSpace), findsOneWidget);
      expect(find.text(l10n.spacesPassLead), findsOneWidget);
      for (final key in [
        'info-pass',
        'info-invite',
        'info-copy',
        'info-new-code',
        'info-inviters',
        'info-notify',
        'info-admins',
        'info-site-start',
        'info-transfer',
        'info-delete',
        'info-leave',
        'space-edit',
      ]) {
        expect(find.byKey(Key(key)), findsOneWidget, reason: key);
      }
      expect(find.text(l10n.spacesOnSiteNotSet), findsOneWidget);
    });

    testWidgets('Space info for a member: no admin rows [$lang]', (
      tester,
    ) async {
      await pumpApp(tester, language: lang, spaces: _spaces(iAmAdmin: false));
      await _openInfo(tester);
      for (final key in [
        'info-inviters',
        'info-transfer',
        'info-delete',
        'space-edit',
        'info-invite',
        'info-new-code',
        // Not set: only admins see the row.
        'info-site-start',
      ]) {
        expect(find.byKey(Key(key)), findsNothing, reason: key);
      }
      expect(find.byKey(const Key('info-notify')), findsOneWidget);
      expect(find.byKey(const Key('info-leave')), findsOneWidget);
    });

    testWidgets('Who can invite and Notifications are one choice each, '
        'saved at once [$lang]', (tester) async {
      final spaces = _spaces();
      await pumpApp(tester, language: lang, spaces: spaces);
      await _openInfo(tester);

      await _tap(tester, 'inviters-everyone');
      expect(spaces.calls.last, 'update $_spaceName everyone');
      await _tap(tester, 'notify-needs-you');
      expect(spaces.calls.last, 'notify needs_you');
      final notify = tester.widget<BvSegmented<SpaceNotify>>(
        find.descendant(
          of: find.byKey(const Key('info-notify')),
          matching: find.byType(BvSegmented<SpaceNotify>),
        ),
      );
      expect(notify.value, SpaceNotify.needsYou);
    });

    testWidgets('On site since: an admin picks the day, then removes it; '
        'others see it read-only once set [$lang]', (tester) async {
      final spaces = _spaces();
      await pumpApp(
        tester,
        language: lang,
        spaces: spaces,
        overrides: [
          pickSiteStartProvider.overrideWithValue(
            (context, {required initial, required last}) async =>
                DateTime(2026, 9, 5),
          ),
        ],
      );
      await _openInfo(tester);
      await _tap(tester, 'info-site-start');
      expect(spaces.calls.last, 'site start 2026-09-05');
      expect(
        find.text(formatLongDate(DateTime(2026, 9, 5), lang)),
        findsOneWidget,
      );
      await _tap(tester, 'info-site-start');
      await _tap(tester, 'site-start-remove');
      expect(spaces.calls.last, 'site start null');
      expect(find.text(l10n.spacesOnSiteNotSet), findsOneWidget);
    });

    testWidgets('On site since, for a member: shown once set, not '
        'changeable [$lang]', (tester) async {
      final spaces = _spaces(iAmAdmin: false);
      final d = spaces.details[_space]!;
      spaces.details[_space] = SpaceDetail(
        id: d.id,
        name: d.name,
        projectId: d.projectId,
        projectName: d.projectName,
        myPass: d.myPass,
        iAmAdmin: false,
        myRights: d.myRights,
        siteStartDate: DateTime(2026, 9, 5),
      );
      await pumpApp(tester, language: lang, spaces: spaces);
      await _openInfo(tester);
      expect(
        find.text(formatLongDate(DateTime(2026, 9, 5), lang)),
        findsOneWidget,
      );
      await _tap(tester, 'info-site-start');
      expect(spaces.calls, isEmpty);
      expect(find.byKey(const Key('site-start-remove')), findsNothing);
    });

    testWidgets('Edit the name and About [$lang]', (tester) async {
      final spaces = _spaces();
      await pumpApp(tester, language: lang, spaces: spaces);
      await _openInfo(tester);
      await _tap(tester, 'space-edit');
      await _type(tester, 'edit-space-name', 'X');
      await _tap(tester, 'edit-space-save');
      expect(find.text(l10n.spacesNameRequired), findsOneWidget);
      await _type(tester, 'edit-space-name', 'Tower C — Finishes');
      await _tap(tester, 'edit-space-save');
      expect(spaces.calls.last, 'update Tower C — Finishes admins');
      // The name is at the top of the list.
      await tester.drag(
        find.byKey(const Key('space-info')),
        const Offset(0, 2000),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tower C — Finishes'), findsOneWidget);
    });

    testWidgets('leave asks first; a member leaves and goes Home [$lang]', (
      tester,
    ) async {
      final spaces = _spaces(iAmAdmin: false);
      await pumpApp(tester, language: lang, spaces: spaces);
      await _openInfo(tester);
      await _tap(tester, 'info-leave');
      expect(find.text(l10n.spacesLeaveTitle(_spaceName)), findsOneWidget);
      expect(find.text(l10n.spacesLeaveBodyPrivate), findsOneWidget);
      await _tap(tester, 'bv-dialog-confirm');
      expect(spaces.calls.last, 'leave $_space');
      expect(find.byKey(const Key('nav-home')), findsOneWidget);
      expect(find.text(l10n.spacesLeft(_spaceName)), findsOneWidget);
    });

    testWidgets('the last admin cannot leave [$lang]', (tester) async {
      final spaces = _spaces();
      await pumpApp(tester, language: lang, spaces: spaces);
      await _openInfo(tester);
      await _tap(tester, 'info-leave');
      await _tap(tester, 'bv-dialog-confirm');
      expect(find.text(l10n.spacesLastAdmin), findsOneWidget);
      expect(find.byType(SpaceInfoScreen), findsOneWidget);
    });

    testWidgets('delete asks first, then the Space is gone [$lang]', (
      tester,
    ) async {
      final spaces = _spaces();
      await pumpApp(tester, language: lang, spaces: spaces);
      await _openInfo(tester);
      await _tap(tester, 'info-delete');
      expect(find.text(l10n.spacesDeleteTitle(_spaceName)), findsOneWidget);
      await _tap(tester, 'bv-dialog-cancel');
      expect(spaces.calls, isEmpty);
      await _tap(tester, 'info-delete');
      await _tap(tester, 'bv-dialog-confirm');
      expect(spaces.calls.last, 'delete $_space');
      expect(find.text(l10n.spacesDeleted(_spaceName)), findsOneWidget);
    });

    testWidgets('transfer: choose a member, confirm, you become a member '
        '[$lang]', (tester) async {
      final spaces = _spaces();
      await pumpApp(tester, language: lang, spaces: spaces);
      await _openInfo(tester);
      await _tap(tester, 'info-transfer');
      expect(find.text(l10n.spacesTransferIntro), findsOneWidget);
      // You are not on the list.
      expect(find.byKey(const Key('transfer-user-1')), findsNothing);
      await _tap(tester, 'transfer-p-rakesh');
      expect(find.text(l10n.spacesTransferTo('Rakesh Nair')), findsOneWidget);
      await _tap(tester, 'transfer-button');
      expect(
        find.text(l10n.spacesTransferBody('Rakesh Nair', _spaceName)),
        findsOneWidget,
      );
      await _tap(tester, 'bv-dialog-confirm');
      expect(spaces.calls.last, 'transfer p-rakesh');
      expect(find.text(l10n.spacesTransferred('Rakesh Nair')), findsOneWidget);
      // Back on Space info, now as a member.
      expect(find.byKey(const Key('info-transfer')), findsNothing);
    });

    testWidgets('People shows Teams as chips, no number; New Team '
        '[$lang]', (tester) async {
      final spaces = _spaces();
      await pumpApp(tester, language: lang, spaces: spaces);
      _router(tester).push('/spaces/$_space', extra: SpaceOpen.people);
      await tester.pumpAndSettle();
      expect(find.text(l10n.spacesTeams), findsOneWidget);
      // Chips with the name only, never "1 member" (rule 3).
      final chips = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('team-chip-'),
      );
      expect(chips, findsWidgets);
      final teamDigits = tester
          .widgetList<Text>(
            find.descendant(of: chips, matching: find.byType(Text)),
          )
          .map((t) => t.data ?? '')
          .where((t) => t.contains(RegExp('[0-9]')));
      expect(teamDigits, isEmpty);

      await _tap(tester, 'people-new-team');
      expect(find.byType(NewTeamScreen), findsOneWidget);
      await _tap(tester, 'create-team');
      expect(find.text(l10n.spacesTeamNameRequired), findsOneWidget);

      // A taken name is refused.
      await _type(tester, 'team-name', 'mep team');
      await _tap(tester, 'create-team');
      expect(find.text(l10n.spacesTeamDuplicate), findsOneWidget);

      await _type(tester, 'team-name', 'Structure team');
      await _tap(tester, 'pick-p-sara');
      await _tap(tester, 'pick-p-rakesh');
      expect(find.text(l10n.spacesCreateTeam(2)), findsOneWidget);
      await _tap(tester, 'create-team');
      expect(spaces.calls.last, 'team Structure team [p-sara, p-rakesh]');
      expect(find.byType(TeamScreen), findsOneWidget);
      expect(find.text(l10n.spacesTeamIntro(_spaceName)), findsOneWidget);
      // "Members" over the people, never how many (rule 3).
      expect(find.text(l10n.spacesTeamMembersTitle), findsOneWidget);
      final digits = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .where((t) => RegExp(r'^\d+\b').hasMatch(t));
      expect(digits, isEmpty, reason: 'no count on the Team screen');
      expect(find.byKey(const Key('team-member-p-sara')), findsOneWidget);
    });

    testWidgets('a Team: Add people, Rename, Delete [$lang]', (tester) async {
      final spaces = _spaces();
      await pumpApp(tester, language: lang, spaces: spaces);
      _router(tester).push('/spaces/$_space/teams/team-mep');
      await tester.pumpAndSettle();
      expect(find.text('Rakesh Nair'), findsOneWidget);

      await _tap(tester, 'team-add-people');
      await _tap(tester, 'pick-p-sara');
      await _tap(tester, 'team-pick-save');
      expect(spaces.calls.last, startsWith('team members team-mep'));
      expect(find.text('Sara Ali'), findsOneWidget);

      await _tap(tester, 'team-more');
      await _tap(tester, 'team-rename');
      await _type(tester, 'team-rename-field', 'MEP crew');
      await _tap(tester, 'team-rename-save');
      expect(spaces.calls.last, 'rename team-mep MEP crew');
      expect(find.text('MEP crew'), findsOneWidget);

      await _tap(tester, 'team-more');
      await _tap(tester, 'team-delete');
      await _tap(tester, 'bv-dialog-confirm');
      expect(spaces.calls.last, 'delete team team-mep');
      expect(find.byType(TeamScreen), findsNothing);
    });

    testWidgets('members see a Team without the admin buttons [$lang]', (
      tester,
    ) async {
      await pumpApp(tester, language: lang, spaces: _spaces(iAmAdmin: false));
      _router(tester).push('/spaces/$_space/teams/team-mep');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('team-add-people')), findsNothing);
      expect(find.byKey(const Key('team-more')), findsNothing);
    });

    testWidgets('profile projects say who confirmed them [$lang]', (
      tester,
    ) async {
      await pumpApp(
        tester,
        language: lang,
        setUp: (pages, _) => pages.cv['user-1'] = const [
          CvProjectEntry(
            id: 'cv-1',
            projectId: 'proj-1',
            projectName: 'Harbour Tower',
            role: 'Site engineer',
            showOnProfile: true,
            confirmed: true,
            confirmedBy: ['Omar Haddad'],
          ),
          CvProjectEntry(
            id: 'cv-2',
            projectId: 'proj-2',
            projectName: 'Block C',
            role: 'Site engineer',
            showOnProfile: true,
            confirmed: true,
            confirmedBy: ['Omar Haddad', 'Sara Ali', 'Dana Ali'],
          ),
        ],
      );
      await tester.tap(find.byKey(const Key('nav-profile')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.proofConfirmedBy('Omar Haddad')), findsOneWidget);
      // Names, never a count (rule 3).
      final sep = lang == 'ar' ? '، ' : ', ';
      expect(
        find.text(
          l10n.proofConfirmedBy(
            l10n.listAndOthers('Omar Haddad${sep}Sara Ali'),
          ),
        ),
        findsOneWidget,
      );
    });
  }
}
