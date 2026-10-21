import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/people_library_specs.dart';
import '../../core/l10n/bidi.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/library.dart';
import '../../data/models/space.dart';
import '../../data/repositories/library_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_faces.dart';
import '../../shared/widgets/bv_search_field.dart';
import '../../shared/widgets/bv_stamp.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../profile/widgets/profile_parts.dart';
import '../spaces/former_member.dart';
import '../work/daybook_photos.dart' show filePreviewProvider;
import 'library_parts.dart';

/// Only the version in use of each file; older ones open from it (LV2).
List<LibraryFile> currentFiles(List<LibraryFile> all) {
  final replaced = {for (final f in all) ?f.supersedesId};
  return [
    for (final f in all)
      if (!replaced.contains(f.id)) f,
  ];
}

/// How many versions came before [file], following its chain in [all].
int olderVersions(LibraryFile file, List<LibraryFile> all) {
  final byId = {for (final f in all) f.id: f};
  var n = 0;
  var next = file.supersedesId;
  final seen = <String>{};
  while (next != null && seen.add(next) && byId.containsKey(next)) {
    n++;
    next = byId[next]!.supersedesId;
  }
  return n;
}

/// "Rev D · 2 older versions · today" (LV1): the file's own facts.
String libraryLine(
  AppLocalizations l10n,
  String locale,
  LibraryFile f, {
  required int older,
  required DateTime now,
}) => joinMeta([
  ?f.revLabel,
  if (older > 0) l10n.libraryOlderVersions(older),
  libraryDay(l10n, locale, f.createdAt.toLocal(), now),
]);

/// LV1 · Space Library (2543:34980): Search files, then each file in use,
/// newest first, with its versions, NEW VERSION when it is new for me, and
/// who received it, as faces (never "3 received", rule 3). "Add a file"
/// for people who may add files opens a file post ([onAddFile]): every
/// file enters through a post (review 69 1b).
class LibraryTab extends ConsumerStatefulWidget {
  const LibraryTab({super.key, required this.space, this.onAddFile});

  final SpaceDetail space;

  /// Opens the Work tab's writing card as a Document for receipt; with
  /// [replaces], as a new version of it.
  final void Function({LibraryFile? replaces})? onAddFile;

  @override
  ConsumerState<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends ConsumerState<LibraryTab> {
  var _query = '';

  String get _spaceId => widget.space.id;

  Future<void> _refresh() async {
    ref
      ..invalidate(libraryOverviewProvider(_spaceId))
      ..invalidate(libraryFilesProvider(_spaceId));
    await ref.read(libraryFilesProvider(_spaceId).future);
  }

  Future<void> _open(LibraryFile f) async {
    final replaces = await context.push<LibraryFile>(
      AppRoutes.libraryFilePage(_spaceId, f.id),
    );
    if (!mounted) return;
    ref.invalidate(libraryOverviewProvider(_spaceId));
    if (replaces != null) widget.onAddFile?.call(replaces: replaces);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final now = ref.watch(clockProvider)();
    final files = ref.watch(libraryFilesProvider(_spaceId));
    // Faces and NEW VERSION; the list shows without them until they come.
    final overview =
        ref.watch(libraryOverviewProvider(_spaceId)).value ?? const {};
    final all = files.value;
    final rights = widget.space.myRights;
    final canAdd =
        rights.addFiles && rights.createItems && widget.onAddFile != null;

    final q = _query.trim().toLowerCase();
    final shown = all == null
        ? const <LibraryFile>[]
        : [
            for (final f in currentFiles(all))
              if (q.isEmpty ||
                  f.name.toLowerCase().contains(q) ||
                  (f.revLabel ?? '').toLowerCase().contains(q) ||
                  (f.note ?? '').toLowerCase().contains(q))
                f,
          ];

    final List<Widget> rows;
    if (all == null) {
      rows = [
        if (files.hasError)
          EmptyNote(l10n.errorGeneric)
        else
          const Padding(
            padding: EdgeInsetsDirectional.all(BvSpace.s32),
            child: Center(child: CircularProgressIndicator()),
          ),
      ];
    } else {
      rows = [
        if (all.isEmpty)
          EmptyNote(l10n.libraryEmpty)
        else if (shown.isEmpty)
          EmptyNote(l10n.libraryNoMatch),
        for (final f in shown)
          LibraryFileRow(
            file: f,
            line: libraryLine(
              l10n,
              locale,
              f,
              older: olderVersions(f, all),
              now: now,
            ),
            stacked: f.supersedesId != null,
            newVersion: overview[f.id]?.newForMe ?? false,
            received: overview[f.id]?.received ?? const [],
            onTap: () => _open(f),
          ),
        if (canAdd && q.isEmpty)
          _AddFileRow(onTap: () => widget.onAddFile!.call()),
      ];
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        key: const Key('library-tab'),
        padding: const EdgeInsetsDirectional.only(
          top: BvSpace.s12,
          bottom: BvSpace.s32,
        ),
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: BvSpace.gutter,
            ),
            child: BvSearchField(
              key: const Key('library-search'),
              placeholder: l10n.librarySearch,
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(height: BvSpace.s8),
          ...rows,
        ],
      ),
    );
  }
}

