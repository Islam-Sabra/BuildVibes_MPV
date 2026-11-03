import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart';
import '../../data/models/library_folder.dart';
import '../../data/models/library.dart';
import '../../data/models/space.dart' show SpaceException;
import '../../data/models/upload_rules.dart';
import '../../data/repositories/library_repository.dart';
import '../../data/repositories/work_repository.dart' show newUuid;
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_chip.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../work/could_not_send.dart';
import '../work/daybook_attach.dart';
import '../work/daybook_draft.dart';
import '../work/work_outbox.dart';
import 'library_folders.dart';

/// libfix (Z14, privacy): who hears that a file has a new version: its
/// folder's own audience (the whole Space at the Library's top level).
/// Null, nobody, for an only-me or a person's folder.
({String? teamId})? newVersionAudience(LibraryFolder? folder) =>
    switch (folder?.share) {
      null || FolderShare.space => (teamId: null),
      FolderShare.team when folder!.shareTeamId != null => (
        teamId: folder.shareTeamId,
      ),
      _ => null,
    };

/// Review 115 (2): who a file at the Library's top level is for: the
/// whole Space, a Team or a person (by [id] and [name]), or only me.
typedef WhoSees = ({FolderShare share, String? id, String? name});

/// libfix (Z14, privacy): + Add a file and Add a new version in the
/// Library. The file from the phone goes into [folder] (or [replaces]'s),
/// with the folder's sharing, and no post: a post would open it for
/// everyone who sees the post. Only a new version in a whole-Space or Team
/// folder tells that same audience, with a small file post.
///
/// Review 115: (1) it goes through the outbox, as posts do: it shows in
/// its list at once, uploads with its percent, waits for signal, and a
/// refusal is Tap to fix ([LibraryPendingRow]). (2) A new file at the top
/// level asks who sees it first; anything but the whole Space puts it in a
/// matching folder, made only when there is none.
Future<void> addLibraryFileHere(
  BuildContext context,
  WidgetRef ref, {
  required String spaceId,
  LibraryFolder? folder,
  LibraryFile? replaces,
}) async {
  final l10n = AppLocalizations.of(context);
  final folderId = folder?.id ?? replaces?.folderId;
  final folders = await _folders(ref, spaceId);
  if (!context.mounted) return;
  final into = folder ?? folders.where((f) => f.id == folderId).firstOrNull;
  final file = await chooseDaybookFile(
    context,
    ref,
    spaceId: spaceId,
    replaces: replaces,
    source: DaybookFileSource.phone,
    folderId: folderId,
    sameFolder: true,
  );
  final local = file?.local;
  if (file == null || local == null || !context.mounted) return;

  var target = folderId;
  FolderChange? make;
  if (folderId == null && file.supersedesId == null) {
    final who = await showWhoSeesSheet(context, ref, spaceId: spaceId);
    if (who == null || !context.mounted) {
      unawaited(_deleteKept(local));
      return;
    }
    (target, make) = _folderFor(ref, l10n, spaceId, folders, who);
  }

  final older =
      replaces ??
      (ref.read(libraryFilesProvider(spaceId)).value ?? const [])
          .where((f) => f.id == file.supersedesId)
          .firstOrNull;
  final to = file.supersedesId == null ? null : newVersionAudience(into);
  final item = PendingItem(
    id: file.libraryId,
    spaceId: spaceId,
    kind: PendingKind.libraryFile,
    title: to == null
        ? ''
        : l10n.libraryNewVersionPost(
            file.name,
            file.revLabel ?? l10n.libraryVersionNo((older?.versionNo ?? 1) + 1),
          ),
    ownerId: '',
    ownerName: '',
    madeAt: ref.read(clockProvider)(),
    files: [
      DraftFile(
        libraryId: file.libraryId,
        name: file.name,
        mime: file.mime,
        bytes: file.bytes,
        local: local,
        revLabel: file.revLabel,
        supersedesId: file.supersedesId,
        folderId: target,
      ),
    ],
    postId: to == null ? null : newUuid(),
    teamId: to?.teamId,
    newFolder: make,
  );
  unawaited(ref.read(workOutboxProvider.notifier).send(item));
}

