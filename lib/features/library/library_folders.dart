import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/people_library_specs.dart';
import '../../core/l10n/bidi.dart';
import '../../core/routing/app_routes.dart';
import '../../core/share.dart';
import '../../data/models/library_folder.dart';
import '../../data/models/space.dart';
import '../../data/repositories/library_repository.dart';
import '../../data/repositories/space_repository.dart';
import '../../data/repositories/work_repository.dart' show newUuid;
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_chip.dart';
import '../../shared/widgets/bv_dialog.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_popover_menu.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../../shared/widgets/bv_text_field.dart';
import '../entry/entry_state.dart';
import '../spaces/former_member.dart';
import '../spaces/space_errors.dart';

/// Review 113 (8, 9): the Library's folders (LB1 2730:40149) and Link
/// folder (LB2 2730:40228). Each folder is seen by only me, a person, a
/// Team or the whole Space: one single choice (rule 6) with the person or
/// the Team picked after it. A linked folder is a OneDrive, Google Drive
/// or Dropbox share link that opens in the browser; BuildVibes never signs
/// in to the service.

/// The service's name, as written.
String linkServiceName(AppLocalizations l10n, LinkService s) => switch (s) {
  LinkService.oneDrive => l10n.libraryServiceOneDrive,
  LinkService.googleDrive => l10n.libraryServiceGoogleDrive,
  LinkService.dropbox => l10n.libraryServiceDropbox,
};

IconData linkServiceIcon(LinkService? s) => switch (s) {
  LinkService.googleDrive => BvIcons.googleDrive,
  LinkService.dropbox => BvIcons.dropbox,
  _ => BvIcons.cloud,
};

/// "Whole Space", "Team · Gulf MEP", "Omar Haddad" or "Only me".
String folderShareLine(AppLocalizations l10n, LibraryFolder f) =>
    switch (f.share) {
      FolderShare.space => l10n.libraryShareSpace,
      FolderShare.team => l10n.libraryShareTeamLine(
        inOwnDirection(f.shareTeamName ?? ''),
      ),
      FolderShare.person => personName(l10n, f.sharePersonName),
      FolderShare.onlyMe => l10n.libraryShareOnlyMe,
    };

IconData folderShareIcon(FolderShare s) => switch (s) {
  FolderShare.space || FolderShare.team => BvIcons.team,
  FolderShare.person => BvIcons.person,
  FolderShare.onlyMe => BvIcons.lock,
};

/// The folder's line: "OneDrive link · Whole Space" for a linked folder.
String folderLine(AppLocalizations l10n, LibraryFolder f) => [
  if (f.isLink && f.service != null)
    l10n.libraryLinkLine(linkServiceName(l10n, f.service!)),
  folderShareLine(l10n, f),
].join(' · ');

/// LB1: a folder row: its tile, the name over who sees it (a small icon
/// first), the chevron.
class LibraryFolderRow extends StatelessWidget {
  const LibraryFolderRow({
    super.key,
    required this.folder,
    required this.onTap,
    this.onHold,
  });

