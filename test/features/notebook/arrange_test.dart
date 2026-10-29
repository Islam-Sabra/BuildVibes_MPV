// Review 102 N3: entries arranged by hand within their day. Hold and let
// go selects, as before. Hold and move without lifting: the card lifts and
// follows the finger, the others slide aside, a line shows where it lands;
// let go, it lands there, "Moved · Undo", and the day's order is saved
// (arrange_day). Only within its own day; not while entries are selected; a
// sideways drag stays a swipe and a drag with no hold a scroll. Screen
// readers have Move up and Move down; with Reduce motion nothing lifts or
// slides, but the move works. The hand order stays inside each day in both
// sorts. In English and Arabic.
import 'package:buildvibes/data/models/note.dart';
import 'package:buildvibes/data/models/notebook_page.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/notebook_fakes.dart';
import '../../helpers/notebook_page_samples.dart';
import '../../helpers/pump_app.dart';

const _path = '/notebook/pages/p-log';

Finder _entry(String id) => find.byKey(ValueKey(('swipe', id)));

Note _note(String id, DateTime at, {int? place}) => Note(
  id: id,
  kind: NoteKind.text,
  title: 'Entry $id',
  body: 'Entry $id',
  createdAt: at,
  pageId: 'p-log',
  dayPosition: place,
);

/// Today: t3 (11:00), t2 (9:00), t1 (8:00); yesterday: y2, y1.
FakeNotebookRepository _notebook({Map<String, int> places = const {}}) =>
    FakeNotebookRepository(
      pages: [
        FakeNotebookRepository.myNotes(),
        NotebookPage(
          id: 'p-log',
          title: 'Log',
          createdAt: DateTime(2026, 10, 1),
          lastActivityAt: DateTime(2026, 10, 15, 11),
        ),
      ],
      notes: [
        for (final (id, at) in [
          ('t3', DateTime(2026, 10, 15, 11)),
          ('t2', DateTime(2026, 10, 15, 9)),
          ('t1', DateTime(2026, 10, 15, 8)),
          ('y2', DateTime(2026, 10, 14, 15)),
          ('y1', DateTime(2026, 10, 14, 9)),
        ])
          _note(id, at, place: places[id]),
      ],
    );

Future<TestApp> _open(
  WidgetTester tester,
  String lang, {
  FakeNotebookRepository? notebook,
}) async {
  final app = await pumpApp(
    tester,
    language: lang,
    now: NotebookPageSamples.now,
    notebook: notebook ?? _notebook(),
  );
  GoRouter.of(tester.element(find.byType(Navigator).first)).push(_path);
  await tester.pumpAndSettle();
  return app;
}

/// The entries top to bottom, as on screen.
List<String> _order(WidgetTester tester) {
  final at = [
    for (final id in ['t1', 't2', 't3', 'y1', 'y2'])
      (id, tester.getTopLeft(_entry(id)).dy),
  ]..sort((a, b) => a.$2.compareTo(b.$2));
  return [for (final (id, _) in at) id];
}

List<String> _arranged(TestApp app) => [
  for (final c in app.notebook.calls)
    if (c.startsWith('day-arrange:')) c,
];

/// Holds [id], then moves the finger by [dy] in steps, without lifting.
Future<TestGesture> _holdAndMove(
  WidgetTester tester,
  String id,
  double dy,
) async {
  final finger = await tester.startGesture(tester.getCenter(_entry(id)));
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
  const steps = 10;
  for (var i = 0; i < steps; i++) {
    await finger.moveBy(Offset(0, dy / steps));
    await tester.pump(const Duration(milliseconds: 16));
  }
  return finger;
}

