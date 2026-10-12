import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/library.dart';
import '../../data/repositories/library_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../entry/entry_state.dart';
import '../library/library_parts.dart';
import '../library/library_tab.dart' show currentFiles;
import '../profile/widgets/profile_parts.dart';

/// W2-A · Attach to KCT-022: from the Space Library, from the phone (it
/// goes to the Library too), or another photo for the tag ([onTakePhoto],
/// W2 only). Returns the Library file's id, or null.
///
/// A Team file only goes on that Team's items, so the choices are limited
/// to Everyone files and the item's Team ([teamId]).
Future<String?> chooseFileToAttach(
  BuildContext context, {
  required String spaceId,
  required String itemRef,
  String? teamId,
  String? teamName,
  Set<String> exclude = const {},
  VoidCallback? onTakePhoto,
}) async {
  final l10n = AppLocalizations.of(context);
  FocusManager.instance.primaryFocus?.unfocus();
  final choice = await showBvSheet<_From>(
    context: context,
    title: l10n.workAttachTitle(itemRef),
    builder: (sheetContext) => ProfileCard(
      padding: false,
      child: DividedColumn(
        children: [
          BvListRow(
            key: const Key('attach-from-library'),
            title: l10n.workAttachLibrary,
            subtitle: l10n.workAttachLibraryHelp,
            leading: const BvRowIcon(BvIcons.library),
            trailing: const BvRowTrailing.none(),
            onTap: () => Navigator.of(sheetContext).pop(_From.library),
          ),
          BvListRow(
            key: const Key('attach-from-phone'),
            title: l10n.workAttachPhone,
            subtitle: l10n.workAttachPhoneHelp,
            leading: const BvRowIcon(BvIcons.document),
            trailing: const BvRowTrailing.none(),
            onTap: () => Navigator.of(sheetContext).pop(_From.phone),
          ),
          if (onTakePhoto != null)
            BvListRow(
              key: const Key('attach-take-photo'),
              title: l10n.workAttachPhoto,
              subtitle: l10n.workAttachPhotoHelp,
              leading: const BvRowIcon(BvIcons.camera),
              trailing: const BvRowTrailing.none(),
              onTap: () => Navigator.of(sheetContext).pop(_From.photo),
            ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return null;
  switch (choice) {
    case _From.photo:
      onTakePhoto?.call();
      return null;
    case _From.phone:
      return context.push<String>(
        AppRoutes.libraryAdd(spaceId, forTeam: teamId ?? AppRoutes.forEveryone),
      );
    case _From.library:
      return showLibraryPicker(
        context,
        spaceId: spaceId,
        teamId: teamId,
        teamName: teamName,
        exclude: exclude,
      );
  }
}

enum _From { library, phone, photo }

/// A sheet of the Space's current files that fit an item (Everyone files,
/// and [teamId]'s). Returns the chosen file's id.
Future<String?> showLibraryPicker(
  BuildContext context, {
  required String spaceId,
  String? teamId,
  String? teamName,
  Set<String> exclude = const {},
}) {
  final l10n = AppLocalizations.of(context);
  return showBvSheet<String>(
    context: context,
    title: l10n.libraryPickTitle,
    subtitle: teamName == null ? null : l10n.libraryPickTeamNote(teamName),
    builder: (sheetContext) => _LibraryPicker(
      spaceId: spaceId,
      teamId: teamId,
      exclude: exclude,
      onPick: (id) => Navigator.of(sheetContext).pop(id),
    ),
  );
}

class _LibraryPicker extends ConsumerWidget {
  const _LibraryPicker({
    required this.spaceId,
    required this.teamId,
    required this.exclude,
    required this.onPick,
  });

  final String spaceId;
  final String? teamId;
  final Set<String> exclude;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final me = ref.watch(authUserIdProvider).value;
    final all = ref.watch(libraryFilesProvider(spaceId)).value;
    if (all == null) {
      return const Padding(
        padding: EdgeInsetsDirectional.all(BvSpace.s24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final fits = <LibraryFile>[
      for (final f in currentFiles(all))
        if ((f.teamId == null || f.teamId == teamId) && !exclude.contains(f.id))
          f,
    ];
    if (fits.isEmpty) return EmptyNote(l10n.libraryEmpty);
    return ProfileCard(
      key: const Key('library-picker'),
      padding: false,
      child: DividedColumn(
        children: [
          for (final f in fits)
            FileRow(
              file: f,
              subtitle: fileMeta(l10n, f, me),
              trailing: const BvRowTrailing.none(),
              onTap: () => onPick(f.id),
            ),
        ],
      ),
    );
  }
}

/// W3 "Attached" and W2's picked files: name, then "From the Space Library
/// · 4.8 MB". Opens F1.
class AttachedFileRow extends StatelessWidget {
  const AttachedFileRow({
    super.key,
    required this.spaceId,
    required this.file,
    this.onRemove,
  });

  final String spaceId;
  final LibraryFile file;

  /// W2: take it off before the item is made.
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FileRow(
      key: Key('attached-${file.id}'),
      file: file,
      subtitle: joinMeta([
        l10n.workAttachedFromLibrary,
        fileSize(l10n, file.bytes),
      ]),
      trailing: onRemove == null
          ? const BvRowTrailing.chevron()
          : BvRowTrailing.badge(
              IconButton(
                key: Key('attached-remove-${file.id}'),
                tooltip: l10n.chatRemoveFile,
                icon: const Icon(
                  BvIcons.close,
                  size: BvSize.iconMd,
                  color: BvColors.iconSecondary,
                ),
                onPressed: onRemove,
              ),
            ),
      onTap: () => context.push(AppRoutes.libraryFile(spaceId, file.id)),
    );
  }
}
