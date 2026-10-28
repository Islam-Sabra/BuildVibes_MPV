// Review 100: the notebook's redesign, against BH1–BH12 (EN 2638:37859,
// 2639:37911, 2639:38016, 2639:38132, 2642:38161, 2640:38023,
// 2640:38122, 2640:38248, 2647:38235, 2640:38416, 2642:38280,
// 2654:38281; AR 2638:37957, 2639:38261, 2639:38366, 2639:38482,
// 2642:38410, 2640:38551, 2640:38650, 2640:38776, 2647:38391,
// 2640:38944, 2642:38529, 2654:38447) and review 99's PG8 (2635:38668,
// 2635:39619). English and Arabic, at 390 × 844 on a 12-hour phone, in the
// app's fonts; the frames that draw a keyboard keep its room, blank. Run:
//   flutter test test_screens/bh_test.dart --update-goldens
import 'dart:convert';

import 'package:buildvibes/data/models/dm.dart';
import 'package:buildvibes/data/models/note.dart';
import 'package:buildvibes/data/models/notebook_page.dart';
import 'package:buildvibes/data/models/post_page.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/notebook/note_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../test/helpers/daybook_samples.dart';
import '../test/helpers/dm_fakes.dart';
import '../test/helpers/notebook_fakes.dart';
import '../test/helpers/notebook_page_samples.dart';
import '../test/helpers/pump_app.dart';
import '../test/helpers/space_fakes.dart';
import 'shot.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

/// Saves the app as it is now to `docs/screens/r100/<name>_<lang>.png`.
Future<void> _snap(WidgetTester tester, String name, String lang) async {
  debugDisableShadows = false;
  try {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byType(MaterialApp).first,
      matchesGoldenFile('../docs/screens/r100/${name}_$lang.png'),
    );
  } finally {
    debugDisableShadows = true;
  }
}

/// The notebook as BH draws it: PG1's pages; Before the pour at Gate 2 and
/// shared to the Space; Snags, lobby archived; three Deleted items; a
/// Space to share in; Ahmed among the recent conversations.
FakeNotebookRepository _notebook(String lang) {
  final s = NotebookPageSamples(lang);
  final d = DaybookSamples(lang);
  final repo = s.repository();
  repo.kept['entry-pour'] = repo.kept['entry-pour']!.copyWith(
    location: () =>
        NoteLocation(text: s.t('Gate 2', 'البوابة 2'), lat: 29.37, lng: 47.97),
    shares: [
      NoteShare(
        target: NoteShareTarget.space,
        name: d.spaceName,
        at: DateTime(2026, 10, 15, 10, 52),
      ),
    ],
  );
  repo.kept['entry-lobby'] = repo.kept['entry-lobby']!.copyWith(
    archivedAt: () => DateTime(2026, 10, 15, 11),
  );
  repo.hits = [
    NotebookHit(
      pageId: NotebookPageSamples.siteA,
      noteId: 'entry-pour',
      title: s.beforePour,
      at: DateTime(2026, 10, 15, 10, 40),
    ),
    NotebookHit(
      pageId: NotebookPageSamples.siteB,
      noteId: 'entry-snags',
      title: s.t('Pour the ground slab', 'صب البلاطة الأرضية'),
      at: DateTime(2026, 10, 14, 16, 20),
    ),
  ];
  // The deleted voice note the phone holds (H21: its icon and length).
  repo.kept['gone-voice'] = Note(
    id: 'gone-voice',
    kind: NoteKind.text,
    createdAt: DateTime(2026, 10, 12, 8),
    blocks: const [
      PageVoice('gone-v', path: 'user-1/gone-voice/v.m4a', durationMs: 42000),
    ],
    pageId: NotebookPageSamples.siteB,
    deletedAt: DateTime(2026, 10, 12, 8),
  );
  repo.deletedList = [
    DeletedItem(
      kind: DeletedKind.entry,
      id: 'gone-pump',
      title: s.pumpTitle,
      pageId: NotebookPageSamples.siteA,
      pageTitle: s.siteATitle,
      deletedAt: DateTime(2026, 10, 15, 9),
      purgeAt: DateTime(2026, 11, 14, 9),
    ),
    DeletedItem(
      kind: DeletedKind.page,
      id: 'gone-snags',
      title: s.t('Old snags', 'ملاحظات قديمة'),
      pageTitle: s.t('My notes', 'ملاحظاتي'),
      deletedAt: DateTime(2026, 10, 12, 9),
      purgeAt: DateTime(2026, 11, 11, 9),
    ),
    DeletedItem(
      kind: DeletedKind.part,
      id: 'gone-voice',
      pageId: NotebookPageSamples.siteB,
      pageTitle: s.siteBTitle,
      deletedAt: DateTime(2026, 10, 12, 8),
      purgeAt: DateTime(2026, 11, 11, 8),
    ),
  ];
  return repo;
}

/// BH6's entry: the title and two numbered lines, going into Site A.
NoteDraft _pour(String lang, {NoteLocation? location, DateTime? remind}) {
  final s = NotebookPageSamples(lang);
  return NoteDraft(
    id: 'd0000000-0000-4000-8000-000000000100',
    startedAt: NotebookPageSamples.now,
    title: s.beforePour,
    blocks: [
      PageNumbered('bh-1', s.t('Clean the formwork', 'تنظيف القوالب')),
      PageNumbered('bh-2', s.t('Check the rebar cover', 'فحص غطاء الحديد')),
    ],
    pageId: NotebookPageSamples.siteA,
    location: location,
    remindAt: remind,
  );
}

