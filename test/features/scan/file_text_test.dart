// Review 103, OCR: "Extract text" («استخرج النص») on a Library file's page
// (a scan, a PDF from a post or a chat, a photo), only when tapped. The
// text shows under the file in a Text section that folds, with Copy; a
// failure says "Couldn't read this file"; 50 pages a day. The extract-text
// function is faked here. In English and Arabic.
import 'package:buildvibes/data/models/library.dart';
import 'package:buildvibes/data/repositories/file_text_repository.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/library_fakes.dart';
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
  _FakeTexts({this.kept, this.text = 'Rebar 16 mm, 4 tonnes', this.fails});

  FileText? kept;
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

Future<void> _open(WidgetTester tester, String lang, _FakeTexts texts) async {
  final s = DaybookSamples(lang);
  await pumpApp(
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
          name: 'Delivery note.pdf',
          path: '$_space/library/f-scan/a.pdf',
          mime: 'application/pdf',
          bytes: 600000,
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
  }
}
