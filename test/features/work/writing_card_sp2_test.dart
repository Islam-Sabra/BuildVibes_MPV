// Review 105 Part 3 (SP2 2667:38511, AR 2667:38891), as review 110 D
// (CP1–CP4) left it: writing in the Space. Title, then details. The lines
// a kind needs open pickers (a work item's For and Team); For is Give to's
// picker, one person for a work item; Team says "Whole Space" until one is
// chosen. Place and Due come from +, as chips. The bar is # · + · camera,
// then Send, with no mic (ruling Q4). In English and Arabic.
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/work/daybook_writing.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_chip.dart';
import 'package:buildvibes/shared/widgets/bv_give_to_picker.dart';
import 'package:buildvibes/shared/widgets/bv_writing_rows.dart';
import 'package:buildvibes/shared/widgets/bv_writing_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/composer_steps.dart';
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
  for (final r
      in tester.widget<BvWritingPills>(find.byType(BvWritingPills)).rows)
    r.key,
];

BvWritingRow _row(WidgetTester tester, String key) => tester
    .widget<BvWritingPills>(find.byType(BvWritingPills))
    .rows
    .firstWhere((r) => r.key == Key(key));

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    final s = DaybookSamples(lang);

    group('Part 3 the writing card [$lang]', () {
      testWidgets('title, then details; the lines under them', (tester) async {
        await _write(tester, lang);
        final title = tester.getRect(_key('writing-title'));
        final body = tester.getRect(_key('writing-body'));
        final rows = tester.getRect(_key('writing-pills'));
        expect(title.top, lessThan(body.top));
        expect(body.bottom, lessThanOrEqualTo(rows.top));
        expect(find.text(l10n.cpDetails), findsOneWidget);
      });

      testWidgets('a work item: For · Team; Team is the whole Space; nothing '
          'chosen reads in grey', (tester) async {
        await _write(tester, lang);
        expect(_rows(tester), const [Key('writing-who'), Key('writing-to')]);
        expect(_row(tester, 'writing-to').value, l10n.daybookWholeSpace);
        expect(_row(tester, 'writing-who').empty, isTrue);
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

      testWidgets('+ → Place opens the Place picker (review 105C); + → Due '
          'its picker; each shows as a chip', (tester) async {
        await _write(
          tester,
          lang,
          due: (day: DateTime(2026, 10, 16), at: null),
        );
        await addExtra(tester, 'place');
        expect(_key('place-picker'), findsOneWidget);
        await tester.enterText(
          find.descendant(
            of: _key('place-search'),
            matching: find.byType(TextField),
          ),
          s.levelTwo,
        );
        await tester.pumpAndSettle();
        await _tap(tester, _key('place-add'));
        expect(
          tester.widget<BvFilterChip>(_key('writing-place-chip')).label,
          s.levelTwo,
        );
        await addExtra(tester, 'due');
        expect(_key('writing-due-chip'), findsOneWidget);
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

      testWidgets('only the lines a kind uses: a Note has no For', (
        tester,
      ) async {
        await _write(tester, lang);
        await chooseKind(tester, 'note');
        expect(_rows(tester), const [Key('writing-to')]);
        await chooseKind(tester, 'announcement');
        expect(_rows(tester), const [Key('writing-to')]);
        await chooseKind(tester, 'activity');
        expect(_rows(tester), const [
          Key('writing-when-row'),
          Key('writing-to'),
        ]);
      });

      testWidgets('the bar: # · + · camera, then Send; no mic', (tester) async {
        await _write(tester, lang);
        final bar = tester.widget<BvWritingToolbar>(
          find.byType(BvWritingToolbar),
        );
        expect(bar.tools!.map((t) => t.key), const [
          Key('writing-kind'),
          Key('writing-add'),
          Key('writing-camera'),
        ]);
        expect(bar.tools!.any((t) => t.holds), isFalse, reason: 'no mic');
        double x(String k) => tester.getCenter(_key(k)).dx;
        if (lang == 'ar') {
          expect(x('writing-kind'), greaterThan(x('writing-add')));
          expect(x('writing-add'), greaterThan(x('writing-camera')));
          expect(x('writing-camera'), greaterThan(x('writing-post')));
        } else {
          expect(x('writing-kind'), lessThan(x('writing-add')));
          expect(x('writing-add'), lessThan(x('writing-camera')));
          expect(x('writing-camera'), lessThan(x('writing-post')));
        }
      });

      testWidgets('+ holds an announcement\'s pin; a work item has none', (
        tester,
      ) async {
        await _write(tester, lang);
        await _tap(tester, _key('writing-add'));
        expect(_key('composer-extra-pin'), findsNothing);
        await _tap(tester, _key('writing-add'));
        await chooseKind(tester, 'announcement');
        await _tap(tester, _key('writing-add'));
        expect(_key('composer-extra-pin'), findsOneWidget);
      });
    });
  }
}
