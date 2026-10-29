// Review 105C-B (Part 9, SP9): removing someone who owns Open work items
// opens a sheet, each item with a Give to picker (its maker by default),
// then Cancel · Give and remove; one step on the server
// (remove_member_with_handover). Leaving by oneself shows the same sheet
// (leave_space_with_handover).
import 'package:buildvibes/core/l10n/bidi.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/spaces/space_info_screen.dart';
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
const _spaceName = 'Tower B — Site team';
const _islam = SpacePerson(id: 'user-1', firstName: 'Islam', lastName: 'Sabra');
const _omar = SpacePerson(id: 'p-omar', firstName: 'Omar', lastName: 'Haddad');
const _khalid = SpacePerson(
  id: 'p-khalid',
  firstName: 'Khalid',
  lastName: 'Al-Mansour',
);
const _noura = SpacePerson(
  id: 'p-noura',
  firstName: 'Noura',
  lastName: 'Al-Sabah',
);
const _vera = SpacePerson(id: 'p-vera', firstName: 'Vera', lastName: 'Lane');

/// Islam (signed in) runs the Space. Omar, Khalid and Noura are Crew,
/// Vera a Viewer. Omar owns two Open items: Khalid made the first, Vera
/// (who can't own work) the second.
FakeSpaceRepository _spaces({bool iAmAdmin = true}) {
  SpaceMember member(SpacePerson p, SpacePass pass, {bool admin = false}) =>
      SpaceMember(
        person: p,
        pass: pass,
        isAdmin: admin,
        confirmedAt: testNow,
        confirmedById: 'user-1',
      );
  final spaces = FakeSpaceRepository(now: testNow);
  spaces.details[_space] = SpaceDetail(
    id: _space,
    name: _spaceName,
    projectId: 'proj-1',
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
      member(_islam, SpacePass.lead, admin: iAmAdmin),
      member(_omar, SpacePass.crew),
      member(_khalid, SpacePass.crew),
      member(_noura, SpacePass.lead, admin: !iAmAdmin),
      member(_vera, SpacePass.viewer),
    ],
  );
  return spaces;
}

const _sleeves = OpenWorkItem(
  id: 'item-022',
  ref: 'KCT-022',
  title: 'Sleeves at grid D2 before the pour',
  makerId: 'p-khalid',
  makerName: 'Khalid Al-Mansour',
  makerMayOwn: true,
);
const _pump = OpenWorkItem(
  id: 'item-025',
  ref: 'KCT-025',
  title: 'Test the fire pump',
  makerId: 'p-vera',
  makerName: 'Vera Lane',
);

Future<void> _openMember(WidgetTester tester, String profileId) async {
  _router(tester).push('/spaces/$_space/members/$profileId');
  await tester.pumpAndSettle();
}

Future<void> _openInfo(WidgetTester tester) async {
  _router(tester).push('/spaces/$_space');
  await tester.pumpAndSettle();
  await _tap(tester, 'space-header');
  expect(find.byType(SpaceInfoScreen), findsOneWidget);
}

