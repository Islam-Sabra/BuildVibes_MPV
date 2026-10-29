// Review 106 T3: the ☰ card has a switch with its word at the top: off
// "Filter", on "Sort"; it opens in the mode used last. Filter is SHOW
// (To-dos open · Photos · Files · Voice notes · Archived) · STATUS (Pinned ·
// Reminder · Shared to the feed · Shared to a Space · Sent in a message) ·
// IN; one choice in each section, SHOW and STATUS together, the chosen one
// tapped again clears it; each choice on is its own chip with ✕. STATUS is
// read from the entries and shares the phone keeps (no server change).
// Sort inside a page: Newest · Oldest · Name A–Z · Type · Status (grouped:
// pinned, reminder, feed, Space, message, then none); the pages list keeps
// its four. In English and Arabic.
import 'dart:ui' show Tristate;

import 'package:buildvibes/core/routing/app_routes.dart';
import 'package:buildvibes/data/models/note.dart';
import 'package:buildvibes/data/models/notebook_page.dart';
import 'package:buildvibes/data/models/post_page.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/notebook_fakes.dart';
import '../../helpers/notebook_samples.dart';
import '../../helpers/pump_app.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

const _page = FakeNotebookRepository.myNotesId;
final _now = NotebookSamples.now;
DateTime _at(int hour) => DateTime(_now.year, _now.month, _now.day, hour);

Note _entry(
  String id,
  int hour, {
  bool pinned = false,
  DateTime? remindAt,
  List<NoteShare> shares = const [],
}) => Note(
  id: id,
  kind: NoteKind.text,
  title: 'Entry $id',
  blocks: [PageTodo('$id-1', 'Line $id')],
  body: 'Entry $id',
  pinned: pinned,
  remindAt: remindAt,
  shares: shares,
  createdAt: _at(hour),
  pageId: _page,
);

/// a: to a Space; b: to the feed; c: pinned; d: a reminder; e: none; f: sent
/// to a person and to a Space.
List<Note> _notes() => [
  _entry(
    'a',
    10,
    shares: [
      NoteShare(target: NoteShareTarget.space, at: _at(10), name: 'KCT'),
    ],
  ),
  _entry(
    'b',
    9,
    shares: [NoteShare(target: NoteShareTarget.feed, at: _at(9))],
  ),
  _entry('c', 8, pinned: true),
  _entry('d', 7, remindAt: _now.add(const Duration(days: 1))),
  _entry('e', 6),
  _entry(
    'f',
    5,
    shares: [
      NoteShare(target: NoteShareTarget.message, at: _at(5), name: 'Ahmed'),
      NoteShare(target: NoteShareTarget.space, at: _at(5), name: 'KCT'),
    ],
  ),
];

NotebookHit _hit(String id, int hour) =>
    NotebookHit(pageId: _page, noteId: id, title: 'Entry $id', at: _at(hour));

