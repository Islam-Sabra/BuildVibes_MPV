import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show instantiateImageCodec;

import 'package:buildvibes/core/photo_privacy.dart';
import 'package:flutter_test/flutter_test.dart';

/// A small JPEG as a phone writes it: EXIF with the orientation and a GPS
/// block (north, 29° 22' 12.34"), XMP repeating the position, then the
/// picture.
Uint8List _jpeg({
  Endian order = Endian.little,
  bool xmp = true,
  bool gps = true,
}) {
  final tiff = ByteData(92);
  final le = order == Endian.little;
  tiff
    ..setUint8(0, le ? 0x49 : 0x4D)
    ..setUint8(1, le ? 0x49 : 0x4D)
    ..setUint16(2, 42, order)
    ..setUint32(4, 8, order);
  // IFD0: Orientation 6, and the GPS block at 38.
  tiff
    ..setUint16(8, gps ? 2 : 1, order)
    ..setUint16(10, 0x0112, order)
    ..setUint16(12, 3, order)
    ..setUint32(14, 1, order)
    ..setUint16(18, 6, order);
  if (gps) {
    tiff
      ..setUint16(22, 0x8825, order)
      ..setUint16(24, 4, order)
      ..setUint32(26, 1, order)
      ..setUint32(30, 38, order);
  }
  // The GPS block: LatitudeRef "N", Latitude 3 rationals at 68.
  tiff
    ..setUint16(38, 2, order)
    ..setUint16(40, 0x0001, order)
    ..setUint16(42, 2, order)
    ..setUint32(44, 2, order)
    ..setUint8(48, 0x4E)
    ..setUint16(52, 0x0002, order)
    ..setUint16(54, 5, order)
    ..setUint32(56, 3, order)
    ..setUint32(60, 68, order);
  for (final (i, v) in [29, 1, 22, 1, 1234, 100].indexed) {
    tiff.setUint32(68 + i * 4, v, order);
  }
  final exif = [...'Exif'.codeUnits, 0, 0, ...tiff.buffer.asUint8List()];
  final xmpBody = [
    ...'http://ns.adobe.com/xap/1.0/'.codeUnits,
    0,
    ...'<x:xmpmeta exif:GPSLatitude="29,22.2N"/>'.codeUnits,
  ];
  return Uint8List.fromList([
    0xFF, 0xD8, //
    0xFF, 0xE1, (exif.length + 2) >> 8, (exif.length + 2) & 0xFF, ...exif,
    if (xmp) ...[
      0xFF,
      0xE1,
      (xmpBody.length + 2) >> 8,
      (xmpBody.length + 2) & 0xFF,
      ...xmpBody,
    ],
    0xFF, 0xDB, 0x00, 0x04, 0x01, 0x02, // a table
    ..._scan,
  ]);
}

/// The picture itself, from the start of scan to the end.
const _scan = [
  0xFF,
  0xDA,
  0x00,
  0x04,
  0x07,
  0x08,
  0x11,
  0x22,
  0xFF,
  0x00,
  0x33,
  0xFF,
  0xD9,
];

bool _has(Uint8List b, List<int> part) {
  for (var i = 0; i + part.length <= b.length; i++) {
    var all = true;
    for (var j = 0; j < part.length && all; j++) {
      all = b[i + j] == part[j];
    }
    if (all) return true;
  }
  return false;
}

List<int> _u32(int v, Endian order) {
  final d = ByteData(4)..setUint32(0, v, order);
  return d.buffer.asUint8List();
}

