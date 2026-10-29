// Review 106 T2: inside a page every entry shows in full (no 3-line cut),
// and each can be folded. The head is the fold control · the title · the
// time; the lead's check: G1 an archived entry keeps its short card; G2 an
// untitled entry's head is fold · time, its words in the body in normal
// weight (folded, its first line in the head, one line); G3 the control
// shows only when folding hides something. The control is a 24 chevron
// at the head's start, ⌄ open and › folded (‹ in Arabic), with a 44 tap
// area. Folded: the head, then "3 lines hidden" at the start and the
// status icons at the end, still tappable. The chevron or the folded head
// opens it again; a tap on an open entry's text still edits it. The page's
// ⋯ has Collapse all · Expand all, for this page only. Folding is kept on
// the entry (notes.collapsed, migration 50). A search or a Filter opening
// a folded entry shows it open. In English and Arabic.
import 'package:buildvibes/core/design/bv_icons.dart';
import 'package:buildvibes/core/routing/app_routes.dart';
import 'package:buildvibes/data/models/note.dart';
import 'package:buildvibes/data/models/notebook_page.dart';
import 'package:buildvibes/data/models/post_page.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
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

const _pageId = FakeNotebookRepository.myNotesId;

final _now = NotebookSamples.now;

const _lines = [
  'Print A-501 Rev D',
  'Charge the laser meter',
  'Bring the snag list from last week',
  'Check the scaffold tags on levels 2 and 3',
  'Photo the cracked tile at the stair',
];

Note _walk({
  bool collapsed = false,
  String page = _pageId,
  String id = 'walk',
}) => Note(
  id: id,
  kind: NoteKind.text,
  title: 'Before the site walk',
  blocks: [
    for (final (i, t) in _lines.indexed) PageTodo('walk-$i', t, done: i < 2),
  ],
  body: 'Before the site walk',
  pinned: true,
  shares: [
    NoteShare(
      target: NoteShareTarget.space,
      at: DateTime(_now.year, _now.month, _now.day, 8, 45),
      name: 'KCT Tower',
    ),
  ],
  collapsed: collapsed,
  createdAt: DateTime(_now.year, _now.month, _now.day, 9, 15),
  pageId: page,
);

/// No title: its words are the body (G2).
Note _snags({bool collapsed = false}) => Note(
  id: 'snags',
  kind: NoteKind.text,
  blocks: const [
    PageText('snags-1', 'Snags, lobby'),
    PageText(
      'snags-2',
      'Cracked tile at the stair. Grout gap at the lift door, grey grout. '
          'Skirting loose at grid A3, needs fixing before handover on Sunday.',
    ),
  ],
  body: 'Snags, lobby',
  collapsed: collapsed,
  createdAt: DateTime(_now.year, _now.month, _now.day, 8),
  pageId: _pageId,
);

