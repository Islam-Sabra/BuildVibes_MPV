import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/chat.dart';
import '../../data/models/library.dart';
import '../../data/models/space.dart';
import '../../core/l10n/bidi.dart';
import '../../data/repositories/library_repository.dart';
import '../../data/repositories/space_repository.dart';
import '../../shared/widgets/bv_popover_menu.dart';
import '../../l10n/gen/app_localizations.dart';
import '../library/library_folders.dart';
import '../library/library_tab.dart';
import '../profile/widgets/profile_parts.dart' show EmptyNote;
import '../../shared/widgets/bv_writing_card.dart' show bvBareField;
import 'people_tab.dart';

/// A file post the Library asked for (review 69 1b): back on the Space's
/// Work, as a new version of [replaces] when it has one.
class SpaceFileAsk {
  const SpaceFileAsk({this.replaces, this.folderId});

  final LibraryFile? replaces;

  /// Review 113 (8): the file goes into this Library folder.
  final String? folderId;
}

/// The Space's People (review 105 Part 1, SP8 2670:38796), from the
/// header's People icon: its own screen, with Invite at the top end for
/// who may invite.
class SpacePeopleScreen extends ConsumerStatefulWidget {
  const SpacePeopleScreen({super.key, required this.spaceId});

  final String spaceId;

  @override
  ConsumerState<SpacePeopleScreen> createState() => _SpacePeopleState();
}

/// Search in People's header (review 105 SP8, the lead's ruling: a Space
/// with 100+ members needs it): the field takes the title's place.
class _SpacePeopleState extends ConsumerState<SpacePeopleScreen> {
  final _query = TextEditingController();
  var _searching = false;

  String get spaceId => widget.spaceId;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _search(bool on) => setState(() {
    _searching = on;
    if (!on) _query.clear();
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final detail = ref.watch(spaceDetailProvider(spaceId)).value;
    return _SectionScaffold(
      title: l10n.spacesTabPeople,
      titleField: _searching
          ? TextField(
              key: const Key('people-search-field'),
              controller: _query,
              autofocus: true,
              style: type.bodyMd,
              onChanged: (_) => setState(() {}),
              decoration: bvBareField(
                hint: l10n.peopleSearchHint,
                style: type.bodyMd,
              ),
            )
          : null,
      actions: [
        IconButton(
          key: const Key('people-search'),
          tooltip: _searching ? l10n.searchClear : l10n.searchMenu,
          onPressed: () => _search(!_searching),
          icon: Icon(
            _searching ? BvIcons.close : BvIcons.search,
            size: BvSize.iconLg,
          ),
        ),
        if (detail?.myRights.invite ?? false)
          IconButton(
            key: const Key('people-invite'),
            tooltip: l10n.spacesInfoInvite,
            onPressed: () => context.push(AppRoutes.spaceInvite(spaceId)),
            icon: const Icon(BvIcons.invite, size: BvSize.iconLg),
          ),
      ],
      body: detail == null
          ? null
          : PeopleTab(space: detail, query: _query.text),
    );
  }
}

/// The Space's Library (review 105 Part 1), from the header's folder icon.
/// Adding a file goes back to Work, writing its post ([SpaceFileAsk]).
/// Review 113 LB1: the Space's name under the title, and + for New folder
/// and Link folder for who may add files.
class SpaceLibraryScreen extends ConsumerWidget {
  const SpaceLibraryScreen({super.key, required this.spaceId});

  final String spaceId;

