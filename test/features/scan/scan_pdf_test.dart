// Review 103: a scan is one PDF of 1–20 pages, made on the phone. Each page
// is a JPEG small enough to send (about 200–300 KB on paper, never over
// 1600 px on its long side) with no location or device data; page 1 also
// becomes a thumbnail. Its name is "Scan · {day} {time}" until changed.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:buildvibes/features/scan/scan.dart';
import 'package:buildvibes/features/work/daybook_words.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:intl/date_symbol_data_local.dart';

/// A page-like photo: white paper with dark lines of "text", 2400 × 3200,
/// with a camera's EXIF, GPS included.
Uint8List _paperPhoto() {
  final page = img.Image(width: 2400, height: 3200);
  img.fill(page, color: img.ColorRgb8(245, 243, 238));
  for (var y = 200; y < 3000; y += 90) {
    img.fillRect(
      page,
      x1: 200,
      y1: y,
      x2: 2200,
      y2: y + 22,
      color: img.ColorRgb8(30, 30, 40),
    );
  }
  page.exif.imageIfd['Make'] = 'PhoneMaker';
  page.exif.gpsIfd['GPSLatitude'] = img.IfdValueRational(29, 1);
  return img.encodeJpg(page, quality: 95);
}

int _pdfPages(Uint8List pdf) =>
    RegExp(r'/Type\s*/Page[^s]').allMatches(latin1.decode(pdf)).length;

void main() {
  setUpAll(() => initializeDateFormatting());

  test('a page: no more than 1600 px long, small, no EXIF or GPS', () {
    final page = scanPage(_paperPhoto());
    final decoded = img.decodeJpg(page)!;
    expect(decoded.height, 1600);
    expect(decoded.width, 1200);
    expect(page.length, lessThan(300 * 1024));
    expect(decoded.exif.isEmpty, isTrue, reason: 'no location or device');
    expect(latin1.decode(page).contains('PhoneMaker'), isFalse);
  });

  test("D20: a page that can't be read fails; never the photo as it came", () {
    expect(
      () => scanPage(Uint8List.fromList(utf8.encode('not a photo'))),
      throwsA(isA<ScanPageUnreadable>()),
    );
  });

  test('D19: at start, a scan nothing waits for goes, with its thumbnail; '
      'one a draft names stays, with its own', () {
    final dir = Directory.systemTemp.createTempSync('bv_scans');
    File named(String name) =>
        File('${dir.path}/$name')..writeAsStringSync('x');
    final waiting = named('a.pdf');
    final waitingThumb = named('a.jpg');
    final left = named('b.pdf');
    final leftThumb = named('b.jpg');
    cleanUpScans(dir, pending: ['{"local": "${waiting.path}"}']);
    expect(waiting.existsSync(), isTrue);
    expect(waitingThumb.existsSync(), isTrue);
    expect(left.existsSync(), isFalse);
    expect(leftThumb.existsSync(), isFalse);
  });

  test('a page already small stays its size', () {
    final small = img.encodeJpg(
      img.Image(width: 800, height: 600),
      quality: 90,
    );
    expect(img.decodeJpg(scanPage(small))!.width, 800);
  });

  test(
    'three pages make one PDF of three pages, and a page 1 thumbnail',
    () async {
      final dir = Directory.systemTemp.createTempSync('bv_scan');
      final pages = [
        for (var i = 0; i < 3; i++)
          (File('${dir.path}/p$i.jpg')..writeAsBytesSync(_paperPhoto())).path,
      ];
      final made = await buildScanPdf(
        pages: pages,
        out: '${dir.path}/scan.pdf',
        thumbOut: '${dir.path}/thumb.jpg',
      );
      final pdf = File('${dir.path}/scan.pdf').readAsBytesSync();
      expect(latin1.decode(pdf.sublist(0, 5)), '%PDF-');
      expect(_pdfPages(pdf), 3);
      expect(made.pages, 3);
      expect(made.bytes, pdf.length);
      expect(made.bytes, lessThan(3 * 300 * 1024));
      final thumb = img.decodeJpg(
        File('${dir.path}/thumb.jpg').readAsBytesSync(),
      )!;
      expect(thumb.height, lessThanOrEqualTo(scanThumbSide));
      expect(latin1.decode(pdf).contains('PhoneMaker'), isFalse);
    },
  );

  for (final lang in ['en', 'ar']) {
    test('the name until it is changed: Scan · day time [$lang]', () {
      final l10n = lookupAppLocalizations(Locale(lang));
      final words = DaybookWords(l10n, lang, use24: false);
      final at = DateTime(2026, 10, 15, 9, 30);
      expect(
        scanName(words, at),
        l10n.scanDefaultName(words.shortDate(at), words.time.clock(at)),
      );
      expect(
        scanName(words, at),
        startsWith(lang == 'en' ? 'Scan · ' : 'مسح · '),
      );
    });
  }
}