Future<FakeNotebookRepository> _open(
  WidgetTester tester,
  String lang, {
  String path = '/notebook',
  List<NotebookHit> hits = const [],
}) async {
  final repo = FakeNotebookRepository(notes: _notes())..hits = hits;
  await pumpApp(tester, language: lang, now: _now, notebook: repo);
  GoRouter.of(tester.element(find.byType(Navigator).first)).push(path);
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    const statuses = ['pinned', 'reminder', 'feed', 'space', 'message'];

    group('T3 the card [$lang]', () {
      testWidgets(
        'the switch reads "Filter": SHOW (no Reminders), STATUS, IN',
        (tester) async {
          await _open(tester, lang);
          await _tap(tester, _key('notebook-filter'));
          final mode = tester.widget<BvSwitch>(_key('filter-mode-switch'));
          expect(mode.value, isFalse);
          expect(
            find.descendant(
              of: _key('filter-mode'),
              matching: find.text(l10n.notebookFilter),
            ),
            findsOneWidget,
          );
          for (final k in [
            'todos_open',
            'photos',
            'files',
            'voice',
            'archived',
          ]) {
            expect(_key('filter-show-$k'), findsOneWidget, reason: k);
          }
          expect(_key('filter-show-reminders'), findsNothing);
          expect(find.text(l10n.notebookFilterStatus), findsOneWidget);
          for (final k in statuses) {
            expect(_key('filter-status-$k'), findsOneWidget, reason: k);
          }
          expect(_key('filter-in'), findsOneWidget);
          // STATUS between SHOW and IN.
          expect(
            tester.getTopLeft(_key('filter-status-pinned')).dy,
            greaterThan(tester.getTopLeft(_key('filter-show-archived')).dy),
          );
          expect(
            tester.getTopLeft(_key('filter-in')).dy,
            greaterThan(tester.getTopLeft(_key('filter-status-message')).dy),
          );
          expect(_key('sort-newest'), findsNothing);
        },
      );

      testWidgets('flipped, it reads "Sort" and lists the sorts; the card '
          'opens in the mode used last', (tester) async {
        await _open(tester, lang, path: AppRoutes.notebookPage(_page));
        await _tap(tester, _key('page-filter'));
        await _tap(tester, _key('filter-mode'));
        expect(
          find.descendant(
            of: _key('filter-mode'),
            matching: find.text(l10n.notebookFilterModeSort),
          ),
          findsOneWidget,
        );
        for (final k in ['newest', 'oldest', 'name', 'type', 'status']) {
          expect(_key('sort-$k'), findsOneWidget, reason: k);
        }
        expect(find.text(l10n.notebookSortTypeHint), findsOneWidget);
        expect(find.text(l10n.notebookSortStatusHint), findsOneWidget);
        expect(_key('filter-show-todos_open'), findsNothing);
        expect(_key('filter-status-pinned'), findsNothing);
        // Closed, then opened again: Sort.
        await tester.tapAt(
          tester.getBottomLeft(_key('line-popover-barrier')) +
              const Offset(4, -4),
        );
        await tester.pumpAndSettle();
        await _tap(tester, _key('page-filter'));
        expect(_key('sort-status'), findsOneWidget);
        expect(_key('filter-status-pinned'), findsNothing);
      });

      testWidgets('the switch is 44×26 and its row is the tap; a screen '
          'reader hears its word and whether it is on', (tester) async {
        final semantics = tester.ensureSemantics();
        await _open(tester, lang);
        await _tap(tester, _key('notebook-filter'));
        expect(
          tester.getSize(
            find.descendant(
              of: _key('filter-mode'),
              matching: find.byKey(const Key('filter-mode-switch')),
            ),
          ),
          const Size(44, 26),
        );
        final off = tester.getSemantics(_key('filter-mode'));
        expect(off.label, contains(l10n.notebookFilter));
        expect(off.flagsCollection.isToggled, Tristate.isFalse);
        // The word beside it flips it too.
        await _tap(
          tester,
          find.descendant(
            of: _key('filter-mode'),
            matching: find.text(l10n.notebookFilter),
          ),
        );
        final on = tester.getSemantics(_key('filter-mode'));
        expect(on.label, contains(l10n.notebookFilterModeSort));
        expect(on.flagsCollection.isToggled, Tristate.isTrue);
        semantics.dispose();
      });

      testWidgets('the pages list keeps its four sorts', (tester) async {
        await _open(tester, lang);
        await _tap(tester, _key('notebook-filter'));
        await _tap(tester, _key('filter-mode'));
        for (final k in ['activity', 'name', 'created', 'oldest_created']) {
          expect(_key('sort-$k'), findsOneWidget, reason: k);
        }
        expect(_key('sort-status'), findsNothing);
        expect(_key('sort-type'), findsNothing);
      });
    });

    group('T3 STATUS [$lang]', () {
      testWidgets('Shared to a Space alone: the entries with one, from the '
          'phone (no search); its chip has ✕', (tester) async {
        final repo = await _open(tester, lang);
        await _tap(tester, _key('notebook-filter'));
        await _tap(tester, _key('filter-status-space'));
        expect(repo.calls.where((c) => c.startsWith('search')), isEmpty);
        expect(_key('filter-hit-a'), findsOneWidget);
        expect(_key('filter-hit-f'), findsOneWidget);
        for (final id in ['b', 'c', 'd', 'e']) {
          expect(_key('filter-hit-$id'), findsNothing, reason: id);
        }
        expect(
          find.descendant(
            of: _key('filter-chip-status'),
            matching: find.text(l10n.notebookStatusTitleSpace),
          ),
          findsOneWidget,
        );
        expect(_key('filter-chip-kind'), findsNothing);
        await _tap(tester, _key('filter-clear-status'));
        expect(_key('filter-chip-status'), findsNothing);
        expect(_key('filter-results'), findsNothing);
      });

      testWidgets('each status finds its own', (tester) async {
        await _open(tester, lang);
        for (final (k, ids) in [
          ('pinned', ['c']),
          ('reminder', ['d']),
          ('feed', ['b']),
          ('message', ['f']),
        ]) {
          await _tap(tester, _key('notebook-filter'));
          await _tap(tester, _key('filter-status-$k'));
          for (final id in ['a', 'b', 'c', 'd', 'e', 'f']) {
            expect(
              _key('filter-hit-$id'),
              ids.contains(id) ? findsOneWidget : findsNothing,
              reason: '$k $id',
            );
          }
        }
      });

      testWidgets('SHOW and STATUS together: open to-dos that went to a '
          'Space; two chips; the chosen one tapped again clears it', (
        tester,
      ) async {
        final repo = await _open(
          tester,
          lang,
          hits: [_hit('a', 10), _hit('b', 9), _hit('f', 5)],
        );
        await _tap(tester, _key('notebook-filter'));
        await _tap(tester, _key('filter-show-todos_open'));
        await _tap(tester, _key('notebook-filter'));
        await _tap(tester, _key('filter-status-space'));
        expect(repo.calls, contains('search::todos_open:'));
        expect(_key('filter-hit-a'), findsOneWidget);
        expect(_key('filter-hit-f'), findsOneWidget);
        expect(_key('filter-hit-b'), findsNothing);
        expect(_key('filter-chip-kind'), findsOneWidget);
        expect(_key('filter-chip-status'), findsOneWidget);
        // Both chosen in the card; Shared to a Space again: off.
        await _tap(tester, _key('notebook-filter'));
        await _tap(tester, _key('filter-status-space'));
        expect(_key('filter-chip-status'), findsNothing);
        expect(_key('filter-chip-kind'), findsOneWidget);
        expect(_key('filter-hit-b'), findsOneWidget);
        // To-dos open again: the Filter is off.
        await _tap(tester, _key('notebook-filter'));
        await _tap(tester, _key('filter-show-todos_open'));
        expect(_key('filter-chip-kind'), findsNothing);
        expect(_key('filter-results'), findsNothing);
      });

      testWidgets('one choice in each section: another status takes the '
          'place of the first', (tester) async {
        await _open(tester, lang);
        await _tap(tester, _key('notebook-filter'));
        await _tap(tester, _key('filter-status-space'));
        await _tap(tester, _key('notebook-filter'));
        await _tap(tester, _key('filter-status-feed'));
        expect(
          find.descendant(
            of: _key('filter-chip-status'),
            matching: find.text(l10n.notebookStatusTitleFeed),
          ),
          findsOneWidget,
        );
        expect(_key('filter-hit-b'), findsOneWidget);
        expect(_key('filter-hit-a'), findsNothing);
      });

      testWidgets('inside a page, STATUS starts with that page; a hit opens '
          'its entry', (tester) async {
        await _open(tester, lang, path: AppRoutes.notebookPage(_page));
        await _tap(tester, _key('page-filter'));
        await _tap(tester, _key('filter-status-reminder'));
        expect(_key('filter-hit-d'), findsOneWidget);
        await _tap(tester, _key('filter-hit-d'));
        expect(_key('filter-chip-status'), findsNothing);
        expect(_key('note-d'), findsOneWidget);
      });

      testWidgets('Search keeps the status that is on', (tester) async {
        final repo = await _open(
          tester,
          lang,
          hits: [_hit('a', 10), _hit('b', 9)],
        );
        await _tap(tester, _key('notebook-filter'));
        await _tap(tester, _key('filter-status-feed'));
        await _tap(tester, _key('notebook-search'));
        await tester.enterText(find.byType(TextField), 'entry');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
        expect(repo.calls, contains('search:entry'));
        expect(_key('notebook-hit-b'), findsOneWidget);
        expect(_key('notebook-hit-a'), findsNothing);
      });
    });

    group('T3 the Status sort [$lang]', () {
      testWidgets('grouped: pinned on top, then reminder, feed, Space, '
          'message, then no status', (tester) async {
        await _open(tester, lang, path: AppRoutes.notebookPage(_page));
        await _tap(tester, _key('page-filter'));
        await _tap(tester, _key('filter-mode'));
        await _tap(tester, _key('sort-status'));
        expect(
          find.descendant(
            of: _key('sort-chip'),
            matching: find.text(l10n.notebookSortStatus),
          ),
          findsOneWidget,
        );
        // The rows in the page's order, as built.
        List<String> rows() => [
          for (final e
              in find
                  .byWidgetPredicate(
                    (w) =>
                        w.key is ValueKey<String> &&
                        RegExp(
                          r'^(status-label-\w+|note-[a-f])$',
                        ).hasMatch((w.key! as ValueKey<String>).value),
                  )
                  .evaluate())
            (e.widget.key! as ValueKey<String>).value,
        ];
        expect(
          rows().take(9),
          [
            'note-c',
            'status-label-reminder',
            'note-d',
            'status-label-feed',
            'note-b',
            'status-label-space',
            'note-a',
            // f went to a Space before it went to a person: under Space.
            'note-f',
          ].take(9),
        );
        expect(rows(), isNot(contains('status-label-message')));
        expect(rows(), isNot(contains('status-label-pinned')));
        expect(
          find.descendant(
            of: _key('status-label-reminder'),
            matching: find.text(l10n.notebookStatusTitleReminder),
          ),
          findsOneWidget,
        );
        await tester.drag(
          find.byType(Scrollable).first,
          const Offset(0, -2000),
        );
        await tester.pumpAndSettle();
        final end = rows();
        expect(
          end.indexOf('status-label-none'),
          allOf(isNonNegative, lessThan(end.indexOf('note-e'))),
        );
        expect(
          find.descendant(
            of: _key('status-label-none'),
            matching: find.text(l10n.notebookStatusNone),
          ),
          findsOneWidget,
        );
      });
    });
  }
}