Future<List<LibraryFolder>> _folders(WidgetRef ref, String spaceId) async {
  try {
    return await ref.read(libraryFoldersProvider(spaceId).future);
  } on SpaceException {
    return const [];
  }
}

/// The folder [who] puts a file in: none for the whole Space; else one I
/// can add to with that sharing (an only-me or a person's folder of mine, a
/// Team's), or one still waiting to be made on this phone, or a new one,
/// named "My files", the Team's or the person's name.
(String?, FolderChange?) _folderFor(
  WidgetRef ref,
  AppLocalizations l10n,
  String spaceId,
  List<LibraryFolder> folders,
  WhoSees who,
) {
  if (who.share == FolderShare.space) return (null, null);
  bool fits(FolderShare share, String? person, String? team, {bool? mine}) =>
      share == who.share &&
      switch (share) {
        FolderShare.onlyMe => mine ?? true,
        FolderShare.person => (mine ?? true) && person == who.id,
        FolderShare.team => team == who.id,
        FolderShare.space => false,
      };
  final there = folders
      .where(
        (f) =>
            !f.isLink &&
            fits(f.share, f.sharePersonId, f.shareTeamId, mine: f.mine),
      )
      .firstOrNull;
  if (there != null) return (there.id, null);
  final waiting = [
    for (final i in ref.read(workOutboxProvider))
      if (i.spaceId == spaceId) ?i.newFolder,
  ].where((f) => fits(f.share, f.personId, f.teamId)).firstOrNull;
  if (waiting != null) return (waiting.id, waiting);
  final made = FolderChange(
    id: newUuid(),
    spaceId: spaceId,
    name: who.share == FolderShare.onlyMe ? l10n.libraryMyFiles : who.name!,
    share: who.share,
    personId: who.share == FolderShare.person ? who.id : null,
    teamId: who.share == FolderShare.team ? who.id : null,
  );
  return (made.id, made);
}

Future<void> _deleteKept(String path) async {
  try {
    await File(path).delete();
  } on FileSystemException {
    // Already gone.
  }
}

/// Review 115 (2): "Who sees it: Whole Space · Change", then Add. Change
/// opens the one choice (rule 6): Whole Space · A Team · A person · Only
/// me, the Team or the person picked after it. Null when closed.
Future<WhoSees?> showWhoSeesSheet(
  BuildContext context,
  WidgetRef ref, {
  required String spaceId,
}) {
  final l10n = AppLocalizations.of(context);
  return showBvSheet<WhoSees>(
    context: context,
    title: l10n.libraryAddFile,
    builder: (_) => _WhoSeesSheet(spaceId: spaceId),
  );
}

class _WhoSeesSheet extends ConsumerStatefulWidget {
  const _WhoSeesSheet({required this.spaceId});

  final String spaceId;

  @override
  ConsumerState<_WhoSeesSheet> createState() => _WhoSeesSheetState();
}

class _WhoSeesSheetState extends ConsumerState<_WhoSeesSheet> {
  WhoSees _who = (share: FolderShare.space, id: null, name: null);
  var _changing = false;

