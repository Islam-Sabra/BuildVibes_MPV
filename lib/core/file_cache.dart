import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../data/repositories/library_repository.dart';

/// Review 114 B2: one copy on the phone of each stored file. A storage
/// path never changes for a version, so it names its copy:
/// `cache/bv_files/<hash>.<ext>`, downloaded once. A PDF's first page,
/// drawn once, is kept beside it in `cache/bv_thumbs/<hash>.png`. Both stay
/// under [maxBytes]: [trim], at start, lets the least recently used go.
class FileCache {
  FileCache({
    required this.root,
    required this.download,
    this.maxBytes = defaultMaxBytes,
  });

  /// 200 MB, the lead's cap for the copies and the first pages together.
  static const defaultMaxBytes = 200 * 1024 * 1024;

  final Future<Directory> Function() root;
  final Future<Uint8List> Function(String path) download;
  final int maxBytes;

  final _loading = <String, Future<File>>{};

  /// The phone's copy of [storagePath], downloaded the first time.
  Future<File> file(String storagePath) =>
      _loading[storagePath] ??= _file(storagePath).whenComplete(() {
        // A block, not `=>`: remove() gives back this future, which
        // whenComplete would then wait for.
        _loading.remove(storagePath);
      });

  Future<File> _file(String storagePath) async {
    final dir = Directory('${(await root()).path}/$_files');
    final copy = File('${dir.path}/${_name(storagePath)}${_ext(storagePath)}');
    if (copy.existsSync()) {
      _used(copy);
      return copy;
    }
    final bytes = await download(storagePath);
    await dir.create(recursive: true);
    // Whole or not at all: a half-written copy is never opened.
    final part = File('${copy.path}.part');
    await part.writeAsBytes(bytes, flush: true);
    return part.rename(copy.path);
  }

  /// [storagePath]'s kept first page, or null.
  Future<File?> thumb(String storagePath) async {
    final kept = File(await _thumbPath(storagePath));
    if (!kept.existsSync()) return null;
    _used(kept);
    return kept;
  }

  Future<void> keepThumb(String storagePath, Uint8List png) async {
    final kept = File(await _thumbPath(storagePath));
    await kept.parent.create(recursive: true);
    await kept.writeAsBytes(png, flush: true);
  }

  /// Copies and first pages over [maxBytes]: the least recently used go.
  Future<void> trim() async {
    final top = (await root()).path;
    final kept = <File>[
      for (final name in [_files, _thumbs])
        if (Directory('$top/$name').existsSync())
          ...Directory('$top/$name').listSync().whereType<File>(),
    ];
    final sized = [
      for (final f in kept)
        if (_stat(f) case final s?) (file: f, bytes: s.size, used: s.modified),
    ]..sort((a, b) => a.used.compareTo(b.used));
    var total = sized.fold(0, (sum, f) => sum + f.bytes);
    for (final f in sized) {
      if (total <= maxBytes) break;
      try {
        f.file.deleteSync();
        total -= f.bytes;
      } on FileSystemException {
        // In use; next start.
      }
    }
  }

  Future<String> _thumbPath(String storagePath) async =>
      '${(await root()).path}/$_thumbs/${_name(storagePath)}.png';

  static const _files = 'bv_files';
  static const _thumbs = 'bv_thumbs';

  /// Opened now: the last to go when over the cap.
  static void _used(File f) {
    try {
      f.setLastModifiedSync(DateTime.now());
    } on FileSystemException {
      // Only the order of trimming.
    }
  }

  static FileStat? _stat(File f) {
    try {
      return f.statSync();
    } on FileSystemException {
      return null;
    }
  }

  static String _ext(String path) {
    final name = path.split('/').last;
    final dot = name.lastIndexOf('.');
    final ext = dot > 0 ? name.substring(dot).toLowerCase() : '';
    return RegExp(r'^\.[a-z0-9]{1,8}$').hasMatch(ext) ? ext : '';
  }

  /// 64-bit FNV-1a of the path, as hex: a name, not a secret.
  static String _name(String path) {
    var h = 0xcbf29ce484222325;
    for (final b in utf8.encode(path)) {
      h ^= b;
      h *= 0x100000001b3;
    }
    String half(int v) => (v & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0');
    return half(h >> 32) + half(h);
  }
}

final fileCacheProvider = Provider<FileCache>(
  (ref) => FileCache(
    root: getTemporaryDirectory,
    download: ref.watch(libraryRepositoryProvider).download,
  ),
);

/// Review 114 B2, at app start: what the app's tools leave in [cache] goes.
/// - `*.pdf` right in it: pdfx's copies (ours are in bv_files);
/// - `file_picker/` and `share_plus/` files older than a day, unless one of
///   [pending] (what waits on the phone: drafts, outboxes) names it.
Future<void> cleanUpCache(
  Directory cache, {
  required DateTime now,
  required Iterable<String> pending,
}) async {
  // Paths compared with one kind of slash (JSON doubles a backslash).
  String plain(String s) => s.replaceAll(r'\\', '/').replaceAll(r'\', '/');
  final held = plain(pending.join('\n'));
  bool named(String path) => held.contains(plain(path));
  final dayAgo = now.subtract(const Duration(days: 1));
  void drop(File f) {
    try {
      f.deleteSync();
    } on FileSystemException {
      // In use; next start.
    }
  }

  if (!cache.existsSync()) return;
  for (final f in cache.listSync().whereType<File>()) {
    if (f.path.toLowerCase().endsWith('.pdf')) drop(f);
  }
  for (final name in ['file_picker', 'share_plus']) {
    final dir = Directory('${cache.path}/$name');
    if (!dir.existsSync()) continue;
    for (final f in dir.listSync(recursive: true).whereType<File>()) {
      final modified = FileCache._stat(f)?.modified;
      if (modified == null || modified.isAfter(dayAgo) || named(f.path)) {
        continue;
      }
      drop(f);
    }
    // The picker's folders left empty.
    for (final d in dir.listSync().whereType<Directory>()) {
      try {
        if (d.listSync(recursive: true).whereType<File>().isEmpty) {
          d.deleteSync(recursive: true);
        }
      } on FileSystemException {
        // Next start.
      }
    }
  }
}

/// At start, after the storage log: the clean-up, then the cap. What waits
/// on the phone is every saved string (drafts, outboxes, chat's outbox),
/// so a file one of them names is never deleted.
Future<void> cleanUpFilesAtStart(
  Iterable<String> saved,
  FileCache files,
) async {
  try {
    await cleanUpCache(
      await getTemporaryDirectory(),
      now: DateTime.now(),
      pending: saved,
    );
    await files.trim();
  } on Object catch (e) {
    debugPrint('cache: ${e.runtimeType}');
  }
}
