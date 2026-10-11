import 'package:buildvibes/core/design/bv_icons.dart';
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/core/l10n/months.dart';
import 'package:buildvibes/data/models/profile.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/repositories/space_repository.dart';
import 'package:buildvibes/features/spaces/invite_screen.dart';
import 'package:buildvibes/features/spaces/new_space_screen.dart';
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

Future<void> _goInvite(WidgetTester tester) async {
  _router(tester).push('/spaces/space-1/invite');
  await tester.pumpAndSettle();
}

Future<void> _openSpacesTab(WidgetTester tester, AppLocalizations l10n) async {
  await tester.tap(find.text(l10n.homeSpaces));
  await tester.pumpAndSettle();
}

const _tower = 'Tower B — Site team';

SpaceDetail _detail({bool admin = true, bool invite = true}) => SpaceDetail(
  id: 'space-1',
  name: _tower,
  projectId: 'proj-1',
  projectName: 'Harbour Tower',
  myPass: admin ? SpacePass.lead : SpacePass.crew,
  iAmAdmin: admin,
  myRights: MemberRights(invite: invite),
);

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);

    testWidgets('no Spaces yet: Join your first Space [$lang]', (tester) async {
      await pumpApp(tester, language: lang);
      await _openSpacesTab(tester, l10n);
      expect(find.text(l10n.spacesEmptyTitle), findsOneWidget);
      expect(find.text(l10n.spacesEnterCode), findsOneWidget);
      expect(find.text(l10n.spacesEmptyFeedNote), findsOneWidget);
      // Create stays on the header (S1); Discover is not in the MVP.
      expect(find.byKey(const Key('spaces-create')), findsOneWidget);
    });

    testWidgets('a wrong code says so; nothing is asked [$lang]', (
      tester,
    ) async {
      final app = await pumpApp(tester, language: lang);
      await _openSpacesTab(tester, l10n);
      await _tap(tester, 'spaces-enter-code');
      // Review 07: capitals keyboard, no autocorrect or word suggestions.
      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('invite-code-field')),
          matching: find.byType(TextField),
        ),
      );
      expect(field.textCapitalization, TextCapitalization.characters);
      expect(field.autocorrect, isFalse);
      expect(field.enableSuggestions, isFalse);
      await _type(tester, 'invite-code-field', 'zzzzzz');
      expect(find.text(l10n.spacesCodeNotValid), findsOneWidget);
      await _tap(tester, 'ask-to-join');
      expect(app.spaces.requests, isEmpty);
    });

    testWidgets('a right code: Invited by, Ask to join, then waiting [$lang]', (
      tester,
    ) async {
      final spaces = FakeSpaceRepository()
        ..invites['K7Q4MD'] = const FakeInvite(
          spaceId: 'space-1',
          spaceName: _tower,
          invitedBy: 'Omar Haddad',
        );
      await pumpApp(tester, language: lang, spaces: spaces);
      await _openSpacesTab(tester, l10n);
      await _tap(tester, 'spaces-enter-code');
      // Typed the way people read it: lower case, a space, Arabic digits.
      await _type(tester, 'invite-code-field', 'k٧q 4md');
      expect(find.text(_tower), findsOneWidget);
      expect(find.text(l10n.spacesInvitedBy('Omar Haddad')), findsOneWidget);

      await _tap(tester, 'ask-to-join');
      expect(find.text(l10n.spacesRequestSent), findsOneWidget);
      expect(spaces.requests.single.spaceName, _tower);
      // The waiting card, with Cancel request.
      expect(find.text(l10n.spacesWaiting), findsOneWidget);
      await _tap(tester, 'cancel-request-request-1');
      expect(spaces.cancelled, ['request-1']);
      expect(find.text(l10n.spacesWaiting), findsNothing);
    });

    testWidgets('declined: no reason; you can ask again tomorrow [$lang]', (
      tester,
    ) async {
      final spaces = FakeSpaceRepository()
        ..invites['K7Q4MD'] = const FakeInvite(
          spaceId: 'space-1',
          spaceName: _tower,
        )
        ..joinStatus = JoinStatus.declined;
      await pumpApp(tester, language: lang, spaces: spaces);
      await _openSpacesTab(tester, l10n);
      await _tap(tester, 'spaces-enter-code');
      await _type(tester, 'invite-code-field', 'K7Q4MD');
      await _tap(tester, 'ask-to-join');
      expect(find.text(l10n.spacesDeclinedWait), findsOneWidget);
    });

    testWidgets(
      'a declined request shows Not confirmed until dismissed [$lang]',
      (tester) async {
        final spaces = FakeSpaceRepository()
          ..requests.add(
            MyJoinRequest(
              id: 'r-9',
              spaceId: 'space-9',
              spaceName: 'Block C — Finishes',
              status: JoinRequestStatus.declined,
              createdAt: testNow,
              decidedAt: testNow,
            ),
          );
        final app = await pumpApp(tester, language: lang, spaces: spaces);
        await _openSpacesTab(tester, l10n);
        expect(find.text(l10n.spacesNotConfirmed), findsOneWidget);
        await _tap(tester, 'dismiss-request-r-9');
        expect(find.text(l10n.spacesNotConfirmed), findsNothing);
        expect(app.prefs.getStringList('dismissed_join_requests'), ['r-9']);
      },
    );

    testWidgets(
      'My Spaces: project · type, and N needs you for admins [$lang]',
      (tester) async {
        final spaces = FakeSpaceRepository()
          ..spaces.addAll(const [
            SpaceSummary(
              id: 'space-1',
              name: _tower,
              pass: SpacePass.lead,
              isAdmin: true,
              projectId: 'proj-1',
              projectName: 'Harbour Tower',
              pendingRequests: 2,
            ),
            SpaceSummary(
              id: 'space-2',
              name: 'Yard crew',
              pass: SpacePass.crew,
              isAdmin: false,
            ),
          ]);
        await pumpApp(tester, language: lang, spaces: spaces);
        await _openSpacesTab(tester, l10n);
        expect(find.text(l10n.spacesProjectSpaces), findsOneWidget);
        expect(find.text(l10n.spacesNeedsYou(2)), findsOneWidget);
        expect(find.textContaining('Harbour Tower'), findsOneWidget);
        // No project: "Private work". No member counts anywhere (rule 3).
        expect(find.text(l10n.spacesPrivateWork), findsOneWidget);
        expect(find.byKey(const Key('space-needs-space-2')), findsNothing);
        // Review 07: no chevrons, and the crane is ink on the peach tile.
        expect(
          find.descendant(
            of: find.byKey(const Key('my-spaces')),
            matching: find.byIcon(BvIcons.caretForward),
          ),
          findsNothing,
        );
        final crane = tester.widget<Icon>(
          find
              .descendant(
                of: find.byKey(const Key('space-row-space-1')),
                matching: find.byIcon(BvIcons.crane),
              )
              .first,
        );
        expect(crane.color, BvColors.iconPrimary);
      },
    );

    testWidgets('New Space: name needed, link a CV project, create [$lang]', (
      tester,
    ) async {
      final app = await pumpApp(
        tester,
        language: lang,
        setUp: (pages, _) => pages.cv['user-1'] = const [
          CvProjectEntry(
            id: 'cv-1',
            projectId: 'proj-1',
            projectName: 'Harbour Tower',
            role: 'BIM Manager',
            showOnProfile: true,
            confirmed: false,
          ),
        ],
      );
      await _openSpacesTab(tester, l10n);
      await _tap(tester, 'spaces-create');
      expect(find.byType(NewSpaceScreen), findsOneWidget);
      // The preview says "Private work", never "Open · 1 member".
      expect(find.text(l10n.spacesPrivateWork), findsOneWidget);

      await _tap(tester, 'create-space');
      expect(find.text(l10n.spacesNameRequired), findsOneWidget);
      expect(app.spaces.created, isEmpty);

      await _type(tester, 'space-name', _tower);
      // Tap the box itself: the label and helper are part of the field.
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('space-project')),
          matching: find.byType(TextField),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.spacesYourRole('BIM Manager')), findsOneWidget);
      await _tap(tester, 'link-project-proj-1');
      expect(find.text('Harbour Tower'), findsWidgets);

      await _tap(tester, 'create-space');
      expect(app.spaces.created.single.name, _tower);
      expect(app.spaces.created.single.projectId, 'proj-1');
      // Opens the Space, with Invite people on top.
      expect(find.byType(InviteScreen), findsOneWidget);
      expect(find.text(l10n.spacesInviteTitle(_tower)), findsOneWidget);
      await _tap(tester, 'entry-back');
      expect(find.byType(SpaceScreen), findsOneWidget);
      expect(find.text(l10n.spacesProjectSpaceLine), findsOneWidget);
      expect(find.byKey(const Key('space-invite')), findsOneWidget);
    });

    testWidgets('Invite: the code grouped, until, Share, New code [$lang]', (
      tester,
    ) async {
      final spaces = FakeSpaceRepository(now: testNow)
        ..details['space-1'] = _detail();
      final app = await pumpApp(tester, language: lang, spaces: spaces);
      await _goInvite(tester);
      expect(find.text('K7Q 4MD'), findsOneWidget);
      expect(
        find.text(
          l10n.spacesCodeWorksUntil(
            formatDay(testNow.add(const Duration(days: 7)), lang),
          ),
        ),
        findsOneWidget,
      );

      await _tap(tester, 'invite-share');
      expect(app.shared.single, l10n.spacesShareText(_tower, 'K7Q4MD'));

      // A new code, after asking: the old one stops working.
      await _tap(tester, 'invite-new-code');
      expect(find.text(l10n.spacesNewCodeTitle), findsOneWidget);
      await _tap(tester, 'bv-sheet-confirm');
      expect(find.text('P2X 9RT'), findsOneWidget);
    });

    testWidgets(
      'Invite: members without admin rights get no New code [$lang]',
      (tester) async {
        final spaces = FakeSpaceRepository()
          ..details['space-1'] = _detail(admin: false);
        await pumpApp(tester, language: lang, spaces: spaces);
        await _goInvite(tester);
        expect(find.text('K7Q 4MD'), findsOneWidget);
        expect(find.byKey(const Key('invite-new-code')), findsNothing);
      },
    );

    testWidgets('no invite right: no Invite people in the Space [$lang]', (
      tester,
    ) async {
      final spaces = FakeSpaceRepository()
        ..details['space-1'] = _detail(admin: false, invite: false);
      await pumpApp(tester, language: lang, spaces: spaces);
      _router(tester).push('/spaces/space-1', extra: SpaceOpen.people);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('space-invite')), findsNothing);
    });

    testWidgets('Create sheet: New Space and Enter an invite code [$lang]', (
      tester,
    ) async {
      await pumpApp(tester, language: lang);
      await _tap(tester, 'nav-create');
      expect(find.text(l10n.spacesNewTitle), findsOneWidget);
      await _tap(tester, 'create-enter-code');
      expect(find.byKey(const Key('code-sheet')), findsOneWidget);
    });

    testWidgets('guests: Enter an invite code asks them to join [$lang]', (
      tester,
    ) async {
      await pumpApp(tester, language: lang, signedIn: false);
      await _tap(tester, 'welcome-skip');
      await _openSpacesTab(tester, l10n);
      await _tap(tester, 'spaces-enter-code');
      expect(find.text(l10n.joinWallTitle), findsOneWidget);
    });
  }

  test('invite codes are cleaned up the way the server does it', () {
    expect(normalizeInviteCode('k7q 4md'), 'K7Q4MD');
    expect(normalizeInviteCode('K7Q-4MD'), 'K7Q4MD');
    expect(normalizeInviteCode('ab٣٤۵6'), 'AB3456');
  });

  test('a code reads in two groups of three', () {
    expect(SpaceInvite(code: 'K7Q4MD', expiresAt: testNow).grouped, 'K7Q 4MD');
  });
}