  Future<void> _choose(FolderShare share) async {
    final pick = switch (share) {
      FolderShare.person => pickFolderPerson,
      FolderShare.team => pickFolderTeam,
      _ => null,
    };
    final picked = await pick?.call(context, ref, widget.spaceId);
    if (!mounted) return;
    if ((share == FolderShare.person || share == FolderShare.team) &&
        picked == null) {
      return;
    }
    setState(() => _who = (share: share, id: picked?.id, name: picked?.name));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final label = switch (_who.share) {
      FolderShare.space => l10n.libraryShareSpace,
      FolderShare.onlyMe => l10n.libraryShareOnlyMe,
      _ => inOwnDirection(_who.name ?? ''),
    };
    return Column(
      key: const Key('library-who-sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BvSpace.s12,
      children: [
        Row(
          key: const Key('library-who-line'),
          spacing: BvSpace.s8,
          children: [
            const Icon(
              BvIcons.team,
              size: BvSize.iconMd,
              color: BvColors.iconSecondary,
            ),
            Expanded(
              child: Text(
                l10n.libraryWhoSeesLine(label),
                style: type.bodyMd.copyWith(color: BvColors.textPrimary),
              ),
            ),
            if (!_changing)
              BvButton(
                key: const Key('library-who-change'),
                label: l10n.libraryWhoChange,
                style: BvButtonStyle.tertiary,
                size: BvButtonSize.medium,
                onPressed: () => setState(() => _changing = true),
              ),
          ],
        ),
        if (_changing)
          Wrap(
            key: const Key('library-who-choice'),
            spacing: BvSpace.s8,
            runSpacing: BvSpace.s8,
            children: [
              for (final s in const [
                FolderShare.space,
                FolderShare.team,
                FolderShare.person,
                FolderShare.onlyMe,
              ])
                BvChip(
                  key: Key('library-who-${s.json}'),
                  label: switch (s) {
                    FolderShare.onlyMe => l10n.libraryShareOnlyMe,
                    FolderShare.person => l10n.librarySharePerson,
                    FolderShare.team => l10n.libraryShareTeam,
                    FolderShare.space => l10n.libraryShareSpace,
                  },
                  tight: true,
                  selected: _who.share == s,
                  onTap: () => unawaited(_choose(s)),
                ),
            ],
          ),
        BvButton(
          key: const Key('library-who-add'),
          label: l10n.libraryAddFile,
          expand: true,
          onPressed: () => Navigator.of(context).pop(_who),
        ),
      ],
    );
  }
}

/// Review 115 (1): a Library file on its way, in its list: "Uploading
/// 40%", "Waiting for signal" (with ✕ to take it off), or "Couldn't upload
/// · Tap to fix", which opens the composer's line (Try again · Remove).
class LibraryPendingRow extends ConsumerWidget {
  const LibraryPendingRow({super.key, required this.item});

  final PendingItem item;

  Future<void> _fix(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final refused = FileRefused.fromCode(item.refusal);
    final picked = await showCouldNotSendFix(
      context,
      why: refused != null
          ? fileRefusedText(l10n, refused)
          : l10n.couldNotSendGeneric,
      refused: refused,
      tryAgain: refused?.problem != UploadProblem.gone,
    );
    if (!context.mounted) return;
    final outbox = ref.read(workOutboxProvider.notifier);
    runCouldNotSendFix(
      picked,
      tryAgain: () => unawaited(outbox.send(item)),
      remove: () => outbox.discard(item),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final going = ref.watch(outboxSendingProvider)[item.id];
    final file = item.files.single;
    final line = item.refused
        ? l10n.libraryCouldNotUpload
        : going != null
        ? l10n.libraryUploading(
            going.hasBytes ? going.sent! * 100 ~/ going.total! : 0,
          )
        : l10n.libraryWaitingForSignal;
    return BvListRow(
      key: Key('library-pending-${item.id}'),
      title: inOwnDirection(file.name),
      subtitle: line,
      leading: const BvRowIcon(BvIcons.upload, ink: true),
      trailing: going != null
          ? const BvRowTrailing.none()
          : BvRowTrailing.badge(
              IconButton(
                key: Key('library-pending-remove-${item.id}'),
                tooltip: l10n.couldNotSendRemove,
                icon: const Icon(BvIcons.close, size: BvSize.iconMd),
                onPressed: () => unawaited(
                  ref.read(workOutboxProvider.notifier).discard(item),
                ),
              ),
            ),
      onTap: item.refused ? () => unawaited(_fix(context, ref)) : null,
    );
  }
}

/// The Library files of [spaceId] on their way into [folderId] (null, the
/// top level, also shows those whose new folder isn't made yet).
List<PendingItem> libraryWaiting(
  List<PendingItem> outbox,
  String spaceId,
  String? folderId,
  List<LibraryFolder> folders,
) => [
  for (final i in outbox)
    if (i.kind == PendingKind.libraryFile &&
        i.spaceId == spaceId &&
        (i.files.single.folderId == folderId ||
            (folderId == null &&
                i.newFolder != null &&
                !folders.any((f) => f.id == i.newFolder!.id))))
      i,
];
