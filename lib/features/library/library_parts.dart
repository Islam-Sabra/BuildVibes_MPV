import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/l10n/bidi.dart';
import '../../data/models/chat.dart';
import '../../data/models/library.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_text_field.dart';
import '../chat/chat_tab.dart' show threadName;

/// The Space bucket's limit (migration 9).
const maxFileBytes = 25 * 1024 * 1024;

/// "2.1 MB", "640 KB", with Western digits.
String fileSize(AppLocalizations l10n, int? bytes) {
  if (bytes == null) return '';
  const kb = 1024;
  if (bytes < kb * kb) {
    return l10n.fileSizeKb('${(bytes / kb).ceil()}');
  }
  final mb = (bytes / (kb * kb)).toStringAsFixed(1);
  return l10n.fileSizeMb(BvWesternDigitsFormatter.normalise(mb));
}

/// Picks a PDF or photo on the phone (the Library, chat, W2-A). Null when
/// the person cancels. A provider so tests can stand in for the picker.
typedef PickDocument = Future<PhoneFile?> Function({bool pdfOnly});

final pickDocumentProvider = Provider<PickDocument>(
  (ref) => ({bool pdfOnly = false}) async {
    final f = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: pdfOnly
          ? const ['pdf']
          : const ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'heic'],
    );
    if (f == null || f.path == null) return null;
    final mime = mimeOfName(f.name);
    if (mime == null) return null;
    return PhoneFile(
      local: f.path!,
      name: f.name,
      mime: mime,
      bytes: await File(f.path!).length(),
    );
  },
);

/// A picked photo from the camera or gallery as a file to upload.
PhoneFile pickedPhoto(String path) => PhoneFile(
  local: path,
  name: path.split(Platform.pathSeparator).last,
  mime: mimeOfName(path) ?? 'image/jpeg',
  bytes: File(path).existsSync() ? File(path).lengthSync() : null,
);

/// Where a file is seen: "Everyone" or its Team's name.
String fileAudience(AppLocalizations l10n, LibraryFile f) => threadName(
  l10n,
  ChatThread(id: '', teamId: f.teamId, teamName: f.teamName),
);

/// S13k: "From chat · Omar · 2.1 MB" or "Structure team · you · 4.8 MB".
String fileMeta(AppLocalizations l10n, LibraryFile f, String? me) => joinMeta([
  if (f.source == LibrarySource.chat)
    l10n.libraryFromChat
  else
    fileAudience(l10n, f),
  if (f.uploadedById != null && f.uploadedById == me)
    l10n.chatYou
  else
    ?f.uploadedByName?.split(' ').first,
  fileSize(l10n, f.bytes),
]);

/// A Library file as a list row (S13k, pickers, W3 "Attached").
class FileRow extends StatelessWidget {
  const FileRow({
    super.key,
    required this.file,
    required this.subtitle,
    this.onTap,
    this.trailing = const BvRowTrailing.chevron(),
  });

  final LibraryFile file;
  final String subtitle;
  final VoidCallback? onTap;
  final BvRowTrailing trailing;

  @override
  Widget build(BuildContext context) {
    return BvListRow(
      key: Key('file-${file.id}'),
      title: inOwnDirection(file.name),
      subtitle: subtitle,
      leading: BvRowIcon(
        file.isImage ? BvIcons.image : BvIcons.document,
        ink: true,
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
