import 'dart:io';

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
}

/// A folder of its own for each test's scans.
Future<String> testScanDir() async =>
    Directory.systemTemp.createTempSync('bv_scans').path;
