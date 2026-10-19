import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart';
import '../../data/models/library.dart';
import '../../data/models/space.dart';
import '../../data/repositories/library_repository.dart';
import '../../data/repositories/work_repository.dart' show newUuid;
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_attach_row.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_choice_card.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../chat/chat_state.dart' show keepFileProvider;
import '../library/library_parts.dart';
import '../spaces/space_errors.dart';
import 'daybook_draft.dart';

/// What the attach sheet chose (K4 v13).
enum DaybookAttach { photos, file }

/// 📎 in the writing toolbar (F21, K4 v13 2594:77576): "Add to this post",
/// a photo from the gallery (up to [photosLeft]) or a file (a PDF or a
/// photo, which also goes to the Library). Proof photos for Sign as done
/// stay camera only: this is for the post itself.
Future<DaybookAttach?> showDaybookAttach(
  BuildContext context, {
  required int photosLeft,
}) {
  final l10n = AppLocalizations.of(context);
  return showBvSheet<DaybookAttach>(
    context: context,
    title: l10n.daybookAttachTitle,
    builder: (sheet) => Column(
      key: const Key('attach-sheet'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BvAttachRow(
          key: const Key('attach-photos'),
          icon: BvIcons.image,
          title: l10n.daybookAttachPhotos,
          subtitle: l10n.daybookAttachPhotosNote(photosLeft),
          onTap: () => Navigator.of(sheet).pop(DaybookAttach.photos),
        ),
        BvAttachRow(
          key: const Key('attach-file'),
          icon: BvIcons.document,
          title: l10n.daybookKindFile,
          subtitle: libraryDocumentLine(),
          onTap: () => Navigator.of(sheet).pop(DaybookAttach.file),
        ),
      ],
    ),
  );
}

/// Choose a file for a post: one in the Space's Library, or one from the
/// phone, which goes to the Library under an id chosen here when the post
/// is sent; for a file from the phone, whether it is a new version of a
/// file already there (NEW VERSION). Null when cancelled.
///
/// Files go to the whole Space's Library (posts are for Everyone in this
/// slice), so only the Library's Everyone files are offered.
Future<DraftFile?> chooseDaybookFile(
  BuildContext context,
  WidgetRef ref, {
  required String spaceId,
}) async {
  final l10n = AppLocalizations.of(context);
  final all = await _libraryFiles(context, ref, spaceId);
  if (all == null || !context.mounted) return null;
  final current = _current(all);
  final picked = await showBvSheet<Object>(
    context: context,
    title: l10n.daybookFileChooseTitle,
    builder: (sheet) => Column(
      key: const Key('file-chooser'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BvAttachRow(
          key: const Key('file-from-phone'),
          icon: BvIcons.upload,
          title: l10n.daybookFileFromPhone,
          subtitle: l10n.daybookFileFromPhoneNote,
          onTap: () => Navigator.of(sheet).pop(_fromPhone),
        ),
        if (current.isNotEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: BvSpace.s12),
            child: Text(
              l10n.daybookFileInLibrary,
              style: BvType.of(
                sheet,
              ).overline.copyWith(color: BvColors.textSecondary),
            ),
          ),
        for (final f in current)
          FileRow(
            file: f,
            subtitle: [
              ?f.revLabel,
              fileSize(l10n, f.bytes),
            ].where((s) => s.isNotEmpty).join(' · '),
            onTap: () => Navigator.of(sheet).pop(f),
          ),
      ],
    ),
  );
  if (picked is LibraryFile) {
    return DraftFile(
      libraryId: picked.id,
      name: picked.name,
      mime: picked.mime,
      bytes: picked.bytes,
      revLabel: picked.revLabel,
    );
  }
  if (picked != _fromPhone || !context.mounted) return null;
  final phone = await ref.read(pickDocumentProvider)();
  if (phone == null || !context.mounted) return null;
  if ((phone.bytes ?? 0) > maxFileBytes) {
    showSpaceMessage(context, l10n.chatFileTooBig);
    return null;
  }
  // Kept in the app's folder until it is in the Library.
  final kept = await ref.read(keepFileProvider)(phone.local, phone.extension);
  if (!context.mounted) return null;
  final older = current.isEmpty
      ? null
      : await showBvSheet<_Replaces>(
          context: context,
          title: l10n.daybookReplacesTitle,
          builder: (_) => _ReplacesChoice(files: current),
        );
  if (!context.mounted) return null;
  // Closing the question keeps the file as a new one.
  final replaced = older?.file;
  return DraftFile(
    libraryId: newUuid(),
    name: phone.name,
    mime: phone.mime,
    bytes: phone.bytes,
    local: kept,
    supersedesId: replaced?.id,
    supersedesRev: replaced?.revLabel ?? replaced?.name,
  );
}

const _fromPhone = 'phone';

Future<List<LibraryFile>?> _libraryFiles(
  BuildContext context,
  WidgetRef ref,
  String spaceId,
) async {
  try {
    return await ref.read(libraryFilesProvider(spaceId).future);
  } on SpaceException catch (e) {
    if (context.mounted) showSpaceError(context, e);
    return null;
  }
}

/// The Library's current Everyone files: none that a newer one replaced.
List<LibraryFile> _current(List<LibraryFile> all) {
  final replaced = {for (final f in all) ?f.supersedesId};
  return [
    for (final f in all)
      if (f.teamId == null && !replaced.contains(f.id)) f,
  ];
}

/// The answer to "Is it a new version of a file?": [file] null is a new
/// file.
typedef _Replaces = ({LibraryFile? file});

/// One single choice (rule 6): a new file, or a new version of one of the
/// Library's files.
class _ReplacesChoice extends StatefulWidget {
  const _ReplacesChoice({required this.files});

  final List<LibraryFile> files;

  @override
  State<_ReplacesChoice> createState() => _ReplacesChoiceState();
}

class _ReplacesChoiceState extends State<_ReplacesChoice> {
  var _chosen = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String name(LibraryFile f) => inOwnDirection(
      f.revLabel == null ? f.name : l10n.daybookFileChip(f.name, f.revLabel!),
    );
    return Column(
      key: const Key('replaces-choice'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BvSpace.s16,
      children: [
        BvChoiceList<String>(
          value: _chosen,
          options: [
            BvChoiceOption(
              key: const Key('replaces-none'),
              value: '',
              title: l10n.daybookReplacesNone,
            ),
            for (final f in widget.files)
              BvChoiceOption(
                key: Key('replaces-${f.id}'),
                value: f.id,
                title: l10n.daybookReplacesOption(name(f)),
              ),
          ],
          onChanged: (v) => setState(() => _chosen = v),
        ),
        BvButton(
          key: const Key('replaces-done'),
          label: l10n.daybookReplacesDone,
          expand: true,
          onPressed: () => Navigator.of(context).pop<_Replaces>((
            file: widget.files.where((f) => f.id == _chosen).firstOrNull,
          )),
        ),
      ],
    );
  }
}
