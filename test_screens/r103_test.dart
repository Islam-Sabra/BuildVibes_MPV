// Review 103 (Scan documents), in English and Arabic at 390 × 844 in the
// app's fonts: SC7 Scan on the composer and notebook bars, SC3 the review
// sheet (and a phone without a scanner), SC4 the scanned file's chip, the
// Library's Add a file, SC6 Photo | Scan on Sign as done; Make it smaller
// (the offer, before → after, too large, still too large); Extract text.
// Run:
//   flutter test test_screens/r103_test.dart --update-goldens
import 'dart:convert';
import 'dart:io';

import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/library.dart';
import 'package:buildvibes/data/models/post_page.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/repositories/file_text_repository.dart';
import 'package:buildvibes/features/notebook/note_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../test/helpers/daybook_fakes.dart';
import '../test/helpers/daybook_samples.dart';
import '../test/helpers/fakes.dart';
import '../test/helpers/library_fakes.dart';
import '../test/helpers/notebook_page_samples.dart';
import '../test/helpers/pump_app.dart';
import '../test/helpers/scan_fakes.dart';
import '../test/helpers/space_fakes.dart';
import 'shot.dart';

const _space = DaybookSamples.space;
const _mb = 1024 * 1024;

Future<void> _snap(WidgetTester tester, String name, String lang) async {
  debugDisableShadows = false;
  try {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byType(MaterialApp).first,
      matchesGoldenFile('../docs/reviews/shots-103/${name}_$lang.png'),
    );
  } finally {
    debugDisableShadows = true;
  }
}

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(_key(key).first);
  await tester.pumpAndSettle();
  await tester.tap(_key(key).first);
  await tester.pumpAndSettle();
}

/// A site photo on disk, as a scanned page.
final String _page = () {
  final dir = Directory.systemTemp.createTempSync('bv_page');
  return (File(
        '${dir.path}/page.jpg',
      )..writeAsBytesSync(File('assets/dev/site_sample.jpg').readAsBytesSync()))
      .path;
}();

class _Texts implements FileTextRepository {
  FileText? kept;

  @override
  Future<FileText?> read(FileTextKind kind, String ref) async => kept;

  @override
  Future<FileText> extract(FileTextKind kind, String ref) async =>
      kept = const FileText(
        text:
            'DELIVERY NOTE 114\nإشعار تسليم\nRebar 16 mm · 4 tonnes\n'
            'Gate 2 · 7:40 am\nReceived by: Omar Haddad',
        lang: 'en',
        pages: 2,
      );
}

