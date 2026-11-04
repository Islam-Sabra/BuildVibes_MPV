// Review 114 B2: one copy of each file on the phone, its first page kept,
// under 200 MB, and the cache cleaned at start.
import 'dart:io';
import 'dart:typed_data';

import 'package:buildvibes/core/file_cache.dart';
import 'package:buildvibes/features/work/daybook_photos.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory cache;
  final downloads = <String>[];

  FileCache cacheWith({int maxBytes = FileCache.defaultMaxBytes}) => FileCache(
    root: () async => cache,
    download: (path) async {
      downloads.add(path);
      return Uint8List.fromList(List.filled(1000, 7));
    },
    maxBytes: maxBytes,
  );

  setUp(() {
    cache = Directory.systemTemp.createTempSync('bv_cache');
    downloads.clear();
  });
  tearDown(() => cache.deleteSync(recursive: true));

  File put(String path, int bytes, DateTime at) => File('${cache.path}/$path')
    ..createSync(recursive: true)
    ..writeAsBytesSync(List.filled(bytes, 1))
    ..setLastModifiedSync(at);

  test('the same file twice: one download, one copy, kept as itself', () async {
    final files = cacheWith();
    final a = await files.file('space/library/f1/A-501 plan.pdf');
    final b = await files.file('space/library/f1/A-501 plan.pdf');
    expect(downloads, ['space/library/f1/A-501 plan.pdf']);
    expect(a.path, b.path);
    expect(a.path, startsWith(cache.path));
    expect(a.path, contains('bv_files'));
    expect(a.path, isNot(contains('A-501')), reason: 'named by a hash');
    expect(a.path, endsWith('.pdf'));
    expect(a.lengthSync(), 1000);
  });

  test('two opens at once still download once', () async {
    final files = cacheWith();
    await Future.wait([files.file('s/x.pdf'), files.file('s/x.pdf')]);
    expect(downloads, hasLength(1));
  });

  test('a first page is kept, and read back', () async {
    final files = cacheWith();
    expect(await files.thumb('s/x.pdf'), isNull);
    await files.keepThumb('s/x.pdf', Uint8List.fromList([1, 2, 3]));
    final kept = await files.thumb('s/x.pdf');
    expect(kept!.readAsBytesSync(), [1, 2, 3]);
    expect(kept.path, contains('bv_thumbs'));
  });

  test('over the cap, the least recently used go first', () async {
    final now = DateTime(2026, 11, 3, 9);
    put('bv_files/old.pdf', 600, now.subtract(const Duration(days: 3)));
    put('bv_thumbs/old.png', 100, now.subtract(const Duration(days: 2)));
    put('bv_files/new.pdf', 600, now);
    await cacheWith(maxBytes: 1000).trim();
    expect(File('${cache.path}/bv_files/old.pdf').existsSync(), isFalse);
    expect(File('${cache.path}/bv_thumbs/old.png').existsSync(), isTrue);
    expect(File('${cache.path}/bv_files/new.pdf').existsSync(), isTrue);
  });

  test('the start-up clean-up: pdfx leftovers, old picker and share copies; '
      'never a file a pending item points at', () async {
    final now = DateTime(2026, 11, 3, 9);
    final old = now.subtract(const Duration(days: 2));
    final fresh = now.subtract(const Duration(hours: 2));
    put('a1b2.pdf', 10, fresh);
    put('named.pdf', 10, old);
    put('keep-me.txt', 10, old);
    put('file_picker/111/drawing.pdf', 10, old);
    put('file_picker/222/waiting.pdf', 10, old);
    put('file_picker/333/just-picked.pdf', 10, fresh);
    put('share_plus/sent.pdf', 10, old);
    put('share_plus/now.pdf', 10, fresh);
    put('bv_files/ours.pdf', 10, old);
    final waiting = '${cache.path}/file_picker/222/waiting.pdf';
    final named = '${cache.path}/named.pdf';
    await cleanUpCache(
      cache,
      now: now,
      pending: [
        '{"files":[{"local":"${waiting.replaceAll(r'\', r'\\')}"}]}',
        '{"local":"$named"}',
      ],
    );
    bool there(String p) => File('${cache.path}/$p').existsSync();
    expect(there('a1b2.pdf'), isFalse, reason: "pdfx's leftover");
    expect(there('named.pdf'), isTrue, reason: 'a pending value names it');
    expect(there('keep-me.txt'), isTrue);
    expect(there('file_picker/111/drawing.pdf'), isFalse);
    expect(there('file_picker/222/waiting.pdf'), isTrue, reason: 'pending');
    expect(there('file_picker/333/just-picked.pdf'), isTrue);
    expect(there('share_plus/sent.pdf'), isFalse);
    expect(there('share_plus/now.pdf'), isTrue);
    expect(there('bv_files/ours.pdf'), isTrue, reason: 'only the cap trims');
    expect(Directory('${cache.path}/file_picker/111').existsSync(), isFalse);
  });

  test(
    'a card\'s first page: drawn from the local copy once, then kept',
    () async {
      final drawn = <String>[];
      final container = ProviderContainer(
        overrides: [
          fileCacheProvider.overrideWithValue(cacheWith()),
          firstPageProvider.overrideWithValue((local) async {
            drawn.add(local);
            return Uint8List.fromList([9, 9]);
          }),
        ],
      );
      addTearDown(container.dispose);
      const file = (
        path: 's/library/f2/B.pdf',
        mime: 'application/pdf',
        thumb: null,
      );
      final first = await container.read(filePreviewProvider(file).future);
      expect(first, isA<ImageProvider>());
      expect(drawn, hasLength(1));
      expect(drawn.single, contains('bv_files'));
      container.invalidate(filePreviewProvider(file));
      await container.read(filePreviewProvider(file).future);
      expect(drawn, hasLength(1), reason: 'the kept picture, no new drawing');
      expect(downloads, hasLength(1));
    },
  );

  test('openData is never used: it leaves a copy in the cache each time', () {
    final uses = [
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            f.readAsStringSync().contains('openData('))
          f.path,
    ];
    expect(uses, isEmpty);
  });
}