  final LibraryFolder folder;
  final VoidCallback onTap;
  final VoidCallback? onHold;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final quiet = type.metadata.copyWith(color: BvColors.textSecondary);
    return InkWell(
      key: Key('folder-${folder.id}'),
      onTap: onTap,
      onLongPress: onHold,
      splashFactory: NoSplash.splashFactory,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: BvSpace.gutter,
        ),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: BvColors.borderDefault,
                width: BvStroke.thin,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              vertical: BvFolderSpec.rowPaddingVertical,
            ),
            child: Row(
              spacing: BvFolderSpec.rowGap,
              children: [
                ExcludeSemantics(
                  child: Container(
                    width: BvFolderSpec.tile,
                    height: BvFolderSpec.tile,
                    decoration: const BoxDecoration(
                      color: BvColors.surfaceSubtle,
                      borderRadius: BvFolderSpec.tileRadius,
                    ),
                    child: Icon(
                      folder.isLink
                          ? linkServiceIcon(folder.service)
                          : BvIcons.folder,
                      size: BvFolderSpec.tileIcon,
                      color: folder.isLink
                          ? BvFolderSpec.linkInk
                          : BvColors.iconPrimary,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: BvSpace.s2,
                    children: [
                      Text(
                        inOwnDirection(folder.name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: type.labelMd.copyWith(
                          color: BvColors.textPrimary,
                        ),
                      ),
                      Row(
                        spacing: BvFolderSpec.lineGap,
                        children: [
                          Icon(
                            folder.isLink
                                ? BvIcons.link
                                : folderShareIcon(folder.share),
                            size: BvFolderSpec.lineIcon,
                            color: BvColors.iconSecondary,
                          ),
                          Flexible(
                            child: Text(
                              folderLine(l10n, folder),
                              key: Key('folder-line-${folder.id}'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: quiet,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(
                  BvIcons.caretForward,
                  size: BvSize.iconMd,
                  color: BvColors.iconSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A tap on a folder: a linked folder opens in the browser; a folder of
/// files opens its own list ([AppRoutes.libraryFolder]), which can hand a
/// file post back up ([onAsk]).
Future<T?> openLibraryFolder<T>(
  BuildContext context,
  WidgetRef ref, {
  required String spaceId,
  required LibraryFolder folder,
}) async {
  final url = folder.url;
  if (url != null) {
    // Z10: checked again here: only a link that still passes opens.
    if (linkServiceOf(url) == null) {
      showSpaceMessage(context, AppLocalizations.of(context).libraryLinkWrong);
      return null;
    }
    final uri = Uri.tryParse(url);
    final opened = uri != null && await ref.read(openLinkProvider)(uri);
    if (!opened && context.mounted) {
      showSpaceMessage(
        context,
        AppLocalizations.of(context).libraryLinkOpenFailed,
      );
    }
    return null;
  }
  return context.push<T>(AppRoutes.libraryFolder(spaceId, folder.id));
}

/// Edit or delete, for its creator or the Space admin (the server decides
/// again). True when it changed.
Future<bool> folderMenu(
  BuildContext context,
  WidgetRef ref, {
  required SpaceDetail space,
  required LibraryFolder folder,
}) async {
  if (!folder.mine && !space.iAmAdmin) return false;
  final l10n = AppLocalizations.of(context);
  final picked = await showBvScreenMenu<bool>(
    context,
    key: const Key('folder-menu'),
    items: [
      BvMenuItem(
        key: const Key('folder-edit'),
        value: true,
        label: l10n.libraryEditFolder,
        icon: BvIcons.edit,
      ),
      BvMenuItem(
        key: const Key('folder-delete'),
        value: false,
        label: l10n.libraryDeleteFolder,
        icon: BvIcons.delete,
        destructive: true,
      ),
    ],
  );
  if (picked == null || !context.mounted) return false;
  if (picked) {
    return await showFolderSheet(context, ref, space: space, editing: folder);
  }
  final sure = await showBvDialog(
    context: context,
    title: l10n.libraryDeleteFolderAsk,
    body: folder.isLink ? l10n.libraryDeleteFolderBody : '',
    cancelLabel: l10n.commonCancel,
    confirmLabel: l10n.libraryDeleteFolder,
    destructive: true,
  );
  if (!sure || !context.mounted) return false;
  try {
    await ref.read(libraryRepositoryProvider).deleteFolder(folder.id);
  } on SpaceException catch (e) {
    if (!context.mounted) return false;
    if ((e.message ?? '').contains('empty it first')) {
      showSpaceMessage(context, l10n.libraryFolderNotEmpty);
    } else {
      showSpaceError(context, e);
    }
    return false;
  }
  ref.invalidate(libraryFoldersProvider(space.id));
  return true;
}

/// A person of [spaceId] other than me, for a folder (or, review 115, a
/// file at the Library's top level) only they and I see. Null when closed.
Future<({String id, String name})?> pickFolderPerson(
  BuildContext context,
  WidgetRef ref,
  String spaceId,
) async {
  final l10n = AppLocalizations.of(context);
  final me = ref.read(authUserIdProvider).value;
  final people = await ref.read(spacePeopleProvider(spaceId).future);
  if (!context.mounted) return null;
  final picked = await showBvSheet<SpaceMember>(
    context: context,
    title: l10n.libraryChoosePerson,
    builder: (sheet) => Column(
      key: const Key('folder-person-picker'),
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final m in people.members)
          if (m.person.id != me)
            BvListRow(
              key: Key('folder-person-${m.person.id}'),
              title: inOwnDirection(m.person.fullName),
              trailing: const BvRowTrailing.none(),
              onTap: () => Navigator.of(sheet).pop(m),
            ),
      ],
    ),
  );
  return picked == null
      ? null
      : (id: picked.person.id, name: picked.person.fullName);
}

/// A Team of [spaceId], for a folder (or a top-level file) its members
/// see. Null when closed.
Future<({String id, String name})?> pickFolderTeam(
  BuildContext context,
  WidgetRef ref,
  String spaceId,
) async {
  final l10n = AppLocalizations.of(context);
  final people = await ref.read(spacePeopleProvider(spaceId).future);
  if (!context.mounted) return null;
  final picked = await showBvSheet<SpaceTeam>(
    context: context,
    title: l10n.libraryChooseTeam,
    builder: (sheet) => Column(
      key: const Key('folder-team-picker'),
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final t in people.teams)
          BvListRow(
            key: Key('folder-team-${t.id}'),
            title: inOwnDirection(t.name),
            leading: const BvRowIcon(BvIcons.team, ink: true),
            trailing: const BvRowTrailing.none(),
            onTap: () => Navigator.of(sheet).pop(t),
          ),
      ],
    ),
  );
  return picked == null ? null : (id: picked.id, name: picked.name);
}

/// LB1's New folder, LB2's Link folder ([link]), or a folder's Edit
/// ([editing]). True when it was saved.
Future<bool> showFolderSheet(
  BuildContext context,
  WidgetRef ref, {
  required SpaceDetail space,
  bool link = false,
  LibraryFolder? editing,
}) async {
  final l10n = AppLocalizations.of(context);
  final saved = await showBvSheet<bool>(
    context: context,
    title: editing != null
        ? l10n.libraryEditFolder
        : link
        ? l10n.libraryLinkFolder
        : l10n.libraryNewFolder,
    builder: (_) => FolderSheet(
      space: space,
      link: editing == null ? link : editing.isLink,
      editing: editing,
    ),
  );
  return saved ?? false;
}

/// The sheet's body (LB2): the link (a linked folder, new only) and the
/// service found, the name, who sees it, the warning, and the button.
class FolderSheet extends ConsumerStatefulWidget {
  const FolderSheet({
    super.key,
    required this.space,
    required this.link,
    this.editing,
  });

  final SpaceDetail space;
  final bool link;
  final LibraryFolder? editing;

  @override
  ConsumerState<FolderSheet> createState() => _FolderSheetState();
}

class _FolderSheetState extends ConsumerState<FolderSheet> {
  late final _url = TextEditingController();
  late final _name = TextEditingController(text: widget.editing?.name);
  late var _share = widget.editing?.share ?? FolderShare.space;
  late ({String id, String name})? _person = switch (widget.editing) {
    final f? when f.sharePersonId != null => (
      id: f.sharePersonId!,
      name: f.sharePersonName ?? '',
    ),
    _ => null,
  };
  late ({String id, String name})? _team = switch (widget.editing) {
    final f? when f.shareTeamId != null => (
      id: f.shareTeamId!,
      name: f.shareTeamName ?? '',
    ),
    _ => null,
  };
  var _saving = false;

  /// The id the new folder gets, chosen once: Add again is the same one.
  final _id = newUuid();

  @override
  void dispose() {
    _url.dispose();
    _name.dispose();
    super.dispose();
  }

  bool get _newLink => widget.link && widget.editing == null;

  FolderChange get _change => FolderChange(
    id: widget.editing?.id ?? _id,
    spaceId: widget.space.id,
    name: _name.text,
    share: _share,
    personId: _person?.id,
    teamId: _team?.id,
    url: _newLink ? _url.text.trim() : null,
  );

  Future<void> _pickPerson() async {
    final picked = await pickFolderPerson(context, ref, widget.space.id);
    if (picked == null || !mounted) return;
    setState(() => _person = picked);
  }

  Future<void> _pickTeam() async {
    final picked = await pickFolderTeam(context, ref, widget.space.id);
    if (picked == null || !mounted) return;
    setState(() => _team = picked);
  }

  Future<void> _choose(FolderShare share) async {
    setState(() => _share = share);
    if (share == FolderShare.person && _person == null) await _pickPerson();
    if (share == FolderShare.team && _team == null) await _pickTeam();
  }

  Future<void> _save() async {
    final change = _change;
    if (!change.complete || _saving) return;
    setState(() => _saving = true);
    final repo = ref.read(libraryRepositoryProvider);
    try {
      if (widget.editing == null) {
        await repo.createFolder(change);
      } else {
        await repo.updateFolder(change);
      }
    } on SpaceException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      final l10n = AppLocalizations.of(context);
      if ((e.message ?? '').contains('OneDrive, Google Drive or Dropbox')) {
        showSpaceMessage(context, l10n.libraryLinkWrong);
      } else {
        showSpaceError(context, e);
      }
      return;
    }
    if (!mounted) return;
    ref.invalidate(libraryFoldersProvider(widget.space.id));
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final quiet = type.metadata.copyWith(color: BvColors.textSecondary);
    final url = _url.text.trim();
    final service = url.isEmpty ? null : linkServiceOf(url);
    final change = _change;
    final picked = switch (_share) {
      FolderShare.person => (
        label: _person == null
            ? l10n.libraryChoosePerson
            : inOwnDirection(_person!.name),
        icon: BvIcons.person,
        onTap: _pickPerson,
        key: 'folder-pick-person',
      ),
      FolderShare.team => (
        label: _team == null
            ? l10n.libraryChooseTeam
            : inOwnDirection(_team!.name),
        icon: BvIcons.team,
        onTap: _pickTeam,
        key: 'folder-pick-team',
      ),
      _ => null,
    };
    return Column(
      key: const Key('folder-sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BvFolderSpec.sheetGap,
      children: [
        if (_newLink) ...[
          BvTextField(
            key: const Key('folder-url'),
            controller: _url,
            placeholder: l10n.libraryLinkPasteHint,
            keyboardType: TextInputType.url,
            textDirection: TextDirection.ltr,
            suggestions: false,
            suffixIcon: BvIcons.link,
            autofocus: true,
            error: url.isNotEmpty && service == null
                ? l10n.libraryLinkWrong
                : null,
            onChanged: (_) => setState(() {}),
          ),
          if (service != null)
            Row(
              key: const Key('folder-service'),
              spacing: BvFolderSpec.lineGap,
              children: [
                Icon(
                  linkServiceIcon(service),
                  size: BvChipSpec.iconSize,
                  color: BvFolderSpec.linkInk,
                ),
                Flexible(
                  child: Text(
                    l10n.libraryLinkFound(linkServiceName(l10n, service)),
                    style: quiet,
                  ),
                ),
              ],
            ),
        ],
        BvTextField(
          key: const Key('folder-name'),
          controller: _name,
          placeholder: l10n.libraryFolderNameHint,
          maxLength: LibraryFolderRules.nameMax,
          autofocus: !_newLink && widget.editing == null,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
        ),
        Text(l10n.libraryWhoSees, style: quiet),
        Wrap(
          key: const Key('folder-share'),
          spacing: BvChipSpec.rowGapTight,
          runSpacing: BvSpace.s8,
          children: [
            for (final s in const [
              FolderShare.onlyMe,
              FolderShare.person,
              FolderShare.team,
              FolderShare.space,
            ])
              BvChip(
                key: Key('folder-share-${s.json}'),
                label: switch (s) {
                  FolderShare.onlyMe => l10n.libraryShareOnlyMe,
                  FolderShare.person => l10n.librarySharePerson,
                  FolderShare.team => l10n.libraryShareTeam,
                  FolderShare.space => l10n.libraryShareSpace,
                },
                tight: true,
                selected: _share == s,
                onTap: () => unawaited(_choose(s)),
              ),
          ],
        ),
        if (picked != null)
          BvListRow(
            key: Key(picked.key),
            title: picked.label,
            leading: BvRowIcon(picked.icon, ink: true),
            onTap: () => unawaited(picked.onTap()),
          ),
        if (_newLink || (widget.editing?.isLink ?? false))
          Container(
            key: const Key('folder-warning'),
            padding: BvFolderSpec.warningPadding,
            decoration: const BoxDecoration(
              color: BvColors.surfaceWarningSoft,
              borderRadius: BvFolderSpec.warningRadius,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: BvSpace.s8,
              children: [
                const Icon(
                  BvIcons.lock,
                  size: BvChipSpec.iconSize,
                  color: BvColors.textWarning,
                ),
                Expanded(
                  child: Text(
                    l10n.libraryLinkWarning,
                    style: type.bodySm.copyWith(color: BvColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        BvButton(
          key: const Key('folder-save'),
          label: widget.editing != null
              ? l10n.librarySaveFolder
              : l10n.libraryAddFolder,
          expand: true,
          onPressed: change.complete && !_saving
              ? () => unawaited(_save())
              : null,
        ),
      ],
    );
  }
}
