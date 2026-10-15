import 'package:buildvibes/core/l10n/bidi.dart';
import 'dart:io';

import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/models/work_item.dart';
import 'package:buildvibes/features/profile/delivered_work.dart';
import 'package:buildvibes/features/work/work_outbox.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_stamp.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
const _me = 'user-1';

FakeSpaceRepository _spaces() =>
    FakeSpaceRepository()
      ..details[_space] = const SpaceDetail(
        id: _space,
        name: 'Site team',
        myPass: SpacePass.lead,
        iAmAdmin: true,
        myRights: MemberRights(createItems: true),
      );

WorkItem _item(
  WorkStatus status, {
  String owner = 'p-rakesh',
  bool shown = false,
}) => WorkItem(
  id: 'item-1',
  spaceId: _space,
  ref: 'KCT-001',
  title: 'Sleeves at grid C7',
  status: status,
  createdAt: testNow,
  ownerId: owner,
  ownerName: owner == _me ? 'Omar Haddad' : 'Rakesh Nair',
  createdById: owner == _me ? 'p-sara' : _me,
  createdByName: owner == _me ? 'Sara Ali' : 'Omar Haddad',
  place: 'Grid C7',
  checkedById: status == WorkStatus.checked ? 'p-sara' : null,
  checkedByName: status == WorkStatus.checked ? 'Sara Al-Mansour' : null,
  checkedAt: status == WorkStatus.checked ? testNow : null,
  shown: shown,
);

