// Review 114 B2: one start-up report of what the app keeps on the phone.
import 'dart:io';

import 'package:buildvibes/core/config/feature_switches.dart';
import 'package:buildvibes/core/storage_report.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;

  File write(String path, int bytes) => File('${root.path}/$path')
    ..createSync(recursive: true)
    ..writeAsBytesSync(List.filled(bytes, 0));

  setUp(() => root = Directory.systemTemp.createTempSync('bv_storage'));
  tearDown(() => root.deleteSync(recursive: true));

  test('each folder\'s size, then the largest files, name and size only', () {
    write('cache/picks/a-long-site-drawing.pdf', 3000);
    write('cache/b.jpg', 1000);
    write('files/c.db', 500);
    final lines = storageReport({
      'cache': '${root.path}/cache',
      'files': '${root.path}/files',
      'app_flutter': '${root.path}/nothing-here',
    });
    expect(lines, [
      'storage cache 4000',
      'storage files 500',
      'storage app_flutter 0',
      'storage top cache a-long-site-drawing.pdf 3000',
      'storage top cache b.jpg 1000',
      'storage top files c.db 500',
    ]);
  });

  test('at most 20 files', () {
    for (var i = 0; i < 25; i++) {
      write('cache/f$i.tmp', i + 1);
    }
    final top = storageReport({
      'cache': '${root.path}/cache',
    }).where((l) => l.startsWith('storage top '));
    expect(top, hasLength(20));
    expect(top.first, 'storage top cache f24.tmp 25');
  });

  test('on for this pilot build; off before the store build', () {
    expect(storageLogEnabled, isTrue);
  });
}
