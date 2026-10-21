import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

// Takes the place a photo was taken out of it before it leaves the phone.
//
// Phones write the GPS position into a photo's metadata. A proof photo
// can end up on a profile, so it must never say where someone works or
// lives, nor which phone took it (its make, model and serial numbers can
// tie every photo to one device; review 50 F60). Only the orientation (so
// the photo isn't turned on its side) and the time it was taken (which
// the proof needs) stay.
//
// - JPEG: the EXIF block is written again from nothing, with only
//   Orientation, DateTimeOriginal and OffsetTimeOriginal. Nothing else of
//   the old block is kept, not even bytes no tag points to (a Xiaomi
//   phone leaves a second copy of its make and model there), and no
//   thumbnail. XMP (which can repeat the position) is dropped.
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
      final old = Uint8List.sublistView(b, i, end);
      // Unreadable, or nothing worth keeping: no block at all.
      final fresh = _freshExif(old, 4 + _exifHeader.length);
      if (fresh == null || !_same(fresh, old)) changed = true;
      if (fresh != null) out.add(fresh);
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

bool _same(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

const _orientation = 0x0112;
const _exifPointer = 0x8769;
const _dateTimeOriginal = 0x9003;
const _offsetTimeOriginal = 0x9011;

/// A whole new APP1 segment for the TIFF data at [base] in [s], with only
/// what the photo needs: Orientation in the first block, and
/// DateTimeOriginal and OffsetTimeOriginal in an EXIF block (left out
/// when neither is there). No GPS, no maker note, no thumbnail, and
/// nothing else of the old block. Null when the data can't be read, or
/// holds none of the three.
Uint8List? _freshExif(Uint8List s, int base) {
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

  // Where each entry of the block at [ifd] sits, by tag. Null when the
  // block can't be read.
  Map<int, int>? entries(int ifd) {
    if (!fits(ifd, 2)) return null;
    final n = u16(ifd);
    if (!fits(ifd + 2, n * 12)) return null;
    return {
      for (var e = 0; e < n; e++) u16(ifd + 2 + e * 12): ifd + 2 + e * 12,
    };
  }

  // A time as the camera wrote it ("2026:10:21 15:21:11", "+03:00"):
  // only digits, colons, signs and spaces, ending in NUL.
  Uint8List? time(Map<int, int> block, int tag) {
    final at = block[tag];
    if (at == null || u16(at + 2) != 2) return null;
    final count = u32(at + 4);
    if (count < 2 || count > 32) return null;
    final value = count <= 4 ? at + 8 : base + u32(at + 8);
    if (!fits(value, count)) return null;
    final text = Uint8List.fromList(s.sublist(value, value + count));
    if (text.last != 0) return null;
    for (final c in text.take(count - 1)) {
      final digit = c >= 0x30 && c <= 0x39;
      if (!digit && c != 0x3A && c != 0x20 && c != 0x2B && c != 0x2D) {
        return null;
      }
    }
    return text;
  }

  if (u16(base + 2) != 42) return null;
  final ifd0 = entries(base + u32(base + 4));
  if (ifd0 == null) return null;
  final at = ifd0[_orientation];
  final orientation = at != null && u16(at + 2) == 3 && u32(at + 4) == 1
      ? u16(at + 8)
      : null;
  final exifAt = ifd0[_exifPointer];
  final exif = exifAt == null ? null : entries(base + u32(exifAt + 8));
  final times = <int, Uint8List>{
    for (final tag in [_dateTimeOriginal, _offsetTimeOriginal])
      if (exif != null) tag: ?time(exif, tag),
  };
  if (orientation == null && times.isEmpty) return null;
  return _exifSegment(orientation, times);
}

/// "Exif", then a big-endian TIFF: the first block with [orientation] and
/// where the EXIF block is, then the EXIF block with [times] and their
/// values. Neither block has a next one: no thumbnail.
Uint8List _exifSegment(int? orientation, Map<int, Uint8List> times) {
  final first = [
    if (orientation != null) _orientation,
    if (times.isNotEmpty) _exifPointer,
  ];
  const ifd0 = 8;
  final exifIfd = ifd0 + 2 + first.length * 12 + 4;
  final tags = times.keys.toList()..sort();
  var size = exifIfd;
  if (tags.isNotEmpty) {
    size += 2 + tags.length * 12 + 4;
    for (final t in tags) {
      final n = times[t]!.length;
      if (n > 4) size += n + n % 2;
    }
  }
  final tiff = ByteData(size)
    ..setUint16(0, 0x4D4D)
    ..setUint16(2, 42)
    ..setUint32(4, ifd0)
    ..setUint16(ifd0, first.length);
  for (final (e, tag) in first.indexed) {
    final at = ifd0 + 2 + e * 12;
    tiff
      ..setUint16(at, tag)
      ..setUint32(at + 4, 1);
    if (tag == _orientation) {
      tiff
        ..setUint16(at + 2, 3)
        ..setUint16(at + 8, orientation!);
    } else {
      tiff
        ..setUint16(at + 2, 4)
        ..setUint32(at + 8, exifIfd);
    }
  }
  if (tags.isNotEmpty) {
    tiff.setUint16(exifIfd, tags.length);
    var value = exifIfd + 2 + tags.length * 12 + 4;
    for (final (e, tag) in tags.indexed) {
      final text = times[tag]!;
      final at = exifIfd + 2 + e * 12;
      tiff
        ..setUint16(at, tag)
        ..setUint16(at + 2, 2)
        ..setUint32(at + 4, text.length);
      var to = at + 8;
      if (text.length > 4) {
        tiff.setUint32(at + 8, value);
        to = value;
        value += text.length + text.length % 2;
      }
      for (final (k, c) in text.indexed) {
        tiff.setUint8(to + k, c);
      }
    }
  }
  final length = 2 + _exifHeader.length + size;
  return (BytesBuilder(copy: false)
        ..add([0xFF, 0xE1, length >> 8, length & 0xFF])
        ..add(_exifHeader.codeUnits)
        ..add(tiff.buffer.asUint8List()))
      .toBytes();
}

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
