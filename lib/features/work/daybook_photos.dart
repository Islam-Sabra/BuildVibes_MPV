import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';

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
final filePreviewProvider = FutureProvider.autoDispose
    .family<ImageProvider?, ({String path, String mime})>((ref, file) async {
      final path = file.path;
      final library = ref.watch(libraryRepositoryProvider);
      if (file.mime.startsWith('image/')) {
        return NetworkImage(await library.fileUrl(path));
      }
      if (file.mime != _pdf) return null;
      final document = await PdfDocument.openData(library.download(path));
      try {
        final page = await document.getPage(1);
        try {
          final image = await page.render(
            width: page.width * _scale,
            height: page.height * _scale,
            format: PdfPageImageFormat.png,
          );
          return image == null ? null : MemoryImage(image.bytes);
        } finally {
          await page.close();
        }
      } finally {
        await document.close();
      }
    });

const _pdf = 'application/pdf';

/// The first page is drawn at twice its size, sharp on a phone's screen.
const _scale = 2.0;
