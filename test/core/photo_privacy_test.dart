import 'dart:io';
import 'dart:typed_data';

import 'package:buildvibes/core/photo_privacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../helpers/photo_bytes.dart';

/// [w]×[h], its left half black and its right half white, as a JPEG.
Uint8List _picture(int w, int h, {int quality = 90}) {
  final image = img.Image(width: w, height: h);
  for (final p in image) {
    final v = p.x < w ~/ 2 ? 0 : 255;
    p.setRgb(v, v, v);
  }
  return img.encodeJpg(image, quality: quality);
}

/// [jpeg] with an EXIF block holding [tiff], right after its start.
Uint8List _withApp1(Uint8List jpeg, List<int> tiff) {
  final body = [...'Exif'.codeUnits, 0, 0, ...tiff];
  return Uint8List.fromList([
    0xFF, 0xD8, //
    0xFF, 0xE1, (body.length + 2) >> 8, (body.length + 2) & 0xFF, ...body,
    ...jpeg.sublist(2),
  ]);
}

List<int> _ascii0(String s) => [...s.codeUnits, 0];

/// What a Xiaomi phone writes (big-endian): Make, Model, Software and
/// Orientation [orientation] in the first block; the times taken, a
/// SubsecTime and a maker note with a serial in the EXIF block; a GPS
/// block; a thumbnail block; and past them all a string area no tag
/// points to, with a second copy of the make, model and software.
List<int> _phoneTiff({int orientation = 1}) {
  final t = ByteData(480);
  void entry(int at, int tag, int type, int count, int value) => t
    ..setUint16(at, tag)
    ..setUint16(at + 2, type)
    ..setUint32(at + 4, count)
    ..setUint32(at + 8, value);
  void text(int at, String s) {
    for (final (k, c) in _ascii0(s).indexed) {
      t.setUint8(at + k, c);
    }
  }

  t
    ..setUint16(0, 0x4D4D)
    ..setUint16(2, 42)
    ..setUint32(4, 8);
  // The first block at 8, then the thumbnail block at 300.
  t.setUint16(8, 6);
  entry(10, 0x010F, 2, 7, 200);
  entry(22, 0x0110, 2, 11, 440);
  entry(34, 0x0112, 3, 1, orientation << 16);
  entry(46, 0x0131, 2, 28, 412);
  entry(58, 0x8769, 4, 1, 90);
  entry(70, 0x8825, 4, 1, 160);
  t.setUint32(82, 300);
  // The EXIF block at 90.
  t.setUint16(90, 4);
  entry(92, 0x9003, 2, 20, 210);
  entry(104, 0x9011, 2, 7, 230);
  entry(116, 0x9291, 2, 4, 0x31323300);
  entry(128, 0x927C, 7, 12, 240);
  t.setUint32(140, 0);
  // The GPS block at 160: Latitude, 3 rationals at 260.
  t.setUint16(160, 1);
  entry(162, 0x0002, 5, 3, 260);
  t.setUint32(174, 0);
  text(200, 'Xiaomi');
  text(210, '2026:10:21 15:21:11');
  text(230, '+03:00');
  text(240, 'MAKERSN0042');
  for (final (k, v) in [29, 1, 22, 1, 1234, 100].indexed) {
    t.setUint32(260 + k * 4, v);
  }
  t.setUint16(300, 1);
  entry(302, 0x0201, 4, 1, 360);
  t.setUint32(314, 0);
  // The string area no tag points to.
  text(340, '22120RN86G');
  text(352, 'Xiaomi');
  text(360, 'SERIAL998877');
  text(374, 'MediaTek Camera Application');
  // The values the first block points to.
  text(412, 'MediaTek Camera Application');
  text(440, '22120RN86G');
  return t.buffer.asUint8List();
}

const _phoneWords = [
  'Xiaomi',
  '22120RN86G',
  'MediaTek Camera Application',
  'SERIAL998877',
  'MAKERSN0042',
];

List<int> _u32(int v, Endian order) {
  final d = ByteData(4)..setUint32(0, v, order);
  return d.buffer.asUint8List();
}