/// A Library file in use (LV1): its thumbnail (paper stacked behind when
/// it has older versions), the name, its line, NEW VERSION when it is new
/// for me, and the faces of who received it on the end side.
class LibraryFileRow extends StatelessWidget {
  const LibraryFileRow({
    super.key,
    required this.file,
    required this.line,
    required this.onTap,
    this.stacked = false,
    this.newVersion = false,
    this.received = const [],
  });

  final LibraryFile file;
  final String line;
  final VoidCallback onTap;
  final bool stacked;
  final bool newVersion;
  final List<LibraryReceipt> received;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    return InkWell(
      key: Key('file-${file.id}'),
      onTap: onTap,
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
              vertical: BvLibrarySpec.rowPaddingVertical,
            ),
            child: Row(
              spacing: BvLibrarySpec.rowGap,
              children: [
                LibraryThumb(file: file, stacked: stacked),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: BvSpace.s2,
                    children: [
                      Text(
                        inOwnDirection(file.name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: type.bodyMd,
                      ),
                      Text(
                        line,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: type.metadata.copyWith(
                          color: BvColors.textSecondary,
                        ),
                      ),
                      if (newVersion)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(
                            top: BvLibrarySpec.tagTop,
                          ),
                          child: BvInkStamp(
                            key: Key('file-new-version-${file.id}'),
                            label: l10n.daybookStampNewVersion,
                            size: BvInkStampSize.xs,
                          ),
                        ),
                    ],
                  ),
                ),
                if (received.isNotEmpty)
                  BvFaces(key: Key('file-faces-${file.id}'), [
                    for (final r in received)
                      (
                        name: personName(l10n, r.name),
                        tint: BvAvatarTints.forId(r.profileId),
                      ),
                  ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A file's small preview (the first page, or the photo): a plain
/// document when it can't be drawn. [stacked] puts a sheet of paper
/// behind it, for a file with older versions.
class LibraryThumb extends ConsumerWidget {
  const LibraryThumb({super.key, required this.file, this.stacked = false});

  final LibraryFile file;
  final bool stacked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = ref
        .watch(filePreviewProvider((path: file.path, mime: file.mime)))
        .value;
    Widget sheet({ImageProvider? image}) => Container(
      width: BvLibrarySpec.thumbWidth,
      height: BvLibrarySpec.thumbHeight,
      decoration: BoxDecoration(
        color: BvColors.surfaceElevated,
        borderRadius: BvLibrarySpec.thumbRadius,
        border: Border.all(color: BvColors.borderDefault, width: BvStroke.thin),
        image: image == null
            ? null
            : DecorationImage(image: image, fit: BoxFit.cover),
      ),
    );
    final front = Stack(
      alignment: Alignment.center,
      children: [
        sheet(image: image),
        if (image == null)
          Icon(
            file.isImage ? BvIcons.image : BvIcons.document,
            size: BvLibrarySpec.thumbIcon,
            color: BvColors.iconSecondary,
          ),
      ],
    );
    const offset = BvLibrarySpec.stackOffset;
    return ExcludeSemantics(
      child: SizedBox(
        width: BvLibrarySpec.thumbWidth + offset,
        height: BvLibrarySpec.thumbHeight + offset,
        child: Stack(
          children: [
            if (stacked)
              PositionedDirectional(start: offset, top: 0, child: sheet()),
            PositionedDirectional(start: 0, top: offset, child: front),
          ],
        ),
      ),
    );
  }
}

/// The quiet last row (review 69 1b): like any row, the + and grey words.
class _AddFileRow extends StatelessWidget {
  const _AddFileRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    return InkWell(
      key: const Key('library-add-file'),
      onTap: onTap,
      splashFactory: NoSplash.splashFactory,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: BvSpace.gutter,
          vertical: BvLibrarySpec.rowPaddingVertical,
        ),
        child: Row(
          spacing: BvLibrarySpec.rowGap,
          children: [
            const SizedBox(
              width: BvLibrarySpec.thumbWidth + BvLibrarySpec.stackOffset,
              child: Icon(
                BvIcons.create,
                size: BvLibrarySpec.thumbIcon,
                color: BvColors.iconSecondary,
              ),
            ),
            Expanded(
              child: Text(
                l10n.libraryAddFile,
                style: type.bodyMd.copyWith(color: BvColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