Future<FakeWorkRepository> _open(
  WidgetTester tester,
  String lang,
  WorkItem item, {
  WorkNeeds needs = const WorkNeeds(),
  List<WorkEvent> events = const [],
  FakeWorkRepository? work,
}) async {
  final w = (work ?? FakeWorkRepository())
    ..details['item-1'] = WorkItemDetail(item: item, events: events)
    ..itemsBySpace[_space] = [item]
    ..needsBySpace[_space] = needs;
  await pumpApp(tester, language: lang, spaces: _spaces(), work: w);
  _router(tester).push('/spaces/$_space/items/item-1');
  await tester.pumpAndSettle();
  return w;
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);

    testWidgets('W4: a photo or a note is needed, then it is signed [$lang]', (
      tester,
    ) async {
      final work = await _open(
        tester,
        lang,
        _item(WorkStatus.open, owner: _me),
        needs: const WorkNeeds(toSign: {'item-1'}),
      );
      await _tap(tester, 'work-sign-done');
      expect(find.text(l10n.workSignTitle(ltrRun('KCT-001'))), findsOneWidget);
      await _tap(tester, 'sign-done-confirm');
      expect(find.text(l10n.workSignNeedsSomething), findsOneWidget);
      expect(work.calls, isEmpty);

      await _tap(tester, 'sign-done-add-photo');
      await _type(tester, 'sign-done-note', 'Rev C confirmed.');
      await _tap(tester, 'sign-done-confirm');
      expect(work.calls.single, 'done item-1 Rev C confirmed. 1');
      expect(work.uploads.single, startsWith('$_space/item-1/'));
      expect(find.text(l10n.workSigned), findsOneWidget);
    });

    testWidgets('W4 on a weak signal: kept on the phone, then Retry [$lang]', (
      tester,
    ) async {
      final work = FakeWorkRepository()..failNext = 3;
      await _open(
        tester,
        lang,
        _item(WorkStatus.open, owner: _me),
        needs: const WorkNeeds(toSign: {'item-1'}),
        work: work,
      );
      await _tap(tester, 'work-sign-done');
      await _tap(tester, 'sign-done-add-photo');
      await _tap(tester, 'sign-done-confirm');
      expect(work.calls, isEmpty);
      expect(find.text(l10n.workPendingSignOff), findsOneWidget);
      // Not offered twice while it waits.
      expect(find.byKey(const Key('work-sign-done')), findsNothing);

      await _tap(tester, 'work-retry-sign-off');
      expect(work.calls.single, 'done item-1  1');
      expect(find.text(l10n.workPendingSignOff), findsNothing);
    });

    testWidgets('an unsent sign-off keeps its photo; a cleaned-up upload is '
        'sent again from the phone [$lang]', (tester) async {
      // Review 11 A4: the photo uploads, then the signal drops.
      final work = FakeWorkRepository()..failSendNext = 3;
      await _open(
        tester,
        lang,
        _item(WorkStatus.open, owner: _me),
        needs: const WorkNeeds(toSign: {'item-1'}),
        work: work,
      );
      await _tap(tester, 'work-sign-done');
      await _tap(tester, 'sign-done-add-photo');
      await _tap(tester, 'sign-done-confirm');
      expect(find.text(l10n.workPendingSignOff), findsOneWidget);
      final first = work.uploads.single;

      // While it waits, the phone copy stays.
      final outbox = ProviderScope.containerOf(
        tester.element(find.byType(Navigator).first),
      ).read(workOutboxProvider);
      final kept = outbox.single.photos.single;
      expect(kept.remote, first);
      expect(File(kept.local).existsSync(), isTrue);

      // A week later the server cleaned up that upload.
      work.cleanedUp.add(first);
      await _tap(tester, 'work-retry-sign-off');
      expect(work.uploads, hasLength(2));
      expect(work.uploads.last, isNot(first));
      expect(work.calls.single, 'done item-1  1');
      expect(find.text(l10n.workPendingSignOff), findsNothing);
    });

    testWidgets('W5: one reason, a note for Other, then Send back [$lang]', (
      tester,
    ) async {
      final work = await _open(
        tester,
        lang,
        _item(WorkStatus.done),
        needs: const WorkNeeds(toCheck: {'item-1'}),
      );
      await _tap(tester, 'work-send-back');
      expect(
        find.text(
          l10n.workSendBackTitle(ltrRun('KCT-001'), inOwnDirection('Rakesh')),
        ),
        findsOneWidget,
      );
      await _tap(tester, 'send-back-confirm');
      expect(find.text(l10n.workReasonRequired), findsOneWidget);
      await _tap(tester, 'reason-other');
      await _tap(tester, 'send-back-confirm');
      expect(find.text(l10n.workOtherNeedsNote), findsOneWidget);
      await _tap(tester, 'reason-not_as_asked');
      await _type(tester, 'send-back-note', 'Sleeve should be 150.');
      await _tap(tester, 'send-back-confirm');
      expect(
        work.calls.single,
        'back item-1 not_as_asked Sleeve should be 150.',
      );
      expect(
        find.text(l10n.workSentBack(inOwnDirection('Rakesh'))),
        findsOneWidget,
      );
    });

    testWidgets('Check and close asks first [$lang]', (tester) async {
      final work = await _open(
        tester,
        lang,
        _item(WorkStatus.done),
        needs: const WorkNeeds(toCheck: {'item-1'}),
      );
      await _tap(tester, 'work-check');
      expect(find.text(l10n.workCheckTitle(ltrRun('KCT-001'))), findsOneWidget);
      await _tap(tester, 'bv-dialog-cancel');
      expect(work.calls, isEmpty);
      // A comment field in focus doesn't take it back after the dialog.
      await _tap(tester, 'work-comment');
      await _tap(tester, 'work-check');
      await _tap(tester, 'bv-dialog-confirm');
      expect(work.calls.single, 'check item-1');
      final comment = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const Key('work-comment')),
          matching: find.byType(EditableText),
        ),
      );
      expect(comment.focusNode.hasFocus, isFalse);
      expect(find.text(l10n.workClosed), findsWidgets);
    });

    testWidgets('Checked: a large stamp; the owner may show it [$lang]', (
      tester,
    ) async {
      final work = await _open(
        tester,
        lang,
        _item(WorkStatus.checked, owner: _me),
      );
      final stamp = tester.widget<BvStamp>(
        find.byKey(const Key('site-tag-checked')),
      );
      expect(stamp.large, isTrue);
      expect(
        stamp.label,
        contains(lang == 'ar' ? 'S. Al-Mansour' : 'S. AL-MANSOUR'),
      );
      await _tap(tester, 'work-show-on-profile');
      expect(work.calls.single, 'shown item-1 true');
    });

    testWidgets('Discussion shows who it was reassigned to [$lang]', (
      tester,
    ) async {
      await _open(
        tester,
        lang,
        _item(WorkStatus.open),
        events: [
          WorkEvent(
            id: 'e1',
            kind: WorkEventKind.reassigned,
            at: testNow,
            fromName: 'Rakesh Nair',
            toName: 'Eve Ali',
          ),
        ],
      );
      expect(
        find.text(l10n.workReassignedLine('Rakesh Nair', 'Eve Ali')),
        findsOneWidget,
      );
    });

    testWidgets('the comment pill: send appears with text [$lang]', (
      tester,
    ) async {
      final work = await _open(tester, lang, _item(WorkStatus.open));
      expect(find.byKey(const Key('work-comment-send')), findsNothing);
      // Review 11 B1: 44 high or more, filled, no outline anywhere.
      final pill = find.byKey(const Key('work-comment'));
      expect(tester.getSize(pill).height, inInclusiveRange(44, 48));
      final box = tester.widget<Container>(pill).decoration! as BoxDecoration;
      expect(box.color, BvColors.surfaceSubtle);
      expect(box.border, isNull);
      final field = tester.widget<TextField>(
        find.descendant(of: pill, matching: find.byType(TextField)),
      );
      expect(field.decoration!.enabledBorder, InputBorder.none);
      expect(field.decoration!.focusedBorder, InputBorder.none);
      // Side padding is the pill's own 16; none from the theme.
      expect(
        field.decoration!.contentPadding,
        const EdgeInsetsDirectional.symmetric(vertical: BvSpace.s8),
      );
      await _type(tester, 'work-comment', 'On it.');
      await _tap(tester, 'work-comment-send');
      expect(work.calls.single, 'comment item-1 On it.');
    });

    testWidgets('RE2: everything hidden until switched on [$lang]', (
      tester,
    ) async {
      final work = FakeWorkRepository()
        ..delivered.add(
          DeliveredWork(
            id: 'w1',
            title: 'Clash report, level 2',
            projectName: 'Kuwait City Tower',
            checkedByName: 'Omar Haddad',
            checkedAt: testNow,
            shown: false,
          ),
        );
      await pumpApp(tester, language: lang, work: work);
      _router(tester).push('/profile/delivered');
      await tester.pumpAndSettle();
      expect(find.byType(DeliveredScreen), findsOneWidget);
      expect(find.byKey(const Key('delivered-hidden-w1')), findsOneWidget);
      await _tap(tester, 'delivered-w1');
      expect(work.calls.single, 'shown w1 true');
      expect(find.byKey(const Key('delivered-shown-w1')), findsOneWidget);
    });

    testWidgets('across a block: Checked, without the name [$lang]', (
      tester,
    ) async {
      // The server leaves the name out (review 11 A5).
      final hidden = DeliveredWork(
        id: 'w1',
        title: 'Sleeves at grid C7',
        projectName: 'Kuwait City Tower',
        checkedAt: testNow,
      );
      final work = FakeWorkRepository()
        ..delivered.add(hidden)
        ..shownBy['p-omar'] = [hidden];
      await pumpApp(tester, language: lang, work: work);
      _router(tester).push('/profile/delivered');
      await tester.pumpAndSettle();
      expect(find.textContaining(l10n.deliveredCheckedOn('')), findsOneWidget);

      _router(tester).push('/people/p-omar/work/w1');
      await tester.pumpAndSettle();
      expect(find.text(l10n.deliveredCheckedRowNoName), findsOneWidget);
      expect(find.text(l10n.deliveredCheckedRow), findsNothing);
    });

    testWidgets('RE1: only the allowed facts, and why [$lang]', (tester) async {
      final work = FakeWorkRepository()
        ..shownBy['p-omar'] = [
          DeliveredWork(
            id: 'w1',
            title: 'Sleeves at grid C7',
            place: 'Level 2 · Grid C7',
            projectName: 'Kuwait City Tower',
            checkedByName: 'Sara Ali',
            checkedAt: testNow,
          ),
        ];
      await pumpApp(tester, language: lang, work: work);
      _router(tester).push('/people/p-omar/work/w1');
      await tester.pumpAndSettle();
      expect(find.byType(DeliveredPublicScreen), findsOneWidget);
      expect(find.text('Sleeves at grid C7'), findsOneWidget);
      expect(find.text('Kuwait City Tower'), findsOneWidget);
      expect(find.byKey(const Key('delivered-stamp')), findsOneWidget);
      // The stamp hugs its label, never the full width.
      expect(
        tester.getSize(find.byKey(const Key('delivered-stamp'))).width,
        lessThan(
          tester.getSize(find.byKey(const Key('delivered-photo'))).width,
        ),
      );
      // No reference and no record: the Space stays private.
      expect(find.textContaining('KCT-'), findsNothing);
      expect(find.byKey(const Key('work-sign-off')), findsNothing);
    });
  }
}
