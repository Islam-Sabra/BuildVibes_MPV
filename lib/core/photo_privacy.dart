import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

// Takes the place a photo was taken out of it before it leaves the phone.
//
// Phones write the GPS position into a photo's metadata. A proof photo
// can end up on a profile, so it must never say where someone works or
// lives. The rest of the metadata stays (the orientation, so the photo
// isn't turned on its side; the time it was taken).
//
// - JPEG: the EXIF GPS block is emptied, and XMP (which can repeat the
//   position) is dropped.
// - PNG: the eXIf chunk and XMP text are dropped.
// - WebP: the EXIF and XMP chunks are dropped.
// - Anything else (PDF, sound) is left as it is. The file picker doesn't
//   offer HEIC, and the camera and gallery pickers give JPEG.

/// Rewrites the photo at [path] without its location. Leaves the file as it
/// is when it has none, or isn't a photo this can read.
Future<void> stripPhotoLocation(String path) async {
  try {
    final file = File(path);
    final clean = withoutLocation(await file.readAsBytes());
    if (clean != null) await file.writeAsBytes(clean, flush: true);
  } on FileSystemException catch (e) {
    debugPrint('photo location: $e');
  }
}

/// [bytes] without the place they were taken, or null when there was
/// nothing to take out (or it isn't a JPEG, PNG or WebP).
Uint8List? withoutLocation(Uint8List bytes) {
  if (_isJpeg(bytes)) return _jpeg(bytes);
  if (_isPng(bytes)) return _png(bytes);
  if (_isWebp(bytes)) return _webp(bytes);
  return null;
}

bool _isJpeg(Uint8List b) => b.length > 3 && b[0] == 0xFF && b[1] == 0xD8;

bool _isPng(Uint8List b) =>
    b.length > 8 &&
    b[0] == 0x89 &&
    b[1] == 0x50 &&
    b[2] == 0x4E &&
    b[3] == 0x47;

bool _isWebp(Uint8List b) =>
    b.length > 12 && _ascii(b, 0, 'RIFF') && _ascii(b, 8, 'WEBP');

bool _ascii(Uint8List b, int at, String s) {
  if (at + s.length > b.length) return false;
  for (var i = 0; i < s.length; i++) {
    if (b[at + i] != s.codeUnitAt(i)) return false;
  }
  return true;
}

// JPEG ------------------------------------------------------------------------

const _exifHeader = 'Exif\u0000\u0000';
const _xmpHeader = 'http://ns.adobe.com/xap/1.0/\u0000';
const _xmpExtHeader = 'http://ns.adobe.com/xmp/extension/\u0000';

Uint8List? _jpeg(Uint8List b) {
  final out = BytesBuilder(copy: false)..add(b.sublist(0, 2));
  var changed = false;
  var i = 2;
  while (i + 4 <= b.length) {
    if (b[i] != 0xFF) return null; // Not a segment: leave the file as it is.
    final marker = b[i + 1];
    // Start of scan: the picture itself follows, copied as it is.
    if (marker == 0xDA) break;
    // Markers with no length.
    if (marker == 0x01 ||
        (marker >= 0xD0 && marker <= 0xD7) ||
        marker == 0xFF) {
      out.add(b.sublist(i, i + 2));
      i += 2;
      continue;
    }
    final length = (b[i + 2] << 8) | b[i + 3];
    final end = i + 2 + length;
    if (length < 2 || end > b.length) return null;
    final body = i + 4;
    if (marker == 0xE1 && _ascii(b, body, _exifHeader)) {
      final segment = Uint8List.fromList(b.sublist(i, end));
      final tiff = 4 + _exifHeader.length;
      final wiped = _wipeGps(segment, tiff);
      if (wiped == null) {
        changed = true; // Can't read it: drop the whole block.
      } else {
        changed |= wiped;
        out.add(segment);
      }
    } else if (marker == 0xE1 &&
        (_ascii(b, body, _xmpHeader) || _ascii(b, body, _xmpExtHeader))) {
      changed = true;
    } else {
      out.add(b.sublist(i, end));
    }
    i = end;
  }
  if (!changed) return null;
  out.add(b.sublist(i));
  return out.toBytes();
}

