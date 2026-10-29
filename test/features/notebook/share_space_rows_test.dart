// Review 104 N9: Share → Space uses the Space's own kinds, Note · Work
// item · Checklist, with the Space's words and icons; Note is the default
// and "Post" is gone. N10: "Team" and "For" are one row each that open a
// picker, never a chip row of members: Team lists the Space's Teams; For
// opens the Space's Give to picker (search; the chosen Team's people
// first, then the rest A–Z); a work item takes exactly one person (me by
// default), a checklist several ("Omar Haddad + 2"). It works with 120
// members. In English and Arabic.
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/work/daybook_draft.dart' show DaybookKind;
import 'package:buildvibes/features/work/daybook_writing.dart'
    show kindIcon, kindName;
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_chip.dart';
import 'package:buildvibes/shared/widgets/bv_give_to_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/daybook_samples.dart';
import '../../helpers/notebook_fakes.dart';
import '../../helpers/notebook_page_samples.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

const _siteA = '/notebook/pages/${NotebookPageSamples.siteA}';

/// A Space of 120 members: me, then Worker 1 … Worker 119 (a Viewer
/// every tenth), a Team of the first five.
SpacePeople _crowd() {
  SpaceMember member(String id, String first, String last, SpacePass pass) =>
      SpaceMember(
        person: SpacePerson(id: id, firstName: first, lastName: last),
        pass: pass,
        isAdmin: id == DaybookSamples.islam,
        confirmedAt: DateTime(2026, 9, 5),
      );
  return SpacePeople(
    members: [
      member(DaybookSamples.islam, 'Islam', 'Sabra', SpacePass.lead),
      for (var i = 1; i < 120; i++)
        member(
          'w-$i',
          'Worker',
          '$i',
          i % 10 == 0 ? SpacePass.viewer : SpacePass.crew,
        ),
    ],
    teams: [
      SpaceTeam(
        id: 't-five',
        name: 'Five',
        memberIds: {for (var i = 1; i <= 5; i++) 'w-$i'},
      ),
    ],
  );
}

Future<FakeNotebookRepository> _open(
  WidgetTester tester,
  String lang, {
  SpacePeople? people,
}) async {
  final repo = NotebookPageSamples(lang).repository();
  final d = DaybookSamples(lang);
  await pumpApp(
    tester,
    language: lang,
    now: NotebookPageSamples.now,
    notebook: repo,
    spaces: FakeSpaceRepository()
      ..spaces.add(
        SpaceSummary(
          id: DaybookSamples.space,
          name: d.spaceName,
          pass: SpacePass.lead,
          isAdmin: true,
        ),
      )
      ..details[DaybookSamples.space] = d.detail()
      ..spacePeople[DaybookSamples.space] = people ?? d.people(),
  );
  GoRouter.of(tester.element(find.byType(Navigator).first)).push(_siteA);
  await tester.pumpAndSettle();
  await tester.longPress(_key('note-entry-pour'));
  await tester.pumpAndSettle();
  // Review 106 T4: the held entry's Space icon.
  await _tap(tester, _key('note-status-entry-pour-space'));
  await _tap(tester, _key('share-space-${DaybookSamples.space}'));
  return repo;
}

/// The words a row shows.
String _row(WidgetTester tester, String key) => tester
    .widgetList<Text>(
      find.descendant(of: _key(key), matching: find.byType(Text)),
    )
    .map((t) => t.data ?? '')
    .join(' ');

