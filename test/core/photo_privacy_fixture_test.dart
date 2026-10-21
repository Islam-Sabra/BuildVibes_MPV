import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../helpers/photo_bytes.dart';

/// The real Xiaomi 22120RN86G EXIF block on a blank 64×48 grey picture,
/// with a GPS block of dummy values (docs/reviews/f60-fixture-for-lead.md).
Uint8List _fixture(String name) =>
    File('test/fixtures/$name').readAsBytesSync();

/// What the phone wrote that tells which phone it is.
const _phoneWords = ['Xiaomi', '22120RN86G', 'MediaTek Camera Application'];

void main() {
  for (final (name, sideways) in [
    ('xiaomi_exif.jpg', false),
    ('xiaomi_exif_sideways.jpg', true),
  ]) {
    testWidgets('F60, a real Xiaomi photo\'s EXIF ($name): no make, model or '
        'software anywhere, no thumbnail, no GPS; the time taken stays, '
        'upright', (tester) async {
      final before = _fixture(name);
      for (final word in _phoneWords) {
        expect(hasBytes(before, word.codeUnits), isTrue, reason: word);
      }
      final first = exifBlocks(before).single;
      expect(first.ifd0.containsKey(0x8825), isTrue, reason: 'GPS to remove');
      expect(first.ifd0[0x0112], [if (sideways) 6 else 0]);

      final after = (await cleanForTest(tester, before))!;
      for (final word in _phoneWords) {
        expect(hasBytes(after, word.codeUnits), isFalse, reason: word);
      }
      final exif = exifBlocks(after).single;
      expect(exif.ifd0.keys, [0x8769], reason: 'no GPS, no orientation');
      expect(exif.exif, {
        0x9003: [...'2026:10:21 15:21:11'.codeUnits, 0],
      });
      expect(exif.next, 0, reason: 'no thumbnail');
      final picture = img.decodeJpg(after)!;
      expect((picture.width, picture.height), sideways ? (48, 64) : (64, 48));
    });
  }
}
