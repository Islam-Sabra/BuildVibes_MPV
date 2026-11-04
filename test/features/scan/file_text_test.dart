// Review 103, OCR: "Extract text" («استخرج النص») on a Library file's page
// (a scan, a PDF from a post or a chat, a photo), only when tapped. The
// text shows under the file in a Text section that folds, with Copy; a
// failure says "Couldn't read this file"; 50 pages a day. The extract-text
// function is faked here. In English and Arabic.
import 'package:buildvibes/core/l10n/bidi.dart';
import 'package:buildvibes/data/models/library.dart';
import 'package:buildvibes/data/models/note.dart';
import 'package:buildvibes/data/repositories/file_text_repository.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/library_fakes.dart';
import '../../helpers/notebook_fakes.dart';
import '../../helpers/notebook_samples.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

const _space = DaybookSamples.space;

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

/// The fake extract-text: [text] after a tap, or [fails].
class _FakeTexts implements FileTextRepository {
  _FakeTexts({
    this.kept,
    this.text = 'Rebar 16 mm, 4 tonnes',
    this.fails,
    this.on = true,
    this.flagFails = false,
  });

  FileText? kept;

  /// D25: ocr_available(), or it fails ([flagFails]).
  final bool on;
  final bool flagFails;
  var flagAsked = 0;

  @override
  Future<bool> available() async {
    flagAsked++;
    if (flagFails) throw Exception('no signal');
    return on;
  }

  final String text;
  final FileTextFailure? fails;
  final asked = <String>[];

  @override
  Future<FileText?> read(FileTextKind kind, String ref) async => kept;

  @override
  Future<FileText> extract(FileTextKind kind, String ref) async {
    asked.add('${kind.json} $ref');
    if (fails case final f?) throw FileTextException(f);
    return kept = FileText(text: text, lang: 'en', pages: 2);
  }
}

