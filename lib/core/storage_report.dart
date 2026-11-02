import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'config/feature_switches.dart';

/// Review 114 B2: what the app keeps on the phone. Each folder of [folders]
/// (name → path) with its size in bytes, then the 20 largest files: folder,
/// file name and size, nothing else.
List<String> storageReport(Map<String, String> folders) {
  const most = 20;
  final sizes = <String, int>{};
  final files = <({String folder, String name, int bytes})>[];
  for (final MapEntry(key: folder, value: path) in folders.entries) {
    var total = 0;
    final dir = Directory(path);
    if (dir.existsSync()) {
      for (final f in dir.listSync(recursive: true, followLinks: false)) {
        if (f is! File) continue;
        final bytes = f.lengthSync();
        total += bytes;
        files.add((
          folder: folder,
          name: f.uri.pathSegments.last,
          bytes: bytes,
        ));
      }
    }
    sizes[folder] = total;
  }
  files.sort((a, b) => b.bytes.compareTo(a.bytes));
  return [
    for (final MapEntry(key: folder, value: bytes) in sizes.entries)
      'storage $folder $bytes',
    for (final f in files.take(most))
      'storage top ${f.folder} ${f.name} ${f.bytes}',
  ];
}

/// Once at start, off the main thread, when [storageLogEnabled]. A failure
/// only leaves the log without it.
Future<void> logStorageReport() async {
  if (!storageLogEnabled) return;
  try {
    final folders = {
      'cache': (await getTemporaryDirectory()).path,
      'files': (await getApplicationSupportDirectory()).path,
      'app_flutter': (await getApplicationDocumentsDirectory()).path,
    };
    final lines = await Isolate.run(() => storageReport(folders));
    lines.forEach(debugPrint);
  } on Object catch (e) {
    debugPrint('storage: $e');
  }
}
