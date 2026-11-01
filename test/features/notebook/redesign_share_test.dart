// Review 100 Part 6 (BH4, BH5): Share on one selected entry, or selected
// lines: the card turns into Feed · Space · Message; each shows a preview
// first, exactly what goes, with one removable location line (no GPS
// tick), "✕ Cancel" and "➤ Send" (or Post) as words. The entry stays, with
// a mark. In English and Arabic.
import 'package:buildvibes/data/models/dm.dart';
import 'package:buildvibes/data/models/note.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_give_to_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/daybook_samples.dart';
import '../../helpers/dm_fakes.dart';
import '../../helpers/notebook_fakes.dart';
import '../../helpers/notebook_page_samples.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

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
  bool feed = true,
}) async {
  final s = NotebookPageSamples(lang);
  final repo = notebook ?? s.repository();
  repo.kept['entry-pour'] = repo.kept['entry-pour']!.copyWith(
    location: () => const NoteLocation(text: 'Gate 2', lat: 29.37, lng: 47.97),
  );
  final d = DaybookSamples(lang);
  await pumpApp(
    tester,
    // Their Share offers the feed (review 113: behind the switch).
    feed: feed,
    language: lang,
    now: NotebookPageSamples.now,
    notebook: repo,
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
            person: const DmPerson(id: 'p-ahmed', name: 'Ahmed Saleh'),
            lastMessageAt: DateTime(2026, 10, 15, 9),
            unread: false,
          ),
        ],
      ),
  );
  GoRouter.of(tester.element(find.byType(Navigator).first)).push(_siteA);
  await tester.pumpAndSettle();
  return repo;
}

