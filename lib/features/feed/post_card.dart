import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/ago.dart';
import '../../core/l10n/bidi.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/post.dart';
import '../../data/models/space.dart';
import '../../data/repositories/post_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_avatar.dart';
import '../../shared/widgets/bv_badge.dart';
import '../../shared/widgets/bv_dialog.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../entry/entry_state.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../spaces/space_errors.dart';
import 'feed_state.dart';

/// How a card shows its project tag: the strip on top (H1 Feed), a chip
/// under the author (profile, post detail), or nothing (the project's own
/// sheet).
enum PostTag { strip, chip, none }

/// A site update card (H1 v2): the project, the author, the text in its
/// own language, the photos, who found it useful, then Useful · Reply.
class PostCard extends ConsumerWidget {
  const PostCard({
    super.key,
    required this.post,
    this.tag = PostTag.strip,
    this.onOpen,
    this.onChanged,
    this.onGone,
  });

  final Post post;
  final PostTag tag;

  /// Opens the post (Reply, a tap on the text). Null on the post page.
  final VoidCallback? onOpen;

  /// The card changed (Useful, edit): the list puts it in place.
  final ValueChanged<Post>? onChanged;

  /// The post was deleted, or its author muted: the list drops it.
  final VoidCallback? onGone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final me = ref.watch(authUserIdProvider).value;
    final now = ref.watch(clockProvider)();
    final mine = post.authorId == me;
    final project = post.project;
    final names = ref.watch(usefulNamesProvider(post.id)).value ?? const [];

    final byline = joinMeta([
      [?post.authorHeadline, ?post.authorCompany].join(', '),
      formatShortAgo(
        l10n,
        post.createdAt.toLocal(),
        now,
        Localizations.localeOf(context).toLanguageTag(),
      ),
      if (post.editedAt != null) l10n.postEdited,
    ]);

    Future<void> useful() async {
      final on = !post.myUseful;
      onChanged?.call(post.copyWith(myUseful: on));
      try {
        await ref.read(postRepositoryProvider).markUseful('post', post.id, on);
        ref.invalidate(usefulNamesProvider(post.id));
      } on SpaceException catch (e) {
        onChanged?.call(post.copyWith(myUseful: !on));
        if (context.mounted) showSpaceError(context, e);
      }
    }

