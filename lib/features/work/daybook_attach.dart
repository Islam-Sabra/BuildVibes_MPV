import 'dart:async';

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
import '../../shared/widgets/bv_search_field.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../chat/chat_state.dart' show keepFileProvider;
import '../library/library_parts.dart';
import '../spaces/space_errors.dart';
import 'daybook_draft.dart';

/// What the attach sheet chose (K4 v13, F72).
enum DaybookAttach { camera, photos, files, library }

/// Where a post's file comes from (F72).
enum DaybookFileSource { phone, library }

/// 📎 in the writing toolbar (F21, K4 v13 2594:77576, F72): the one way to
/// add to a post: a photo from the camera or the gallery (up to
/// [photosLeft]), a file from the phone (a PDF or a photo, which also goes
/// to the Library), or one already in the Library. Proof photos for Sign as
/// done stay camera only: this is for the post itself.
Future<DaybookAttach?> showDaybookAttach(
  BuildContext context, {
  required int photosLeft,
  bool photos = true,
}) {
  final l10n = AppLocalizations.of(context);
  return showBvSheet<DaybookAttach>(
    context: context,
    title: l10n.daybookAttachTitle,
    builder: (sheet) => Column(
      key: const Key('attach-sheet'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (photos) ...[
          BvAttachRow(
            key: const Key('attach-camera'),
            icon: BvIcons.camera,
            title: l10n.daybookCamera,
            subtitle: l10n.daybookAttachCameraNote,
            onTap: () => Navigator.of(sheet).pop(DaybookAttach.camera),
          ),
          BvAttachRow(
            key: const Key('attach-photos'),
            icon: BvIcons.image,
            title: l10n.daybookAttachPhotos,
            subtitle: l10n.daybookAttachPhotosNote(photosLeft),
            onTap: () => Navigator.of(sheet).pop(DaybookAttach.photos),
          ),
        ],
        BvAttachRow(
          key: const Key('attach-file'),
          icon: BvIcons.upload,
          title: l10n.daybookAttachFiles,
          subtitle: libraryDocumentLine(),
          onTap: () => Navigator.of(sheet).pop(DaybookAttach.files),
        ),
        BvAttachRow(
          key: const Key('attach-library'),
          icon: BvIcons.library,
          title: l10n.daybookAttachLibrary,
          subtitle: l10n.daybookAttachLibraryNote,
          onTap: () => Navigator.of(sheet).pop(DaybookAttach.library),
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
///
/// [replaces] (LV2 "Add a new version"): straight to the phone's files,
/// and the new one replaces it, with no question.
Future<DraftFile?> chooseDaybookFile(
  BuildContext context,
  WidgetRef ref, {
  required String spaceId,
  LibraryFile? replaces,
  DaybookFileSource? source,
}) async {
  final l10n = AppLocalizations.of(context);
  final all = replaces != null
      ? const <LibraryFile>[]
      : await _libraryFiles(context, ref, spaceId);
  if (all == null || !context.mounted) return null;
  final current = _current(all);
  // F72: the paper clip already said where from.
  final picked = replaces != null || source == DaybookFileSource.phone
      ? _fromPhone
      : await showBvSheet<Object>(
          context: context,
          title: l10n.daybookFileChooseTitle,
          builder: (sheet) => Column(
            key: const Key('file-chooser'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (source != DaybookFileSource.library)
                BvAttachRow(
                  key: const Key('file-from-phone'),
                  icon: BvIcons.upload,
                  title: l10n.daybookFileFromPhone,
                  subtitle: l10n.daybookFileFromPhoneNote,
                  onTap: () => Navigator.of(sheet).pop(_fromPhone),
                ),
              if (current.isNotEmpty && source != DaybookFileSource.library)
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
  final (file: phone, :refused) = await ref.read(pickDocumentProvider)();
  if (!context.mounted) return null;
  // Review 74 H1: a photo nobody could open doesn't go.
  if (refused) showSpaceMessage(context, l10n.photoCannotOpen);
  if (phone == null) return null;
  if ((phone.bytes ?? 0) > maxFileBytes) {
    showSpaceMessage(context, l10n.chatFileTooBig);
    return null;
  }
  // Kept in the app's folder until it is in the Library.
  final kept = await ref.read(keepFileProvider)(phone.local, phone.extension);
  if (!context.mounted) return null;
  final older = replaces != null
      ? (file: replaces)
      : current.isEmpty
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
    // "Replaces A-501 · V2" (F71, F75).
    supersedesRev: replaced == null
        ? null
        : [
            replaced.name,
            versionLabel(l10n, replaced),
          ].where((t) => t.isNotEmpty).join(' · '),
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

/// A version's label (F75): "V2", else its revision.
String versionLabel(AppLocalizations l10n, LibraryFile f) => f.versionNo == null
    ? (f.revLabel ?? '')
    : l10n.libraryVersionNo(f.versionNo!);

/// F71 (rule 6): one single choice, "New file" (chosen first) or "New
/// version of a file", which opens the Library's files in use, newest
/// first, with Search files on top; the choice then reads "Replaces A-501 ·
/// V2" with ✕ to undo.
class _ReplacesChoice extends StatefulWidget {
  const _ReplacesChoice({required this.files});

  final List<LibraryFile> files;

  @override
  State<_ReplacesChoice> createState() => _ReplacesChoiceState();
}

class _ReplacesChoiceState extends State<_ReplacesChoice> {
  static const _newFile = '';
  static const _newVersion = 'version';
  LibraryFile? _picked;

  Future<void> _pick() async {
    final f = await showBvSheet<LibraryFile>(
      context: context,
      title: AppLocalizations.of(context).daybookPickVersionTitle,
      builder: (_) => _VersionPicker(files: widget.files),
    );
    if (mounted && f != null) setState(() => _picked = f);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final picked = _picked;
    return Column(
      key: const Key('replaces-choice'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BvSpace.s16,
      children: [
        BvChoiceList<String>(
          value: picked == null ? _newFile : _newVersion,
          options: [
            BvChoiceOption(
              key: const Key('replaces-none'),
              value: _newFile,
              title: l10n.daybookNewFile,
            ),
            BvChoiceOption(
              key: const Key('replaces-version'),
              value: _newVersion,
              title: l10n.daybookNewVersion,
            ),
          ],
          onChanged: (v) {
            if (v == _newFile) {
              setState(() => _picked = null);
            } else {
              unawaited(_pick());
            }
          },
        ),
        if (picked != null)
          Row(
            key: const Key('replaces-picked'),
            children: [
              const Icon(
                BvIcons.document,
                size: BvSize.iconMd,
                color: BvColors.iconSecondary,
              ),
              const SizedBox(width: BvSpace.s8),
              Expanded(
                child: Text(
                  l10n.daybookReplacesOption(
                    joinMeta([
                      inOwnDirection(picked.name),
                      versionLabel(l10n, picked),
                    ]),
                  ),
                  style: BvType.of(context).bodyMd,
                ),
              ),
              IconButton(
                key: const Key('replaces-clear'),
                tooltip: l10n.daybookNotNewVersion,
                icon: const Icon(BvIcons.close, size: BvSize.iconMd),
                onPressed: () => setState(() => _picked = null),
              ),
            ],
          ),
        BvButton(
          key: const Key('replaces-done'),
          label: l10n.daybookReplacesDone,
          expand: true,
          onPressed: () => Navigator.of(context).pop<_Replaces>((file: picked)),
        ),
      ],
    );
  }
}

/// F71: the Library's files in use, newest first, found by a few letters.
class _VersionPicker extends StatefulWidget {
  const _VersionPicker({required this.files});

  final List<LibraryFile> files;

  @override
  State<_VersionPicker> createState() => _VersionPickerState();
}

class _VersionPickerState extends State<_VersionPicker> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final q = _query.trim().toLowerCase();
    final files = [
      for (final f in [
        ...widget.files,
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
        if (q.isEmpty ||
            f.name.toLowerCase().contains(q) ||
            (f.revLabel ?? '').toLowerCase().contains(q))
          f,
    ];
    return Column(
      key: const Key('version-picker'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BvSpace.s8,
      children: [
        BvSearchField(
          key: const Key('version-search'),
          placeholder: l10n.librarySearch,
          onChanged: (v) => setState(() => _query = v),
        ),
        for (final f in files)
          FileRow(
            key: Key('version-${f.id}'),
            file: f,
            subtitle: joinMeta([
              versionLabel(l10n, f),
              ?f.revLabel,
              fileSize(l10n, f.bytes),
            ]),
            onTap: () => Navigator.of(context).pop(f),
          ),
      ],
    );
  }
}
