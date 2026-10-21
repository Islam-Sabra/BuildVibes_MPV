import 'dart:io';
import 'dart:typed_data';

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
            reason: 'the latitude is zeroed',
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
          expect(_has(after, 'Exif'.codeUnits), isTrue, reason: 'EXIF stays');
          // Orientation 6 is still in IFD0.
          final orientation = [
            ...(ByteData(2)..setUint16(0, 0x0112, order)).buffer.asUint8List(),
            ...(ByteData(2)..setUint16(0, 3, order)).buffer.asUint8List(),
          ];
          expect(_has(after, orientation), isTrue);
          expect(after.sublist(after.length - _scan.length), _scan);
          expect(
            withoutLocation(after),
            isNull,
            reason: 'a second pass changes nothing',
          );
        },
      );
    }

    test('a photo with no position is left as it is', () {
      expect(withoutLocation(_jpeg(xmp: false, gps: false)), isNull);
    });

    test('EXIF it cannot read is dropped whole', () {
      final b = _jpeg(xmp: false);
      b[12] = 0x58; // The byte order mark is now nonsense.
      final after = withoutLocation(b)!;
      expect(_has(after, 'Exif'.codeUnits), isFalse);
      expect(after.sublist(after.length - _scan.length), _scan);
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