Future<void> _share(WidgetTester tester, String choice) async {
  await tester.longPress(_key('note-entry-pour'));
  await tester.pumpAndSettle();
  // Review 106 T4: the held entry's icon for [choice].
  await _tap(tester, _key('note-status-entry-pour-$choice'));
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    final s = NotebookPageSamples(lang);
    final d = DaybookSamples(lang);

    group('BH4 Share [$lang]', () {
      testWidgets('review 106 T4: on one entry, Share left the bar; its '
          'Space icon opens the Space step, whose ‹ closes it', (tester) async {
        await _open(tester, lang);
        await tester.longPress(_key('note-entry-pour'));
        await tester.pumpAndSettle();
        expect(_key('select-share'), findsNothing);
        await _tap(tester, _key('note-status-entry-pour-space'));
        expect(_key('share-space-${DaybookSamples.space}'), findsOneWidget);
        await _tap(tester, _key('menu-back'));
        expect(_key('share-menu'), findsNothing);
      });

      testWidgets('review 113 (6): with the feed hidden, the card offers '
          'Space and Message only', (tester) async {
        await _open(tester, lang, feed: false);
        await _tap(tester, _key('note-entry-pour'));
        await tester.tap(
          find.text(s.t('Check the rebar cover', 'فحص غطاء الحديد')),
        );
        await tester.pumpAndSettle();
        await tester.longPress(_key('note-marker-b-2'));
        await tester.pumpAndSettle();
        await _tap(tester, _key('select-share'));
        expect(_key('share-menu'), findsOneWidget);
        expect(_key('share-feed'), findsNothing);
        expect(_key('share-space'), findsOneWidget);
        expect(_key('share-message'), findsOneWidget);
        expect(find.text(l10n.notebookShareFeed), findsNothing);
      });

      testWidgets('on selected lines: the bar\'s first action; its card over '
          'the bar turns into Feed · Space · Message', (tester) async {
        await _open(tester, lang);
        await _tap(tester, _key('note-entry-pour'));
        await tester.tap(
          find.text(s.t('Check the rebar cover', 'فحص غطاء الحديد')),
        );
        await tester.pumpAndSettle();
        await tester.longPress(_key('note-marker-b-2'));
        await tester.pumpAndSettle();
        await _tap(tester, _key('select-share'));
        expect(_key('share-menu'), findsOneWidget);
        for (final c in ['feed', 'space', 'message']) {
          expect(_key('share-$c'), findsOneWidget, reason: c);
        }
        expect(find.text(l10n.notebookShareFeedNote), findsOneWidget);
        // Review 104 S1: a note, not a post.
        expect(
          find.text(
            lang == 'en'
                ? 'A note, work item or checklist'
                : 'ملاحظة أو بند عمل أو قائمة تحقق',
          ),
          findsOneWidget,
        );
        expect(find.byType(BottomSheet), findsNothing);
        // Over the bar.
        expect(
          tester.getRect(_key('share-menu')).bottom,
          lessThanOrEqualTo(tester.getRect(_key('selection-bar')).top),
        );
        // ‹ closes it.
        await _tap(tester, _key('menu-back'));
        expect(_key('share-menu'), findsNothing);
      });
    });

    group('BH5 the previews [$lang]', () {
      testWidgets('Feed: what goes, the share check, one location line with '
          '✕; no GPS tick; Cancel and Post as words', (tester) async {
        final repo = await _open(tester, lang);
        await _share(tester, 'feed');
        expect(_key('share-preview'), findsOneWidget);
        expect(
          find.descendant(
            of: _key('share-preview'),
            matching: find.text(s.beforePour),
          ),
          findsOneWidget,
        );
        expect(find.text(l10n.notebookShareCheck), findsOneWidget);
        expect(
          find.descendant(
            of: _key('share-preview'),
            matching: find.text(
              l10n.notebookShareLocation('Gate 2', l10n.notebookOnMap),
            ),
          ),
          findsOneWidget,
        );
        expect(find.textContaining('GPS'), findsNothing);
        expect(find.byType(Checkbox), findsNothing);
        expect(
          find.descendant(
            of: _key('share-cancel'),
            matching: find.text(l10n.commonCancel),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: _key('share-send'),
            matching: find.text(l10n.notebookPost),
          ),
          findsOneWidget,
        );
        // ✕ leaves the location out of this share only.
        await _tap(tester, _key('share-location-remove'));
        expect(_key('share-location'), findsNothing);
        await _tap(tester, _key('share-send'));
        expect(_key('share-preview'), findsNothing);
        expect(repo.calls, contains('share-feed:entry-pour:$lang:false:'));
        expect(repo.kept['entry-pour']!.location!.text, 'Gate 2');
        expect(find.text(l10n.notebookSharedFeed), findsOneWidget);
      });

      testWidgets('Cancel sends nothing', (tester) async {
        final repo = await _open(tester, lang);
        await _share(tester, 'feed');
        await _tap(tester, _key('share-cancel'));
        expect(_key('share-preview'), findsNothing);
        expect(repo.calls.where((c) => c.startsWith('share')), isEmpty);
      });

      testWidgets('Message: recent conversations first; the preview says '
          'who it goes to; Send goes to their thread', (tester) async {
        final repo = await _open(tester, lang);
        await _share(tester, 'message');
        expect(_key('share-person-p-ahmed'), findsOneWidget);
        await _tap(tester, _key('share-person-p-ahmed'));
        expect(
          find.descendant(
            of: _key('share-to'),
            matching: find.text('Ahmed Saleh'),
          ),
          findsOneWidget,
        );
        expect(find.text(l10n.notebookShareWhatSees('Ahmed')), findsOneWidget);
        expect(
          find.descendant(
            of: _key('share-send'),
            matching: find.text(l10n.chatSend),
          ),
          findsOneWidget,
        );
        // The arrow flips in Arabic.
        final arrow = tester.widget<Icon>(
          find.descendant(of: _key('share-send'), matching: find.byType(Icon)),
        );
        expect(arrow.icon!.matchTextDirection, isTrue);
        await _tap(tester, _key('share-send'));
        expect(
          repo.calls,
          contains('share-person:entry-pour:p-ahmed:thread-ahmed:true:'),
        );
        expect(find.text(l10n.notebookSentTo('Ahmed Saleh')), findsOneWidget);
      });

      testWidgets('Space: the Space, then post or work item; the '
          'Space\'s own rules are the server\'s', (tester) async {
        final repo = await _open(tester, lang);
        await _share(tester, 'space');
        await _tap(tester, _key('share-space-${DaybookSamples.space}'));
        expect(_key('share-kind-note'), findsOneWidget);
        expect(_key('share-kind-work_item'), findsOneWidget);
        // Review 110 W8: no Checklist; to-do lines go in as a work item's.
        expect(_key('share-kind-checklist'), findsNothing);
        await _tap(tester, _key('share-kind-work_item'));
        // Review 112: a work item is for someone chosen, never me.
        await _tap(tester, _key('share-for'));
        await _tap(
          tester,
          find.descendant(
            of: find.byType(BvGiveToPicker),
            matching: find.text(d.omarName),
          ),
        );
        await _tap(tester, _key('share-send'));
        expect(
          repo.calls,
          contains(
            'share-space:entry-pour:${DaybookSamples.space}:work_item:true:',
          ),
        );
        expect(find.text(l10n.notebookSharedTo(d.spaceName)), findsOneWidget);
      });

      testWidgets('selected lines of a saved entry share as themselves', (
        tester,
      ) async {
        final repo = await _open(tester, lang);
        await _tap(tester, _key('note-entry-pour'));
        await tester.tap(
          find.text(s.t('Check the rebar cover', 'فحص غطاء الحديد')),
        );
        await tester.pumpAndSettle();
        await tester.longPress(_key('note-marker-b-2'));
        await tester.pumpAndSettle();
        await _tap(tester, _key('select-share'));
        await _tap(tester, _key('share-feed'));
        expect(
          find.descendant(
            of: _key('share-preview'),
            matching: find.text(s.t('Clean the formwork', 'تنظيف القوالب')),
          ),
          findsNothing,
        );
        await _tap(tester, _key('share-send'));
        expect(repo.calls, contains('share-feed:entry-pour:$lang:true:b-2'));
      });
    });

    group('the mark [$lang]', () {
      testWidgets('the entry stays, marked where it went and when', (
        tester,
      ) async {
        final notebook = s.repository();
        notebook.kept['entry-gate'] = notebook.kept['entry-gate']!.copyWith(
          shares: [
            NoteShare(
              target: NoteShareTarget.space,
              name: d.spaceName,
              at: DateTime(2026, 10, 15, 8, 45),
            ),
          ],
        );
        await _open(tester, lang, notebook: notebook);
        // Review 104 N12: the mark is the Space icon in the top line; its
        // card says where and when.
        expect(_key('note-status-entry-gate-space'), findsOneWidget);
        await tester.tap(_key('note-status-entry-gate-space'));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: _key('note-status-card'),
            matching: find.textContaining(d.spaceName),
          ),
          findsOneWidget,
        );
      });
    });
  }
}
