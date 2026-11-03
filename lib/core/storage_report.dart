import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Review 114 B2: one start-up log of what the app keeps on the phone, only
/// in a build made with `--dart-define=BV_STORAGE_LOG=true` (the pilot's).
const storageLogOn = bool.fromEnvironment('BV_STORAGE_LOG');

/// Review 114 B2, the lead's V11. Each top folder of [folders] (name →
/// path) with its size in bytes; each folder under it with the size of the
/// files right in it; then the 20 largest files as their folder (from the
/// top folder), their extension and their size. Never a file's name. A
/// file that can't be read is left out on its own.
List<String> storageReport(Map<String, String> folders) {
  const most = 20;
  final tops = <String, int>{};
  final dirs = <String, int>{};
  final files = <({String folder, String ext, int bytes})>[];
  for (final MapEntry(key: top, value: path) in folders.entries) {
    var total = 0;
    final dir = Directory(path);
    var entries = const <FileSystemEntity>[];
    try {
      if (dir.existsSync()) {
        entries = dir.listSync(recursive: true, followLinks: false);
      }
    } on Object {
      entries = const [];
    }
    for (final f in entries) {
      try {
        if (f is! File) continue;
        final bytes = f.lengthSync();
        final parts = f.uri.pathSegments.where((p) => p.isNotEmpty).toList();
        final rootParts = dir.uri.pathSegments.where((p) => p.isNotEmpty);
        final folder = [
          top,
          ...parts
              .skip(rootParts.length)
              .take(parts.length - rootParts.length - 1),
        ].join('/');
        final name = parts.last;
        final dot = name.lastIndexOf('.');
        files.add((
          folder: folder,
          ext: dot > 0 ? name.substring(dot) : '-',
          bytes: bytes,
        ));
        dirs[folder] = (dirs[folder] ?? 0) + bytes;
        total += bytes;
      } on Object {
        // This file only.
      }
    }
    tops[top] = total;
  }
  files.sort((a, b) => b.bytes.compareTo(a.bytes));
  final folderNames = dirs.keys.toList()..sort();
  return [
    for (final MapEntry(key: top, value: bytes) in tops.entries)
      'storage $top $bytes',
    for (final f in folderNames) 'storage folder $f ${dirs[f]}',
    for (final f in files.take(most))
      'storage top ${f.folder} ${f.ext} ${f.bytes}',
  ];
}

/// Once at start, off the main thread, when [storageLogOn]. A failure only
/// leaves the log without it, and says only what kind of failure it was.
Future<void> logStorageReport() async {
  if (!storageLogOn) return;
  try {
    final folders = {
      'cache': (await getTemporaryDirectory()).path,
      'files': (await getApplicationSupportDirectory()).path,
      'app_flutter': (await getApplicationDocumentsDirectory()).path,
    };
    final lines = await Isolate.run(() => storageReport(folders));
    lines.forEach(debugPrint);
  } on Object catch (e) {
    debugPrint('storage: ${e.runtimeType}');
  }
}