/// A real JPEG (made with Pillow): orientation 6, the time taken, a GPS
/// position, and the phone's make, model, owner, artist and serial numbers.
const _phoneJpeg =
    '/9j/4AAQSkZJRgABAQAAAQABAAD/4QEcRXhpZgAATU0AKgAAAAgABgEPAAIAAAAHAAAAVgEQAAIA'
    'AAALAAAAXgESAAMAAAABAAYAAAE7AAIAAAAMAAAAaodpAAQAAAABAAAAdoglAAQAAAABAAAA3gAA'
    'AABYaWFvbWkAADIyMTIwUk44NkcAAE9tYXIgSGFkZGFkAAAEkAMAAgAAABQAAACspDAAAgAAAAUA'
    'AADApDEAAgAAAAsAAADGpDUAAgAAAAsAAADSAAAAADIwMjY6MTA6MjEgMDk6MDA6MDAAT21hcgAA'
    'U04xMjM0NTY3OAAATEVOUzk5ODg3NwAAAAIAAQACAAAAAk4AAAAAAgAFAAAAAwAAAPwAAAAAAAAA'
    'HQAAAAEAAAAWAAAAAQAAAmkAAAAy/9sAQwANCQoLCggNCwoLDg4NDxMgFRMSEhMnHB4XIC4pMTAu'
    'KS0sMzpKPjM2RjcsLUBXQUZMTlJTUjI+WmFaUGBKUVJP/9sAQwEODg4TERMmFRUmTzUtNU9PT09P'
    'T09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09P/8AAEQgABgAIAwEi'
    'AAIRAQMRAf/EAB8AAAEFAQEBAQEBAAAAAAAAAAABAgMEBQYHCAkKC//EALUQAAIBAwMCBAMFBQQE'
    'AAABfQECAwAEEQUSITFBBhNRYQcicRQygZGhCCNCscEVUtHwJDNicoIJChYXGBkaJSYnKCkqNDU2'
    'Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6g4SFhoeIiYqSk5SVlpeYmZqio6Sl'
    'pqeoqaqys7S1tre4ubrCw8TFxsfIycrS09TV1tfY2drh4uPk5ebn6Onq8fLz9PX29/j5+v/EAB8B'
    'AAMBAQEBAQEBAQEAAAAAAAABAgMEBQYHCAkKC//EALURAAIBAgQEAwQHBQQEAAECdwABAgMRBAUh'
    'MQYSQVEHYXETIjKBCBRCkaGxwQkjM1LwFWJy0QoWJDThJfEXGBkaJicoKSo1Njc4OTpDREVGR0hJ'
    'SlNUVVZXWFlaY2RlZmdoaWpzdHV2d3h5eoKDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2'
    't7i5usLDxMXGx8jJytLT1NXW19jZ2uLj5OXm5+jp6vLz9PX29/j5+v/aAAwDAQACEQMRAD8Ay6KK'
    'K4T6s//Z';

/// The EXIF of a JPEG as written: each block's tags, and the first
/// block's next block (a thumbnail, when not 0).
({Map<int, List<int>> ifd0, Map<int, List<int>> exif, int next, int size})?
_exifOf(Uint8List b) {
  var i = 2;
  while (i + 4 <= b.length && b[i] == 0xFF && b[i + 1] != 0xDA) {
    final length = (b[i + 2] << 8) | b[i + 3];
    if (b[i + 1] == 0xE1 && String.fromCharCodes(b, i + 4, i + 8) == 'Exif') {
      final base = i + 10;
      final view = ByteData.sublistView(b);
      final order = b[base] == 0x4D ? Endian.big : Endian.little;
      int u16(int at) => view.getUint16(base + at, order);
      int u32(int at) => view.getUint32(base + at, order);
      Map<int, List<int>> block(int at) {
        final n = u16(at);
        return {
          for (var e = 0; e < n; e++)
            u16(at + 2 + e * 12): () {
              final entry = at + 2 + e * 12;
              final type = u16(entry + 2);
              final count = u32(entry + 4);
              final size = (type == 3 ? 2 : (type == 4 ? 4 : 1)) * count;
              final from = size <= 4 ? entry + 8 : u32(entry + 8);
              return type == 3
                  ? [u16(from)]
                  : b.sublist(base + from, base + from + size);
            }(),
        };
      }

      final first = u32(4);
      final ifd0 = block(first);
      final pointer = ifd0[0x8769];
      return (
        ifd0: ifd0,
        exif: pointer == null
            ? const {}
            : block(
                ByteData.sublistView(
                  Uint8List.fromList(pointer),
                ).getUint32(0, order),
              ),
        next: u32(first + 2 + u16(first) * 12),
        size: length + 2,
      );
    }
    i += 2 + length;
  }
  return null;
}