void main() {
  group('F60: a JPEG is drawn again from its pixels', () {
    testWidgets('nothing of the phone stays: no make, model, software, '
        'serial, GPS, maker note or thumbnail anywhere in the file, only '
        'the time taken', (tester) async {
      final before = _withApp1(_picture(64, 48), _phoneTiff());
      for (final word in _phoneWords) {
        expect(hasBytes(before, word.codeUnits), isTrue, reason: word);
      }
      final after = (await cleanForTest(tester, before))!;
      for (final word in _phoneWords) {
        expect(hasBytes(after, word.codeUnits), isFalse, reason: word);
      }
      expect(
        hasBytes(after, [..._u32(29, Endian.big), ..._u32(1, Endian.big)]),
        isFalse,
        reason: 'no latitude',
      );
      final exif = exifBlocks(after).single;
      // The first block only says where the EXIF block is.
      expect(exif.ifd0.keys, [0x8769]);
      expect(exif.exif, {
        0x9003: _ascii0('2026:10:21 15:21:11'),
        0x9011: _ascii0('+03:00'),
      });
      expect(exif.next, 0, reason: 'no thumbnail');
      final picture = img.decodeJpg(after)!;
      expect((picture.width, picture.height), (64, 48));
    });

    testWidgets('a sideways photo comes out upright, with no orientation '
        'tag', (tester) async {
      // Orientation 6: the camera was turned a quarter clockwise.
      final before = _withApp1(_picture(40, 20), _phoneTiff(orientation: 6));
      final after = (await cleanForTest(tester, before))!;
      final picture = img.decodeJpg(after)!;
      expect((picture.width, picture.height), (20, 40));
      // Turned upright, the black left half is now the top.
      expect(picture.getPixel(10, 5).r, lessThan(60));
      expect(picture.getPixel(10, 35).r, greaterThan(200));
      final exif = exifBlocks(after).single;
      expect(exif.ifd0.containsKey(0x0112), isFalse);
      expect(exif.exif.containsKey(0x0112), isFalse);
    });

    testWidgets('a large photo is made 2560 on its longest side', (
      tester,
    ) async {
      final before = _withApp1(_picture(4000, 3000, quality: 50), _phoneTiff());
      final after = (await cleanForTest(tester, before))!;
      final picture = img.decodeJpg(after)!;
      expect((picture.width, picture.height), (photoMaxSide, 1920));
      // Sideways too: made smaller and turned upright, never squashed.
      final sideways = _withApp1(
        _picture(4000, 3000, quality: 50),
        _phoneTiff(orientation: 6),
      );
      final upright = img.decodeJpg((await cleanForTest(tester, sideways))!)!;
      expect((upright.width, upright.height), (1920, photoMaxSide));
      expect(upright.getPixel(960, 100).r, lessThan(60));
      expect(upright.getPixel(960, 2400).r, greaterThan(200));
    });

    testWidgets('a small photo is never made bigger', (tester) async {
      final after = (await cleanForTest(tester, _picture(64, 48)))!;
      final picture = img.decodeJpg(after)!;
      expect((picture.width, picture.height), (64, 48));
      expect(exifBlocks(after), isEmpty, reason: 'no time taken, no EXIF');
    });

    testWidgets('H1: a JPEG the decoder refuses, with well-formed markers, '
        'goes without APP1 to APP15 or comments; APP0 and the picture stay', (
      tester,
    ) async {
      List<int> segment(int marker, List<int> body) => [
        0xFF,
        marker,
        (body.length + 2) >> 8,
        (body.length + 2) & 0xFF,
        ...body,
      ];
      final exif = [...'Exif'.codeUnits, 0, 0, ..._phoneTiff()];
      // No frame (SOF): the decoder can't draw it.
      final scan = [0x01, 0x02, 0x03, 0xFF, 0x00, 0x04, 0xFF, 0xD9];
      final before = Uint8List.fromList([
        0xFF, 0xD8, //
        ...segment(0xE0, [...'JFIF'.codeUnits, 0, 1, 1, 0, 0, 1, 0, 1, 0, 0]),
        ...segment(0xE1, exif),
        ...segment(0xE2, [...'ICC_PROFILE'.codeUnits, 0, 1, 1, 9, 9]),
        ...segment(0xED, 'Photoshop Xiaomi'.codeUnits),
        ...segment(0xFE, 'Xiaomi 22120RN86G'.codeUnits),
        ...segment(0xDB, List.filled(65, 1)),
        ...segment(0xDA, [1, 1, 0, 0, 0x3F, 0]),
        ...scan,
      ]);
      final cleaned = await cleanedForTest(tester, before);
      expect(cleaned.result, PhotoCleaning.cleaned);
      expect(cleaned.step, 'stripped');
      final after = cleaned.bytes!;
      for (final word in _phoneWords) {
        expect(hasBytes(after, word.codeUnits), isFalse, reason: word);
      }
      // The markers left, in order, up to the picture.
      final markers = <int>[];
      var i = 2;
      while (after[i + 1] != 0xDA) {
        markers.add(after[i + 1]);
        i += 2 + ((after[i + 2] << 8) | after[i + 3]);
      }
      expect(markers, [0xE0, 0xDB]);
      expect(after.sublist(after.length - scan.length), scan);
    });

    testWidgets('H1: a broken JPEG, PNG and WebP are each refused', (
      tester,
    ) async {
      for (final broken in [
        [0xFF, 0xD8, 0x00, 0x01, 0x02, 0x03],
        // An APP1 longer than the file.
        [0xFF, 0xD8, 0xFF, 0xE1, 0x40, 0x00, 0x45, 0x78],
        // A PNG with no header chunk.
        [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 1],
        // A WebP whose only chunk runs past the end.
        [
          ...'RIFF'.codeUnits, 20, 0, 0, 0, ...'WEBP'.codeUnits, //
          ...'VP8 '.codeUnits, 99, 0, 0, 0, 1, 2,
        ],
      ]) {
        final cleaned = await cleanedForTest(
          tester,
          Uint8List.fromList(broken),
        );
        expect(cleaned.result, PhotoCleaning.refused, reason: '$broken');
        expect(cleaned.bytes, isNull);
      }
    });

    testWidgets('cleanPhoto rewrites the file; a missing one is refused', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final dir = await Directory.systemTemp.createTemp('photo_privacy');
        final file = File('${dir.path}/p.jpg')
          ..writeAsBytesSync(_withApp1(_picture(64, 48), _phoneTiff()));
        final clean = await cleanPhoto(file.path, from: 'test');
        expect(clean, (result: PhotoCleaning.cleaned, path: file.path));
        expect(hasBytes(file.readAsBytesSync(), 'Xiaomi'.codeUnits), isFalse);
        final none = await cleanPhoto('${dir.path}/none.jpg', from: 'test');
        expect(none.result, PhotoCleaning.refused);
        await dir.delete(recursive: true);
      });
    });

    testWidgets('H1: a photo that cannot be written back goes as a fresh '
        "copy in the app's folder, never as the original", (tester) async {
      await tester.runAsync(() async {
        final dir = await Directory.systemTemp.createTemp('photo_privacy');
        final spare = await Directory('${dir.path}/spare').create();
        final original = _withApp1(_picture(64, 48), _phoneTiff());
        final file = File('${dir.path}/p.jpg')..writeAsBytesSync(original);
        // Read only.
        if (Platform.isWindows) {
          await Process.run('attrib', ['+r', file.path]);
        } else {
          await Process.run('chmod', ['444', file.path]);
        }
        final clean = await cleanPhoto(
          file.path,
          from: 'test',
          spare: () async => spare,
        );
        expect(clean.result, PhotoCleaning.cleaned);
        expect(clean.path, startsWith(spare.path));
        expect(clean.path, endsWith('.jpg'));
        final sent = File(clean.path).readAsBytesSync();
        expect(hasBytes(sent, 'Xiaomi'.codeUnits), isFalse);
        expect(file.readAsBytesSync(), original, reason: 'left alone');
        if (Platform.isWindows) {
          await Process.run('attrib', ['-r', file.path]);
        }
        await dir.delete(recursive: true);
      });
    });

    testWidgets('H1, H2: photos picked at once are cleaned side by side; a '
        'broken one is left out and the others go', (tester) async {
      await tester.runAsync(() async {
        final dir = await Directory.systemTemp.createTemp('photo_privacy');
        final good = [
          for (var i = 0; i < 2; i++)
            File('${dir.path}/good$i.jpg')
              ..writeAsBytesSync(_withApp1(_picture(64, 48), _phoneTiff())),
        ];
        final broken = File('${dir.path}/broken.jpg')
          ..writeAsBytesSync([0xFF, 0xD8, 0x00, 0x01]);
        final told = <int>[];
        final clean = await cleanPhotos(
          [good[0].path, broken.path, good[1].path],
          from: 'test',
          onPreparing: told.add,
        );
        expect(clean.paths, [good[0].path, good[1].path]);
        expect(clean.refused, 1);
        // Told, if it took long enough, how many; then 0.
        expect(told, anyOf(isEmpty, [3, 0]));
        await dir.delete(recursive: true);
      });
    });
  });

  test('PNG: the eXIf chunk and XMP go, the rest stays', () async {
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
    final after = (await cleanPhotoBytes(png)).bytes!;
    expect(after, [...png.sublist(0, 8), ...ihdr, ...iend]);
    final again = await cleanPhotoBytes(after);
    expect(again.result, PhotoCleaning.cleaned);
    expect(again.bytes, isNull, reason: 'nothing left to take out');
  });

  test('WebP: EXIF and XMP go, the header says so', () async {
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
    final after = (await cleanPhotoBytes(webp)).bytes!;
    final kept = [...vp8x, ...image]..[8] = 0x00;
    expect(after.sublist(12), kept);
    expect(
      ByteData.sublistView(after).getUint32(4, Endian.little),
      after.length - 8,
    );
  });

  test('H1: a PDF is not a photo: it passes unchanged', () async {
    final pdf = await cleanPhotoBytes(Uint8List.fromList('%PDF-1.7'.codeUnits));
    expect(pdf.result, PhotoCleaning.notImage);
    expect(pdf.bytes, isNull);
  });
}
