import 'dart:io';

import 'package:buildvibes/data/repositories/file_text_repository.dart';
import 'package:buildvibes/features/scan/pdf_smaller.dart';
import 'package:buildvibes/features/scan/scan.dart';

/// The phone's document scanner in tests (review 103): [pages] page images
/// each time it is opened, or nothing when [cancel]; [hasScanner] false is a
/// phone without Google Play services (the app's camera takes the pages).
class FakeDocumentScanner implements DocumentScanner {
  FakeDocumentScanner({
    required this.pages,
    this.hasScanner = true,
    this.cancel = false,
  });

  final List<String> pages;
  bool hasScanner;
  bool cancel;

  /// How many times it was opened, and with what page limit.
  final opened = <int>[];

  @override
  Future<bool> available() async => hasScanner;

  @override
  Future<List<String>?> scan({required int maxPages}) async {
    opened.add(maxPages);
    return cancel ? null : List.of(pages);
  }

  /// The lead's check, D19: the pages it was told to clean up, each time.
  final finished = <List<String>>[];

  @override
  Future<void> finish(List<String> pages) async => finished.add(pages);
}

/// A folder of its own for each test's scans.
Future<String> testScanDir() async =>
    Directory.systemTemp.createTempSync('bv_scans').path;

/// Make it smaller in tests (review 103): writes a copy and says it came
/// to [bytes] (by default a quarter of [inBytes]); [calls] counts them.
class FakePdfShrinker {
  FakePdfShrinker({this.bytes, this.progress, this.hold});

  /// The size the smaller PDF comes to; null: a quarter.
  int? bytes;

  /// Said as it works (page, of how many), then it waits for [hold].
  final (int, int)? progress;
  final Future<void>? hold;
  final calls = <String>[];

  Future<ShrunkPdf?> call({
    required String input,
    required String out,
    required int inBytes,
    PdfPageDone? onPage,
  }) async {
    calls.add(input);
    if (progress case (final page, final total)) onPage?.call(page, total);
    if (hold case final hold?) await hold;
    File(out).writeAsBytesSync(File(input).readAsBytesSync());
    return (bytes: bytes ?? inBytes ~/ 4, pages: 1);
  }
}

/// Extract text in tests that don't use it: nothing read, nothing to read.
class NoFileTexts implements FileTextRepository {
  const NoFileTexts();

  /// Extract text is on (D25), so screens show its button.
  @override
  Future<bool> available() async => true;

  @override
  Future<FileText?> read(FileTextKind kind, String ref) async => null;

  @override
  Future<FileText> extract(FileTextKind kind, String ref) async =>
      throw const FileTextException(FileTextFailure.failed);
}