/// Picks [name] on the Give to picker of [item].
Future<void> _giveTo(WidgetTester tester, String item, String name) async {
  await _tap(tester, 'handover-give-$item');
  expect(find.byKey(const Key('handover-picker')), findsOneWidget);
  // Omar, who is leaving, and Vera, a Viewer, aren't offered.
  expect(
    find.descendant(
      of: find.byKey(const Key('handover-picker')),
      matching: find.text('Omar Haddad'),
    ),
    findsNothing,
  );
  expect(
    find.descendant(
      of: find.byKey(const Key('handover-picker')),
      matching: find.text('Vera Lane'),
    ),
    findsNothing,
  );
  await tester.tap(
    find.descendant(
      of: find.byKey(const Key('handover-picker')),
      matching: find.text(name),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);

    testWidgets('SP9: Remove lists each Open item with Give to, its maker '
        'chosen when they may own it; Give and remove waits until each has '
        'someone [$lang]', (tester) async {
      final spaces = _spaces()..openWorkBy['p-omar'] = const [_sleeves, _pump];
      await pumpApp(tester, language: lang, spaces: spaces);
      await _openMember(tester, 'p-omar');
      await _tap(tester, 'member-remove');
      final sheet = find.byKey(const Key('handover-sheet'));
      expect(sheet, findsOneWidget);
      // No hold here: the sheet is the question.
      expect(find.text(l10n.holdToRemove), findsNothing);
      expect(
        find.text(l10n.spacesRemoveTitle(inOwnDirection('Omar Haddad'))),
        findsOneWidget,
      );
      expect(
        find.text(l10n.handoverRemoveBody(inOwnDirection('Omar'), 2)),
        findsOneWidget,
      );
      for (final i in [_sleeves, _pump]) {
        final row = find.byKey(Key('handover-item-${i.id}'));
        expect(
          find.descendant(of: row, matching: find.text(i.ref!)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: row, matching: find.text(i.title)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: row, matching: find.text(l10n.handoverGiveTo)),
          findsOneWidget,
        );
      }
      // The maker by default; a Viewer maker can't own it: chosen by hand.
      expect(
        find.descendant(
          of: find.byKey(Key('handover-item-${_sleeves.id}')),
          matching: find.text(inOwnDirection('Khalid Al-Mansour')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(Key('handover-item-${_pump.id}')),
          matching: find.text(l10n.handoverChoose),
        ),
        findsOneWidget,
      );
      expect(find.text(l10n.handoverTheirChecked), findsOneWidget);
      // Not yet: one item has nobody.
      await tester.tap(find.byKey(const Key('handover-confirm')));
      await tester.pumpAndSettle();
      expect(sheet, findsOneWidget);
      await _giveTo(tester, _pump.id, 'Noura Al-Sabah');
      expect(
        find.descendant(
          of: find.byKey(Key('handover-item-${_pump.id}')),
          matching: find.text(inOwnDirection('Noura Al-Sabah')),
        ),
        findsOneWidget,
      );
      await _tap(tester, 'handover-confirm');
      expect(sheet, findsNothing);
      // As any removal: Undo for 5 seconds, then one step on the server.
      expect(find.text(l10n.spacesRemovedUndo), findsOneWidget);
      expect(spaces.calls, isNot(contains(startsWith('remove p-omar'))));
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(
        spaces.calls.last,
        'remove p-omar give item-022>p-khalid, item-025>p-noura',
      );
    });

    testWidgets('SP9: Cancel removes nobody [$lang]', (tester) async {
      final spaces = _spaces()..openWorkBy['p-omar'] = const [_sleeves];
      await pumpApp(tester, language: lang, spaces: spaces);
      await _openMember(tester, 'p-omar');
      await _tap(tester, 'member-remove');
      expect(
        find.text(l10n.handoverRemoveBody(inOwnDirection('Omar'), 1)),
        findsOneWidget,
      );
      await _tap(tester, 'handover-cancel');
      expect(find.byKey(const Key('handover-sheet')), findsNothing);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(spaces.calls, isNot(contains(startsWith('remove'))));
    });

    testWidgets('no Open work: Remove is held, as before [$lang]', (
      tester,
    ) async {
      final spaces = _spaces();
      await pumpApp(tester, language: lang, spaces: spaces);
      await _openMember(tester, 'p-omar');
      await _tap(tester, 'member-remove');
      expect(find.byKey(const Key('handover-sheet')), findsNothing);
      expect(find.text(l10n.holdToRemove), findsOneWidget);
      expect(spaces.openWorkReads, 1);
    });

    testWidgets('no signal for the list: nothing opens, it says why '
        '[$lang]', (tester) async {
      final spaces = _spaces()..failOpenWork = true;
      await pumpApp(tester, language: lang, spaces: spaces);
      await _openMember(tester, 'p-omar');
      await _tap(tester, 'member-remove');
      expect(find.byKey(const Key('handover-sheet')), findsNothing);
      expect(find.text(l10n.holdToRemove), findsNothing);
      expect(find.text(l10n.errorNetwork), findsOneWidget);
    });

    testWidgets('SP9: leaving with my Open work shows the same sheet; Give '
        'and leave does it in one step [$lang]', (tester) async {
      final spaces = _spaces(iAmAdmin: false)
        ..openWorkBy['user-1'] = const [
          OpenWorkItem(
            id: 'item-030',
            ref: 'KCT-030',
            title: 'Fire stopping, level 4',
            makerId: 'p-noura',
            makerName: 'Noura Al-Sabah',
            makerMayOwn: true,
          ),
        ];
      await pumpApp(tester, language: lang, spaces: spaces);
      await _openInfo(tester);
      await _tap(tester, 'info-leave');
      expect(find.byKey(const Key('handover-sheet')), findsOneWidget);
      expect(find.text(l10n.handoverLeaveBody(1)), findsOneWidget);
      expect(find.text(l10n.handoverMyChecked), findsOneWidget);
      expect(find.text(l10n.handoverGiveAndLeave), findsOneWidget);
      // The old dialog doesn't come first.
      expect(find.text(l10n.spacesLeaveBodyPrivate), findsNothing);
      await _tap(tester, 'handover-confirm');
      expect(spaces.calls.last, 'leave $_space give item-030>p-noura');
      expect(find.byKey(const Key('nav-home')), findsOneWidget);
      expect(find.text(l10n.spacesLeft(_spaceName)), findsOneWidget);
    });

    testWidgets('leaving with no Open work asks as before [$lang]', (
      tester,
    ) async {
      final spaces = _spaces(iAmAdmin: false);
      await pumpApp(tester, language: lang, spaces: spaces);
      await _openInfo(tester);
      await _tap(tester, 'info-leave');
      expect(find.byKey(const Key('handover-sheet')), findsNothing);
      expect(find.text(l10n.spacesLeaveBodyPrivate), findsOneWidget);
      await _tap(tester, 'bv-dialog-confirm');
      expect(spaces.calls.last, 'leave $_space');
    });

    testWidgets('SP9 mirrored: Cancel at the ${lang == 'ar' ? 'right' : 'left'}'
        ', the Give to row\'s caret pointing on [$lang]', (tester) async {
      final spaces = _spaces()..openWorkBy['p-omar'] = const [_sleeves];
      await pumpApp(tester, language: lang, spaces: spaces);
      await _openMember(tester, 'p-omar');
      await _tap(tester, 'member-remove');
      final cancel = tester.getCenter(find.byKey(const Key('handover-cancel')));
      final give = tester.getCenter(find.byKey(const Key('handover-confirm')));
      if (lang == 'ar') {
        expect(cancel.dx, greaterThan(give.dx));
      } else {
        expect(cancel.dx, lessThan(give.dx));
      }
      final row = find.byKey(Key('handover-give-${_sleeves.id}'));
      final label = tester.getCenter(
        find.descendant(of: row, matching: find.text(l10n.handoverGiveTo)),
      );
      final name = tester.getCenter(
        find.descendant(
          of: row,
          matching: find.text(inOwnDirection('Khalid Al-Mansour')),
        ),
      );
      if (lang == 'ar') {
        expect(label.dx, greaterThan(name.dx));
      } else {
        expect(label.dx, lessThan(name.dx));
      }
    });

    testWidgets('the lead\'s check N4: the sheet names the person by the '
        'first name on their profile, even of two words [$lang]', (
      tester,
    ) async {
      const abdul = SpacePerson(
        id: 'p-abdul',
        firstName: 'Abdul Rahman',
        lastName: 'Saleh',
      );
      final spaces = _spaces()..openWorkBy['p-abdul'] = const [_sleeves];
      spaces.spacePeople[_space] = SpacePeople(
        members: [
          ...spaces.spacePeople[_space]!.members,
          SpaceMember(
            person: abdul,
            pass: SpacePass.crew,
            isAdmin: false,
            confirmedAt: testNow,
            confirmedById: 'user-1',
          ),
        ],
      );
      await pumpApp(tester, language: lang, spaces: spaces);
      await _openMember(tester, 'p-abdul');
      await _tap(tester, 'member-remove');
      expect(
        find.text(l10n.handoverRemoveBody(inOwnDirection('Abdul Rahman'), 1)),
        findsOneWidget,
      );
    });

    test('the lead\'s check N4: the open-work count from 11 up [$lang]', () {
      expect(
        l10n.handoverLeaveBody(11),
        lang == 'ar'
            ? 'لديك 11 بند عمل مفتوحًا. أعطِ كل بند لشخص آخر حتى لا يبقى '
                  'بند بلا مكلّف.'
            : 'You have 11 open work items. Give each one to someone so '
                  'nothing is left without an owner.',
      );
      expect(
        l10n.handoverLeaveBody(3),
        lang == 'ar'
            ? 'لديك 3 بنود عمل مفتوحة. أعطِ كل بند لشخص آخر حتى لا يبقى '
                  'بند بلا مكلّف.'
            : 'You have 3 open work items. Give each one to someone so '
                  'nothing is left without an owner.',
      );
    });
  }
}