Future<void> _open(
  WidgetTester tester,
  String lang,
  String path, {
  NoteDraft? draft,
  bool keyboard = false,
}) async {
  final d = DaybookSamples(lang);
  await pumpApp(
    tester,
    language: lang,
    now: NotebookPageSamples.now,
    notebook: _notebook(lang),
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
      ..spacePeople[DaybookSamples.space] = d.people(),
    dm: FakeDmRepository()
      ..inboxValue = DmInbox(
        threads: [
          DmRow(
            threadId: 'thread-ahmed',
            person: DmPerson(
              id: 'p-ahmed',
              name: NotebookPageSamples(lang).t('Ahmed Saleh', 'أحمد صالح'),
            ),
            lastMessageAt: DateTime(2026, 10, 15, 9),
            unread: false,
          ),
        ],
      ),
    stored: {
      if (draft != null) 'notebook_draft:user-1': jsonEncode(draft.toJson()),
    },
  );
  tester.view.physicalSize = shotSize * shotPixelRatio;
  tester.view.devicePixelRatio = shotPixelRatio;
  if (keyboard) {
    tester.view.viewInsets = const FakeViewPadding(
      bottom: shotKeyboard * shotPixelRatio,
    );
  }
  addTearDown(tester.view.reset);
  GoRouter.of(tester.element(find.byType(Navigator).first)).push(path);
  await tester.pumpAndSettle();
}

const _siteA = '/notebook/pages/${NotebookPageSamples.siteA}';

/// Writing BH6's entry, the cursor at the end of its last line.
Future<void> _write(
  WidgetTester tester,
  String lang, {
  NoteDraft? draft,
}) async {
  await _open(
    tester,
    lang,
    _siteA,
    draft: draft ?? _pour(lang),
    keyboard: true,
  );
  await _tap(tester, _key('note-draft-card-${(draft ?? _pour(lang)).id}'));
  final last = find.byKey(const Key('page-field-t:bh-2'));
  await tester.tap(last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  for (final lang in ['en', 'ar']) {
    final s = NotebookPageSamples(lang);

    testWidgets('BH1 the pages list [$lang]', (tester) async {
      await _open(tester, lang, '/notebook');
      await _snap(tester, 'BH1-pages', lang);
    });

    testWidgets('BH2 an entry selected [$lang]', (tester) async {
      await _open(tester, lang, _siteA);
      await tester.longPress(_key('note-entry-pour'));
      await tester.pumpAndSettle();
      await _snap(tester, 'BH2-entry-selected', lang);
    });

    testWidgets('BH3 an entry swiped toward the end; Archived › [$lang]', (
      tester,
    ) async {
      await _open(tester, lang, _siteA);
      await tester.timedDrag(
        _key('note-entry-pour'),
        Offset(lang == 'ar' ? -160 : 160, 0),
        const Duration(milliseconds: 300),
      );
      await tester.pumpAndSettle();
      await _snap(tester, 'BH3-swipe', lang);
    });

    testWidgets('BH4 Share: Feed · Space · Message [$lang]', (tester) async {
      await _open(tester, lang, _siteA);
      await tester.longPress(_key('note-entry-pour'));
      await tester.pumpAndSettle();
      await _tap(tester, _key('select-share'));
      await _snap(tester, 'BH4-share', lang);
    });

    testWidgets('BH5 Share → Message: the preview [$lang]', (tester) async {
      await _open(tester, lang, _siteA);
      await tester.longPress(_key('note-entry-pour'));
      await tester.pumpAndSettle();
      await _tap(tester, _key('select-share'));
      await _tap(tester, _key('share-message'));
      await _tap(tester, _key('share-person-p-ahmed'));
      await _snap(tester, 'BH5-message-preview', lang);
    });

    testWidgets('BH6 the bar [$lang]', (tester) async {
      await _write(tester, lang);
      await _snap(tester, 'BH6-bar', lang);
    });

    testWidgets('BH7 📎 Add [$lang]', (tester) async {
      await _write(
        tester,
        lang,
        draft: _pour(
          lang,
          location: NoteLocation(text: s.t('Gate 2', 'البوابة 2')),
          remind: DateTime(2026, 10, 16, 7),
        ),
      );
      await _tap(tester, _key('note-tool-add'));
      await _snap(tester, 'BH7-add', lang);
    });

    testWidgets('BH8 + opens the block list [$lang]', (tester) async {
      await _write(tester, lang);
      await _tap(tester, _key('note-tool-categories'));
      await _snap(tester, 'BH8-blocks', lang);
    });

    testWidgets('BH9 the Filter card [$lang]', (tester) async {
      await _open(tester, lang, '/notebook');
      await _tap(tester, _key('notebook-filter'));
      await _snap(tester, 'BH9-filter', lang);
    });

    testWidgets('BH10 ⋮⋮ the line menu [$lang]', (tester) async {
      await _write(tester, lang);
      await _tap(tester, _key('page-handle-bh-2'));
      await _snap(tester, 'BH10-line-menu', lang);
    });

    testWidgets('BH11 the filtered list [$lang]', (tester) async {
      await _open(tester, lang, '/notebook');
      await _tap(tester, _key('notebook-filter'));
      await _tap(tester, _key('filter-show-todos_open'));
      await _snap(tester, 'BH11-filtered', lang);
    });

    testWidgets('BH12 a line selected [$lang]', (tester) async {
      await _write(tester, lang);
      await tester.longPress(_key('note-marker-bh-2'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();
      await _snap(tester, 'BH12-line-selected', lang);
    });

    testWidgets('PG8 Deleted items [$lang]', (tester) async {
      await _open(tester, lang, '/notebook/deleted');
      await _snap(tester, 'PG8-deleted', lang);
      expect(find.text(s.pumpTitle), findsOneWidget);
    });
  }
}
