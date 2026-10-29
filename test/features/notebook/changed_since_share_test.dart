// Review 106 T5: a shared copy never changes by itself. A share icon whose
// last share is older than the entry gets a small accent dot at its top
// end; each kind its own; it goes when that kind is shared again. The card
// lists every share, an older one with "Older version · changed at
// {time}", and ends with Share again, which sends the entry as it is now
// through the same step; the old share stays in the log.
//
// The lead's check of r106b: K1, older is the server's one rule: a share
// keeps the entry's content_key from when it was made, and it is older
// exactly when that key differs from the entry's (no clocks; migration
// 51). The phone has no rule of its own; after a save it reads the entry
// again. Ticking a to-do and pinning don't change the key; an edit does;
// editing back to the shared words is the same again. K4, Share again ends
// every share card. K5, "changed at" names the day when it isn't today.
// In English and Arabic.
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

/// The entry, its content key [key] (the server's) and when it changed.
Note _entry({
  String key = 'k2',
  DateTime? changed,
  List<NoteShare> shares = const [],
}) => Note(
  id: 'a',
  kind: NoteKind.text,
  title: 'Before the site walk',
  blocks: const [
    PageTodo('a-1', 'Print A-501 Rev D'),
    PageTodo('a-2', 'Bring the snag list'),
  ],
  body: 'Before the site walk',
  shares: shares,
  contentKey: key,
  contentChangedAt: changed,
  createdAt: _at(7, 0),
  pageId: FakeNotebookRepository.myNotesId,
);

/// A share to a Space at [h]:[m] that kept the entry's key [key].
NoteShare _space(
  int h,
  int m, {
  String name = 'KCT Tower',
  String key = 'k2',
}) => NoteShare(
  target: NoteShareTarget.space,
  at: _at(h, m),
  name: name,
  contentKey: key,
);

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
              _space(8, 45, key: 'k1'),
              NoteShare(
                target: NoteShareTarget.feed,
                at: _at(10, 30),
                contentKey: 'k2',
              ),
              NoteShare(
                target: NoteShareTarget.message,
                at: _at(9, 0),
                name: 'Ahmed Saleh',
                contentKey: 'k1',
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
          _entry(
            changed: _at(10, 12),
            shares: [
              _space(8, 45, key: 'k1'),
              _space(10, 40),
            ],
          ),
        ]);
        expect(_key('note-status-a-space-dot'), findsNothing);
      });

      testWidgets('K1: no clocks: a share made before the change time but '
          'with the entry\'s key is not older', (tester) async {
        await _open(tester, lang, [
          _entry(changed: _at(10, 12), shares: [_space(8, 45)]),
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

    group('K1 what counts, as the server says [$lang]', () {
      testWidgets('ticking a to-do and pinning don\'t count', (tester) async {
        await _open(tester, lang, [
          _entry(
            key: FakeNotebookRepository.keyOf(_entry()),
            shares: [
              _space(8, 45, key: FakeNotebookRepository.keyOf(_entry())),
            ],
          ),
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

      testWidgets('an edit counts: the dot shows once it is saved and read '
          'again; editing back to the shared words takes it away', (
        tester,
      ) async {
        final shared = FakeNotebookRepository.keyOf(_entry());
        await _open(tester, lang, [
          _entry(
            key: shared,
            shares: [_space(8, 45, key: shared)],
          ),
        ]);
        Future<void> retitle(String from, String to) async {
          await _tap(tester, find.text(from));
          await tester.enterText(_key('note-title'), to);
          await tester.pumpAndSettle();
          await _tap(tester, _key('writing-post'));
        }

        await retitle('Before the site walk', 'Before the site walk, level 3');
        expect(_key('note-status-a-space-dot'), findsOneWidget);
        await retitle('Before the site walk, level 3', 'Before the site walk');
        expect(_key('note-status-a-space-dot'), findsNothing);
      });
    });

    group('T5 the card [$lang]', () {
      testWidgets('every share, an older one "Older version · changed at '
          '{time}"; Share again opens the same step', (tester) async {
        await _open(tester, lang, [
          _entry(
            changed: _at(10, 12),
            shares: [
              _space(8, 45, key: 'k1'),
              _space(9, 2, name: 'NBKCH Site team', key: 'k1'),
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

      testWidgets('K4: a share as the entry is now: no "Older version", '
          'and Share again still ends the card', (tester) async {
        await _open(tester, lang, [
          _entry(changed: _at(8, 0), shares: [_space(8, 45)]),
        ]);
        await _tap(tester, _key('note-status-a-space'));
        expect(
          inCard(l10n.notebookOlderVersion(clock(_at(8, 0)))),
          findsNothing,
        );
        expect(_key('note-status-share-again'), findsOneWidget);
        final again = tester.getRect(_key('note-status-share-again'));
        final last = tester.getRect(
          inCard(l10n.notebookStatusShareLine('KCT Tower', clock(_at(8, 45)))),
        );
        expect(again.top, greaterThanOrEqualTo(last.bottom));
      });

      testWidgets('K5: changed on another day: the day is named', (
        tester,
      ) async {
        final yesterday = _at(10, 12).subtract(const Duration(days: 1));
        final before = _at(16, 5).subtract(const Duration(days: 5));
        await _open(tester, lang, [
          _entry(
            changed: yesterday,
            shares: [_space(8, 45, key: 'k1')],
          ),
        ]);
        await _tap(tester, _key('note-status-a-space'));
        expect(
          inCard(
            l10n.notebookOlderVersionOn(
              l10n.notebookRowYesterday,
              clock(yesterday),
            ),
          ),
          findsOneWidget,
        );
        await tester.tapAt(const Offset(4, 4));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
        await _open(tester, lang, [
          _entry(
            changed: before,
            shares: [_space(8, 45, key: 'k1')],
          ),
        ]);
        await _tap(tester, _key('note-status-a-space'));
        expect(
          inCard(
            l10n.notebookOlderVersionOn(words.shortDate(before), clock(before)),
          ),
          findsOneWidget,
        );
      });
    });
  }
}
