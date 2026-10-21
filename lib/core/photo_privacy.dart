import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

// Makes a photo safe to leave the phone (review 50 F60, review 74).
//
// Phones write the GPS position, the make, model and serial numbers into
// a photo. A proof photo can end up on a profile, so it must never say
// where someone works or lives, nor which phone took it. Only the time it
// was taken stays, which the proof needs.
//
// - JPEG, in three steps (review 74 H1):
//   1. Drawn again from its pixels: decoded, turned upright, made at most
//      [photoMaxSide] on its longest side, and written as a new JPEG at
//      [photoQuality]. Its only metadata is a new EXIF block with the time
//      it was taken (DateTimeOriginal, OffsetTimeOriginal), so nothing of
//      the old file comes along: no GPS, no make or model, no maker note,
//      no thumbnail, no XMP, not even bytes no tag points to.
//   2. When the phone can't decode it but its markers read up to the
//      picture, every metadata block is taken out without decoding (APP1
//      to APP15 and comments: EXIF, XMP, maker notes, ICC, the thumbnail).
//      APP0 and the picture stay, and it goes.
//   3. Otherwise nobody could open it: it is refused, never sent.
// - PNG and WebP stay as they are drawn (a screenshot or a drawing keeps
//   its sharp lines and its transparency); their EXIF and XMP are dropped.
//   One that can't be read is refused.
// - Anything else (PDF, sound) is not a photo and goes as it is. The file
//   picker doesn't offer HEIC, and the camera and gallery pickers give
//   JPEG.
//
// Each photo writes one line to the phone's log, and nowhere else, for
// timing on a real phone (review 74 H3): see [photoLogPrefix].

/// The longest side of a photo that leaves the phone; a smaller one is
/// never made bigger.
const photoMaxSide = 2560;

/// The JPEG quality a photo is written at.
const photoQuality = 85;

/// How long cleaning may take before the photo slots say "Preparing…"
/// (review 74 H2).
const photoPreparingAfter = Duration(milliseconds: 400);

/// The start of each photo's line in the phone's log (`adb logcat`):
/// `BV-PHOTO from=gallery result=cleaned step=redrawn ms=812
/// before=4000x3000 after=2560x1920 bytes=6042657>1336974`.
const photoLogPrefix = 'BV-PHOTO';

/// What became of a photo on its way out.
enum PhotoCleaning {
  /// Made safe: it goes.
  cleaned,

  /// Not a photo (a PDF): it goes as it is.
  notImage,

  /// Nobody could open it: it doesn't go.
  refused,
}

/// [cleanPhoto]'s answer: what became of the photo, and the file to send
/// (the same one, or a fresh copy in the app's own folder when it
/// couldn't be written).
typedef CleanedPhoto = ({PhotoCleaning result, String path});

/// [cleanPhotoBytes]'s answer. [bytes] is what to write, or null to leave
/// the file as it is; [step] how it was made safe; [before] and [after]
/// the picture's sizes when it was drawn again.
typedef CleanedBytes = ({
  PhotoCleaning result,
  Uint8List? bytes,
  String step,
  String? before,
  String? after,
});

/// The photos picked at once, cleaned side by side: the files to send,
/// and how many were refused.
typedef CleanedPhotos = ({List<String> paths, int refused});

/// Cleans every one of [paths] at the same time. When that takes longer
/// than [photoPreparingAfter], [onPreparing] hears how many are being
/// prepared, and 0 once they are done. [from] names the picker in the
/// log.
Future<CleanedPhotos> cleanPhotos(
  List<String> paths, {
  required String from,
  void Function(int count)? onPreparing,
}) async {
  var told = false;
  final timer = Timer(photoPreparingAfter, () {
    told = true;
    onPreparing?.call(paths.length);
  });
  final done = await Future.wait([
    for (final p in paths) cleanPhoto(p, from: from),
  ]);
  timer.cancel();
  if (told) onPreparing?.call(0);
  return (
    paths: [
      for (final c in done)
        if (c.result != PhotoCleaning.refused) c.path,
    ],
    refused: done.where((c) => c.result == PhotoCleaning.refused).length,
  );
}

/// Photos a picker gave, made safe to leave the phone (cleanPhotos):
/// [photos] to send, and how many of those picked nobody could open
/// (review 74 H1). None when the person cancels.
typedef PickedPhotos = ({List<XFile> photos, int refused});

/// Cleans [picked] side by side (cleanPhotos); [onPreparing] as there.
Future<PickedPhotos> cleanPicked(
  List<XFile> picked, {
  required String from,
  void Function(int count)? onPreparing,
}) async {
  if (picked.isEmpty) return (photos: const <XFile>[], refused: 0);
  final clean = await cleanPhotos(
    [for (final p in picked) p.path],
    from: from,
    onPreparing: onPreparing,
  );
  return (
    photos: [for (final p in clean.paths) XFile(p)],
    refused: clean.refused,
  );
}

/// How many photos a card is still preparing, by card: its "Preparing…"
/// slots (review 74 H2).
final photosPreparingProvider =
    NotifierProvider.family<PhotosPreparing, int, String>(PhotosPreparing.new);

class PhotosPreparing extends Notifier<int> {
  PhotosPreparing(this.card);

  /// Which card (`daybook:<space id>`, `post`).
  final String card;

  @override
  int build() => 0;

  void set(int count) => state = count;
}

