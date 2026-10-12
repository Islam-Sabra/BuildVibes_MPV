import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/library.dart';
import '../../data/models/space.dart';
import '../../data/repositories/library_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_chip.dart';
import '../../shared/widgets/bv_search_field.dart';
import '../entry/entry_state.dart';
import '../profile/widgets/profile_parts.dart';
import 'library_parts.dart';

/// "All" is every file; "Files" the documents (PDF drawings). Lists, Notes
/// and Events (Notebook) aren't in the MVP.
enum LibraryFilter { all, files }

/// Only the newest revision of each file; older ones open from it (F1).
List<LibraryFile> currentFiles(List<LibraryFile> all) {
  final replaced = {for (final f in all) ?f.supersedesId};
  return [
    for (final f in all)
      if (!replaced.contains(f.id)) f,
  ];
}

/// S13k · Space Library: search, All · Files, then the files, newest
/// first. "Add file" for people whose pass may add files.
class LibraryTab extends ConsumerStatefulWidget {
  const LibraryTab({super.key, required this.space});

  final SpaceDetail space;

  @override
  ConsumerState<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends ConsumerState<LibraryTab> {
  var _filter = LibraryFilter.all;
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final me = ref.watch(authUserIdProvider).value;
    final files = ref.watch(libraryFilesProvider(widget.space.id));
    final all = files.value;
    final canAdd = widget.space.myRights.addFiles;

    final q = _query.trim().toLowerCase();
    final shown = all == null
        ? const <LibraryFile>[]
        : [
            for (final f in currentFiles(all))
              if ((_filter == LibraryFilter.all || f.isPdf) &&
                  (q.isEmpty ||
                      f.name.toLowerCase().contains(q) ||
                      (f.note ?? '').toLowerCase().contains(q)))
                f,
          ];

    final Widget list;
    if (all == null) {
      list = files.hasError
          ? EmptyNote(l10n.errorGeneric)
          : const Center(child: CircularProgressIndicator());
    } else if (all.isEmpty) {
      list = EmptyNote(l10n.libraryEmpty);
    } else if (shown.isEmpty) {
      list = EmptyNote(l10n.libraryNoMatch);
    } else {
      list = ColoredBox(
        color: BvColors.surfaceElevated,
        child: Column(
          children: [
            for (final f in shown)
              FileRow(
                file: f,
                subtitle: fileMeta(l10n, f, me),
                onTap: () =>
                    context.push(AppRoutes.libraryFile(widget.space.id, f.id)),
              ),
          ],
        ),
      );
    }

    final body = RefreshIndicator(
      onRefresh: () =>
          ref.refresh(libraryFilesProvider(widget.space.id).future),
      child: ListView(
        key: const Key('library-tab'),
        padding: EdgeInsetsDirectional.only(
          top: BvSpace.s12,
          // The last row scrolls clear of Add file.
          bottom: canAdd ? BvButtonSpec.heightLarge + BvSpace.s16 * 2 : 0,
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
          const SizedBox(height: BvSpace.s12),
          // One single choice.
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: BvSpace.gutter,
            ),
            child: Row(
              spacing: BvSpace.s8,
              children: [
                for (final f in LibraryFilter.values)
                  BvChip(
                    key: Key('library-filter-${f.name}'),
                    label: switch (f) {
                      LibraryFilter.all => l10n.libraryAll,
                      LibraryFilter.files => l10n.libraryFiles,
                    },
                    selected: f == _filter,
                    onTap: () => setState(() => _filter = f),
                  ),
              ],
            ),
          ),
          const SizedBox(height: BvSpace.s16),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: BvSpace.gutter,
              vertical: BvSpace.s8,
            ),
            child: Text(
              l10n.libraryRecent,
              style: type.labelMd.copyWith(color: BvColors.textSecondary),
            ),
          ),
          list,
        ],
      ),
    );

    return Stack(
      children: [
        Positioned.fill(child: body),
        if (canAdd)
          PositionedDirectional(
            end: BvSpace.gutter,
            bottom: BvSpace.s16,
            child: BvButton(
              key: const Key('library-add'),
              label: l10n.libraryAdd,
              icon: BvIcons.create,
              onPressed: () async {
                await context.push(AppRoutes.libraryAdd(widget.space.id));
                ref.invalidate(libraryFilesProvider(widget.space.id));
              },
            ),
          ),
      ],
    );
  }
}
