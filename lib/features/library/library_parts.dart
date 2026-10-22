import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/photo_privacy.dart';
import '../../core/design/bv_icons.dart';
import '../../core/l10n/bidi.dart';
import '../../data/models/chat.dart';
import '../../data/models/library.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_text_field.dart';
import '../chat/chat_tab.dart' show threadName;
import '../spaces/former_member.dart';

/// The Space bucket's limit (migration 9).
const maxFileBytes = 25 * 1024 * 1024;

/// The document formats a Space takes, besides photos (review 50 F49).
/// It mirrors the server's own list: add_library_file and add_post_files
/// accept `application/pdf` and images (supabase/migrations/
/// 20261019120000_model_views.sql, 20261015120000_daybook.sql), and the
/// bucket `space-files` the same types. Add a format here only once the
/// server takes it; the File row's line lists them ("PDF", "PDF, DWG").
/// Formats are named as written, in every language.
const libraryDocumentFormats = ['PDF'];

/// The File row's small line: the formats the server takes.
String libraryDocumentLine() => libraryDocumentFormats.join(', ');

/// "2.1 MB", "640 KB", with Western digits.
/// The phone's megabyte, as file sizes are written everywhere.
const bvMegabyte = 1024 * 1024;

String fileSize(AppLocalizations l10n, int? bytes) {
  if (bytes == null) return '';
  const kb = 1024;
  if (bytes < bvMegabyte) {
    return l10n.fileSizeKb('${(bytes / kb).ceil()}');
  }
  final mb = (bytes / bvMegabyte).toStringAsFixed(1);
  return l10n.fileSizeMb(BvWesternDigitsFormatter.normalise(mb));
}

/// A file picked on the phone: none when the person cancels; [refused]
/// when it is a photo nobody could open (review 74 H1).
typedef PickedDocument = ({PhoneFile? file, bool refused});

/// Picks a PDF or photo on the phone (the Library, chat, W2-A); a photo
/// is made safe to leave the phone (cleanPhoto). A provider so tests can
/// stand in for the picker.
typedef PickDocument = Future<PickedDocument> Function({bool pdfOnly});

final pickDocumentProvider = Provider<PickDocument>(
  (ref) => ({bool pdfOnly = false}) async {
    const none = (file: null, refused: false);
    final f = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: pdfOnly
          ? const ['pdf']
          // No HEIC: its location can't be taken out on the phone (the
          // gallery pickers turn HEIC into JPEG).
          : const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
    );
    if (f == null || f.path == null) return none;
    final mime = mimeOfName(f.name);
    if (mime == null) return none;
    final clean = await cleanPhoto(f.path!, from: 'files');
    if (clean.result == PhotoCleaning.refused) {
      return (file: null, refused: true);
    }
    return (
      file: PhoneFile(
        local: clean.path,
        name: f.name,
        mime: mime,
        bytes: await File(clean.path).length(),
      ),
      refused: false,
    );
  },
);

/// A title from a file's name: no extension, `_` and `-` as spaces
/// ("C15B33V_site_report.pdf" → "C15B33V site report").
String titleFromFileName(String name) {
  final dot = name.lastIndexOf('.');
  final base = dot > 0 ? name.substring(0, dot) : name;
  return base
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// "today" or "9 Oct", with Western digits (LV1, LV2).
String libraryDay(
  AppLocalizations l10n,
  String locale,
  DateTime day,
  DateTime now,
) => DateUtils.isSameDay(day, now)
    ? l10n.daybookToday
    : BvWesternDigitsFormatter.normalise(
        DateFormat('d MMM', locale).format(day),
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
    personFirstName(l10n, f.uploadedByName),
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