/// The people the For picker lists, top to bottom.
List<String> _listed(WidgetTester tester) => [
  for (final p
      in tester.widget<BvGiveToPicker>(find.byType(BvGiveToPicker)).people)
    p.id,
];

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    final d = DaybookSamples(lang);

    group('N9 the Space\'s own kinds [$lang]', () {
      testWidgets('Note · Work item · Checklist with the Space\'s words and '
          'icons; Note by default; no "Post"', (tester) async {
        await _open(tester, lang);
        for (final (json, kind) in [
          ('note', DaybookKind.note),
          ('work_item', DaybookKind.workItem),
          ('checklist', DaybookKind.checklist),
        ]) {
          final chip = tester.widget<BvChip>(_key('share-kind-$json'));
          expect(chip.label, kindName(l10n, kind));
          expect(chip.icon, kindIcon(kind));
          expect(chip.selected, json == 'note');
        }
        // No other kind: the three chips are all there is.
        expect(find.byType(BvChip), findsNWidgets(3));
      });

      testWidgets('Send as it is goes as a Note', (tester) async {
        final repo = await _open(tester, lang);
        await _tap(tester, _key('share-send'));
        expect(
          repo.calls.where(
            (c) => c.startsWith(
              'share-space:entry-pour:${DaybookSamples.space}:note:',
            ),
          ),
          hasLength(1),
        );
      });
    });

    group('N10 Team and For are rows [$lang]', () {
      testWidgets('Team: one row, "Team: Whole Space ›"; it opens the '
          'Space\'s Teams', (tester) async {
        final repo = await _open(tester, lang);
        expect(_key('share-team-none'), findsNothing);
        expect(
          _row(tester, 'share-team'),
          l10n.notebookShareTeamRow(l10n.notebookShareWholeSpace),
        );
        await _tap(tester, _key('share-team'));
        expect(_key('share-team-none'), findsOneWidget);
        expect(_key('share-team-t-mep'), findsOneWidget);
        await _tap(tester, _key('share-team-t-site'));
        expect(_key('share-team-none'), findsNothing);
        expect(
          _row(tester, 'share-team'),
          l10n.notebookShareTeamRow(d.t('Site', 'الموقع')),
        );
        await _tap(tester, _key('share-send'));
        expect(repo.spaceShares.last['team'], 't-site');
      });

      testWidgets('a Note asks no For; a work item shows one For row, me by '
          'default, and no chip of any member', (tester) async {
        await _open(tester, lang);
        expect(_key('share-for'), findsNothing);
        await _tap(tester, _key('share-kind-work_item'));
        expect(_key('share-for'), findsOneWidget);
        expect(
          _row(tester, 'share-for'),
          l10n.notebookShareForRow(l10n.daybookYou),
        );
        expect(_key('share-for-${DaybookSamples.omar}'), findsNothing);
      });

      testWidgets('For opens the Give to picker: me first, the chosen '
          'Team\'s people, then the rest A–Z; no Viewer', (tester) async {
        await _open(tester, lang);
        await _tap(tester, _key('share-team'));
        await _tap(tester, _key('share-team-t-mep'));
        await _tap(tester, _key('share-kind-work_item'));
        await _tap(tester, _key('share-for'));
        expect(find.byType(BvGiveToPicker), findsOneWidget);
        final names = {
          for (final m in d.people().members) m.person.id: m.person.fullName,
        };
        final rest = [DaybookSamples.sara, DaybookSamples.lina]
          ..sort((a, b) => names[a]!.compareTo(names[b]!));
        final team = [DaybookSamples.omar, DaybookSamples.rakesh]
          ..sort((a, b) => names[a]!.compareTo(names[b]!));
        expect(_listed(tester), [DaybookSamples.islam, ...team, ...rest]);
        expect(_listed(tester), isNot(contains(DaybookSamples.mona)));
      });

      testWidgets('a work item takes exactly one person: a pick closes the '
          'picker and replaces who it is for', (tester) async {
        final repo = await _open(tester, lang);
        await _tap(tester, _key('share-kind-work_item'));
        await _tap(tester, _key('share-for'));
        await _tap(
          tester,
          find.descendant(
            of: find.byType(BvGiveToPicker),
            matching: find.text(d.omarName),
          ),
        );
        expect(find.byType(BvGiveToPicker), findsNothing);
        expect(_row(tester, 'share-for'), l10n.notebookShareForRow(d.omarName));
        await _tap(tester, _key('share-for'));
        // One choice: the picker marks the one owner, never several.
        expect(
          tester.widget<BvGiveToPicker>(find.byType(BvGiveToPicker)).chosenIds,
          isNull,
        );
        await _tap(
          tester,
          find.descendant(
            of: find.byType(BvGiveToPicker),
            matching: find.text(d.rakeshName),
          ),
        );
        await _tap(tester, _key('share-send'));
        expect(repo.spaceShares.last['owner'], DaybookSamples.rakesh);
        expect(repo.spaceShares.last['people'], isEmpty);
      });

      testWidgets('a checklist takes several: "You + 2"', (tester) async {
        final repo = await _open(tester, lang);
        await _tap(tester, _key('share-kind-checklist'));
        await _tap(tester, _key('share-for'));
        for (final name in [d.omarName, d.rakeshName]) {
          await _tap(
            tester,
            find.descendant(
              of: find.byType(BvGiveToPicker),
              matching: find.text(name),
            ),
          );
        }
        // The picker stays for more; Done closes it.
        expect(find.byType(BvGiveToPicker), findsOneWidget);
        await _tap(tester, _key('share-for-done'));
        expect(
          _row(tester, 'share-for'),
          l10n.notebookShareForRow(
            l10n.notebookShareForMore(l10n.daybookYou, 2),
          ),
        );
        await _tap(tester, _key('share-send'));
        expect(
          repo.spaceShares.last['people'],
          unorderedEquals([
            DaybookSamples.islam,
            DaybookSamples.omar,
            DaybookSamples.rakesh,
          ]),
        );
      });

      testWidgets('120 members: one For row; the picker searches; a work '
          'item still takes one', (tester) async {
        final repo = await _open(tester, lang, people: _crowd());
        await _tap(tester, _key('share-kind-work_item'));
        expect(_key('share-for'), findsOneWidget);
        expect(find.byType(BvChip), findsNWidgets(3)); // the three kinds
        await _tap(tester, _key('share-for'));
        // Viewers can't own a work item: 120 less 11 Viewers.
        expect(_listed(tester), hasLength(120 - 11));
        await tester.enterText(
          find.descendant(
            of: _key('give-to-search'),
            matching: find.byType(TextField),
          ),
          'Worker 117',
        );
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(BvGiveToPicker),
            matching: find.byWidgetPredicate(
              (w) => w is Text && w.data == 'Worker 117',
            ),
          ),
          findsOneWidget,
        );
        await _tap(
          tester,
          find.descendant(
            of: find.byType(BvGiveToPicker),
            matching: find.byWidgetPredicate(
              (w) => w is Text && w.data == 'Worker 117',
            ),
          ),
        );
        await _tap(tester, _key('share-send'));
        expect(repo.spaceShares.last['owner'], 'w-117');
      });
    });
  }
}