Future<TestApp> _open(
  WidgetTester tester,
  String lang,
  _FakeTexts texts, {
  int bytes = 600000,
  String name = 'Delivery note.pdf',
}) async {
  final s = DaybookSamples(lang);
  final app = await pumpApp(
    tester,
    language: lang,
    spaces: FakeSpaceRepository()
      ..details[_space] = s.detail(addFiles: true)
      ..spacePeople[_space] = s.people(),
    daybook: FakeDaybookRepository()..posts[_space] = const [],
    library: FakeLibraryRepository(now: DaybookSamples.thursday)
      ..filesBySpace[_space] = [
        LibraryFile(
          id: 'f-scan',
          spaceId: _space,
          name: name,
          path: '$_space/library/f-scan/a.pdf',
          mime: 'application/pdf',
          bytes: bytes,
          createdAt: DaybookSamples.thursday,
          scanned: true,
          pageCount: 2,
        ),
      ],
    fileTexts: texts,
    now: DaybookSamples.thursday,
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/$_space/library/f-scan/page');
  await tester.pumpAndSettle();
  return app;
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));

    testWidgets('Extract text only on a tap; the text under the file, with '
        'Copy [$lang]', (tester) async {
      final texts = _FakeTexts();
      await _open(tester, lang, texts);
      expect(texts.asked, isEmpty, reason: 'never automatic');
      expect(find.text(l10n.fileExtractText), findsOneWidget);
      await _tap(tester, _key('file-extract-text'));
      expect(texts.asked, ['library f-scan']);
      expect(find.text(l10n.fileTextTitle), findsOneWidget);
      expect(find.text('Rebar 16 mm, 4 tonnes'), findsOneWidget);
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      await _tap(tester, _key('file-text-copy'));
      expect(copied, 'Rebar 16 mm, 4 tonnes');
      // The section folds.
      await _tap(tester, _key('file-text-toggle'));
      expect(find.text('Rebar 16 mm, 4 tonnes'), findsNothing);
    });

    testWidgets('already read: the text is there, no button [$lang]', (
      tester,
    ) async {
      final texts = _FakeTexts(
        kept: const FileText(text: 'Permit 22, valid to Friday', pages: 1),
      );
      await _open(tester, lang, texts);
      expect(_key('file-extract-text'), findsNothing);
      expect(find.text('Permit 22, valid to Friday'), findsOneWidget);
    });

    testWidgets('a failure: "Couldn\'t read this file"; the day\'s limit '
        'says so [$lang]', (tester) async {
      await _open(tester, lang, _FakeTexts(fails: FileTextFailure.failed));
      await _tap(tester, _key('file-extract-text'));
      expect(find.text(l10n.fileTextFailed), findsOneWidget);
      expect(_key('file-extract-text'), findsOneWidget, reason: 'try again');
    });

    testWidgets('50 pages a day [$lang]', (tester) async {
      await _open(tester, lang, _FakeTexts(fails: FileTextFailure.dailyLimit));
      await _tap(tester, _key('file-extract-text'));
      expect(find.text(l10n.fileTextLimit), findsOneWidget);
    });

    testWidgets('read, but no words: says so [$lang]', (tester) async {
      await _open(tester, lang, _FakeTexts(text: ''));
      await _tap(tester, _key('file-extract-text'));
      expect(find.text(l10n.fileTextEmpty), findsOneWidget);
    });

    // The lead's check, D3: a file over 20 pages says it is only a part.
    testWidgets('D3: the first 20 pages say so [$lang]', (tester) async {
      await _open(
        tester,
        lang,
        _FakeTexts(
          kept: const FileText(
            text: 'Spec section 03',
            pages: 20,
            partial: true,
          ),
        ),
      );
      expect(find.text(l10n.fileTextPartial), findsOneWidget);
    });

    // D7: over 10 MB the function says so before reading; the file page
    // offers Make it smaller, which sends a smaller new version.
    testWidgets('D7: too large to read: Make it smaller sends a smaller '
        'version [$lang]', (tester) async {
      final app = await _open(
        tester,
        lang,
        _FakeTexts(fails: FileTextFailure.tooLarge),
        bytes: 14 * 1024 * 1024,
      );
      await _tap(tester, _key('file-extract-text'));
      expect(find.text(l10n.fileTextTooLarge), findsOneWidget);
      // The file is downloaded and written on the phone: real time.
      await tester.runAsync(() async {
        await tester.tap(_key('file-text-smaller'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      await _tap(tester, _key('pdf-use-smaller'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();
      expect(
        app.library.calls.where((c) => c.contains('supersedes:f-scan')),
        hasLength(1),
      );
    });

    // D9: a PDF on a note reads too, as the note's file.
    testWidgets('D9: Extract text on a notebook PDF [$lang]', (tester) async {
      final texts = _FakeTexts();
      await pumpApp(
        tester,
        language: lang,
        now: NotebookSamples.now,
        notebook: FakeNotebookRepository(
          notes: [
            Note(
              id: 'note-pdf',
              kind: NoteKind.text,
              body: 'Rebar delivery',
              files: const [
                NoteFile(path: 'user-1/note-pdf/a.pdf', name: 'Note.pdf'),
              ],
              createdAt: DateTime(2026, 10, 15, 9),
            ),
          ],
        ),
        fileTexts: texts,
      );
      GoRouter.of(
        tester.element(find.byType(Navigator).first),
      ).push('/notebook/pages/page-my-notes');
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Rebar delivery'));
      await _tap(tester, _key('file-extract-text'));
      expect(texts.asked, ['note user-1/note-pdf/a.pdf']);
      expect(find.text('Rebar 16 mm, 4 tonnes'), findsOneWidget);
    });

    // D17, seen on the emulator: the file's page title keeps an Arabic
    // name whole, «… عصرًا.pdf», never «pdf.».
    testWidgets("D17: the file page's title keeps the name whole [$lang]", (
      tester,
    ) async {
      await _open(tester, lang, _FakeTexts(), name: 'مسح 114.pdf');
      expect(find.text(fileTitle('مسح 114.pdf')), findsOneWidget);
    });

    // D25 (founder): Extract text hidden until the Google trial starts,
    // from the server, with no build needed to turn it on.
    testWidgets('D25: off: no button, no space [$lang]', (tester) async {
      final texts = _FakeTexts(on: false);
      await _open(tester, lang, texts);
      expect(_key('file-extract-text'), findsNothing);
      expect(_key('file-text'), findsNothing);
      expect(texts.flagAsked, 1);
    });

    testWidgets("D25: the flag can't be read: hidden [$lang]", (tester) async {
      await _open(tester, lang, _FakeTexts(flagFails: true));
      expect(_key('file-extract-text'), findsNothing);
      expect(_key('file-text'), findsNothing);
    });

    testWidgets('D25: on: the button [$lang]', (tester) async {
      await _open(tester, lang, _FakeTexts());
      expect(_key('file-extract-text'), findsOneWidget);
    });

    testWidgets('D25: off, a text already kept still shows, with Copy '
        '[$lang]', (tester) async {
      await _open(
        tester,
        lang,
        _FakeTexts(
          on: false,
          kept: const FileText(text: 'Permit 22, valid to Friday', pages: 1),
        ),
      );
      expect(find.text('Permit 22, valid to Friday'), findsOneWidget);
      expect(_key('file-text-copy'), findsOneWidget);
    });

    testWidgets('D25: off, a notebook PDF has no button either [$lang]', (
      tester,
    ) async {
      await pumpApp(
        tester,
        language: lang,
        now: NotebookSamples.now,
        notebook: FakeNotebookRepository(
          notes: [
            Note(
              id: 'note-pdf',
              kind: NoteKind.text,
              body: 'Rebar delivery',
              files: const [
                NoteFile(path: 'user-1/note-pdf/a.pdf', name: 'Note.pdf'),
              ],
              createdAt: DateTime(2026, 10, 15, 9),
            ),
          ],
        ),
        fileTexts: _FakeTexts(on: false),
      );
      GoRouter.of(
        tester.element(find.byType(Navigator).first),
      ).push('/notebook/pages/page-my-notes');
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Rebar delivery'));
      expect(_key('file-extract-text'), findsNothing);
    });
  }
}
