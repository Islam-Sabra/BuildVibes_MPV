import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Opens the phone's own share sheet (WhatsApp, SMS and so on). A provider
/// so tests can see what was shared.
typedef ShareText = Future<void> Function(String text);

final shareTextProvider = Provider<ShareText>(
  (ref) =>
      (text) => SharePlus.instance.share(ShareParams(text: text)),
);

/// Shares a file through the phone's share sheet (F1).
typedef ShareFileBytes =
    Future<void> Function(String name, String mime, Uint8List bytes);

final shareFileProvider = Provider<ShareFileBytes>(
  (ref) =>
      (name, mime, bytes) => SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, name: name, mimeType: mime)],
          fileNameOverrides: [name],
        ),
      ),
);

/// F1 Download: the phone asks where to save it. True when saved.
typedef SaveFileBytes = Future<bool> Function(String name, Uint8List bytes);

final saveFileProvider = Provider<SaveFileBytes>(
  (ref) =>
      (name, bytes) async =>
          await FilePicker.saveFile(fileName: name, bytes: bytes) != null,
);
