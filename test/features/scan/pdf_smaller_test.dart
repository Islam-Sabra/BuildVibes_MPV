// Review 103 (founder, 4 Nov 12:28): Make it smaller («صغّر الملف») on
// every PDF of 1 MB or more attached in the composer, the Library, chat
// and the notebook. An offer, never automatic: it compresses on the phone,
// then shows before → after with the warning line, and Use smaller · Keep
// original. Over 25 MB the "too large" sheet offers Make it smaller first,
// with Link folder beside it; still too large after it, only Link folder.
// In English and Arabic.
import 'dart:convert';

import 'package:buildvibes/data/models/dm.dart';
import 'package:buildvibes/data/models/library.dart';
import 'package:buildvibes/data/models/post_page.dart';
import 'package:buildvibes/features/notebook/note_draft.dart';
import 'package:buildvibes/features/library/library_parts.dart';
import 'package:buildvibes/features/work/daybook_draft.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/composer_steps.dart';
import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/dm_fakes.dart';
import '../../helpers/library_fakes.dart';
import '../../helpers/notebook_page_samples.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/scan_fakes.dart';
import '../../helpers/space_fakes.dart';

const _space = DaybookSamples.space;
const _mb = 1024 * 1024;

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

PhoneFile _pdf(int bytes) => PhoneFile(
  local: testPdfPath,
  name: 'A-501 Rev D.pdf',
  mime: 'application/pdf',
  bytes: bytes,
);