List<int> _ascii0(String s) => [...s.codeUnits, 0];

/// A JPEG whose EXIF has, past every block, a string area no tag points
/// to: a Xiaomi phone's second copy of its make, model and serial. Its
/// blocks hold Orientation 6, Make, a GPS block, a maker note and the
/// times taken.
Uint8List _orphanJpeg() {
  const order = Endian.big;
  final t = ByteData(420);
  t
    ..setUint16(0, 0x4D4D)
    ..setUint16(2, 42)
    ..setUint32(4, 8);
  void entry(int at, int tag, int type, int count, int value) => t
    ..setUint16(at, tag, order)
    ..setUint16(at + 2, type, order)
    ..setUint32(at + 4, count, order)
    ..setUint32(at + 8, value, order);
  void text(int at, String s) {
    for (final (k, c) in _ascii0(s).indexed) {
      t.setUint8(at + k, c);
    }
  }

  // IFD0 at 8: Make, Orientation, the EXIF block, the GPS block; then a
  // thumbnail block at 300.
  t.setUint16(8, 4);
  entry(10, 0x010F, 2, 7, 200);
  entry(22, 0x0112, 3, 1, 6 << 16);
  entry(34, 0x8769, 4, 1, 60);
  entry(46, 0x8825, 4, 1, 160);
  t.setUint32(58, 300);
  // The EXIF block at 60: DateTimeOriginal, OffsetTimeOriginal,
  // SubsecTimeOriginal, a maker note.
  t.setUint16(60, 4);
  entry(62, 0x9003, 2, 20, 210);
  entry(74, 0x9011, 2, 7, 230);
  entry(86, 0x9291, 2, 4, 0x31323300);
  entry(98, 0x927C, 7, 12, 240);
  t.setUint32(110, 0);
  // The GPS block at 160: Latitude (3 rationals at 260).
  t.setUint16(160, 1);
  entry(162, 0x0002, 5, 3, 260);
  t.setUint32(174, 0);
  text(200, 'Xiaomi');
  text(210, '2026:10:21 15:21:11');
  text(230, '+03:00');
  text(240, 'MAKERSN0042');
  for (final (k, v) in [29, 1, 22, 1, 1234, 100].indexed) {
    t.setUint32(260 + k * 4, v, order);
  }
  // A thumbnail block at 300, then the orphan string area at 340.
  t.setUint16(300, 1);
  entry(302, 0x0201, 4, 1, 360);
  t.setUint32(314, 0);
  text(340, '22120RN86G');
  text(352, 'Xiaomi');
  text(360, 'SERIAL998877');
  text(374, 'MediaTek Camera Application');
  final exif = [...'Exif'.codeUnits, 0, 0, ...t.buffer.asUint8List()];
  return Uint8List.fromList([
    0xFF, 0xD8, //
    0xFF, 0xE1, (exif.length + 2) >> 8, (exif.length + 2) & 0xFF, ...exif,
    0xFF, 0xDB, 0x00, 0x04, 0x01, 0x02, // a table
    ..._scan,
  ]);
}

/// A small real JPEG: the APP1 (EXIF) block of a Xiaomi 22120RN86G photo
/// posted from the app, byte for byte, on a blank 8×8 grey picture.
Uint8List _xiaomi() => File('test/fixtures/xiaomi_exif.jpg').readAsBytesSync();

/// What the phone wrote that tells which phone it is.
const _xiaomiWords = ['Xiaomi', '22120RN86G', 'MediaTek Camera Application'];

