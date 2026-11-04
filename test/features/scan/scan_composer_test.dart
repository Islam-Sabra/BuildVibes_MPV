// Review 103 SC7, SC3: Scan has its own button on the Space composer's bar,
// right after the camera (+ · camera · Scan · mic · Send). The phone's
// scanner gives pages; the review sheet shows "3 pages", the page strip,
// Scan more pages, the name (Scan · day time), ✕ Cancel (asked once) and
// Add. Add puts one PDF on the post as a file marked scanned. Over the
// Space's file limit, Add is off with "Too large: remove some pages". A
// phone without Google Play services takes pages with the app's camera,
// and says so. In English and Arabic.
import 'dart:convert';
import 'dart:io';

import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/scan/scan.dart';
import 'package:buildvibes/features/work/daybook_draft.dart';
import 'package:buildvibes/features/work/daybook_words.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/scan_fakes.dart';
import '../../helpers/space_fakes.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

Future<TestApp> _compose(
  WidgetTester tester,
  String lang, {
  String kind = 'note',
  FakeDocumentScanner? scanner,
  ScanPdfBuilder? scanBuilder,
}) async {
  final s = DaybookSamples(lang);
  final app = await pumpApp(
    tester,
    language: lang,
    composerKind: kind,
    scanner: scanner,
    spaces: FakeSpaceRepository()
      ..details[DaybookSamples.space] = s.detail(pass: SpacePass.lead)
      ..spacePeople[DaybookSamples.space] = s.people(),
    daybook: FakeDaybookRepository()..posts[DaybookSamples.space] = const [],
    now: DaybookSamples.thursday,
    scanBuilder: scanBuilder,
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/${DaybookSamples.space}');
  await tester.pumpAndSettle();
  await _tap(tester, _key('post-bar-notepad'));
  return app;
}

DaybookPostDraft? _draft(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(Navigator).first),
).read(daybookDraftProvider(DaybookSamples.space));

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    final rtl = lang == 'ar';

    group('SC7 Scan on the composer bar [$lang]', () {
      testWidgets('right after the camera, before the mic', (tester) async {
        await _compose(tester, lang);
        double x(String k) => tester.getCenter(_key(k)).dx;
        final camera = x('writing-camera');
        final scan = x('writing-scan');
        final mic = x('writing-mic');
        if (rtl) {
          expect(scan, lessThan(camera));
          expect(mic, lessThan(scan));
        } else {
          expect(scan, greaterThan(camera));
          expect(mic, greaterThan(scan));
        }
      });

      testWidgets('not on a kind that takes no file (Thanks)', (tester) async {
        await _compose(tester, lang, kind: 'thanks');
        expect(_key('writing-scan'), findsNothing);
      });
    });

    group('SC3 the review sheet [$lang]', () {
      testWidgets('3 pages, the strip, the name; renamed, Add puts one '
          'scanned PDF on the post', (tester) async {
        final scanner = FakeDocumentScanner(
          pages: List.filled(3, testPhotoPath),
        );
        await _compose(tester, lang, scanner: scanner);
        await _tap(tester, _key('writing-scan'));
        expect(scanner.opened, [scanPagesMax]);
        expect(_key('scan-review'), findsOneWidget);
        expect(find.text(l10n.scanReviewTitle), findsOneWidget);
        expect(find.text(l10n.scanPages(3)), findsOneWidget);
        for (var i = 0; i < 3; i++) {
          expect(_key('scan-page-$i'), findsOneWidget);
        }
        final words = DaybookWords(l10n, lang, use24: false);
        final name = tester.widget<TextField>(_key('scan-name'));
        expect(name.controller!.text, scanName(words, DaybookSamples.thursday));
        await tester.enterText(_key('scan-name'), 'Delivery note 114');
        await _tap(tester, _key('scan-add'));
        expect(_key('scan-review'), findsNothing);
        final file = _draft(tester)!.files.single;
        expect(file.name, 'Delivery note 114.pdf');
        expect(file.mime, 'application/pdf');
        expect(file.scanned, isTrue);
        expect(file.pages, 3);
        final pdf = File(file.local!).readAsBytesSync();
        expect(latin1.decode(pdf.sublist(0, 5)), '%PDF-');
        expect(file.bytes, pdf.length);
        // SC4: the composer's chip says it was scanned.
        expect(
          find.textContaining(l10n.scannedPages(l10n.scanPages(3))),
          findsOneWidget,
        );
      });

      testWidgets('✕ on a page takes it off; Scan more pages adds', (
        tester,
      ) async {
        final scanner = FakeDocumentScanner(
          pages: List.filled(2, testPhotoPath),
        );
        await _compose(tester, lang, scanner: scanner);
        await _tap(tester, _key('writing-scan'));
        await _tap(tester, _key('scan-page-remove-1'));
        expect(find.text(l10n.scanPages(1)), findsOneWidget);
        await _tap(tester, _key('scan-more'));
        expect(scanner.opened, hasLength(2));
        expect(find.text(l10n.scanPages(3)), findsOneWidget);
      });

      testWidgets('Cancel asks once; Discard leaves nothing', (tester) async {
        await _compose(tester, lang);
        await _tap(tester, _key('writing-scan'));
        await _tap(tester, _key('scan-cancel'));
        expect(find.text(l10n.scanDiscardTitle), findsOneWidget);
        await _tap(tester, _key('bv-dialog-cancel'));
        expect(_key('scan-review'), findsOneWidget, reason: 'Keep scanning');
        await _tap(tester, _key('scan-cancel'));
        await _tap(tester, _key('bv-dialog-confirm'));
        expect(_key('scan-review'), findsNothing);
        expect(_draft(tester)?.files ?? const [], isEmpty);
      });

      testWidgets('a cancelled scanner opens no sheet', (tester) async {
        await _compose(
          tester,
          lang,
          scanner: FakeDocumentScanner(pages: const [], cancel: true),
        );
        await _tap(tester, _key('writing-scan'));
        expect(_key('scan-review'), findsNothing);
      });

      testWidgets('over the Space\'s limit: Add is off, "Too large"', (
        tester,
      ) async {
        await _compose(
          tester,
          lang,
          scanBuilder:
              ({required pages, required out, required thumbOut}) async {
                await buildScanPdf(pages: pages, out: out, thumbOut: thumbOut);
                return (pages: pages.length, bytes: 30 * 1024 * 1024);
              },
        );
        await _tap(tester, _key('writing-scan'));
        expect(find.text(l10n.scanTooLarge), findsOneWidget);
        await _tap(tester, _key('scan-add'));
        expect(_key('scan-review'), findsOneWidget, reason: 'Add is off');
        expect(_draft(tester)?.files ?? const [], isEmpty);
      });

      testWidgets('no document scanner: the camera takes pages, and says so', (
        tester,
      ) async {
        final scanner = FakeDocumentScanner(pages: const [], hasScanner: false);
        final app = await _compose(tester, lang, scanner: scanner);
        await _tap(tester, _key('writing-scan'));
        expect(scanner.opened, isEmpty);
        expect(app.cameraAsks, [true]);
        expect(find.text(l10n.scanNoScanner), findsOneWidget);
        expect(find.text(l10n.scanPages(1)), findsOneWidget);
        expect(find.text(l10n.scanAddPage), findsOneWidget);
        await _tap(tester, _key('scan-more'));
        expect(app.cameraAsks, [true, true]);
        await _tap(tester, _key('scan-add'));
        final file = _draft(tester)!.files.single;
        expect(file.pages, 2);
        expect(file.scanned, isTrue);
      });
    });
  }
}