Future<TestApp> _open(
  WidgetTester tester,
  String lang, {
  required int bytes,
  FakePdfShrinker? shrinker,
}) async {
  final s = DaybookSamples(lang);
  final app = await pumpApp(
    tester,
    language: lang,
    spaces: FakeSpaceRepository()
      ..details[_space] = s.detail(addFiles: true)
      ..spacePeople[_space] = s.people(),
    daybook: FakeDaybookRepository()..posts[_space] = const [],
    library: FakeLibraryRepository(now: DaybookSamples.thursday),
    now: DaybookSamples.thursday,
    composerKind: 'note',
    pickDocument: () => _pdf(bytes),
    shrinker: shrinker,
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/$_space');
  await tester.pumpAndSettle();
  return app;
}

/// A note with a PDF from the phone (+ → File).
Future<void> _attach(WidgetTester tester) async {
  await _tap(tester, _key('post-bar-notepad'));
  await tester.enterText(_key('writing-title'), 'Level 3');
  await tester.pumpAndSettle();
  await addExtra(tester, 'file');
  await _tap(tester, _key('attach-file'));
}

DaybookPostDraft? _draft(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(Navigator).first),
).read(daybookDraftProvider(_space));

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));

    group('the offer [$lang]', () {
      testWidgets('a PDF under 1 MB: no offer', (tester) async {
        await _open(tester, lang, bytes: 900 * 1024);
        await _attach(tester);
        expect(_key('writing-file-smaller-0'), findsNothing);
      });

      testWidgets('1 MB and up: the offer; before → after with the warning; '
          'Use smaller puts it in place', (tester) async {
        final shrinker = FakePdfShrinker(bytes: 2 * _mb + 300 * 1024);
        await _open(
          tester,
          lang,
          bytes: 9 * _mb + 100 * 1024,
          shrinker: shrinker,
        );
        await _attach(tester);
        expect(find.text(l10n.pdfSmaller), findsOneWidget);
        await _tap(tester, _key('writing-file-smaller-0'));
        expect(shrinker.calls, hasLength(1));
        expect(
          find.text(
            l10n.pdfSmallerResult(
              fileSize(l10n, 9 * _mb + 100 * 1024),
              fileSize(l10n, 2 * _mb + 300 * 1024),
            ),
          ),
          findsOneWidget,
        );
        expect(find.text(l10n.pdfSmallerWarning), findsOneWidget);
        await _tap(tester, _key('pdf-use-smaller'));
        final file = _draft(tester)!.files.single;
        expect(file.bytes, 2 * _mb + 300 * 1024);
        expect(file.local, isNot(testPdfPath));
        expect(file.name, 'A-501 Rev D.pdf');
        expect(
          _key('writing-file-smaller-0'),
          findsOneWidget,
          reason: 'still 2.3 MB: it can be offered again',
        );
      });

      testWidgets('Keep original leaves it as it was', (tester) async {
        await _open(tester, lang, bytes: 4 * _mb);
        await _attach(tester);
        final before = _draft(tester)!.files.single;
        await _tap(tester, _key('writing-file-smaller-0'));
        await _tap(tester, _key('pdf-keep-original'));
        final after = _draft(tester)!.files.single;
        expect(after.local, before.local);
        expect(after.bytes, 4 * _mb);
      });
    });

    group('too large [$lang]', () {
      testWidgets('over 25 MB: Make it smaller first, Link folder beside; '
          'smaller, it fits and goes on the post', (tester) async {
        final shrinker = FakePdfShrinker(bytes: 12 * _mb);
        await _open(tester, lang, bytes: 38 * _mb, shrinker: shrinker);
        await _attach(tester);
        expect(_key('file-refused'), findsOneWidget);
        expect(_key('file-refused-smaller'), findsOneWidget);
        expect(_key('file-refused-link-folder'), findsOneWidget);
        await _tap(tester, _key('file-refused-smaller'));
        await _tap(tester, _key('pdf-use-smaller'));
        final file = _draft(tester)!.files.single;
        expect(file.bytes, 12 * _mb);
      });

      testWidgets('still too large after it: "Still too large", only Link '
          'folder; nothing is added', (tester) async {
        final shrinker = FakePdfShrinker(bytes: 31 * _mb);
        await _open(tester, lang, bytes: 60 * _mb, shrinker: shrinker);
        await _attach(tester);
        await _tap(tester, _key('file-refused-smaller'));
        expect(find.text(l10n.pdfStillTooLarge('31', '25')), findsOneWidget);
        expect(_key('pdf-use-smaller'), findsNothing);
        expect(_key('file-still-link-folder'), findsOneWidget);
        await _tap(tester, _key('file-still-link-folder'));
        expect(_key('folder-sheet'), findsOneWidget);
        expect(_draft(tester)?.files ?? const [], isEmpty);
      });
    });

    group('the other places [$lang]', () {
      testWidgets('the Library: a 9 MB PDF is offered smaller before it goes; '
          'Use smaller sends the smaller copy', (tester) async {
        final app = await _open(tester, lang, bytes: 9 * _mb);
        await _tap(tester, _key('space-library'));
        await _tap(tester, _key('library-add-file'));
        await _tap(tester, _key('file-from-phone'));
        expect(_key('pdf-offer'), findsOneWidget);
        await _tap(tester, _key('pdf-offer-smaller'));
        await _tap(tester, _key('pdf-use-smaller'));
        await _tap(tester, _key('library-who-add'));
        expect(
          app.library.calls.where((c) => c.startsWith('add A-501 Rev D.pdf')),
          hasLength(1),
        );
        final sent = app.library.filesBySpace[_space]!.single;
        expect(sent.bytes, 9 * _mb ~/ 4);
      });

      testWidgets('the Library: Keep original sends it as it was', (
        tester,
      ) async {
        final app = await _open(tester, lang, bytes: 9 * _mb);
        await _tap(tester, _key('space-library'));
        await _tap(tester, _key('library-add-file'));
        await _tap(tester, _key('file-from-phone'));
        await _tap(tester, _key('pdf-offer-keep'));
        await _tap(tester, _key('library-who-add'));
        expect(app.library.filesBySpace[_space]!.single.bytes, 9 * _mb);
      });

      // Space chat and direct messages share the composer.
      testWidgets('a message: the picked PDF offers Make it smaller', (
        tester,
      ) async {
        await pumpApp(
          tester,
          language: lang,
          dm: FakeDmRepository()
            ..pages['t-omar'] = const DmThreadPage(
              threadId: 't-omar',
              person: DmPerson(id: 'p-omar', name: 'Omar Haddad'),
              messages: [],
            ),
          pickDocument: () => _pdf(6 * _mb),
        );
        GoRouter.of(
          tester.element(find.byType(Scaffold).first),
        ).push('/messages/t-omar');
        await tester.pumpAndSettle();
        await _tap(tester, _key('chat-attach'));
        await _tap(tester, find.text(l10n.chatAttachPdf));
        await _tap(tester, _key('chat-picked-smaller-0'));
        expect(find.text(l10n.pdfSmallerWarning), findsOneWidget);
        await _tap(tester, _key('pdf-use-smaller'));
        // 1.5 MB: still offered.
        expect(_key('chat-picked-smaller-0'), findsOneWidget);
        expect(
          find.textContaining(fileSize(l10n, 6 * _mb ~/ 4)),
          findsOneWidget,
        );
      });

      testWidgets("the notebook: an entry's PDF offers Make it smaller", (
        tester,
      ) async {
        final repo = NotebookPageSamples(lang).repository();
        await pumpApp(
          tester,
          language: lang,
          now: NotebookPageSamples.now,
          notebook: repo,
          pickDocument: () => _pdf(5 * _mb),
          stored: {
            'notebook_draft:user-1': jsonEncode(
              NoteDraft(
                id: 'draft-1',
                startedAt: NotebookPageSamples.now,
                title: 'Drawings',
                blocks: [PageText('l-1', 'Rev D came')],
                pageId: NotebookPageSamples.siteA,
              ).toJson(),
            ),
          },
        );
        GoRouter.of(
          tester.element(find.byType(Navigator).first),
        ).push('/notebook/pages/${NotebookPageSamples.siteA}');
        await tester.pumpAndSettle();
        await _tap(tester, _key('note-draft-card-draft-1'));
        await tester.tap(find.text('Rev D came'));
        await tester.pumpAndSettle();
        await _tap(tester, _key('note-tool-add'));
        await _tap(tester, _key('note-add-file'));
        await _tap(tester, _key('note-file-smaller-0'));
        await _tap(tester, _key('pdf-use-smaller'));
        final draft = ProviderScope.containerOf(
          tester.element(find.byType(Scaffold).first),
        ).read(noteDraftProvider)!;
        expect(draft.files.single.bytes, 5 * _mb ~/ 4);
      });
    });

    // The lead's check, D2: over 25 MB in messages and the notebook gets
    // the same sheet as the composer, never a toast.
    group('D2 too large in messages and the notebook [$lang]', () {
      Future<void> dm(WidgetTester tester, FakePdfShrinker shrinker) async {
        await pumpApp(
          tester,
          language: lang,
          dm: FakeDmRepository()
            ..pages['t-omar'] = const DmThreadPage(
              threadId: 't-omar',
              person: DmPerson(id: 'p-omar', name: 'Omar Haddad'),
              messages: [],
            ),
          pickDocument: () => _pdf(38 * _mb),
          shrinker: shrinker,
        );
        GoRouter.of(
          tester.element(find.byType(Scaffold).first),
        ).push('/messages/t-omar');
        await tester.pumpAndSettle();
        await _tap(tester, _key('chat-attach'));
        await _tap(tester, find.text(l10n.chatAttachPdf));
      }

      testWidgets('a message: Make it smaller first; smaller, it is picked', (
        tester,
      ) async {
        await dm(tester, FakePdfShrinker(bytes: 12 * _mb));
        expect(find.text(l10n.chatFileTooBig), findsNothing);
        expect(_key('file-refused-smaller'), findsOneWidget);
        await _tap(tester, _key('file-refused-smaller'));
        await _tap(tester, _key('pdf-use-smaller'));
        expect(find.textContaining(fileSize(l10n, 12 * _mb)), findsOneWidget);
      });

      testWidgets('a message: still too large, nothing is picked', (
        tester,
      ) async {
        await dm(tester, FakePdfShrinker(bytes: 31 * _mb));
        await _tap(tester, _key('file-refused-smaller'));
        expect(find.text(l10n.pdfStillTooLarge('31', '25')), findsOneWidget);
        expect(_key('chat-picked'), findsNothing);
      });

      testWidgets('the notebook: the sheet, then the smaller PDF', (
        tester,
      ) async {
        final repo = NotebookPageSamples(lang).repository();
        await pumpApp(
          tester,
          language: lang,
          now: NotebookPageSamples.now,
          notebook: repo,
          pickDocument: () => _pdf(38 * _mb),
          shrinker: FakePdfShrinker(bytes: 12 * _mb),
          stored: {
            'notebook_draft:user-1': jsonEncode(
              NoteDraft(
                id: 'draft-1',
                startedAt: NotebookPageSamples.now,
                title: 'Drawings',
                blocks: [PageText('l-1', 'Full set')],
                pageId: NotebookPageSamples.siteA,
              ).toJson(),
            ),
          },
        );
        GoRouter.of(
          tester.element(find.byType(Navigator).first),
        ).push('/notebook/pages/${NotebookPageSamples.siteA}');
        await tester.pumpAndSettle();
        await _tap(tester, _key('note-draft-card-draft-1'));
        await tester.tap(find.text('Full set'));
        await tester.pumpAndSettle();
        await _tap(tester, _key('note-tool-add'));
        await _tap(tester, _key('note-add-file'));
        expect(find.text(l10n.chatFileTooBig), findsNothing);
        await _tap(tester, _key('file-refused-smaller'));
        await _tap(tester, _key('pdf-use-smaller'));
        final draft = ProviderScope.containerOf(
          tester.element(find.byType(Scaffold).first),
        ).read(noteDraftProvider)!;
        expect(draft.files.single.bytes, 12 * _mb);
      });
    });
  }
}
