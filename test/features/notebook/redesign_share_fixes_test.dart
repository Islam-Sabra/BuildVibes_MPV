// Review 100, the lead's check of the redesign (28 Oct): Share. H1 a
// refusal is said and the preview stays; H2 what goes is what the server
// has (the entry's waiting changes go first, or Share hides); H11 a
// Space's Team, and who a checklist is for; H13 files and voice go to a
// person as the message's attachments; H14 "To" searches inside the same
// card; H20 a feed post is in the entry's language. In English and Arabic.
import 'package:buildvibes/data/models/dm.dart';
import 'package:buildvibes/data/models/note.dart';
import 'package:buildvibes/data/models/post_page.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/spaces/space_errors.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/features/notebook/note_page_editor.dart'
    show NoteTick;
import 'package:buildvibes/features/notebook/notebook_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/daybook_samples.dart';
import '../../helpers/dm_fakes.dart';
import '../../helpers/notebook_fakes.dart';
import '../../helpers/notebook_page_samples.dart';
import '../../helpers/people_search_fakes.dart';
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
  FakePeopleSearchRepository? people,
}) async {
  final s = NotebookPageSamples(lang);
  final repo = notebook ?? s.repository();
  final d = DaybookSamples(lang);
  await pumpApp(
    tester,
    language: lang,
    now: NotebookPageSamples.now,
    notebook: repo,
    peopleSearch: people,
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

Future<void> _share(
  WidgetTester tester,
  String choice, {
  String id = 'entry-pour',
}) async {
  await tester.ensureVisible(_key('note-$id'));
  await tester.pumpAndSettle();
  await tester.longPress(_key('note-$id'));
  await tester.pumpAndSettle();
  await _tap(tester, _key('select-share'));
  await _tap(tester, _key('share-$choice'));
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    final s = NotebookPageSamples(lang);

    group('H1 a refusal [$lang]', () {
      testWidgets('is said, the preview stays open, and nothing says it was '
          'sent', (tester) async {
        final repo = s.repository()
          ..shareError = const SpaceException(SpaceFailure.notAllowed);
        await _open(tester, lang, notebook: repo);
        await _share(tester, 'message');
        await _tap(tester, _key('share-person-p-ahmed'));
        await _tap(tester, _key('share-send'));
        expect(_key('share-preview'), findsOneWidget);
        expect(_key('share-error'), findsOneWidget);
        expect(
          find.text(
            spaceErrorText(l10n, const SpaceException(SpaceFailure.notAllowed)),
          ),
          findsOneWidget,
        );
        expect(find.text(l10n.notebookSentTo('Ahmed Saleh')), findsNothing);
        // Taken back, it goes the second time.
        repo.shareError = null;
        await _tap(tester, _key('share-send'));
        expect(_key('share-preview'), findsNothing);
        expect(find.text(l10n.notebookSentTo('Ahmed Saleh')), findsOneWidget);
      });
    });

    group('H2 what goes is what the server has [$lang]', () {
      testWidgets('the entry\'s waiting changes go first, then the share', (
        tester,
      ) async {
        final repo = await _open(tester, lang);
        repo.offline = true;
        // Pinned with no signal: it waits on the phone.
        await tester.timedDrag(
          _key('note-entry-pour'),
          Offset(lang == 'ar' ? -160 : 160, 0),
          const Duration(milliseconds: 300),
        );
        await tester.pumpAndSettle();
        // As it is (a scroll would close it).
        await tester.tap(_key('swipe-pin-entry-pour'));
        await tester.pumpAndSettle();
        // No signal: Share is hidden for it.
        await tester.longPress(_key('note-entry-pour'));
        await tester.pumpAndSettle();
        expect(_key('select-share'), findsNothing);
        expect(_key('select-move'), findsOneWidget);
        await _tap(tester, _key('selection-close'));
        // Back on (the outbox tries again by itself): the pin goes before
        // the share.
        repo.offline = false;
        repo.calls.clear();
        await ProviderScope.containerOf(
          tester.element(find.byType(Scaffold).first),
        ).read(notebookProvider.notifier).retry();
        await tester.pumpAndSettle();
        await _share(tester, 'feed');
        await _tap(tester, _key('share-send'));
        final pin = repo.calls.indexOf('pin:entry-pour:true');
        final share = repo.calls.indexWhere((c) => c.startsWith('share-feed'));
        expect(pin, isNonNegative);
        expect(share, greaterThan(pin));
      });

      testWidgets('lines being edited are shared once their entry is saved', (
        tester,
      ) async {
        final repo = await _open(tester, lang);
        await _tap(tester, _key('note-entry-pour'));
        final line = find.byKey(const Key('page-field-t:b-2'));
        await tester.enterText(line, 'Check the rebar cover again');
        await tester.pumpAndSettle();
        await tester.longPress(_key('note-marker-b-2'));
        await tester.pumpAndSettle();
        await _tap(tester, _key('select-share'));
        await _tap(tester, _key('share-feed'));
        expect(
          find.descendant(
            of: _key('share-preview'),
            matching: find.textContaining('Check the rebar cover again'),
          ),
          findsOneWidget,
        );
        await _tap(tester, _key('share-send'));
        final save = repo.calls.indexOf('save:entry-pour');
        final share = repo.calls.indexWhere((c) => c.startsWith('share-feed'));
        expect(save, isNonNegative);
        expect(share, greaterThan(save));
        expect(
          (repo.kept['entry-pour']!.blocks![1] as PageNumbered).text,
          'Check the rebar cover again',
        );
      });
    });

    group('H11 a Space [$lang]', () {
      testWidgets('its Team; a work item is mine by default; a checklist '
          'asks who it is for', (tester) async {
        final repo = await _open(tester, lang);
        await _share(tester, 'space');
        await _tap(tester, _key('share-space-${DaybookSamples.space}'));
        expect(_key('share-team-none'), findsOneWidget);
        await _tap(tester, _key('share-team-t-site'));
        await _tap(tester, _key('share-kind-work_item'));
        expect(_key('share-for-${DaybookSamples.islam}'), findsOneWidget);
        await _tap(tester, _key('share-send'));
        expect(repo.spaceShares.last['team'], 't-site');
        expect(repo.spaceShares.last['owner'], DaybookSamples.islam);
        // A checklist: who it's for.
        await _share(tester, 'space');
        await _tap(tester, _key('share-space-${DaybookSamples.space}'));
        await _tap(tester, _key('share-kind-checklist'));
        await _tap(tester, _key('share-for-${DaybookSamples.omar}'));
        await _tap(tester, _key('share-send'));
        expect(
          repo.spaceShares.last['people'],
          containsAll([DaybookSamples.islam, DaybookSamples.omar]),
        );
      });
    });

    group('H13 files and voice to a person [$lang]', () {
      testWidgets('go as the message\'s attachments, listed in the preview', (
        tester,
      ) async {
        final repo = s.repository();
        repo.kept['entry-pour'] = repo.kept['entry-pour']!.copyWith(
          files: const [
            NoteFile(path: 'user-1/entry-pour/plan.pdf', name: 'Plan.pdf'),
          ],
          blocks: [
            ...repo.kept['entry-pour']!.blocks!,
            const PageVoice(
              'b-v',
              path: 'user-1/entry-pour/voice.m4a',
              durationMs: 42000,
            ),
          ],
        );
        await _open(tester, lang, notebook: repo);
        await _share(tester, 'message');
        await _tap(tester, _key('share-person-p-ahmed'));
        expect(
          find.descendant(
            of: _key('share-preview'),
            matching: find.text('Plan.pdf'),
          ),
          findsOneWidget,
        );
        expect(_key('share-voice-b-v'), findsOneWidget);
        await tester.tap(_key('share-send'));
        // The copies are real files: real time for each, until it went.
        for (var i = 0; i < 40 && repo.personShares.isEmpty; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }
        await tester.pumpAndSettle();
        final sent = repo.personShares.last['attachments'] as List;
        expect(sent, hasLength(2));
        expect([
          for (final a in sent) (a as Map)['name'],
        ], contains('Plan.pdf'));
        expect([
          for (final a in sent) (a as Map)['duration_ms'],
        ], contains(42000));
      });
    });

    group('H14 "To" [$lang]', () {
      testWidgets('recent first, then a search among people you can message, '
          'in the same card', (tester) async {
        final people = FakePeopleSearchRepository(
          people: [
            const SpacePerson(id: 'p-sara', firstName: 'Sara', lastName: 'Ali'),
          ],
        );
        final repo = await _open(tester, lang, people: people);
        await _share(tester, 'message');
        expect(_key('share-person-p-ahmed'), findsOneWidget);
        await tester.enterText(_key('share-find-field'), 'Sara');
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
        expect(_key('share-menu'), findsOneWidget);
        await _tap(tester, _key('share-person-p-sara'));
        await _tap(tester, _key('share-send'));
        expect(repo.personShares.last['person'], 'p-sara');
      });
    });

    group('the preview\'s to-dos [$lang]', () {
      testWidgets('are drawn as the app\'s boxes (BH5), never as a mark the '
          'fonts lack', (tester) async {
        await _open(tester, lang);
        await _share(tester, 'feed', id: 'entry-cubes');
        expect(
          find.descendant(
            of: _key('share-preview'),
            matching: find.byType(NoteTick),
          ),
          findsOneWidget,
        );
        expect(find.textContaining(noteTodoOpenMark), findsNothing);
      });
    });

    group('H20 a feed post\'s language [$lang]', () {
      testWidgets('is the entry\'s, not the app\'s', (tester) async {
        final repo = s.repository();
        repo.kept['entry-pour'] = repo.kept['entry-pour']!.copyWith(
          title: 'قبل الصب',
          blocks: [const PageText('b-1', 'تنظيف القوالب')],
          body: 'قبل الصب\nتنظيف القوالب',
        );
        await _open(tester, lang, notebook: repo);
        await _share(tester, 'feed');
        await _tap(tester, _key('share-send'));
        expect(
          repo.calls.where((c) => c.startsWith('share-feed:entry-pour:ar:')),
          hasLength(1),
        );
      });
    });
  }
}
