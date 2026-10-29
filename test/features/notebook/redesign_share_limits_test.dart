// Review 100, the lead's second check (28 Oct): J1 a message holds 3,000
// characters: a longer entry says so in the preview and Send is off; J2
// shared words use characters every phone's font has: to-dos as [ ] and
// [x], as the server's note_words writes them, and a message received
// with them shows no stray mark. In English and Arabic.
import 'package:buildvibes/data/models/chat.dart' show ChatKind;
import 'package:buildvibes/data/models/dm.dart';
import 'package:buildvibes/data/models/note.dart';
import 'package:buildvibes/data/models/post_page.dart';
import 'package:buildvibes/features/notebook/note_share.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/dm_fakes.dart';
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

/// Before the pour, its to-dos, a bullet and a number, at Gate 2.
Note _pour() => Note(
  id: 'entry-pour',
  kind: NoteKind.text,
  title: 'Before the pour',
  blocks: const [
    PageTodo('t-1', 'Clean the formwork'),
    PageTodo('t-2', 'Check the cover', done: true),
    PageBullet('t-3', 'Spacers'),
    PageNumbered('t-4', 'Pump at 7'),
    PageNumbered('t-5', 'Pour at 8'),
  ],
  location: const NoteLocation(text: 'Gate 2', lat: 29.3759, lng: 47.9774),
  createdAt: DateTime(2026, 10, 15, 9),
  pageId: NotebookPageSamples.siteA,
);

void main() {
  test(
    'J2: shareText writes what the server writes, to-dos as [ ] and [x]',
    () {
      expect(
        shareText(_pour(), null, location: true),
        'Before the pour\n'
        '[ ] Clean the formwork\n'
        '[x] Check the cover\n'
        '• Spacers\n'
        '1. Pump at 7\n'
        '2. Pour at 8\n'
        '📍 Gate 2 · 29.375900, 47.977400',
      );
      expect(shareText(_pour(), null, location: false), isNot(contains('📍')));
      expect(shareText(_pour(), null, location: true), isNot(contains('☐')));
      expect(shareText(_pour(), null, location: true), isNot(contains('☑')));
      // A line group: its lines only, no title.
      expect(
        shareText(_pour(), const [
          PageTodo('t-1', 'Clean the formwork'),
        ], location: false),
        '[ ] Clean the formwork',
      );
    },
  );

  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));

    testWidgets('J1: an entry longer than a message can hold: the preview '
        'says so and Send is off [$lang]', (tester) async {
      final s = NotebookPageSamples(lang);
      final repo = s.repository();
      repo.kept['entry-pour'] = repo.kept['entry-pour']!.copyWith(
        blocks: [PageText('t-long', 'x' * 3100)],
      );
      await pumpApp(
        tester,
        language: lang,
        now: NotebookPageSamples.now,
        notebook: repo,
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
      GoRouter.of(
        tester.element(find.byType(Navigator).first),
      ).push('/notebook/pages/${NotebookPageSamples.siteA}');
      await tester.pumpAndSettle();
      // Review 106 T2: shown in full, the long entry runs past the screen;
      // its head is held.
      await tester.longPress(_key('note-head-entry-pour'));
      await tester.pumpAndSettle();
      await _tap(tester, _key('select-share'));
      await _tap(tester, _key('share-message'));
      await _tap(tester, _key('share-person-p-ahmed'));
      expect(find.text(l10n.notebookShareTooLong), findsOneWidget);
      await _tap(tester, _key('share-send'));
      expect(_key('share-preview'), findsOneWidget);
      expect(repo.personShares, isEmpty);
    });

    testWidgets('J2: a message received with an entry\'s words shows them '
        'as written, no stray mark [$lang]', (tester) async {
      await pumpApp(
        tester,
        language: lang,
        now: NotebookPageSamples.now,
        notebook: FakeNotebookRepository(),
        dm: FakeDmRepository()
          ..pages['t-ahmed'] = DmThreadPage(
            threadId: 't-ahmed',
            person: const DmPerson(id: 'p-ahmed', name: 'Ahmed Saleh'),
            messages: [
              DmMessage(
                id: 'm1',
                fromMe: false,
                kind: ChatKind.text,
                createdAt: DateTime(2026, 10, 15, 10, 40),
                body: shareText(_pour(), null, location: false),
              ),
            ],
          ),
      );
      GoRouter.of(
        tester.element(find.byType(Navigator).first),
      ).push('/messages/t-ahmed');
      await tester.pumpAndSettle();
      expect(find.textContaining('[ ] Clean the formwork'), findsOneWidget);
      expect(find.textContaining('[x] Check the cover'), findsOneWidget);
      for (final stray in ['☐', '☑', '≡']) {
        expect(find.textContaining(stray), findsNothing, reason: stray);
      }
    });
  }
}
