// Review 100, the lead's check of the redesign (28 Oct): the rulings and
// the parts missing. H9 the reminder's short value, never cut; H10 plain
// icons in 📎 and the Filter, the Filter's card at the margin over a dim
// background; H12 no "GPS" in the location panel; H15 an edit changed on
// another phone comes back as a marked Draft; H16 📎 File has its ✕; H17
// the feed in Arabic; H18 the mic's own hint; H19 the Draft's Discard has
// its own key and icon; H21 a deleted voice note shows the voice icon. In
// English and Arabic.
import 'dart:convert';

import 'package:buildvibes/core/design/bv_icons.dart';
import 'package:buildvibes/data/models/note.dart';
import 'package:buildvibes/data/models/notebook_page.dart';
import 'package:buildvibes/data/models/post_page.dart';
import 'package:buildvibes/features/notebook/note_draft.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/notebook_fakes.dart';
import '../../helpers/notebook_page_samples.dart';
import '../../helpers/pump_app.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

const _siteA = '/notebook/pages/${NotebookPageSamples.siteA}';

Future<FakeNotebookRepository> _open(
  WidgetTester tester,
  String lang, {
  FakeNotebookRepository? notebook,
  NoteDraft? draft,
  String path = _siteA,
}) async {
  final repo = notebook ?? NotebookPageSamples(lang).repository();
  await pumpApp(
    tester,
    language: lang,
    now: NotebookPageSamples.now,
    notebook: repo,
    stored: {
      if (draft != null) 'notebook_draft:user-1': jsonEncode(draft.toJson()),
    },
  );
  GoRouter.of(tester.element(find.byType(Navigator).first)).push(path);
  await tester.pumpAndSettle();
  return repo;
}

NoteDraft _draft({DateTime? remind, List<NoteFile> files = const []}) =>
    NoteDraft(
      id: 'draft-1',
      startedAt: NotebookPageSamples.now,
      title: 'Before the pour',
      blocks: [PageText('l-1', 'Clean the formwork')],
      pageId: NotebookPageSamples.siteA,
      remindAt: remind,
      files: files,
    );

