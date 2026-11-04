import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../work/daybook_words.dart';

/// Review 103: the most pages one scan holds.
const scanPagesMax = 20;

/// A page's long side, in pixels: text stays readable, a page stays about
/// 200–300 KB.
const scanPageSide = 1600;

/// A page's JPEG quality.
const scanPageQuality = 60;

/// Page 1's thumbnail for cards, proofs and lists: its long side, sharp
/// across a phone's screen (a card shows it full width).
const scanThumbSide = 1000;

/// The lead's check, D10: where a scan's page 1 thumbnail is on the phone,
/// beside its PDF ([pdf] with .jpg for .pdf).
String scanThumbFor(String pdf) =>
    '${pdf.substring(0, pdf.length - '.pdf'.length)}.jpg';

/// The thumbnail beside [pdf], when the phone still has it.
String? scanThumbOf(String pdf) {
  if (!pdf.toLowerCase().endsWith('.pdf')) return null;
  final thumb = scanThumbFor(pdf);
  return File(thumb).existsSync() ? thumb : null;
}

/// The phone's own document scanner (Google's on Android, Apple's on
/// iPhone), or none: then the app's camera takes pages one by one.
abstract interface class DocumentScanner {
  /// Whether the phone has one (Google Play services on Android).
  Future<bool> available();

  /// Page images on the phone, in order; null when the scan was cancelled.
  Future<List<String>?> scan({required int maxPages});

  /// The lead's check, D19: [pages] are a PDF that was added, or were
  /// discarded: they leave the phone.
  Future<void> finish(List<String> pages);
}

class PhoneDocumentScanner implements DocumentScanner {
  const PhoneDocumentScanner();

  /// MainActivity.kt answers whether Google Play services are there.
  static const _channel = MethodChannel('buildvibes/scan');

  @override
  Future<bool> available() async {
    if (!Platform.isAndroid) return Platform.isIOS;
    try {
      return await _channel.invokeMethod<bool>('hasDocumentScanner') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<List<String>?> scan({required int maxPages}) async {
    try {
      return await CunningDocumentScanner.getPictures(noOfPages: maxPages);
    } on CunningDocumentScannerException {
      return null;
    }
  }

  @override
  Future<void> finish(List<String> pages) async {
    for (final page in pages) {
      try {
        File(page).deleteSync();
      } on FileSystemException {
        // Already gone.
      }
    }
    await cleanUp();
  }

  /// The scanner's own pages (its DOCUMENT_SCAN_ files), at app start too.
  static Future<void> cleanUp() async {
    try {
      await CunningDocumentScanner.cleanCache();
    } on Object catch (e) {
      debugPrint('scan clean-up: ${e.runtimeType}');
    }
  }
}

/// The lead's check, D19, at app start: a scan in [scans] that nothing
/// waiting on the phone names ([pending]: drafts, outboxes) goes, with its
/// thumbnail. A waiting one keeps its own.
void cleanUpScans(Directory scans, {required Iterable<String> pending}) {
  String plain(String s) => s.replaceAll(r'\\', '/').replaceAll(r'\', '/');
  final held = plain(pending.join('\n'));
  bool named(String path) => held.contains(plain(path));
  if (!scans.existsSync()) return;
  for (final f in scans.listSync().whereType<File>()) {
    final path = f.path;
    final lower = path.toLowerCase();
    final pdf = lower.endsWith('.jpg')
        ? '${path.substring(0, path.length - '.jpg'.length)}.pdf'
        : path;
    if (named(path) || named(pdf)) continue;
    try {
      f.deleteSync();
    } on FileSystemException {
      // In use; next start.
    }
  }
}

/// The lead's check, D19: a copy of a scan (or of its smaller copy) the
/// place took its own copy of ([kept]) goes, with its thumbnail.
void dropScanCopy(String scan, {required String kept}) {
  if (scan == kept) return;
  for (final p in [scan, ?scanThumbOf(scan)]) {
    try {
      File(p).deleteSync();
    } on FileSystemException {
      // Already gone.
    }
  }
}

/// Tests stand in for the phone's scanner.
final documentScannerProvider = Provider<DocumentScanner>(
  (ref) => const PhoneDocumentScanner(),
);

/// Where scans are made and kept until they are sent.
final scanDirProvider = Provider<Future<String> Function()>(
  (ref) => () async {
    final dir = Directory(
      '${(await getApplicationDocumentsDirectory()).path}/scans',
    );
    await dir.create(recursive: true);
    return dir.path;
  },
);

/// A scan made into one PDF: [pages] pages, [bytes] long.
typedef MadeScan = ({int pages, int bytes});

/// Makes the PDF; on the phone away from the screen's work (an isolate),
/// in tests at once.
typedef ScanPdfBuilder =
    Future<MadeScan> Function({
      required List<String> pages,
      required String out,
      required String thumbOut,
    });

final scanPdfBuilderProvider = Provider<ScanPdfBuilder>(
  (ref) =>
      ({required pages, required out, required thumbOut}) => Isolate.run(
        () => buildScanPdf(pages: pages, out: out, thumbOut: thumbOut),
      ),
);

/// The lead's check, D20: a page the phone can't read. The scan fails;
/// the photo never goes as it came, with its EXIF.
class ScanPageUnreadable implements Exception {
  const ScanPageUnreadable();
}

/// One page as it goes in the PDF: upright, at most [scanPageSide] long,
/// JPEG at [scanPageQuality], with no EXIF at all (no location, no phone).
/// Throws [ScanPageUnreadable] for one it can't read.
Uint8List scanPage(Uint8List photo) {
  final img.Image? decoded;
  try {
    decoded = img.decodeImage(photo);
  } on Object {
    throw const ScanPageUnreadable();
  }
  if (decoded == null) throw const ScanPageUnreadable();
  var page = img.bakeOrientation(decoded);
  final long = math.max(page.width, page.height);
  if (long > scanPageSide) {
    page = page.width >= page.height
        ? img.copyResize(page, width: scanPageSide)
        : img.copyResize(page, height: scanPageSide);
  }
  page.exif = img.ExifData();
  return img.encodeJpg(page, quality: scanPageQuality);
}

/// The PDF of [pages] (page images on the phone) at [out], each page sized
/// to its image, and page 1's thumbnail at [thumbOut]. Plain file reads and
/// writes: it runs in an isolate on the phone.
Future<MadeScan> buildScanPdf({
  required List<String> pages,
  required String out,
  required String thumbOut,
}) async {
  final doc = pw.Document(compress: true);
  for (final (i, path) in pages.indexed) {
    final jpeg = scanPage(File(path).readAsBytesSync());
    final size = img.decodeJpg(jpeg)!;
    if (i == 0) {
      final thumb = size.width >= size.height
          ? img.copyResize(size, width: scanThumbSide)
          : img.copyResize(size, height: scanThumbSide);
      File(thumbOut).writeAsBytesSync(img.encodeJpg(thumb, quality: 70));
    }
    // An A4-wide page, as tall as the paper is.
    final width = PdfPageFormat.a4.width;
    final height = width * size.height / size.width;
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(width, height),
        build: (_) => pw.Image(pw.MemoryImage(jpeg), fit: pw.BoxFit.fill),
      ),
    );
  }
  final bytes = await doc.save();
  File(out).writeAsBytesSync(bytes);
  return (pages: pages.length, bytes: bytes.length);
}

/// "Scan · Thu 15 Oct 9:30 am": a scan's name until it is changed.
String scanName(DaybookWords words, DateTime at) =>
    words.l10n.scanDefaultName(words.shortDate(at), words.time.clock(at));
