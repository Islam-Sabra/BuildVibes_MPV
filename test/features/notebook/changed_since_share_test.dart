// Review 106 T5: a shared copy never changes by itself. A share icon whose
// last share is older than the entry's last change (its title, words,
// lines, photos or files; notes.content_changed_at, migration 51) gets a
// small accent dot at its top end; each kind its own; it goes when that
// kind is shared again. Ticking a to-do, pinning, folding and moving don't
// count. The card lists every share, an older one with "Older version ·
// changed at {time}", and Share again sends the entry as it is now
// through the same step; the old share stays in the log. In English and
// Arabic.
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/data/models/note.dart';
import 'package:buildvibes/data/models/post_page.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/work/daybook_words.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/notebook_fakes.dart';
import '../../helpers/notebook_samples.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

const _page = '/notebook/pages/${FakeNotebookRepository.myNotesId}';

final _now = NotebookSamples.now;
DateTime _at(int h, int m) => DateTime(_now.year, _now.month, _now.day, h, m);

Note _entry({DateTime? changed, List<NoteShare> shares = const []}) => Note(
  id: 'a',
  kind: NoteKind.text,
  title: 'Before the site walk',
  blocks: const [
    PageTodo('a-1', 'Print A-501 Rev D'),
    PageTodo('a-2', 'Bring the snag list'),
  ],
  body: 'Before the site walk',
  shares: shares,
  contentChangedAt: changed,
  createdAt: _at(7, 0),
  pageId: FakeNotebookRepository.myNotesId,
);

NoteShare _space(int h, int m, {String name = 'KCT Tower'}) =>
    NoteShare(target: NoteShareTarget.space, at: _at(h, m), name: name);

Future<FakeNotebookRepository> _open(
  WidgetTester tester,
  String lang,
  List<Note> notes,
) async {
  final repo = FakeNotebookRepository(notes: notes);
  final spaces = FakeSpaceRepository(now: _now)
    ..details['space-kct'] = const SpaceDetail(
      id: 'space-kct',
      name: 'KCT Tower',
      myPass: SpacePass.lead,
      iAmAdmin: true,
      myRights: MemberRights(createItems: true),
    )
    ..spaces.add(
      const SpaceSummary(
        id: 'space-kct',
        name: 'KCT Tower',
        pass: SpacePass.lead,
        isAdmin: true,
      ),
    );
  await pumpApp(
    tester,
    language: lang,
    now: _now,
    notebook: repo,
    spaces: spaces,
  );
  GoRouter.of(tester.element(find.byType(Navigator).first)).push(_page);
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    final words = DaybookWords(l10n, lang, use24: false);
    String clock(DateTime at) => words.time.clock(at);
    Finder inCard(String text) => find.descendant(
      of: _key('note-status-card'),
      matching: find.text(text),
    );

    group('T5 the dot [$lang]', () {
      testWidgets('a kind shared before the last change has a 9 accent dot '
          'with a ring at its top end; one shared after has none', (
        tester,
      ) async {
        await _open(tester, lang, [
          _entry(
            changed: _at(10, 12),
            shares: [
              _space(8, 45),
              NoteShare(target: NoteShareTarget.feed, at: _at(10, 30)),
              NoteShare(
                target: NoteShareTarget.message,
                at: _at(9, 0),
                name: 'Ahmed Saleh',
              ),
            ],
          ),
        ]);
        expect(_key('note-status-a-space-dot'), findsOneWidget);
        expect(_key('note-status-a-message-dot'), findsOneWidget);
        expect(_key('note-status-a-feed-dot'), findsNothing);
        final dot = tester.getRect(_key('note-status-a-space-dot'));
        expect(dot.size, const Size(9, 9));
        final disc = tester.widget<DecoratedBox>(
          _key('note-status-a-space-dot'),
        );
        final paint = disc.decoration as BoxDecoration;
        expect(paint.color, BvColors.iconAction);
        expect((paint.border! as Border).top.color, BvColors.surfaceElevated);
        final icon = tester.getRect(_key('note-status-a-space'));
        expect(dot.top, lessThanOrEqualTo(icon.top + 2));
        if (lang == 'ar') {
          expect(dot.left, lessThanOrEqualTo(icon.left + 2));
        } else {
          expect(dot.right, greaterThanOrEqualTo(icon.right - 2));
        }
      });

      testWidgets('it goes when that kind is shared again, after the change', (
        tester,
      ) async {
        await _open(tester, lang, [
          _entry(changed: _at(10, 12), shares: [_space(8, 45), _space(10, 40)]),
        ]);
        expect(_key('note-status-a-space-dot'), findsNothing);
      });

      testWidgets('an entry never changed after its shares has no dot', (
        tester,
      ) async {
        await _open(tester, lang, [
          _entry(shares: [_space(8, 45)]),
        ]);
        expect(_key('note-status-a-space-dot'), findsNothing);
      });
    });

    group('T5 what counts, on this phone [$lang]', () {
      testWidgets('ticking a to-do and pinning don\'t count', (tester) async {
        await _open(tester, lang, [
          _entry(changed: _at(7, 0), shares: [_space(8, 45)]),
        ]);
        await _tap(tester, _key('note-summary-tick-a-1'));
        expect(_key('note-status-a-space-dot'), findsNothing);
        await tester.timedDrag(
          _key('note-a'),
          Offset(lang == 'ar' ? -160 : 160, 0),
          const Duration(milliseconds: 300),
        );
        await tester.pumpAndSettle();
        await _tap(tester, _key('swipe-pin-a'));
        expect(_key('note-status-a-space-dot'), findsNothing);
      });

      testWidgets('an edit counts: the dot shows once it is saved', (
        tester,
      ) async {
        await _open(tester, lang, [
          _entry(changed: _at(7, 0), shares: [_space(8, 45)]),
        ]);
        await _tap(tester, find.text('Before the site walk'));
        await tester.enterText(
          _key('note-title'),
          'Before the site walk, level 3',
        );
        await tester.pumpAndSettle();
        await _tap(tester, _key('writing-post'));
        expect(_key('note-status-a-space-dot'), findsOneWidget);
      });
    });

    group('T5 the card [$lang]', () {
      testWidgets('every share, an older one "Older version · changed at '
          '{time}"; Share again opens the same step', (tester) async {
        await _open(tester, lang, [
          _entry(
            changed: _at(10, 12),
            shares: [
              _space(8, 45),
              _space(9, 2, name: 'NBKCH Site team'),
            ],
          ),
        ]);
        await _tap(tester, _key('note-status-a-space'));
        expect(inCard(l10n.notebookStatusTitleSpace), findsOneWidget);
        expect(
          inCard(l10n.notebookOlderVersion(clock(_at(10, 12)))),
          findsNWidgets(2),
        );
        final older = tester.widget<Text>(
          inCard(l10n.notebookOlderVersion(clock(_at(10, 12)))).first,
        );
        expect(older.style!.color, BvColors.textAction);
        await _tap(tester, _key('note-status-share-again'));
        expect(_key('note-status-card'), findsNothing);
        // The Space step: the Spaces to share to.
        expect(_key('share-space-space-kct'), findsOneWidget);
      });

      testWidgets('a share made after the change: no "Older version", no '
          'Share again', (tester) async {
        await _open(tester, lang, [
          _entry(changed: _at(8, 0), shares: [_space(8, 45)]),
        ]);
        await _tap(tester, _key('note-status-a-space'));
        expect(
          inCard(l10n.notebookOlderVersion(clock(_at(8, 0)))),
          findsNothing,
        );
        expect(_key('note-status-share-again'), findsNothing);
      });
    });
  }
}
