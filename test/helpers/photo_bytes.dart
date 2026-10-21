import 'dart:typed_data';

import 'package:buildvibes/core/photo_privacy.dart';
import 'package:flutter_test/flutter_test.dart';

/// Whether [part] is anywhere in [b].
bool hasBytes(Uint8List b, List<int> part) {
  for (var i = 0; i + part.length <= b.length; i++) {
    var all = true;
    for (var j = 0; j < part.length && all; j++) {
      all = b[i + j] == part[j];
    }
    if (all) return true;
  }
  return false;
}

/// One EXIF block as [exifBlocks] reads it.
typedef ExifBlock = ({
  Map<int, List<int>> ifd0,
  Map<int, List<int>> exif,
  int next,
});

/// The EXIF blocks of a JPEG, in order: each block's tags with their
/// values, and the first block's next block (a thumbnail when not 0).
List<ExifBlock> exifBlocks(Uint8List b) {
  final found = <ExifBlock>[];
  var i = 2;
  while (i + 4 <= b.length && b[i] == 0xFF && b[i + 1] != 0xDA) {
    final length = (b[i + 2] << 8) | b[i + 3];
    if (b[i + 1] == 0xE1 && String.fromCharCodes(b, i + 4, i + 8) == 'Exif') {
      final base = i + 10;
      final view = ByteData.sublistView(b);
      final order = b[base] == 0x4D ? Endian.big : Endian.little;
      int u16(int at) => view.getUint16(base + at, order);
      int u32(int at) => view.getUint32(base + at, order);
      List<int> value(int entry) {
        final type = u16(entry + 2);
        if (type == 3) return [u16(entry + 8)];
        if (type == 4) return [u32(entry + 8)];
        final size = u32(entry + 4);
        final from = size <= 4 ? entry + 8 : u32(entry + 8);
        return b.sublist(base + from, base + from + size);
      }

      Map<int, List<int>> block(int at) => {
        for (var e = 0; e < u16(at); e++)
          u16(at + 2 + e * 12): value(at + 2 + e * 12),
      };
      final first = u32(4);
      final ifd0 = block(first);
      final pointer = ifd0[0x8769];
      found.add((
        ifd0: ifd0,
        exif: pointer == null ? const {} : block(pointer.single),
        next: u32(first + 2 + u16(first) * 12),
      ));
    }
    i += 2 + length;
  }
  return found;
}

/// [bytes] through [cleanPhotoBytes], with the phone's decoder.
Future<Uint8List?> cleanForTest(WidgetTester tester, Uint8List bytes) =>
    tester.runAsync<Uint8List?>(() => cleanPhotoBytes(bytes));