void main() {
  group('JPEG', () {
    for (final order in [Endian.little, Endian.big]) {
      test(
        'the position goes, the orientation and the picture stay ($order)',
        () {
          final before = _jpeg(order: order);
          expect(_has(before, [..._u32(29, order), ..._u32(1, order)]), isTrue);

          final after = withoutLocation(before)!;
          expect(
            _has(after, [..._u32(29, order), ..._u32(1, order)]),
            isFalse,
            reason: 'the latitude is gone',
          );
          expect(
            _has(after, [..._u32(1234, order), ..._u32(100, order)]),
            isFalse,
          );
          expect(
            _has(after, 'GPSLatitude'.codeUnits),
            isFalse,
            reason: 'XMP is dropped',
          );
          final exif = _exifOf(after)!;
          expect(exif.ifd0, {
            0x0112: [6],
          });
          expect(exif.exif, isEmpty);
          expect(after.sublist(after.length - _scan.length), _scan);
          expect(
            withoutLocation(after),
            isNull,
            reason: 'a second pass changes nothing',
          );
        },
      );
    }

    test('a photo with no metadata is left as it is', () {
      final bare = Uint8List.fromList([
        0xFF, 0xD8, 0xFF, 0xDB, 0x00, 0x04, 0x01, 0x02, //
        ..._scan,
      ]);
      expect(withoutLocation(bare), isNull);
    });

    test('EXIF it cannot read is dropped whole', () {
      final b = _jpeg(xmp: false);
      b[12] = 0x58; // The byte order mark is now nonsense.
      final after = withoutLocation(b)!;
      expect(_has(after, 'Exif'.codeUnits), isFalse);
      expect(after.sublist(after.length - _scan.length), _scan);
    });

    test('EXIF with none of the three is dropped whole', () {
      final b = _jpeg(xmp: false);
      b[22] = 0x01; // Orientation becomes tag 0x0101, ImageLength.
      final after = withoutLocation(b)!;
      expect(_has(after, 'Exif'.codeUnits), isFalse);
    });

    test('a broken file is left as it is', () {
      expect(
        withoutLocation(
          Uint8List.fromList([0xFF, 0xD8, 0x00, 0x01, 0x02, 0x03]),
        ),
        isNull,
      );
    });
  });

  group('F60: the phone goes, orientation and the time taken stay', () {
    test('an orphan string area, a maker note, GPS and a thumbnail: none '
        'of it is anywhere in the file', () {
      final before = _orphanJpeg();
      for (final word in [
        'Xiaomi',
        '22120RN86G',
        'SERIAL998877',
        'MAKERSN0042',
        'MediaTek',
      ]) {
        expect(_has(before, word.codeUnits), isTrue, reason: word);
      }
      final after = withoutLocation(before)!;
      for (final word in [
        'Xiaomi',
        '22120RN86G',
        'SERIAL998877',
        'MAKERSN0042',
        'MediaTek',
      ]) {
        expect(_has(after, word.codeUnits), isFalse, reason: word);
      }
      expect(
        _has(after, [..._u32(29, Endian.big), ..._u32(1, Endian.big)]),
        isFalse,
      );
      final exif = _exifOf(after)!;
      expect(exif.ifd0.keys, [0x0112, 0x8769]);
      expect(exif.ifd0[0x0112], [6]);
      expect(exif.exif, {
        0x9003: _ascii0('2026:10:21 15:21:11'),
        0x9011: _ascii0('+03:00'),
      });
      expect(exif.next, 0, reason: 'no thumbnail');
      // "Exif\0\0", the header, two blocks of two entries, the time taken.
      expect(exif.size, 2 + 2 + 6 + 8 + 30 + 30 + 20 + 8);
      expect(after.length, before.length - _exifOf(before)!.size + exif.size);
      expect(after.sublist(after.length - _scan.length), _scan);
      expect(withoutLocation(after), isNull);
    });

    testWidgets("a real Xiaomi photo's EXIF: no make, model or software "
        'anywhere, and it still opens', (tester) async {
      final before = _xiaomi();
      for (final word in _xiaomiWords) {
        expect(_has(before, word.codeUnits), isTrue, reason: word);
      }
      final after = withoutLocation(before)!;
      for (final word in _xiaomiWords) {
        expect(_has(after, word.codeUnits), isFalse, reason: word);
      }
      final exif = _exifOf(after)!;
      // Orientation as the phone wrote it, the time taken, nothing else.
      expect(exif.ifd0, {
        0x0112: _exifOf(before)!.ifd0[0x0112],
        0x8769: [0, 0, 0, 38],
      });
      expect(exif.exif, {0x9003: _ascii0('2026:10:21 15:21:11')});
      expect(exif.next, 0, reason: 'no IFD1, no thumbnail');
      expect(exif.size, 2 + 2 + 6 + 8 + 30 + 18 + 20);
      final size = await tester.runAsync(() async {
        final codec = await instantiateImageCodec(after);
        final frame = await codec.getNextFrame();
        return (frame.image.width, frame.image.height);
      });
      expect(size, (8, 8));
    });
    test("the phone's make, model, owner, artist and serials go; the "
        'orientation and the time taken stay', () {
      final before = base64Decode(_phoneJpeg);
      const words = [
        'Xiaomi',
        '22120RN86G',
        'SN12345678',
        'LENS998877',
        'Omar Haddad',
      ];
      for (final word in words) {
        expect(_has(before, word.codeUnits), isTrue, reason: word);
      }
      final after = withoutLocation(before)!;
      for (final word in words) {
        expect(_has(after, word.codeUnits), isFalse, reason: word);
      }
      final exif = _exifOf(after)!;
      expect(exif.ifd0[0x0112], [6]);
      expect(exif.exif, {0x9003: _ascii0('2026:10:21 09:00:00')});
      expect(exif.next, 0);
      expect(after.length, lessThan(before.length));
      expect(withoutLocation(after), isNull);
    });
  });

  test('PNG: the eXIf chunk and XMP go, the rest stays', () {
    List<int> chunk(String type, List<int> data) => [
      ..._u32(data.length, Endian.big),
      ...type.codeUnits,
      ...data,
      0, 0, 0, 0, // the checksum; not checked here
    ];
    final ihdr = chunk('IHDR', List.filled(13, 1));
    final iend = chunk('IEND', []);
    final png = Uint8List.fromList([
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
      ...ihdr,
      ...chunk('eXIf', [0x4D, 0x4D, 0, 42, 9, 9]),
      ...chunk('iTXt', [
        ...'XML:com.adobe.xmp'.codeUnits,
        0,
        ...'GPS'.codeUnits,
      ]),
      ...iend,
    ]);
    final after = withoutLocation(png)!;
    expect(after, [...png.sublist(0, 8), ...ihdr, ...iend]);
    expect(withoutLocation(after), isNull);
  });

  test('WebP: EXIF and XMP go, the header says so', () {
    List<int> chunk(String type, List<int> data) => [
      ...type.codeUnits,
      ..._u32(data.length, Endian.little),
      ...data,
      if (data.length.isOdd) 0,
    ];
    final vp8x = chunk('VP8X', [0x0C, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
    final image = chunk('VP8 ', [1, 2, 3]);
    final body = [
      ...vp8x,
      ...image,
      ...chunk('EXIF', [9, 9, 9, 9]),
      ...chunk('XMP ', [7]),
    ];
    final webp = Uint8List.fromList([
      ...'RIFF'.codeUnits,
      ..._u32(4 + body.length, Endian.little),
      ...'WEBP'.codeUnits,
      ...body,
    ]);
    final after = withoutLocation(webp)!;
    final kept = [...vp8x, ...image]..[8] = 0x00;
    expect(after.sublist(12), kept);
    expect(
      ByteData.sublistView(after).getUint32(4, Endian.little),
      after.length - 8,
    );
  });

  test('a PDF is left as it is', () {
    expect(withoutLocation(Uint8List.fromList('%PDF-1.7'.codeUnits)), isNull);
  });

  test(
    'stripPhotoLocation rewrites the file, and leaves a missing one alone',
    () async {
      final dir = await Directory.systemTemp.createTemp('photo_privacy');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/p.jpg')..writeAsBytesSync(_jpeg());
      await stripPhotoLocation(file.path);
      expect(_has(file.readAsBytesSync(), 'GPSLatitude'.codeUnits), isFalse);
      await stripPhotoLocation('${dir.path}/none.jpg');
    },
  );
}
