import 'package:buildvibes/core/l10n/bidi.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/models/work_item.dart';
import 'package:buildvibes/features/work/work_item_screen.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';
import '../../helpers/work_fakes.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)).first);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)).first);
  await tester.pumpAndSettle();
}

const _space = 'space-1';
const _me = 'user-1';
const _omar = SpacePerson(id: _me, firstName: 'Omar', lastName: 'Haddad');
const _rakesh = SpacePerson(
  id: 'p-rakesh',
  firstName: 'Rakesh',
  lastName: 'Nair',
);
const _nadia = SpacePerson(
  id: 'p-nadia',
  firstName: 'Nadia',
  lastName: 'Fawzi',
);

FakeSpaceRepository _spaces() {
  SpaceMember member(SpacePerson p, SpacePass pass, {bool admin = false}) =>
      SpaceMember(person: p, pass: pass, isAdmin: admin, confirmedAt: testNow);
  return FakeSpaceRepository()
    ..details[_space] = const SpaceDetail(
      id: _space,
      name: 'Site team',
      myPass: SpacePass.lead,
      iAmAdmin: true,
      myRights: MemberRights(createItems: true, invite: true),
    )
    ..spacePeople[_space] = SpacePeople(
      members: [
        member(_omar, SpacePass.lead, admin: true),
        member(_rakesh, SpacePass.crew),
        member(_nadia, SpacePass.viewer),
      ],
      teams: const [SpaceTeam(id: 'team-mep', name: 'MEP Team')],
    );
}

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Navigator).first));

WorkItem _item(
  WorkStatus status, {
  String owner = 'p-rakesh',
  String ownerName = 'Rakesh Nair',
}) => WorkItem(
  id: 'item-1',
  spaceId: _space,
  ref: 'KCT-001',
  title: 'Sleeves at grid C7 before the pour',
  status: status,
  createdAt: testNow,
  ownerId: owner,
  ownerName: ownerName,
  createdById: _me,
  createdByName: 'Omar Haddad',
  teamName: 'MEP Team',
  place: 'Level 2 · Grid C7',
  due: testNow.add(const Duration(days: 1)),
  checkedById: status == WorkStatus.checked ? 'p-sara' : null,
  checkedByName: status == WorkStatus.checked ? 'Sara Ali' : null,
  checkedAt: status == WorkStatus.checked ? testNow : null,
);

WorkEvent _event(
  WorkEventKind kind, {
  String actor = 'p-rakesh',
  String name = 'Rakesh Nair',
  String? note,
  SendBackReason? reason,
  int minutes = 0,
}) => WorkEvent(
  id: '${kind.name}-$minutes',
  kind: kind,
  at: testNow.add(Duration(minutes: minutes)),
  actorId: actor,
  actorName: name,
  note: note,
  reason: reason,
);

Future<FakeWorkRepository> _openItem(
  WidgetTester tester,
  String lang,
  WorkItemDetail detail, {
  WorkNeeds needs = const WorkNeeds(),
}) async {
  final work = FakeWorkRepository()
    ..details['item-1'] = detail
    ..itemsBySpace[_space] = [detail.item]
    ..needsBySpace[_space] = needs;
  await pumpApp(tester, language: lang, spaces: _spaces(), work: work);
  _router(tester).push('/spaces/$_space/items/item-1');
  await tester.pumpAndSettle();
  return work;
}