  Future<void> _add(BuildContext context, WidgetRef ref, SpaceDetail d) async {
    final l10n = AppLocalizations.of(context);
    final link = await showBvScreenMenu<bool>(
      context,
      key: const Key('library-add-menu'),
      items: [
        BvMenuItem(
          key: const Key('library-new-folder'),
          value: false,
          label: l10n.libraryNewFolder,
          icon: BvIcons.folder,
        ),
        BvMenuItem(
          key: const Key('library-link-folder'),
          value: true,
          label: l10n.libraryLinkFolder,
          icon: BvIcons.link,
        ),
      ],
    );
    if (link == null || !context.mounted) return;
    await showFolderSheet(context, ref, space: d, link: link);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final detail = ref.watch(spaceDetailProvider(spaceId)).value;
    return _SectionScaffold(
      title: l10n.spacesTabLibrary,
      subtitle: detail?.name,
      actions: [
        if (detail != null && detail.myRights.addFiles)
          IconButton(
            key: const Key('library-add'),
            tooltip: l10n.libraryNewFolder,
            onPressed: () => unawaited(_add(context, ref, detail)),
            icon: const Icon(BvIcons.add, size: BvSize.iconLg),
          ),
      ],
      body: detail == null
          ? null
          : LibraryTab(
              space: detail,
              onAddFile: ({replaces, folderId}) => context.pop(
                SpaceFileAsk(replaces: replaces, folderId: folderId),
              ),
            ),
    );
  }
}

/// Review 113 LB1: a folder's files, with its line under its name; ⋯
/// edits or deletes it for its creator or the Space admin. Adding a file
/// here hands the post up with the folder.
class LibraryFolderScreen extends ConsumerWidget {
  const LibraryFolderScreen({
    super.key,
    required this.spaceId,
    required this.folderId,
  });

  final String spaceId;
  final String folderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final detail = ref.watch(spaceDetailProvider(spaceId)).value;
    final folder = ref
        .watch(libraryFoldersProvider(spaceId))
        .value
        ?.where((f) => f.id == folderId)
        .firstOrNull;
    final mayChange =
        folder != null && detail != null && (folder.mine || detail.iAmAdmin);
    return _SectionScaffold(
      title: folder == null
          ? l10n.spacesTabLibrary
          : inOwnDirection(folder.name),
      subtitle: folder == null ? null : folderLine(l10n, folder),
      actions: [
        if (mayChange)
          IconButton(
            key: const Key('folder-more'),
            tooltip: l10n.libraryEditFolder,
            onPressed: () async {
              final router = GoRouter.of(context);
              final changed = await folderMenu(
                context,
                ref,
                space: detail,
                folder: folder,
              );
              // Deleted: back to the Library.
              if (changed &&
                  context.mounted &&
                  !(ref.read(libraryFoldersProvider(spaceId)).value ?? const [])
                      .any((f) => f.id == folderId)) {
                router.pop();
              }
            },
            icon: const Icon(BvIcons.more, size: BvSize.iconLg),
          ),
      ],
      body: detail == null || folder == null
          ? null
          : LibraryTab(
              space: detail,
              folder: folder,
              onAddFile: ({replaces, folderId}) => context.pop(
                SpaceFileAsk(replaces: replaces, folderId: folderId),
              ),
            ),
    );
  }
}

class _SectionScaffold extends StatelessWidget {
  const _SectionScaffold({
    required this.title,
    required this.body,
    this.actions = const [],
    this.titleField,
    this.subtitle,
  });

  final String title;

  /// Under the title, small (LB1: the Space's name).
  final String? subtitle;
  final Widget? body;
  final List<Widget> actions;

  /// In the title's place (People's search).
  final Widget? titleField;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: BvColors.surfaceApp,
    appBar: AppBar(
      backgroundColor: BvColors.surfaceApp,
      centerTitle: false,
      titleSpacing: 0,
      title:
          titleField ??
          (subtitle == null
              ? Text(title, style: BvType.of(context).titleLg)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BvType.of(context).titleLg,
                    ),
                    Text(
                      subtitle!,
                      key: const Key('section-subtitle'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BvType.of(
                        context,
                      ).metadata.copyWith(color: BvColors.textSecondary),
                    ),
                  ],
                )),
      actions: actions,
    ),
    body:
        body ??
        Padding(
          padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
          child: EmptyNote(AppLocalizations.of(context).spacesNotFound),
        ),
  );
}

/// What Space info hands back to the Space (review 105 Part 1: it holds
/// what ⋯ held): the daily report opens on Work.
enum SpaceInfoAction { dailyReport }

/// The Space's whole Chat unread, for its Work · Chat switch.
int spaceUnread(List<ChatThread> threads) =>
    threads.fold(0, (n, t) => n + t.unread);

/// A Space member who wants in is waiting (Needs you): People's dot.
bool joinWaiting(SpacePeople? people) => people?.requests.isNotEmpty ?? false;
