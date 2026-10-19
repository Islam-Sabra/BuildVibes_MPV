import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
