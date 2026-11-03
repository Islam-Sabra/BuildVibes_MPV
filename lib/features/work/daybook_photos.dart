import 'dart:io';

import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';

import '../../core/file_cache.dart';
import '../../data/repositories/library_repository.dart';
import '../../data/repositories/work_repository.dart';

/// A photo in the Space's private files, through a short-lived link; null
/// while the link loads. Screens stand in for it in tests.
final daybookPhotoProvider = Provider.autoDispose
    .family<ImageProvider?, String>((ref, path) {
      final url = ref.watch(workPhotoUrlProvider(path)).value;
      return url == null ? null : NetworkImage(url);
    });

/// A photo kept on the phone (a draft's, or one waiting to be sent).
final localPhotoProvider = Provider.autoDispose.family<ImageProvider, String>(
  (ref, path) => FileImage(File(path)),
);

/// A file post's big preview (K2 v13): a photo as it is, a PDF's first
/// page drawn by the phone's own PDF renderer. Null while it loads, or
/// when it can't be drawn (the card shows the plain surface). Screens
/// stand in for it in tests.
///
/// Review 114 B2: the PDF is the phone's one copy ([fileCacheProvider]),
/// and its first page, once drawn, is kept: a card shown again neither
/// downloads nor draws.
final filePreviewProvider = FutureProvider.autoDispose
    .family<ImageProvider?, ({String path, String mime})>((ref, file) async {
      final path = file.path;
      if (file.mime.startsWith('image/')) {
        final library = ref.watch(libraryRepositoryProvider);
        return NetworkImage(await library.fileUrl(path));
      }
      if (file.mime != _pdf) return null;
      final files = ref.watch(fileCacheProvider);
      // Read before the waits: a card scrolled away may dispose this.
      final draw = ref.read(firstPageProvider);
      final kept = await files.thumb(path);
      if (kept != null) return MemoryImage(await kept.readAsBytes());
      final local = await files.file(path);
      final png = await draw(local.path);
      if (png == null) return null;
      await files.keepThumb(path, png);
      return MemoryImage(png);
    });

/// A PDF's first page as a PNG, from its copy on the phone (openFile: no
/// copy of its own). Tests stand in for it.
final firstPageProvider = Provider<Future<Uint8List?> Function(String local)>(
  (ref) => (local) async {
    final document = await PdfDocument.openFile(local);
    try {
      final page = await document.getPage(1);
      try {
        final image = await page.render(
          width: page.width * _scale,
          height: page.height * _scale,
          format: PdfPageImageFormat.png,
        );
        return image?.bytes;
      } finally {
        await page.close();
      }
    } finally {
      await document.close();
    }
  },
);

const _pdf = 'application/pdf';

/// The first page is drawn at twice its size, sharp on a phone's screen.
const _scale = 2.0;
