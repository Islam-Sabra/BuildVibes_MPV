import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

// Makes a photo safe to leave the phone (review 50 F60).
//
// Phones write the GPS position, the make, model and serial numbers into
// a photo. A proof photo can end up on a profile, so it must never say
// where someone works or lives, nor which phone took it. Only the time it
// was taken stays, which the proof needs.
//
// - JPEG: drawn again from its pixels. It is decoded, turned upright, made
//   at most [photoMaxSide] on its longest side, and written as a new JPEG
//   at [photoQuality]. Its only metadata is a new EXIF block with the
//   time it was taken (DateTimeOriginal, OffsetTimeOriginal), so nothing
//   of the old file comes along: no GPS, no make or model, no maker note,
//   no thumbnail, no XMP, not even bytes no tag points to.
// - PNG and WebP stay as they are drawn (a screenshot or a drawing keeps
//   its sharp lines and its transparency); their EXIF and XMP are dropped.
// - Anything else (PDF, sound) is left as it is. The file picker doesn't
//   offer HEIC, and the camera and gallery pickers give JPEG.

/// The longest side of a photo that leaves the phone; a smaller one is
/// never made bigger.
const photoMaxSide = 2560;

/// The JPEG quality a photo is written at.
const photoQuality = 85;

/// Rewrites the photo at [path] as [cleanPhotoBytes] makes it. Leaves the
/// file as it is when there is nothing to change, or it isn't a photo this
/// can read.
Future<void> cleanPhoto(String path) async {
  try {
    final file = File(path);
    final clean = await cleanPhotoBytes(await file.readAsBytes());
    if (clean != null) await file.writeAsBytes(clean, flush: true);
  } on FileSystemException catch (e) {
    debugPrint('photo: $e');
  }
}

/// [bytes] made safe to leave the phone, or null when there was nothing
/// to change (or it isn't a JPEG, PNG or WebP this can read).
Future<Uint8List?> cleanPhotoBytes(Uint8List bytes) async {
  if (_isJpeg(bytes)) return _redrawJpeg(bytes);
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

/// Decodes with the phone's own decoder (turned upright by its EXIF
/// orientation, and made smaller as it decodes), then writes the JPEG in
/// a background isolate. Null when it can't be decoded.
Future<Uint8List?> _redrawJpeg(Uint8List bytes) async {
  final taken = _takenAt(bytes);
  final ByteData pixels;
  final int width;
  final int height;
  try {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final scale = min(
      1.0,
      photoMaxSide / max(descriptor.width, descriptor.height),
    );
    final codec = await descriptor.instantiateCodec(
      targetWidth: scale < 1 ? (descriptor.width * scale).round() : null,
      targetHeight: scale < 1 ? (descriptor.height * scale).round() : null,
    );
    final image = (await codec.getNextFrame()).image;
    codec.dispose();
    descriptor.dispose();
    buffer.dispose();
    width = image.width;
    height = image.height;
    final rgba = await image.toByteData();
    image.dispose();
    if (rgba == null) return null;
    pixels = rgba;
  } on Exception catch (e) {
    debugPrint('photo: $e');
    return null;
  }
  final jpeg = await Isolate.run(
    () => img.encodeJpg(
      img.Image.fromBytes(
        width: width,
        height: height,
        bytes: pixels.buffer,
        bytesOffset: pixels.offsetInBytes,
        numChannels: 4,
      ),
      quality: photoQuality,
    ),
  );
  return taken.isEmpty ? jpeg : _withExif(jpeg, _exifSegment(taken));
}

const _exifHeader = 'Exif\u0000\u0000';
const _exifPointer = 0x8769;
const _dateTimeOriginal = 0x9003;
const _offsetTimeOriginal = 0x9011;

/// The time [b] was taken, as its EXIF says it: DateTimeOriginal and
/// OffsetTimeOriginal, by tag, each when it is there and reads as a time.
Map<int, Uint8List> _takenAt(Uint8List b) {
  var i = 2;
  while (i + 4 <= b.length && b[i] == 0xFF) {
    final marker = b[i + 1];
    if (marker == 0xDA || marker == 0xD9) break;
    final length = (b[i + 2] << 8) | b[i + 3];
    if (length < 2 || i + 2 + length > b.length) break;
    if (marker == 0xE1 && _ascii(b, i + 4, _exifHeader)) {
      return _timesIn(
        Uint8List.sublistView(b, i, i + 2 + length),
        4 + _exifHeader.length,
      );
    }
    i += 2 + length;
  }
  return const {};
}

/// The times in the TIFF data at [base] in [s].
Map<int, Uint8List> _timesIn(Uint8List s, int base) {
  if (base + 8 > s.length) return const {};
  final Endian order;
  if (s[base] == 0x49 && s[base + 1] == 0x49) {
    order = Endian.little;
  } else if (s[base] == 0x4D && s[base + 1] == 0x4D) {
    order = Endian.big;
  } else {
    return const {};
  }
  final view = ByteData.sublistView(s);
  int u16(int at) => view.getUint16(at, order);
  int u32(int at) => view.getUint32(at, order);
  bool fits(int at, int size) => at >= base && at + size <= s.length;

  // Where each entry of the block at [ifd] sits, by tag.
  Map<int, int> entries(int ifd) {
    if (!fits(ifd, 2)) return const {};
    final n = u16(ifd);
    if (!fits(ifd + 2, n * 12)) return const {};
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

  if (u16(base + 2) != 42) return const {};
  final ifd0 = entries(base + u32(base + 4));
  final pointer = ifd0[_exifPointer];
  if (pointer == null) return const {};
  final exif = entries(base + u32(pointer + 8));
  return {
    for (final tag in [_dateTimeOriginal, _offsetTimeOriginal])
      tag: ?time(exif, tag),
  };
}

/// "Exif", then a big-endian TIFF: a first block that only says where the
/// EXIF block is, then the EXIF block with [times] and their values.
/// Neither block has a next one: no thumbnail.
Uint8List _exifSegment(Map<int, Uint8List> times) {
  const ifd0 = 8;
  const exifIfd = ifd0 + 2 + 12 + 4;
  final tags = times.keys.toList()..sort();
  var size = exifIfd + 2 + tags.length * 12 + 4;
  for (final t in tags) {
    final n = times[t]!.length;
    if (n > 4) size += n + n % 2;
  }
  final tiff = ByteData(size)
    ..setUint16(0, 0x4D4D)
    ..setUint16(2, 42)
    ..setUint32(4, ifd0)
    ..setUint16(ifd0, 1)
    ..setUint16(ifd0 + 2, _exifPointer)
    ..setUint16(ifd0 + 4, 4)
    ..setUint32(ifd0 + 6, 1)
    ..setUint32(ifd0 + 10, exifIfd)
    ..setUint16(exifIfd, tags.length);
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
  final length = 2 + _exifHeader.length + size;
  return (BytesBuilder(copy: false)
        ..add([0xFF, 0xE1, length >> 8, length & 0xFF])
        ..add(_exifHeader.codeUnits)
        ..add(tiff.buffer.asUint8List()))
      .toBytes();
}

/// [jpeg] with [exif] after its start (and its JFIF block, when it has one).
Uint8List _withExif(Uint8List jpeg, Uint8List exif) {
  var at = 2;
  if (jpeg.length > 6 && jpeg[2] == 0xFF && jpeg[3] == 0xE0) {
    at += 2 + ((jpeg[4] << 8) | jpeg[5]);
  }
  return (BytesBuilder(copy: false)
        ..add(Uint8List.sublistView(jpeg, 0, at))
        ..add(exif)
        ..add(Uint8List.sublistView(jpeg, at)))
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