final _raised = _event(WorkEventKind.raised, actor: _me, name: 'Omar Haddad');

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);

    testWidgets('W3a: an Open item you own: Sign as done [$lang]', (
      tester,
    ) async {
      await _openItem(
        tester,
        lang,
        WorkItemDetail(
          item: _item(WorkStatus.open, owner: _me, ownerName: 'Omar Haddad'),
          events: [_raised],
        ),
        needs: const WorkNeeds(toSign: {'item-1'}),
      );
      expect(find.byType(WorkItemScreen), findsOneWidget);
      expect(find.text('KCT-001'), findsWidgets);
      expect(find.byKey(const Key('work-sign-off')), findsOneWidget);
      expect(find.byKey(const Key('work-sign-done')), findsOneWidget);
      expect(find.byKey(const Key('work-banner')), findsNothing);
    });

    testWidgets('W3c: Done, and you check it [$lang]', (tester) async {
      await _openItem(
        tester,
        lang,
        WorkItemDetail(
          item: _item(WorkStatus.done),
          events: [
            _raised,
            _event(WorkEventKind.done, note: 'Sleeves fixed', minutes: 5),
          ],
        ),
        needs: const WorkNeeds(toCheck: {'item-1'}),
      );
      expect(
        find.text(l10n.workCheckBannerTitle(inOwnDirection('Rakesh'))),
        findsOneWidget,
      );
      expect(find.text(l10n.workEvidence), findsOneWidget);
      expect(find.textContaining('Sleeves fixed'), findsOneWidget);
      expect(find.text(l10n.workYouCheckIt), findsOneWidget);
      expect(find.byKey(const Key('work-send-back')), findsOneWidget);
      expect(find.byKey(const Key('work-check')), findsOneWidget);
    });

    testWidgets('W3b: Done, waiting for the creator [$lang]', (tester) async {
      final item = WorkItem(
        id: 'item-1',
        spaceId: _space,
        ref: 'KCT-001',
        title: 'Confirm the schedule',
        status: WorkStatus.done,
        createdAt: testNow,
        ownerId: _me,
        ownerName: 'Omar Haddad',
        createdById: 'p-sara',
        createdByName: 'Sara Ali',
      );
      await _openItem(
        tester,
        lang,
        WorkItemDetail(
          item: item,
          events: [
            _event(
              WorkEventKind.done,
              actor: _me,
              name: 'Omar Haddad',
              note: 'Done',
            ),
          ],
        ),
      );
      expect(
        find.text(l10n.workWaitingCheckBy(inOwnDirection('Sara Ali'))),
        findsOneWidget,
      );
      expect(find.byKey(const Key('work-check')), findsNothing);
    });

    testWidgets('W3d: Checked: the stamp and "Closed" [$lang]', (tester) async {
      await _openItem(
        tester,
        lang,
        WorkItemDetail(
          item: _item(WorkStatus.checked),
          events: [
            _raised,
            _event(WorkEventKind.done, note: 'Fixed', minutes: 5),
            _event(
              WorkEventKind.checked,
              actor: 'p-sara',
              name: 'Sara Ali',
              minutes: 10,
            ),
          ],
        ),
      );
      expect(find.byKey(const Key('site-tag-checked')), findsOneWidget);
      expect(find.text(l10n.workClosed), findsOneWidget);
      expect(
        find.text(l10n.workClosedCanShow(inOwnDirection('Rakesh'))),
        findsOneWidget,
      );
    });

    testWidgets('sent back: the reason and the note [$lang]', (tester) async {
      await _openItem(
        tester,
        lang,
        WorkItemDetail(
          item: _item(WorkStatus.open),
          events: [
            _raised,
            _event(WorkEventKind.done, note: 'Fixed', minutes: 5),
            _event(
              WorkEventKind.sentBack,
              actor: _me,
              name: 'Omar Haddad',
              reason: SendBackReason.photoMissing,
              note: 'Add a photo of the ties.',
              minutes: 10,
            ),
          ],
        ),
      );
      expect(
        find.text(l10n.workSentBackTitle(l10n.workReasonPhotoMissing)),
        findsOneWidget,
      );
      expect(find.text('Add a photo of the ties.'), findsOneWidget);
    });

    testWidgets('owner left: Reassign to someone who can sign [$lang]', (
      tester,
    ) async {
      final work = await _openItem(
        tester,
        lang,
        WorkItemDetail(item: _item(WorkStatus.open), events: [_raised]),
        needs: const WorkNeeds(toReassign: {'item-1'}),
      );
      expect(find.text(l10n.workOwnerLeftTitle), findsOneWidget);
      await _tap(tester, 'work-banner-reassign');
      expect(find.byKey(const Key('reassign-p-nadia')), findsNothing);
      await _tap(tester, 'reassign-user-1');
      expect(work.calls.single, 'reassign item-1 user-1');
    });

    testWidgets('discussion: comments and Add a comment [$lang]', (
      tester,
    ) async {
      final work = await _openItem(
        tester,
        lang,
        WorkItemDetail(
          item: _item(WorkStatus.open),
          events: [
            _raised,
            _event(
              WorkEventKind.comment,
              actor: _me,
              name: 'Omar Haddad',
              note: 'Before the pour, please.',
              minutes: 1,
            ),
          ],
        ),
      );
      expect(find.text('Before the pour, please.'), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('work-comment')),
          matching: find.byType(TextField),
        ),
        'On it.',
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'work-comment-send');
      expect(work.calls.single, 'comment item-1 On it.');
    });

    testWidgets('an item you can no longer see [$lang]', (tester) async {
      await pumpApp(
        tester,
        language: lang,
        spaces: _spaces(),
        work: FakeWorkRepository(),
      );
      _router(tester).push('/spaces/$_space/items/gone');
      await tester.pumpAndSettle();
      expect(find.text(l10n.workItemGone), findsOneWidget);
    });
  }
}
