// Review 114 B2, the lead's V11: one start-up report of what the app keeps
// on the phone. A file is its folder (from the top folder), its extension
// and its size: never its name.
import 'dart:io';

import 'package:buildvibes/core/storage_report.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;

  File write(String path, int bytes) => File('${root.path}/$path')
    ..createSync(recursive: true)
    ..writeAsBytesSync(List.filled(bytes, 0));

  setUp(() => root = Directory.systemTemp.createTempSync('bv_storage'));
  tearDown(() => root.deleteSync(recursive: true));

  List<String> report() => storageReport({
    'cache': '${root.path}/cache',
    'files': '${root.path}/files',
    'app_flutter': '${root.path}/nothing-here',
  });

  test('each top folder, each subfolder, then the largest files by folder, '
      'extension and size', () {
    write('cache/picks/a-long-site-drawing.pdf', 3000);
    write('cache/b.jpg', 1000);
    write('files/c.db', 500);
    expect(report(), [
      'storage cache 4000',
      'storage files 500',
      'storage app_flutter 0',
      'storage folder cache 1000',
      'storage folder cache/picks 3000',
      'storage folder files 500',
      'storage top cache/picks .pdf 3000',
      'storage top cache .jpg 1000',
      'storage top files .db 500',
    ]);
  });

  test('a name never appears, nor a name with no extension', () {
    write('cache/islam-sabra-passport/secret-name.pdf', 10);
    write('cache/no_extension_file', 5);
    final lines = report().join('\n');
    expect(lines, isNot(contains('secret-name')));
    expect(lines, isNot(contains('no_extension_file')));
    expect(lines, contains('storage top cache/islam-sabra-passport .pdf 10'));
    expect(lines, contains('storage top cache - 5'));
  });

  test('at most 20 files', () {
    for (var i = 0; i < 25; i++) {
      write('cache/f$i.tmp', i + 1);
    }
    final top = storageReport({
      'cache': '${root.path}/cache',
    }).where((l) => l.startsWith('storage top '));
    expect(top, hasLength(20));
    expect(top.first, 'storage top cache .tmp 25');
  });

  test('off unless the build passes BV_STORAGE_LOG', () {
    expect(storageLogOn, isFalse);
  });
}