    return Material(
      key: Key('post-${post.id}'),
      color: BvColors.surfaceElevated,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BvRadius.cardAll,
        side: BorderSide(color: BvColors.borderDefault, width: BvStroke.thin),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (project != null && tag == PostTag.strip)
            _ProjectStrip(project: project),
          InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                BvSpace.s16,
                BvSpace.s12,
                BvSpace.s4,
                BvSpace.s12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: BvSpace.s8,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: BvSpace.s12,
                    children: [
                      Expanded(
                        child: GestureDetector(
                          key: Key('post-author-${post.id}'),
                          onTap: () => _openAuthor(context, me),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                inOwnDirection(post.authorName),
                                style: type.titleMd,
                              ),
                              Text(
                                byline,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: type.bodySm.copyWith(
                                  color: BvColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        key: Key('post-menu-${post.id}'),
                        tooltip: l10n.postMenu,
                        icon: const Icon(
                          BvIcons.more,
                          color: BvColors.iconSecondary,
                        ),
                        onPressed: () => _menu(context, ref, mine),
                      ),
                    ],
                  ),
                  if (project != null && tag == PostTag.chip)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: _ProjectChip(project: project),
                    ),
                  if ((post.body ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        end: BvSpace.s12,
                      ),
                      child: Text(
                        post.body!,
                        // In the language it was written in.
                        textDirection: post.lang == 'ar'
                            ? TextDirection.rtl
                            : TextDirection.ltr,
                        textAlign: TextAlign.start,
                        style: type.bodyMd,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (post.photos.isNotEmpty) _Photos(photos: post.photos),
          if (names.isNotEmpty)
            Padding(
              key: Key('post-proof-${post.id}'),
              padding: const EdgeInsetsDirectional.fromSTEB(
                BvSpace.s16,
                BvSpace.s8,
                BvSpace.s16,
                0,
              ),
              child: Text(
                names.length == 1
                    ? l10n.postUsefulOne(names.first)
                    : l10n.postUsefulTwo(names[0], names[1]),
                style: type.bodySm.copyWith(color: BvColors.textSecondary),
              ),
            ),
          const Divider(
            height: BvSpace.s16,
            thickness: BvStroke.thin,
            color: BvColors.borderDefault,
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: BvSpace.s8,
              bottom: BvSpace.s4,
            ),
            child: Row(
              children: [
                _Action(
                  key: Key('post-useful-${post.id}'),
                  icon: BvIcons.useful,
                  label: l10n.postUseful,
                  active: post.myUseful,
                  // Not on your own post.
                  onTap: mine ? null : useful,
                ),
                _Action(
                  key: Key('post-reply-${post.id}'),
                  icon: BvIcons.chat,
                  label: l10n.postReply,
                  onTap: onOpen,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openAuthor(BuildContext context, String? me) => context.push(
    post.authorId == me
        ? AppRoutes.profile
        : '${AppRoutes.people}/${post.authorId}',
  );

  Future<void> _menu(BuildContext context, WidgetRef ref, bool mine) async {
    final l10n = AppLocalizations.of(context);
    final choice = await showBvSheet<_Menu>(
      context: context,
      builder: (sheet) => ClipRRect(
        borderRadius: BvRadius.cardAll,
        child: BvListGroup(
          rows: mine
              ? [
                  BvListRow(
                    key: const Key('post-edit'),
                    leading: const BvRowIcon(BvIcons.edit),
                    title: l10n.postEdit,
                    trailing: const BvRowTrailing.none(),
                    onTap: () => Navigator.of(sheet).pop(_Menu.edit),
                  ),
                  BvListRow(
                    key: const Key('post-delete'),
                    leading: const BvRowIcon(BvIcons.delete, destructive: true),
                    title: l10n.postDelete,
                    destructive: true,
                    trailing: const BvRowTrailing.none(),
                    onTap: () => Navigator.of(sheet).pop(_Menu.delete),
                  ),
                ]
              : [
                  // Report comes with block in week 8.
                  BvListRow(
                    key: const Key('post-mute'),
                    leading: const BvRowIcon(BvIcons.close),
                    title: l10n.postMute(post.authorName),
                    trailing: const BvRowTrailing.none(),
                    onTap: () => Navigator.of(sheet).pop(_Menu.mute),
                  ),
                ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    final repo = ref.read(postRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    // The card leaves the list when muted: Undo reloads through the app's
    // state, which outlives it.
    final container = ProviderScope.containerOf(context);
    switch (choice) {
      case _Menu.edit:
        await context.push(AppRoutes.postEdit(post.id));
        ref.invalidate(postProvider(post.id));
        final edited = await ref.read(postProvider(post.id).future);
        if (edited != null) onChanged?.call(edited);
      case _Menu.delete:
        final yes = await showBvDialog(
          context: context,
          title: l10n.postDeleteTitle,
          body: l10n.postDeleteBody,
          cancelLabel: l10n.commonCancel,
          confirmLabel: l10n.postDelete,
          destructive: true,
        );
        if (!yes || !context.mounted) return;
        try {
          await repo.delete(post.id);
          ref.read(feedProvider.notifier).remove(postId: post.id);
          onGone?.call();
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(l10n.postDeleted)));
        } on SpaceException catch (e) {
          if (context.mounted) showSpaceError(context, e);
        }
      case _Menu.mute:
        try {
          await repo.mute(post.authorId, true);
          ref.read(feedProvider.notifier).remove(authorId: post.authorId);
          onGone?.call();
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(l10n.postMuted(post.authorName)),
                action: SnackBarAction(
                  label: l10n.postUndo,
                  onPressed: () async {
                    await repo.mute(post.authorId, false);
                    container.invalidate(feedProvider);
                  },
                ),
              ),
            );
        } on SpaceException catch (e) {
          if (context.mounted) showSpaceError(context, e);
        }
    }
  }
}

enum _Menu { edit, delete, mute }

/// H1: the project tile, its name and place, and its type. Opens PJ1.
class _ProjectStrip extends StatelessWidget {
  const _ProjectStrip({required this.project});

  final PostProject project;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final locale = Localizations.localeOf(context);
    final kind = project.typeName?.of(locale);
    final place = project.place(locale);
    return InkWell(
      key: Key('post-project-${project.id}'),
      onTap: () => context.push('${AppRoutes.projects}/${project.id}'),
      child: Container(
        padding: const EdgeInsetsDirectional.all(BvSpace.s16),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: BvColors.borderDefault,
              width: BvStroke.thin,
            ),
          ),
        ),
        child: Row(
          spacing: BvSpace.s12,
          children: [
            BvProjectAvatar(id: project.id, icon: BvIcons.crane),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    inOwnDirection(project.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: type.titleMd,
                  ),
                  if (place != null)
                    Text(
                      place,
                      style: type.bodySm.copyWith(
                        color: BvColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            // The project type: the MVP has no phase.
            if (kind != null)
              BvBadge(
                label: locale.languageCode == 'ar' ? kind : kind.toUpperCase(),
                tone: BvBadgeTone.brand,
              ),
          ],
        ),
      ),
    );
  }
}

/// R12 / H10: the project as a small chip under the author.
class _ProjectChip extends StatelessWidget {
  const _ProjectChip({required this.project});

  final PostProject project;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return InkWell(
      key: Key('post-project-${project.id}'),
      borderRadius: BvRadius.smallAll,
      onTap: () => context.push('${AppRoutes.projects}/${project.id}'),
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: BvSpace.s8,
          vertical: BvSpace.s4,
        ),
        decoration: const BoxDecoration(
          color: BvColors.surfaceSubtle,
          borderRadius: BvRadius.smallAll,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: BvSpace.s6,
          children: [
            const Icon(
              BvIcons.crane,
              size: BvSize.iconSm,
              color: BvColors.iconPrimary,
            ),
            Flexible(
              child: Text(
                inOwnDirection(project.name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: type.labelSm,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One photo large; two to four in a grid. A tap opens it full screen.
class _Photos extends ConsumerWidget {
  const _Photos({required this.photos});

  final List<PostPhoto> photos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget tile(PostPhoto p, {double? aspect}) {
      final url = ref.watch(postPhotoUrlProvider(p.path)).value;
      final image = Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: BvColors.surfaceSubtle),
          if (url != null)
            Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => const SizedBox.shrink(),
            ),
        ],
      );
      return GestureDetector(
        key: Key('post-photo-${p.path}'),
        onTap: url == null ? null : () => _view(context, url),
        child: aspect == null
            ? image
            : AspectRatio(aspectRatio: aspect, child: image),
      );
    }

    if (photos.length == 1) {
      final p = photos.single;
      final aspect = p.width != null && p.height != null && p.height! > 0
          ? (p.width! / p.height!).clamp(
              BvPostSpec.photoMinAspect,
              BvPostSpec.photoMaxAspect,
            )
          : BvPostSpec.photoAspect;
      return tile(p, aspect: aspect);
    }
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: BvPostSpec.photoGap,
      crossAxisSpacing: BvPostSpec.photoGap,
      children: [for (final p in photos) tile(p)],
    );
  }

  void _view(BuildContext context, String url) => showDialog<void>(
    context: context,
    barrierColor: BvColors.brandInk,
    builder: (context) => GestureDetector(
      key: const Key('post-photo-viewer'),
      onTap: () => Navigator.of(context).pop(),
      child: InteractiveViewer(
        maxScale: BvPreviewSpec.maxZoom,
        child: Center(child: Image.network(url, fit: BoxFit.contain)),
      ),
    ),
  );
}

class _Action extends StatelessWidget {
  const _Action({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final color = active ? BvColors.textAction : BvColors.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BvRadius.controlAll,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: BvSize.touchMin),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: BvSpace.s8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: BvSpace.s6,
            children: [
              Icon(icon, size: BvSize.iconMd, color: color),
              Text(label, style: type.labelMd.copyWith(color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
