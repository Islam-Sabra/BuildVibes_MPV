// Review 112 (founder, 1 Nov): a work item is always for someone else; what
// is yours alone belongs in My notebook. The For picker has no "You" (F69's
// row goes); alone in a Space it says "Invite someone to give work items
// to." and Post stays off; a Duplicate of an item for yourself asks For
// again; the server's refusal says so in plain words. In English and
// Arabic.
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/models/work_item.dart';
import 'package:buildvibes/features/spaces/space_errors.dart';
import 'package:buildvibes/features/work/daybook_draft.dart';
import 'package:buildvibes/features/work/daybook_writing.dart' show ownerPeople;
import 'package:buildvibes/features/work/daybook_loop.dart' show DaybookLoop;
import 'package:buildvibes/features/work/work_outbox.dart'
    show DaybookRefusal, RefusalWhy, RefusedAction;
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_give_to_picker.dart';
import 'package:buildvibes/shared/widgets/bv_writing_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

/// The Space's daybook as Islam (Lead), the composer open on a work item.
Future<FakeDaybookRepository> _write(
  WidgetTester tester,
  String lang, {
  SpacePeople? people,
}) async {
  final s = DaybookSamples(lang);
  final fake = FakeDaybookRepository()..posts[DaybookSamples.space] = s.d1();
  await pumpApp(
    tester,
    language: lang,
    spaces: FakeSpaceRepository()
      ..details[DaybookSamples.space] = s.detail(pass: SpacePass.lead)
      ..spacePeople[DaybookSamples.space] = people ?? s.people(),
    daybook: fake,
    now: DaybookSamples.thursday,
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/${DaybookSamples.space}');
  await tester.pumpAndSettle();
  await _tap(tester, _key('post-bar-notepad'));
  await tester.enterText(
    _key('writing-title'),
    s.t('Fix the tile', 'إصلاح البلاط'),
  );
  await tester.pumpAndSettle();
  return fake;
}

/// Islam, a Lead, alone but for a Viewer (who can't own a work item).
SpacePeople _alone(DaybookSamples s) {
  SpaceMember member(String id, String first, String last, SpacePass pass) =>
      SpaceMember(
        person: SpacePerson(id: id, firstName: first, lastName: last),
        pass: pass,
        isAdmin: id == DaybookSamples.islam,
        confirmedAt: DateTime(2026, 9, 5),
      );
  return SpacePeople(
    members: [
      member(DaybookSamples.islam, 'Islam', 'Ahmed', SpacePass.lead),
      member(DaybookSamples.mona, 'Mona', 'Adel', SpacePass.viewer),
    ],
    teams: const [],
  );
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    final s = DaybookSamples(lang);

    group('Review 112: the For picker [$lang]', () {
      testWidgets('no You, and not me by name; a search for my name finds '
          'nobody', (tester) async {
        await _write(tester, lang);
        await _tap(tester, _key('writing-who'));
        final picker = find.byType(BvGiveToPicker);
        expect(_key('give-to-me'), findsNothing);
        expect(
          tester.widget<BvGiveToPicker>(picker).people.map((p) => p.id),
          isNot(contains(DaybookSamples.islam)),
        );
        expect(
          find.descendant(of: picker, matching: find.text(l10n.daybookYou)),
          findsNothing,
        );
        expect(
          find.descendant(of: picker, matching: find.text(s.omarName)),
          findsOneWidget,
        );
        await tester.enterText(
          find.descendant(
            of: _key('give-to-search'),
            matching: find.byType(TextField),
          ),
          s.islamName.split(' ').first,
        );
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: picker, matching: find.text(s.islamName)),
          findsNothing,
        );
      });

      testWidgets('alone in the Space: Post stays off, and the picker says '
          '"Invite someone to give work items to."', (tester) async {
        await _write(tester, lang, people: _alone(s));
        expect(
          tester.widget<BvWritingToolbar>(find.byType(BvWritingToolbar)).onPost,
          isNull,
        );
        await _tap(tester, _key('writing-who'));
        expect(_key('give-to-empty'), findsOneWidget);
        expect(find.text(l10n.workItemInviteSomeone), findsOneWidget);
        expect(_key('give-to-search'), findsNothing);
      });

      testWidgets('a refusal for yourself comes back as the draft, with its '
          'plain line', (tester) async {
        final fake = await _write(tester, lang);
        fake.refuseItemsWith = const SpaceException(
          SpaceFailure.badInput,
          'a work item is for someone else',
        );
        await _tap(tester, _key('writing-who'));
        await _tap(
          tester,
          find.descendant(
            of: find.byType(BvGiveToPicker),
            matching: find.text(s.omarName),
          ),
        );
        await _tap(tester, _key('writing-post'));
        await _tap(tester, _key('daybook-draft'));
        expect(find.text(l10n.workItemForSomeoneElse), findsOneWidget);
        expect(find.text(l10n.daybookCouldNotSend), findsNothing);
      });
    });

    test('the server\'s refusal in plain words [$lang]', () {
      const e = SpaceException(
        SpaceFailure.badInput,
        'a work item is for someone else',
      );
      expect(spaceErrorText(l10n, e), l10n.workItemForSomeoneElse);
      expect(RefusalWhy.of(e), RefusalWhy.forSomeoneElse);
      // Give to yourself, refused: the same sentence, on its own.
      expect(
        DaybookLoop.refusalText(
          l10n,
          const DaybookRefusal(
            action: RefusedAction.giveTo,
            spaceId: DaybookSamples.space,
            postId: 'post-trays',
            why: RefusalWhy.forSomeoneElse,
          ),
          const [],
        ),
        l10n.workItemForSomeoneElse,
      );
      expect(
        spaceErrorText(l10n, const SpaceException(SpaceFailure.badInput)),
        l10n.errorGeneric,
      );
    });
  }

  test('ownerPeople: Lead and Crew, never me, never a Viewer', () {
    final people = DaybookSamples('en').people();
    final ids = [
      for (final p in ownerPeople(people, me: DaybookSamples.islam)) p.id,
    ];
    expect(ids, isNot(contains(DaybookSamples.islam)));
    expect(ids, isNot(contains(DaybookSamples.mona)));
    expect(ids, contains(DaybookSamples.omar));
  });

  group('Duplicate', () {
    DaybookPost item(String owner) => DaybookPost(
      id: 'post-old',
      kind: DaybookPost.workItemKind,
      createdAt: DaybookSamples.thursday,
      title: 'Gate check',
      authorId: DaybookSamples.islam,
      item: DaybookItem(
        status: WorkStatus.open,
        ownerId: owner,
        ownerName: 'Name',
      ),
    );

    test('an old item for myself asks For again', () {
      final d = DaybookPostDraft.of(
        item(DaybookSamples.islam),
        id: 'post-new',
        me: DaybookSamples.islam,
      );
      expect(d.ownerId, isNull);
      expect(d.ownerName, isNull);
    });

    test('one for someone else keeps them', () {
      final d = DaybookPostDraft.of(
        item(DaybookSamples.omar),
        id: 'post-new',
        me: DaybookSamples.islam,
      );
      expect(d.ownerId, DaybookSamples.omar);
    });

    test('editing it (no new id) keeps its owner as it is', () {
      final d = DaybookPostDraft.of(
        item(DaybookSamples.islam),
        me: DaybookSamples.islam,
      );
      expect(d.ownerId, DaybookSamples.islam);
    });
  });
}