Future<TestApp> _open(
  WidgetTester tester,
  String lang, {
  String kind = 'note',
  int pdfBytes = 9 * _mb + 100 * 1024,
  FakeDocumentScanner? scanner,
  FakePdfShrinker? shrinker,
  List<LibraryFile> files = const [],
  FileTextRepository? texts,
  String? me,
  SpacePass pass = SpacePass.lead,
  List<DaybookCard> posts = const [],
}) async {
  final s = DaybookSamples(lang);
  final app = await pumpApp(
    tester,
    language: lang,
    composerKind: kind,
    auth: me == null
        ? null
        : FakeAuthRepository(userId: me, phone: '+96550000001'),
    scanner: scanner ?? FakeDocumentScanner(pages: List.filled(3, _page)),
    shrinker: shrinker,
    fileTexts: texts,
    pickDocument: () => PhoneFile(
      local: testPdfPath,
      name: 'A-501 Rev D.pdf',
      mime: 'application/pdf',
      bytes: pdfBytes,
    ),
    spaces: FakeSpaceRepository()
      ..details[_space] = s.detail(pass: pass, addFiles: true)
      ..spacePeople[_space] = s.people(),
    daybook: FakeDaybookRepository()..posts[_space] = posts,
    library: FakeLibraryRepository(now: DaybookSamples.thursday)
      ..filesBySpace[_space] = List.of(files),
    now: DaybookSamples.thursday,
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/$_space');
  await tester.pumpAndSettle();
  return app;
}

void main() {
  setUpAll(loadAppFonts);

  for (final lang in ['en', 'ar']) {
    final s = DaybookSamples(lang);

    testWidgets('SC7 Scan on the composer bar [$lang]', (tester) async {
      await _open(tester, lang);
      await _tap(tester, 'post-bar-notepad');
      steadyCursor();
      await tester.pumpAndSettle();
      await _snap(tester, 'SC7-composer-bar', lang);
    });

    testWidgets('SC3 the review sheet [$lang]', (tester) async {
      await _open(tester, lang);
      await _tap(tester, 'post-bar-notepad');
      await _tap(tester, 'writing-scan');
      // The page photos stay blank here: a file image can't be decoded in
      // this test runner (it waits forever).
      await _snap(tester, 'SC3-review', lang);
      await tester.enterText(
        _key('scan-name'),
        s.t('Delivery note 114', 'إشعار تسليم 114'),
      );
      await _tap(tester, 'scan-add');
      await tester.enterText(
        _key('writing-title'),
        s.t('Rebar delivered', 'وصل الحديد'),
      );
      steadyCursor();
      await tester.pumpAndSettle();
      await _snap(tester, 'SC4-composer-file', lang);
    });

    testWidgets('SC3 a phone without a document scanner [$lang]', (
      tester,
    ) async {
      await _open(
        tester,
        lang,
        scanner: FakeDocumentScanner(pages: const [], hasScanner: false),
      );
      await _tap(tester, 'post-bar-notepad');
      await _tap(tester, 'writing-scan');
      await _snap(tester, 'SC3-no-scanner', lang);
    });

    testWidgets('the Library: Add a file [$lang]', (tester) async {
      await _open(tester, lang);
      await _tap(tester, 'space-library');
      await _tap(tester, 'library-add-file');
      await _snap(tester, 'LB1-add-a-file', lang);
    });

    testWidgets('SC6 Sign as done: Photo | Scan [$lang]', (tester) async {
      await _open(
        tester,
        lang,
        posts: s.o1(),
        me: DaybookSamples.omar,
        pass: SpacePass.crew,
      );
      await tester.tap(
        find.text(lang == 'en' ? 'Sign as done' : 'وقّع كمنجز').first,
      );
      await tester.pumpAndSettle();
      await _snap(tester, 'SC6-proof-photo', lang);
      await _tap(tester, 'proof-mode-scan');
      await _snap(tester, 'SC6-proof-scan', lang);
    });

    testWidgets('MS Make it smaller: the offer, before → after [$lang]', (
      tester,
    ) async {
      await _open(
        tester,
        lang,
        shrinker: FakePdfShrinker(bytes: 2 * _mb + 300 * 1024),
      );
      await _tap(tester, 'post-bar-notepad');
      await tester.enterText(_key('writing-title'), 'A-501');
      await _tap(tester, 'writing-add');
      await _tap(tester, 'composer-extra-file');
      await _tap(tester, 'attach-file');
      steadyCursor();
      await tester.pumpAndSettle();
      await _snap(tester, 'MS1-offer', lang);
      await _tap(tester, 'writing-file-smaller-0');
      await _snap(tester, 'MS2-before-after', lang);
    });

    testWidgets('MS too large, then still too large [$lang]', (tester) async {
      await _open(
        tester,
        lang,
        pdfBytes: 60 * _mb,
        shrinker: FakePdfShrinker(bytes: 31 * _mb),
      );
      await _tap(tester, 'post-bar-notepad');
      await tester.enterText(_key('writing-title'), 'A-501 full set');
      await _tap(tester, 'writing-add');
      await _tap(tester, 'composer-extra-file');
      await _tap(tester, 'attach-file');
      await _snap(tester, 'MS3-too-large', lang);
      await _tap(tester, 'file-refused-smaller');
      await _snap(tester, 'MS4-still-too-large', lang);
    });

    testWidgets('TX Extract text [$lang]', (tester) async {
      final texts = _Texts();
      await _open(
        tester,
        lang,
        texts: texts,
        files: [
          LibraryFile(
            id: 'f-scan',
            spaceId: _space,
            name: s.t('Delivery note 114.pdf', 'إشعار تسليم 114.pdf'),
            path: '$_space/library/f-scan/a.pdf',
            mime: 'application/pdf',
            bytes: 640000,
            createdAt: DaybookSamples.thursday,
            scanned: true,
            pageCount: 2,
          ),
        ],
      );
      GoRouter.of(
        tester.element(find.byType(Navigator).first),
      ).push('/spaces/$_space/library/f-scan/page');
      await tester.pumpAndSettle();
      await _snap(tester, 'TX1-extract-text', lang);
      await _tap(tester, 'file-extract-text');
      await _snap(tester, 'TX2-text', lang);
    });

    testWidgets('SC7 Scan on the notebook bar [$lang]', (tester) async {
      await pumpApp(
        tester,
        language: lang,
        now: NotebookPageSamples.now,
        notebook: NotebookPageSamples(lang).repository(),
        stored: {
          'notebook_draft:user-1': jsonEncode(
            NoteDraft(
              id: 'draft-1',
              startedAt: NotebookPageSamples.now,
              title: s.t('Delivery', 'التسليم'),
              blocks: [PageText('l-1', s.t('Rebar arrived', 'وصل الحديد'))],
              pageId: NotebookPageSamples.siteA,
            ).toJson(),
          ),
        },
      );
      GoRouter.of(
        tester.element(find.byType(Navigator).first),
      ).push('/notebook/pages/${NotebookPageSamples.siteA}');
      await tester.pumpAndSettle();
      await _tap(tester, 'note-draft-card-draft-1');
      await tester.tap(find.text(s.t('Rebar arrived', 'وصل الحديد')));
      steadyCursor();
      await tester.pumpAndSettle();
      await _snap(tester, 'SC7-notebook-bar', lang);
    });
  }
}
