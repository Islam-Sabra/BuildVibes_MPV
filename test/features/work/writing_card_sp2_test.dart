// Review 105 Part 3 (SP2 2667:38511, AR 2667:38891): writing in the Space.
// The kinds are one choice that scrolls sideways (Note · Work item ·
// Checklist · Announcement · Scheduled · Walk), Work item chosen first. Title,
// then details. For · Place · Due · Team are rows that open pickers, only
// those the kind uses (a Note has no For or Due); For is Give to's picker,
// one person for a work item; Team says "Whole Space" until one is chosen.
// The bar is + · camera · attach, then Send, with no mic (ruling Q4). In
// English and Arabic.
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/work/daybook_draft.dart';
import 'package:buildvibes/features/work/daybook_writing.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_give_to_picker.dart';
import 'package:buildvibes/shared/widgets/bv_writing_rows.dart';
import 'package:buildvibes/shared/widgets/bv_writing_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<TestApp> _write(
  WidgetTester tester,
  String lang, {
  PickedDue? due,
}) async {
  final s = DaybookSamples(lang);
  final app = await pumpApp(
    tester,
    language: lang,
    auth: FakeAuthRepository(
      userId: DaybookSamples.islam,
      phone: '+96550000001',
    ),
    spaces: FakeSpaceRepository()
      ..details[DaybookSamples.space] = s.detail(pass: SpacePass.lead)
      ..spacePeople[DaybookSamples.space] = s.people(),
    daybook: FakeDaybookRepository()..posts[DaybookSamples.space] = [],
    now: DaybookSamples.thursday,
    overrides: [
      pickDueProvider.overrideWithValue(
        (context, {required now, day, at}) async => due,
      ),
    ],
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/${DaybookSamples.space}');
  await tester.pumpAndSettle();
  await _tap(tester, _key('post-bar-notepad'));
  return app;
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

List<Key> _rows(WidgetTester tester) => [
  for (final r in tester.widget<BvWritingRows>(find.byType(BvWritingRows)).rows)
    r.key,
];

BvWritingRow _row(WidgetTester tester, String key) => tester
    .widget<BvWritingRows>(find.byType(BvWritingRows))
    .rows
    .firstWhere((r) => r.key == Key(key));

Future<void> _kind(WidgetTester tester, DaybookKind kind) =>
    _tap(tester, _key('kind-chip-$kind'));

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    final s = DaybookSamples(lang);

    group('Part 3 the writing card [$lang]', () {
      testWidgets('the kinds are one choice, Note · Work item · Checklist · '
          'Announcement · Scheduled; Work item first chosen; it scrolls '
          'sideways', (tester) async {
        await _write(tester, lang);
        final chips = tester.widget<BvKindChips<Object>>(_key('writing-kinds'));
        expect(chips.choices.map((c) => c.value), const [
          DaybookKind.note,
          DaybookKind.workItem,
          DaybookKind.checklist,
          DaybookKind.announcement,
          DaybookKind.activity,
          // H3: Walk last, for who may post work.
          kindChipWalk,
        ]);
        expect(chips.selected, DaybookKind.workItem);
        expect(
          find.descendant(
            of: _key('writing-kinds'),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is SingleChildScrollView &&
                  w.scrollDirection == Axis.horizontal,
            ),
          ),
          findsOneWidget,
        );
        await _kind(tester, DaybookKind.checklist);
        expect(
          tester.widget<BvKindChips<Object>>(_key('writing-kinds')).selected,
          DaybookKind.checklist,
        );
        // The old kind chip and its menu are gone.
        expect(_key('writing-kind-chip'), findsNothing);
      });

      testWidgets('title, then details; the rows under them', (tester) async {
        await _write(tester, lang);
        final title = tester.getRect(_key('writing-title'));
        final body = tester.getRect(_key('writing-body'));
        final rows = tester.getRect(_key('writing-rows'));
        expect(title.top, lessThan(body.top));
        expect(body.bottom, lessThanOrEqualTo(rows.top));
        expect(find.text(l10n.daybookWritingDetails), findsOneWidget);
      });

      testWidgets('a work item: For · Place · Due · Team; Team is the whole '
          'Space; nothing chosen reads in grey', (tester) async {
        await _write(tester, lang);
        expect(_rows(tester), const [
          Key('writing-who'),
          Key('writing-place-row'),
          Key('writing-due-row'),
          Key('writing-to'),
        ]);
        expect(_row(tester, 'writing-to').value, l10n.daybookWholeSpace);
        expect(_row(tester, 'writing-who').empty, isTrue);
        expect(_row(tester, 'writing-due-row').empty, isTrue);
        for (final r in [l10n.daybookRowFor, l10n.daybookRowTeam]) {
          expect(find.text(r), findsOneWidget, reason: r);
        }
      });

      testWidgets('For opens Give to\'s picker; one person, and the row '
          'shows them', (tester) async {
        await _write(tester, lang);
        await _tap(tester, _key('writing-who'));
        expect(find.byType(BvGiveToPicker), findsOneWidget);
        await _tap(
          tester,
          find.descendant(
            of: find.byType(BvGiveToPicker),
            matching: find.text(s.omarName),
          ),
        );
        expect(find.byType(BvGiveToPicker), findsNothing);
        final who = _row(tester, 'writing-who');
        expect(who.value, s.omarName);
        expect(who.person, s.omarName);
        expect(who.empty, isFalse);
      });

      testWidgets('Place opens its field (free text until 105B); Due its '
          'picker', (tester) async {
        await _write(
          tester,
          lang,
          due: (day: DateTime(2026, 10, 16), at: null),
        );
        await _tap(tester, _key('writing-place-row'));
        expect(_key('writing-place'), findsOneWidget);
        await tester.enterText(
          find.descendant(
            of: _key('writing-place'),
            matching: find.byType(TextField),
          ),
          s.levelTwo,
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(_row(tester, 'writing-place-row').value, s.levelTwo);
        await _tap(tester, _key('writing-due-row'));
        expect(_row(tester, 'writing-due-row').empty, isFalse);
      });

      testWidgets('Team: one choice of the Space\'s Teams; a work item goes '
          'with its Team', (tester) async {
        final app = await _write(tester, lang);
        await _tap(tester, _key('writing-to'));
        await _tap(
          tester,
          find.descendant(
            of: _key('writing-to-menu'),
            matching: find.text(s.t('MEP', 'الكهروميكانيك')),
          ),
        );
        expect(_row(tester, 'writing-to').value, s.t('MEP', 'الكهروميكانيك'));
        await tester.enterText(_key('writing-title'), 'Sleeves at C7');
        await tester.pumpAndSettle();
        await _tap(tester, _key('writing-who'));
        await _tap(
          tester,
          find.descendant(
            of: find.byType(BvGiveToPicker),
            matching: find.text(s.omarName),
          ),
        );
        await _tap(tester, _key('writing-post'));
        final sent = app.daybook.created.single;
        expect(sent.teamId, 't-mep');
      });

      testWidgets('only the rows a kind uses: a Note has no For or Due', (
        tester,
      ) async {
        await _write(tester, lang);
        await _kind(tester, DaybookKind.note);
        expect(_rows(tester), const [Key('writing-to')]);
        await _kind(tester, DaybookKind.checklist);
        expect(_rows(tester), const [
          Key('writing-who'),
          Key('writing-due-row'),
          Key('writing-to'),
        ]);
        await _kind(tester, DaybookKind.announcement);
        expect(_rows(tester), const [Key('writing-to')]);
        await _kind(tester, DaybookKind.activity);
        expect(_rows(tester), const [
          Key('writing-who'),
          Key('writing-place-row'),
          Key('writing-when-row'),
          Key('writing-to'),
        ]);
      });

      testWidgets('the bar: + · camera · attach, then Send; no mic', (
        tester,
      ) async {
        await _write(tester, lang);
        final bar = tester.widget<BvWritingToolbar>(
          find.byType(BvWritingToolbar),
        );
        expect(bar.tools!.map((t) => t.key), const [
          Key('writing-add'),
          Key('writing-camera'),
          Key('writing-attach'),
        ]);
        expect(bar.tools!.any((t) => t.holds), isFalse, reason: 'no mic');
        double x(String k) => tester.getCenter(_key(k)).dx;
        if (lang == 'ar') {
          expect(x('writing-add'), greaterThan(x('writing-camera')));
          expect(x('writing-attach'), greaterThan(x('writing-post')));
        } else {
          expect(x('writing-add'), lessThan(x('writing-camera')));
          expect(x('writing-attach'), lessThan(x('writing-post')));
        }
      });

      testWidgets('+ holds what the rows don\'t: an announcement\'s pin; a '
          'work item with no template has nothing there', (tester) async {
        await _write(tester, lang);
        final bar = tester.widget<BvWritingToolbar>(
          find.byType(BvWritingToolbar),
        );
        expect(bar.tools!.first.onTap, isNull);
        await _kind(tester, DaybookKind.announcement);
        await _tap(tester, _key('writing-add'));
        expect(find.text(l10n.daybookPinUntil), findsOneWidget);
      });
    });
  }
}