Future<FakeNotebookRepository> _open(
  WidgetTester tester,
  String lang,
  List<Note> notes, {
  List<NotebookPage>? pages,
  String? entry,
}) async {
  final repo = FakeNotebookRepository(notes: notes, pages: pages);
  await pumpApp(tester, language: lang, now: _now, notebook: repo);
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push(AppRoutes.notebookPage(_pageId, entry: entry));
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));

    group('T2 in full [$lang]', () {
      testWidgets('every line shows, wrapping; no 3-line cut', (tester) async {
        await _open(tester, lang, [_walk(), _snags()]);
        for (final t in _lines) {
          expect(find.text(t), findsOneWidget, reason: t);
        }
        final long = find.textContaining('Cracked tile at the stair');
        expect(long, findsOneWidget);
        expect(tester.widget<Text>(long).maxLines, isNull);
        expect(
          tester.getSize(long).height,
          greaterThan(tester.getSize(find.text(_lines.first)).height * 1.5),
        );
      });

      testWidgets('the head: a 24 chevron at the start with a 44 tap area, '
          'the title, the time', (tester) async {
        await _open(tester, lang, [_walk()]);
        final fold = _key('note-fold-walk');
        expect(tester.getSize(fold), const Size(44, 44));
        final chevron = tester.widget<Icon>(
          find.descendant(of: fold, matching: find.byType(Icon)),
        );
        expect(chevron.icon, BvIcons.caretDown);
        expect(chevron.size, 24);
        final title = tester.getRect(find.text('Before the site walk'));
        final at = tester.getRect(fold);
        if (lang == 'ar') {
          expect(at.left, greaterThanOrEqualTo(title.right));
        } else {
          expect(at.right, lessThanOrEqualTo(title.left));
        }
        expect(
          find.descendant(
            of: _key('note-head-walk'),
            matching: find.text('Before the site walk'),
          ),
          findsOneWidget,
        );
      });

      testWidgets('G2: an untitled entry\'s head is fold · time; its words '
          'are the body, in normal weight, all of them', (tester) async {
        await _open(tester, lang, [_snags()]);
        Finder inHead(Finder f) =>
            find.descendant(of: _key('note-head-snags'), matching: f);
        expect(inHead(find.text('Snags, lobby')), findsNothing);
        expect(inHead(find.text(l10n.notebookNote)), findsNothing);
        expect(_key('note-fold-snags'), findsOneWidget);
        final first = tester.widget<Text>(find.text('Snags, lobby'));
        final rest = tester.widget<Text>(
          find.textContaining('Cracked tile at the stair'),
        );
        expect(first.style!.fontWeight, rest.style!.fontWeight);
        expect(
          tester.getTopLeft(find.text('Snags, lobby')).dy,
          greaterThan(tester.getBottomLeft(_key('note-head-snags')).dy - 1),
        );
      });

      testWidgets('G2: the kind words don\'t come back, for any kind', (
        tester,
      ) async {
        await _open(tester, lang, [
          Note(
            id: 'todo',
            kind: NoteKind.todo,
            body: 'Order 40 more sleeves',
            createdAt: DateTime(_now.year, _now.month, _now.day, 7),
            pageId: _pageId,
          ),
          Note(
            id: 'check',
            kind: NoteKind.checklist,
            body: 'Before the walk',
            points: const [NotePoint('Gloves'), NotePoint('Helmet')],
            createdAt: DateTime(_now.year, _now.month, _now.day, 6),
            pageId: _pageId,
          ),
        ]);
        for (final (id, kind) in [
          ('todo', l10n.notebookTodo),
          ('check', l10n.daybookKindChecklist),
        ]) {
          expect(
            find.descendant(
              of: _key('note-head-$id'),
              matching: find.text(kind),
            ),
            findsNothing,
            reason: id,
          );
        }
        expect(find.text('Order 40 more sleeves'), findsOneWidget);
        expect(find.text('Before the walk'), findsOneWidget);
        expect(find.text('Helmet'), findsOneWidget);
      });

      testWidgets('G1: an archived entry keeps its short 3-line card, and no '
          'fold control', (tester) async {
        final repo = FakeNotebookRepository(
          notes: [_walk().copyWith(archivedAt: () => _now)],
        );
        await pumpApp(tester, language: lang, now: _now, notebook: repo);
        GoRouter.of(
          tester.element(find.byType(Navigator).first),
        ).push(AppRoutes.notebookArchived(_pageId));
        await tester.pumpAndSettle();
        expect(_key('note-walk'), findsOneWidget);
        for (final t in _lines.take(3)) {
          expect(find.text(t), findsOneWidget, reason: t);
        }
        for (final t in _lines.skip(3)) {
          expect(find.text(t), findsNothing, reason: t);
        }
        expect(_key('note-fold-walk'), findsNothing);
      });
    });

    group('G3 nothing to fold [$lang]', () {
      Note gate({bool collapsed = false}) => Note(
        id: 'gate',
        kind: NoteKind.text,
        blocks: const [PageText('gate-1', 'Gate 2')],
        body: 'Gate 2',
        collapsed: collapsed,
        createdAt: DateTime(_now.year, _now.month, _now.day, 7),
        pageId: _pageId,
      );
      Note titleOnly({bool collapsed = false}) => Note(
        id: 'pump',
        kind: NoteKind.text,
        title: 'Pump booked',
        blocks: const [],
        body: 'Pump booked',
        pinned: true,
        collapsed: collapsed,
        createdAt: DateTime(_now.year, _now.month, _now.day, 6),
        pageId: _pageId,
      );

      testWidgets('an untitled one-line entry and a title alone: no fold '
          'control', (tester) async {
        await _open(tester, lang, [gate(), titleOnly()]);
        expect(_key('note-fold-gate'), findsNothing);
        expect(_key('note-fold-pump'), findsNothing);
        expect(find.text('Gate 2'), findsOneWidget);
        expect(_key('note-status-pump'), findsOneWidget);
      });

      testWidgets('kept folded but hiding nothing: shown open, no empty row', (
        tester,
      ) async {
        await _open(tester, lang, [
          gate(collapsed: true),
          titleOnly(collapsed: true),
        ]);
        expect(_key('note-folded-gate'), findsNothing);
        expect(_key('note-folded-pump'), findsNothing);
        expect(find.text('Gate 2'), findsOneWidget);
        expect(find.text(l10n.notebookLinesHidden(0)), findsNothing);
        expect(_key('note-status-pump'), findsOneWidget);
      });
    });

    group('T2 folding [$lang]', () {
      testWidgets('the chevron folds it: the head, "5 lines hidden" and its '
          'status icons, still tappable; kept on the entry', (tester) async {
        final repo = await _open(tester, lang, [_walk()]);
        await _tap(tester, _key('note-fold-walk'));
        expect(repo.calls, contains('collapse:walk:true'));
        expect(_key('note-folded-walk'), findsOneWidget);
        expect(find.text(l10n.notebookLinesHidden(5)), findsOneWidget);
        for (final t in _lines) {
          expect(find.text(t), findsNothing, reason: t);
        }
        final chevron = tester.widget<Icon>(
          find.descendant(
            of: _key('note-fold-walk'),
            matching: find.byType(Icon),
          ),
        );
        expect(chevron.icon, BvIcons.caretForward);
        expect(chevron.icon!.matchTextDirection, isTrue);
        // The words at the start, the icons at the end, on one line.
        final hidden = tester.getRect(find.text(l10n.notebookLinesHidden(5)));
        final icons = tester.getRect(_key('note-status-walk'));
        expect(icons.center.dy, closeTo(hidden.center.dy, icons.height / 2));
        if (lang == 'ar') {
          expect(icons.right, lessThanOrEqualTo(hidden.left));
        } else {
          expect(icons.left, greaterThanOrEqualTo(hidden.right));
        }
        await _tap(tester, _key('note-status-walk-space'));
        expect(_key('note-status-card'), findsOneWidget);
      });

      testWidgets('the chevron, or the folded head, opens it again', (
        tester,
      ) async {
        final repo = await _open(tester, lang, [_walk(collapsed: true)]);
        expect(_key('note-folded-walk'), findsOneWidget);
        await _tap(tester, _key('note-fold-walk'));
        expect(repo.calls, contains('collapse:walk:false'));
        expect(find.text(_lines.last), findsOneWidget);
        await _tap(tester, _key('note-fold-walk'));
        expect(_key('note-folded-walk'), findsOneWidget);
        await _tap(tester, find.text('Before the site walk'));
        expect(_key('note-folded-walk'), findsNothing);
        expect(find.text(_lines.last), findsOneWidget);
        // Opening it is not editing it.
        expect(_key('note-tools'), findsNothing);
      });

      testWidgets('G2: folded, an untitled entry\'s head shows its first '
          'line in normal weight, on one line; the rest is counted', (
        tester,
      ) async {
        await _open(tester, lang, [_snags(collapsed: true)]);
        expect(_key('note-folded-snags'), findsOneWidget);
        final first = find.descendant(
          of: _key('note-head-snags'),
          matching: find.text('Snags, lobby'),
        );
        expect(first, findsOneWidget);
        final text = tester.widget<Text>(first);
        expect(text.maxLines, 1);
        expect(text.overflow, TextOverflow.ellipsis);
        expect(text.style!.fontWeight, isNot(FontWeight.w700));
        expect(find.text(l10n.notebookLinesHidden(1)), findsOneWidget);
        expect(find.textContaining('Cracked tile'), findsNothing);
      });

      testWidgets('a tap on an open entry\'s text still edits it', (
        tester,
      ) async {
        await _open(tester, lang, [_snags()]);
        await _tap(tester, find.textContaining('Cracked tile at the stair'));
        expect(_key('note-tools'), findsOneWidget);
      });

      testWidgets('the page\'s ⋯: Collapse all, then Expand all, this page\'s '
          'entries only', (tester) async {
        final other = NotebookPage(
          id: 'page-other',
          title: 'Snags',
          createdAt: DateTime(2026, 10, 1),
          lastActivityAt: DateTime(2026, 10, 1),
        );
        final repo = await _open(
          tester,
          lang,
          [_walk(), _snags(), _walk(page: other.id, id: 'elsewhere')],
          pages: [FakeNotebookRepository.myNotes(), other],
        );
        await _tap(tester, _key('page-more'));
        await _tap(tester, _key('page-menu-collapse'));
        expect(repo.calls, contains('collapse:walk,snags:true'));
        expect(_key('note-folded-walk'), findsOneWidget);
        expect(_key('note-folded-snags'), findsOneWidget);
        expect(repo.kept['elsewhere']!.collapsed, isFalse);
        await _tap(tester, _key('page-more'));
        await _tap(tester, _key('page-menu-expand'));
        expect(repo.calls, contains('collapse:walk,snags:false'));
        expect(_key('note-folded-walk'), findsNothing);
        expect(_key('note-folded-snags'), findsNothing);
        expect(
          find.text(l10n.notebookCollapseAll),
          findsNothing,
          reason: 'the sheet closed',
        );
      });

      testWidgets('a search or a Filter opening a folded entry shows it open', (
        tester,
      ) async {
        final repo = await _open(tester, lang, [
          _walk(collapsed: true),
          _snags(collapsed: true),
        ], entry: 'walk');
        expect(_key('note-folded-walk'), findsNothing);
        expect(find.text(_lines.last), findsOneWidget);
        // The other stays folded, and nothing is written.
        expect(_key('note-folded-snags'), findsOneWidget);
        expect(repo.calls.where((c) => c.startsWith('collapse')), isEmpty);
      });

      testWidgets('a screen reader hears the control', (tester) async {
        final semantics = tester.ensureSemantics();
        await _open(tester, lang, [_walk()]);
        expect(
          tester.getSemantics(_key('note-fold-walk')).label,
          l10n.notebookFoldEntry,
        );
        await _tap(tester, _key('note-fold-walk'));
        expect(
          tester.getSemantics(_key('note-fold-walk')).label,
          l10n.notebookUnfoldEntry,
        );
        semantics.dispose();
      });
    });
  }
}