/// From [id]'s middle to [to]'s, plus [past].
double _down(WidgetTester tester, String id, String to, {double past = 8}) =>
    tester.getCenter(_entry(to)).dy - tester.getCenter(_entry(id)).dy + past;

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));

    testWidgets('hold and let go selects, as before; nothing is arranged '
        '[$lang]', (tester) async {
      final app = await _open(tester, lang);
      await tester.longPress(_entry('t2'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('note-selected-t2')), findsOneWidget);
      expect(_arranged(app), isEmpty);
    });

    testWidgets('hold and move: it lifts, the others slide, a line shows; '
        'let go, it lands, the order is saved, Moved · Undo [$lang]', (
      tester,
    ) async {
      final app = await _open(tester, lang);
      expect(_order(tester), ['t3', 't2', 't1', 'y2', 'y1']);
      final t2Before = tester.getTopLeft(_entry('t2')).dy;
      final finger = await _holdAndMove(
        tester,
        't3',
        _down(tester, 't3', 't2'),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const Key('note-lifted')), findsOneWidget);
      expect(find.byKey(const Key('arrange-line')), findsOneWidget);
      // t2 slid up into t3's place.
      expect(tester.getTopLeft(_entry('t2')).dy, lessThan(t2Before));
      await finger.up();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('note-lifted')), findsNothing);
      expect(_order(tester), ['t2', 't3', 't1', 'y2', 'y1']);
      expect(_arranged(app), ['day-arrange:t2,t3,t1']);
      expect(find.text(l10n.notebookUndoMoved), findsOneWidget);
      // Not selected by the hold.
      expect(find.byKey(const Key('note-selected-t3')), findsNothing);

      await tester.tap(find.byKey(const Key('undo-bar-action')));
      await tester.pumpAndSettle();
      expect(_order(tester), ['t3', 't2', 't1', 'y2', 'y1']);
      expect(_arranged(app).last, 'day-arrange:t3,t2,t1');
    });

    testWidgets('only within its day: at its day\'s edge it stops [$lang]', (
      tester,
    ) async {
      final app = await _open(tester, lang);
      final finger = await _holdAndMove(
        tester,
        't2',
        _down(tester, 't2', 'y1', past: 40),
      );
      await finger.up();
      await tester.pumpAndSettle();
      // The last of today, never into yesterday.
      expect(_order(tester), ['t3', 't1', 't2', 'y2', 'y1']);
      expect(_arranged(app), ['day-arrange:t3,t1,t2']);
    });

    testWidgets('kept: opened again, the day is in the hand order [$lang]', (
      tester,
    ) async {
      await _open(
        tester,
        lang,
        notebook: _notebook(places: {'t2': 1, 't3': 2, 't1': 3}),
      );
      expect(_order(tester), ['t2', 't3', 't1', 'y2', 'y1']);
    });

    testWidgets('the hand order stays inside each day when oldest first '
        '[$lang]', (tester) async {
      await _open(
        tester,
        lang,
        notebook: _notebook(places: {'t2': 1, 't3': 2, 't1': 3}),
      );
      await tester.tap(find.byKey(const Key('page-filter')));
      await tester.pumpAndSettle();
      // Review 106 T3: the card's switch on Sort.
      await tester.tap(find.byKey(const Key('filter-mode')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sort-oldest')));
      await tester.pumpAndSettle();
      expect(_order(tester), ['y1', 'y2', 't2', 't3', 't1']);
    });

    testWidgets('not while entries are selected [$lang]', (tester) async {
      final app = await _open(tester, lang);
      await tester.longPress(_entry('y1'));
      await tester.pumpAndSettle();
      final finger = await _holdAndMove(
        tester,
        't3',
        _down(tester, 't3', 't2'),
      );
      expect(find.byKey(const Key('note-lifted')), findsNothing);
      await finger.up();
      await tester.pumpAndSettle();
      expect(_order(tester), ['t3', 't2', 't1', 'y2', 'y1']);
      expect(_arranged(app), isEmpty);
    });

    testWidgets('a sideways drag stays a swipe, a drag with no hold a '
        'scroll [$lang]', (tester) async {
      // The sample page: its entries are as tall as the swipe's own tests'
      // (a one-line entry's swipe has a 2-pixel overflow of its own, on
      // slice2-app already: not this review's).
      final app = await pumpApp(
        tester,
        language: lang,
        now: NotebookPageSamples.now,
        notebook: NotebookPageSamples(lang).repository(),
      );
      GoRouter.of(
        tester.element(find.byType(Navigator).first),
      ).push('/notebook/pages/${NotebookPageSamples.siteA}');
      await tester.pumpAndSettle();
      // As the swipe's own tests open it.
      await tester.timedDrag(
        _entry('entry-pour'),
        Offset(lang == 'ar' ? -160 : 160, 0),
        const Duration(milliseconds: 300),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('swipe-pin-entry-pour')), findsOneWidget);
      await tester.drag(_entry('entry-gate'), const Offset(0, 200));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('note-lifted')), findsNothing);
      expect(_arranged(app), isEmpty);
    });

    testWidgets('screen readers: Move up and Move down, within the day '
        '[$lang]', (tester) async {
      final semantics = tester.ensureSemantics();
      final app = await _open(tester, lang);
      SemanticsNode node(String id) => tester.getSemantics(
        find.descendant(of: _entry(id), matching: find.byKey(Key('note-$id'))),
      );
      List<String> actions(String id) => [
        for (final a
            in node(id).getSemanticsData().customSemanticsActionIds ??
                const <int>[])
          CustomSemanticsAction.getAction(a)!.label!,
      ];
      expect(actions('t3'), [l10n.notebookMoveDown]);
      expect(
        actions('t2'),
        unorderedEquals([l10n.notebookMoveUp, l10n.notebookMoveDown]),
      );
      expect(actions('t1'), [l10n.notebookMoveUp]);
      final up = node('t2')
          .getSemanticsData()
          .customSemanticsActionIds!
          .firstWhere(
            (a) =>
                CustomSemanticsAction.getAction(a)!.label ==
                l10n.notebookMoveUp,
          );
      node(
        't2',
      ).owner!.performAction(node('t2').id, SemanticsAction.customAction, up);
      await tester.pumpAndSettle();
      expect(_order(tester), ['t2', 't3', 't1', 'y2', 'y1']);
      expect(_arranged(app), ['day-arrange:t2,t3,t1']);
      semantics.dispose();
    });

    testWidgets('Reduce motion: nothing lifts or slides, the move works '
        '[$lang]', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final app = await _open(tester, lang);
      final t2Before = tester.getTopLeft(_entry('t2')).dy;
      final finger = await _holdAndMove(
        tester,
        't3',
        _down(tester, 't3', 't2'),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const Key('note-lifted')), findsNothing);
      expect(tester.getTopLeft(_entry('t2')).dy, t2Before);
      expect(find.byKey(const Key('arrange-line')), findsOneWidget);
      await finger.up();
      await tester.pumpAndSettle();
      expect(_order(tester), ['t2', 't3', 't1', 'y2', 'y1']);
      expect(_arranged(app), ['day-arrange:t2,t3,t1']);
    });
  }
}