/// Makes the photo at [path] safe as [cleanPhotoBytes] does, and writes it
/// back. When it can't be written there, a fresh copy goes in [spare]
/// (the app's own folder); the original is never sent. [from] names the
/// picker in the log.
Future<CleanedPhoto> cleanPhoto(
  String path, {
  required String from,
  Future<Directory> Function() spare = _spareFolder,
}) async {
  final watch = Stopwatch()..start();
  var size = '0';
  CleanedPhoto answer;
  CleanedBytes? clean;
  try {
    final bytes = await File(path).readAsBytes();
    size = '${bytes.length}';
    clean = await cleanPhotoBytes(bytes);
    final out = clean.bytes;
    answer = (result: clean.result, path: path);
    if (out != null) {
      size = '$size>${out.length}';
      answer = (result: clean.result, path: await _write(path, out, spare));
    }
  } on FileSystemException catch (e) {
    debugPrint('$photoLogPrefix $e');
    answer = (result: PhotoCleaning.refused, path: path);
  }
  debugPrint(
    '$photoLogPrefix from=$from result=${answer.result.name} '
    'step=${clean?.step ?? 'unread'} ms=${watch.elapsedMilliseconds} '
    'before=${clean?.before ?? '-'} after=${clean?.after ?? '-'} '
    'bytes=$size',
  );
  return answer;
}

/// Writes [bytes] at [path], or in a fresh file in [spare] when [path]
/// can't be written. Throws when neither can.
Future<String> _write(
  String path,
  Uint8List bytes,
  Future<Directory> Function() spare,
) async {
  try {
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  } on FileSystemException catch (e) {
    debugPrint('$photoLogPrefix $e');
    final dot = path.lastIndexOf('.');
    final ext = dot < 0 ? '' : path.substring(dot);
    final dir = await spare();
    final copy = File(
      '${dir.path}/${DateTime.now().microsecondsSinceEpoch}$ext',
    );
    await copy.writeAsBytes(bytes, flush: true);
    return copy.path;
  }
}

Future<Directory> _spareFolder() async => Directory(
  '${(await getApplicationDocumentsDirectory()).path}/cleaned',
).create(recursive: true);

/// [bytes] made safe to leave the phone, as the steps above say.
Future<CleanedBytes> cleanPhotoBytes(Uint8List bytes) async {
  CleanedBytes cleaned(Uint8List? out, String step) => (
    result: PhotoCleaning.cleaned,
    bytes: out,
    step: step,
    before: null,
    after: null,
  );
  const refused = (
    result: PhotoCleaning.refused,
    bytes: null,
    step: 'refused',
    before: null,
    after: null,
  );
  if (_isJpeg(bytes)) {
    final redrawn = await _redrawJpeg(bytes);
    if (redrawn != null) return redrawn;
    final stripped = _stripJpeg(bytes);
    return stripped == null ? refused : cleaned(stripped, 'stripped');
  }
  final Uint8List? kept;
  if (_isPng(bytes)) {
    kept = _png(bytes);
  } else if (_isWebp(bytes)) {
    kept = _webp(bytes);
  } else {
    return (
      result: PhotoCleaning.notImage,
      bytes: null,
      step: 'none',
      before: null,
      after: null,
    );
  }
  if (kept == null) return refused;
  return cleaned(identical(kept, bytes) ? null : kept, 'chunks');
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

/// Step 1: decoded with the phone's own decoder (turned upright by its
/// EXIF orientation, and made smaller as it decodes), then written in a
/// background isolate. Null when it can't be decoded.
Future<CleanedBytes?> _redrawJpeg(Uint8List bytes) async {
  final taken = _takenAt(bytes);
  final ByteData pixels;
  final int width;
  final int height;
  final String before;
  try {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    before = '${descriptor.width}x${descriptor.height}';
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
    debugPrint('$photoLogPrefix $e');
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
  return (
    result: PhotoCleaning.cleaned,
    bytes: taken.isEmpty ? jpeg : _withExif(jpeg, _exifSegment(taken)),
    step: 'redrawn',
    before: before,
    after: '${width}x$height',
  );
}

/// Step 2: [b] without APP1 to APP15 and comments, read marker by marker
/// up to the picture, which is copied as it is. Null when the markers
/// don't read up to the start of scan.
Uint8List? _stripJpeg(Uint8List b) {
  final out = BytesBuilder(copy: false)..add(b.sublist(0, 2));
  var i = 2;
  while (i + 4 <= b.length) {
    if (b[i] != 0xFF) return null;
    final marker = b[i + 1];
    // Fill bytes and markers with no length.
    if (marker == 0xFF) {
      i++;
      continue;
    }
    if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
      out.add(b.sublist(i, i + 2));
      i += 2;
      continue;
    }
    if (marker == 0xD8 || marker == 0xD9) return null;
    final length = (b[i + 2] << 8) | b[i + 3];
    final end = i + 2 + length;
    if (length < 2 || end > b.length) return null;
    // Start of scan: the picture itself follows, copied as it is.
    if (marker == 0xDA) {
      out.add(b.sublist(i));
      return out.toBytes();
    }
    final metadata = (marker >= 0xE1 && marker <= 0xEF) || marker == 0xFE;
    if (!metadata) out.add(b.sublist(i, end));
    i = end;
  }
  return null;
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

/// [b] without its eXIf chunk and XMP text; [b] itself when it has
/// neither, null when its chunks don't read.
Uint8List? _png(Uint8List b) {
  if (!_ascii(b, 12, 'IHDR')) return null;
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
  if (!changed) return b;
  out.add(b.sublist(i));
  return out.toBytes();
}

// WebP ------------------------------------------------------------------------

/// [b] without its EXIF and XMP chunks; [b] itself when it has neither,
/// null when its chunks don't read.
Uint8List? _webp(Uint8List b) {
  if (b.length < 20) return null;
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
  if (!changed) return b;
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
