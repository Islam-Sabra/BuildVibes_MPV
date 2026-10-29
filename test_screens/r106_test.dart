// Review 106: the shots it adds, in English and Arabic at 390 × 844 in the
// app's fonts, after the frames NS1–NS4. NS1: an entry's status row, the
// Space icon's card open with its two Spaces. NS2: a page's entries in
// full, one folded ("1 line hidden" with its status icons). NS3: My
// notebook's card in Filter mode, To-dos open and Shared to a Space on.
// NS4: the card in Sort mode inside a page. NS6 (review 106 T5): the
// entry changed after one of its Space shares, so the Space icon has its
// dot, and its card says "Older version · changed at …", then Share
// again. Run:
//   flutter test test_screens/r106_test.dart --update-goldens
import 'package:buildvibes/data/models/note.dart';
import 'package:buildvibes/features/notebook/note_filter.dart'
    show filterModeKey;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../test/helpers/notebook_fakes.dart';
import '../test/helpers/notebook_page_samples.dart';
import '../test/helpers/pump_app.dart';
import 'shot.dart';

/// Saves the app as it is now to `docs/screens/r106/<name>_<lang>.png`.
Future<void> _snap(WidgetTester tester, String name, String lang) async {
  debugDisableShadows = false;
  try {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byType(MaterialApp).first,
      matchesGoldenFile('../docs/screens/r106/${name}_$lang.png'),
    );
  } finally {
    debugDisableShadows = true;
  }
}

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(_key(key));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  for (final lang in ['en', 'ar']) {
    final s = NotebookPageSamples(lang);
    final day = NotebookPageSamples.now;
    DateTime at(int h, int m) => DateTime(day.year, day.month, day.day, h, m);

    /// Site A, its first entry pinned, with a reminder, shared to the feed
    /// and to two Spaces; its second pinned and shared to the feed.
    /// With [changed], the entry changed at 09:20 (its content key k2), after
    /// its 08:45 Space share (k1): that share is older (NS6).
    FakeNotebookRepository repo({bool fold = false, bool changed = false}) {
      final r = s.repository();
      String? kept(String key) => changed ? key : null;
      r.kept['entry-pour'] = r.kept['entry-pour']!.copyWith(
        pinned: true,
        remindAt: () => day.add(const Duration(hours: 6)),
        contentKey: () => kept('k2'),
        contentChangedAt: () => changed ? at(9, 20) : null,
        shares: [
          NoteShare(
            target: NoteShareTarget.feed,
            at: at(8, 30),
            contentKey: kept('k2'),
          ),
          NoteShare(
            target: NoteShareTarget.space,
            at: at(8, 45),
            name: s.t('Kuwait City Tower', 'برج مدينة الكويت'),
            contentKey: kept('k1'),
          ),
          NoteShare(
            target: NoteShareTarget.space,
            at: at(9, 2),
            name: s.t('NBKCH Site team', 'فريق موقع NBKCH'),
            contentKey: kept('k1'),
          ),
        ],
      );
      r.kept['entry-gate'] = r.kept['entry-gate']!.copyWith(
        pinned: true,
        collapsed: fold,
        shares: [NoteShare(target: NoteShareTarget.feed, at: at(9, 10))],
      );
      return r;
    }

    Future<void> open(
      WidgetTester tester,
      FakeNotebookRepository notebook, {
      String path = '/notebook/pages/${NotebookPageSamples.siteA}',
      Map<String, Object> stored = const {},
    }) async {
      await pumpApp(
        tester,
        language: lang,
        now: day,
        notebook: notebook,
        stored: stored,
      );
      GoRouter.of(tester.element(find.byType(Navigator).first)).push(path);
      await tester.pumpAndSettle();
    }

    testWidgets('NS1 the status row, a Space icon\'s card [$lang]', (
      tester,
    ) async {
      await open(tester, repo());
      await _tap(tester, 'note-status-entry-pour-space');
      await _snap(tester, 'NS1-status-card', lang);
    });

    testWidgets('NS6 an older Space share: the dot, its card [$lang]', (
      tester,
    ) async {
      await open(tester, repo(changed: true));
      await _tap(tester, 'note-status-entry-pour-space');
      await _snap(tester, 'NS6-older-share', lang);
    });

    testWidgets('NS2 a page in full, one entry folded [$lang]', (tester) async {
      await open(tester, repo(fold: true));
      await _snap(tester, 'NS2-folded', lang);
    });

    testWidgets('NS3 the card in Filter mode, SHOW and STATUS on [$lang]', (
      tester,
    ) async {
      await open(tester, repo(), path: '/notebook');
      await _tap(tester, 'notebook-filter');
      await _tap(tester, 'filter-show-todos_open');
      await _tap(tester, 'notebook-filter');
      await _tap(tester, 'filter-status-space');
      await _tap(tester, 'notebook-filter');
      await _snap(tester, 'NS3-filter-status', lang);
    });

    testWidgets('NS4 the card in Sort mode inside a page [$lang]', (
      tester,
    ) async {
      await open(tester, repo(), stored: {filterModeKey: 'sort'});
      await _tap(tester, 'page-filter');
      await _snap(tester, 'NS4-sort', lang);
    });
  }
}