Future<void> _write(WidgetTester tester) async {
  await _tap(tester, _key('note-draft-card-draft-1'));
  await tester.tap(find.text('Clean the formwork'));
  await tester.pumpAndSettle();
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    final s = NotebookPageSamples(lang);

    testWidgets('H9: the reminder\'s value is short and never cut; H16: '
        'File has its ✕; H10: plain icons in 📎 [$lang]', (tester) async {
      await _open(
        tester,
        lang,
        draft: _draft(
          remind: DateTime(2026, 10, 16, 7),
          files: const [NoteFile(path: 'user-1/d/plan.pdf', name: 'Plan.pdf')],
        ),
      );
      await _write(tester);
      await _tap(tester, _key('note-tool-add'));
      final value = find.descendant(
        of: _key('note-add-remind'),
        // "Tomorrow" and the phone's own time.
        matching: find.textContaining(l10n.notebookTomorrow),
      );
      expect(value, findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(value).didExceedMaxLines,
        isFalse,
      );
      expect(_key('note-add-file-clear'), findsOneWidget);
      expect(
        find.descendant(of: _key('note-add-menu'), matching: _key('menu-tile')),
        findsNothing,
      );
      await _tap(tester, _key('note-add-file-clear'));
      expect(_key('note-file-0'), findsNothing);
    });

    testWidgets('H10: the Filter\'s card ends at the screen\'s margin, over '
        'a dim background, its icons plain [$lang]', (tester) async {
      await _open(tester, lang, path: '/notebook');
      await _tap(tester, _key('notebook-filter'));
      final card = tester.getRect(_key('notebook-filter-menu'));
      const margin = 16.0;
      if (lang == 'ar') {
        expect(card.left, closeTo(margin, 1));
      } else {
        expect(card.right, closeTo(390 - margin, 1));
      }
      expect(_key('line-popover-dim'), findsOneWidget);
      expect(
        find.descendant(
          of: _key('notebook-filter-menu'),
          matching: _key('menu-tile'),
        ),
        findsNothing,
      );
    });

    testWidgets('H12: no "GPS" in the location panel [$lang]', (tester) async {
      await _open(tester, lang, draft: _draft());
      await _write(tester);
      await _tap(tester, _key('note-tool-add'));
      await _tap(tester, _key('note-add-location'));
      expect(_key('note-location-panel'), findsOneWidget);
      expect(find.textContaining('GPS'), findsNothing);
      expect(find.textContaining(l10n.notebookOnMap), findsWidgets);
    });

    testWidgets('H15: an edit changed meanwhile on another phone comes back '
        'as a Draft marked "Changed on another phone"; the entry stays as '
        'it is [$lang]', (tester) async {
      final repo = await _open(tester, lang);
      await _tap(tester, _key('note-entry-gate'));
      // Another phone saved it meanwhile.
      repo.kept['entry-gate'] = repo.kept['entry-gate']!.copyWith(version: 5);
      await tester.enterText(_key('note-title'), 'Pump booked 3 pm');
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text(l10n.notebookChangedElsewhere), findsOneWidget);
      expect(find.text(s.pumpTitle), findsWidgets);
      expect(repo.kept['entry-gate']!.title, s.pumpTitle);
      final drafts = find.byWidgetPredicate(
        (w) => w is! KeyedSubtree && '${w.key}'.contains('note-draft-card-'),
      );
      expect(drafts, findsOneWidget);
    });

    testWidgets('H18: a short tap on the mic says how, in the notebook\'s '
        'own words [$lang]', (tester) async {
      await _open(tester, lang, draft: _draft());
      await _write(tester);
      await _tap(tester, _key('note-tool-voice'));
      expect(find.text(l10n.notebookHoldToRecord), findsOneWidget);
    });

    testWidgets('H17: the feed is «الأخبار» in Arabic [$lang]', (tester) async {
      if (lang == 'ar') {
        for (final w in [
          l10n.notebookShareFeed,
          l10n.notebookShareFeedTitle,
          l10n.notebookSharedFeed,
          l10n.notebookMarkFeed('9:00'),
        ]) {
          expect(w, contains('الأخبار'), reason: w);
        }
      }
    });

    testWidgets('H19: a Draft\'s Discard has its own key and icon [$lang]', (
      tester,
    ) async {
      await _open(tester, lang, draft: _draft());
      await tester.timedDrag(
        _key('swipe-card-draft-1'),
        Offset(lang == 'ar' ? 120 : -120, 0),
        const Duration(milliseconds: 300),
      );
      await tester.pumpAndSettle();
      expect(_key('swipe-discard-draft-1'), findsOneWidget);
      expect(_key('swipe-archive-draft-1'), findsNothing);
      expect(
        find.descendant(
          of: _key('swipe-discard-draft-1'),
          matching: find.byIcon(BvIcons.discard),
        ),
        findsOneWidget,
      );
      expect(BvIcons.shareEntry.matchTextDirection, isTrue);
    });

    testWidgets('H21: a deleted voice note shows the voice icon and its '
        'length [$lang]', (tester) async {
      final repo = s.repository();
      repo.kept['gone-voice'] = Note(
        id: 'gone-voice',
        kind: NoteKind.text,
        createdAt: DateTime(2026, 10, 12, 8),
        blocks: const [
          PageVoice('v-1', path: 'user-1/gone-voice/v.m4a', durationMs: 42000),
        ],
        pageId: NotebookPageSamples.siteB,
        deletedAt: DateTime(2026, 10, 12, 8),
      );
      repo.deletedList = [
        DeletedItem(
          kind: DeletedKind.part,
          id: 'gone-voice',
          pageId: NotebookPageSamples.siteB,
          pageTitle: s.siteBTitle,
          deletedAt: DateTime(2026, 10, 12, 8),
          purgeAt: DateTime(2026, 11, 11, 8),
        ),
      ];
      await _open(tester, lang, notebook: repo, path: '/notebook/deleted');
      expect(
        find.descendant(
          of: _key('deleted-gone-voice'),
          matching: find.byIcon(BvIcons.microphone),
        ),
        findsOneWidget,
      );
      expect(find.text(l10n.notebookVoiceTitle('0:42')), findsOneWidget);
    });
  }
}