/// Empties the GPS block of the TIFF data at [base] in [s], in place: its
/// values are zeroed and it is left with no entries. True when there was
/// one, false when there was none, null when the data can't be read.
bool? _wipeGps(Uint8List s, int base) {
  if (base + 8 > s.length) return null;
  final Endian order;
  if (s[base] == 0x49 && s[base + 1] == 0x49) {
    order = Endian.little;
  } else if (s[base] == 0x4D && s[base + 1] == 0x4D) {
    order = Endian.big;
  } else {
    return null;
  }
  final view = ByteData.sublistView(s);
  int u16(int at) => view.getUint16(at, order);
  int u32(int at) => view.getUint32(at, order);
  bool fits(int at, int size) => at >= base && at + size <= s.length;

  if (u16(base + 2) != 42) return null;
  final ifd0 = base + u32(base + 4);
  if (!fits(ifd0, 2)) return null;
  final entries = u16(ifd0);
  if (!fits(ifd0 + 2, entries * 12)) return null;
  int? gps;
  for (var e = 0; e < entries; e++) {
    final at = ifd0 + 2 + e * 12;
    if (u16(at) == 0x8825) gps = base + u32(at + 8);
  }
  if (gps == null) return false;
  if (!fits(gps, 2)) return null;
  final count = u16(gps);
  if (count == 0) return false;
  if (!fits(gps + 2, count * 12 + 4)) return null;
  for (var e = 0; e < count; e++) {
    final at = gps + 2 + e * 12;
    final size = _typeSize(u16(at + 2)) * u32(at + 4);
    if (size > 4) {
      final value = base + u32(at + 8);
      if (fits(value, size)) s.fillRange(value, value + size, 0);
    }
  }
  // No entries, and no next block.
  s.fillRange(gps, gps + 2 + count * 12 + 4, 0);
  return true;
}

int _typeSize(int type) => switch (type) {
  1 || 2 || 6 || 7 => 1,
  3 || 8 => 2,
  4 || 9 || 11 => 4,
  5 || 10 || 12 => 8,
  _ => 0,
};

// PNG -------------------------------------------------------------------------

Uint8List? _png(Uint8List b) {
  final view = ByteData.sublistView(b);
  final out = BytesBuilder(copy: false)..add(b.sublist(0, 8));
  var changed = false;
  var i = 8;
  while (i + 12 <= b.length) {
    final length = view.getUint32(i);
    final end = i + 12 + length;
    if (end > b.length) return null;
    final drop =
        _ascii(b, i + 4, 'eXIf') ||
        (_ascii(b, i + 4, 'iTXt') && _ascii(b, i + 8, 'XML:com.adobe.xmp'));
    if (drop) {
      changed = true;
    } else {
      out.add(b.sublist(i, end));
    }
    i = end;
  }
  if (!changed) return null;
  out.add(b.sublist(i));
  return out.toBytes();
}

// WebP ------------------------------------------------------------------------

Uint8List? _webp(Uint8List b) {
  final view = ByteData.sublistView(b);
  final body = BytesBuilder(copy: false);
  var changed = false;
  var vp8x = -1;
  var i = 12;
  while (i + 8 <= b.length) {
    final length = view.getUint32(i + 4, Endian.little);
    final end = i + 8 + length + (length.isOdd ? 1 : 0);
    if (end > b.length) return null;
    if (_ascii(b, i, 'EXIF') || _ascii(b, i, 'XMP ')) {
      changed = true;
    } else {
      if (_ascii(b, i, 'VP8X')) vp8x = body.length;
      body.add(b.sublist(i, end));
    }
    i = end;
  }
  if (!changed) return null;
  final chunks = body.toBytes();
  // The extended header says which chunks follow: no EXIF (0x08), no XMP (0x04).
  if (vp8x >= 0 && vp8x + 8 < chunks.length) chunks[vp8x + 8] &= ~0x0C;
  final head = Uint8List(12)..setRange(0, 12, b);
  ByteData.sublistView(head).setUint32(4, 4 + chunks.length, Endian.little);
  return (BytesBuilder(copy: false)
        ..add(head)
        ..add(chunks))
      .toBytes();
}
