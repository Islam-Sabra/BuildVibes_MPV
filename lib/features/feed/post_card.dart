import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/around_specs.dart';
import '../../core/design/bv_icons.dart';
import '../../core/design/daybook_paper_specs.dart';
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
import '../../shared/widgets/bv_dialog.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_slip.dart';
import '../../shared/widgets/bv_torn_edge.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../../data/repositories/safety_repository.dart';
import '../activity/activity_state.dart';
import '../entry/entry_state.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../safety/report_flow.dart';
import '../spaces/space_errors.dart';
import 'feed_state.dart';

/// Whether a card shows its project tag: yes (Home, profile, post
/// detail), or not on the project's own sheet.
enum PostTag { shown, none }

/// A site update as a Daybook slip (H1 v3 2555:35307): the author and
/// their line, the text in its own language, the photos, the project tag,
/// who found it useful (names, never a count), then Useful · Reply.
/// [ago] adds how long ago it was posted, where no time spine shows it.
class PostCard extends ConsumerWidget {
  const PostCard({
    super.key,
    required this.post,
    this.tag = PostTag.shown,
    this.ago = true,
    this.onOpen,
    this.onChanged,
    this.onGone,
  });

  final Post post;
  final PostTag tag;
  final bool ago;

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
      if (ago)
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

    return BvSlip(
      key: Key('post-${post.id}'),
      tear: BvSlipBorder.forId(post.id).variant,
      onTap: onOpen,
      children: [
        Row(
          spacing: BvSpace.s8,
          children: [
            Expanded(
              child: GestureDetector(
                key: Key('post-author-${post.id}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => _openAuthor(context, me),
                child: Row(
                  spacing: BvSpace.s8,
                  children: [
                    BvAvatar(
                      name: post.authorName,
                      size: BvAvatarSize.xsm,
                      tint: BvAvatarTints.forId(post.authorId),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            inOwnDirection(post.authorName),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: type.labelSm.copyWith(
                              color: BvColors.textPrimary,
                            ),
                          ),
                          if (byline.isNotEmpty)
                            Text(
                              byline,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: type.metadata.copyWith(
                                color: BvColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Semantics(
              button: true,
              label: l10n.postMenu,
              excludeSemantics: true,
              child: InkResponse(
                key: Key('post-menu-${post.id}'),
                radius: BvSize.touchMin / 2,
                onTap: () => _menu(context, ref, mine),
                child: const SizedBox.square(
                  dimension: BvSize.controlMd,
                  child: Icon(
                    BvIcons.more,
                    size: BvHomeSpec.menuIcon,
                    color: BvColors.iconPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
        if ((post.body ?? '').isNotEmpty)
          Text(
            post.body!,
            // In the language it was written in.
            textDirection: post.lang == 'ar'
                ? TextDirection.rtl
                : TextDirection.ltr,
            textAlign: TextAlign.start,
            style: type.bodyMd,
          ),
        if (post.photos.isNotEmpty) _Photos(photos: post.photos),
        if (project != null && tag == PostTag.shown)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: _ProjectTag(project: project),
          ),
        if (names.isNotEmpty)
          Text(
            names.length == 1
                ? l10n.postUsefulOne(names.first)
                : l10n.postUsefulTwo(names[0], names[1]),
            key: Key('post-proof-${post.id}'),
            style: type.metadata.copyWith(color: BvColors.textSecondary),
          ),
        Row(
          spacing: BvHomeSpec.actionsGap,
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
      ],
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
                  BvListRow(
                    key: const Key('post-report'),
                    leading: const BvRowIcon(BvIcons.report),
                    title: l10n.postReport,
                    trailing: const BvRowTrailing.none(),
                    onTap: () => Navigator.of(sheet).pop(_Menu.report),
                  ),
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
      case _Menu.report:
        // Hidden for you at once (the server); the list drops it too.
        await startReport(
          context,
          kind: ReportKind.post,
          id: post.id,
          person: (id: post.authorId, name: post.authorName),
          onReported: () {
            container.read(feedProvider.notifier).remove(postId: post.id);
            onGone?.call();
          },
          // Blocked, or Undo: the feed and Activity read again (the
          // server leaves blocked people out).
          onBlocked: () => container
            ..invalidate(feedProvider)
            ..invalidate(activityProvider),
        );
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

enum _Menu { edit, delete, mute, report }

/// The project under the post (H1 v3 2555:35321): a dot, its name and
/// its place. Opens the project record (PJ1).
class _ProjectTag extends StatelessWidget {
  const _ProjectTag({required this.project});

  final PostProject project;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final place = project.place(Localizations.localeOf(context));
    return Semantics(
      button: true,
      child: GestureDetector(
        key: Key('post-project-${project.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push('${AppRoutes.projects}/${project.id}'),
        child: Container(
          padding: const EdgeInsetsDirectional.only(
            start: BvHomeSpec.tagPaddingStart,
            end: BvHomeSpec.tagPaddingEnd,
            top: BvHomeSpec.tagPaddingVertical,
            bottom: BvHomeSpec.tagPaddingVertical,
          ),
          decoration: const BoxDecoration(
            color: BvColors.surfaceSubtle,
            borderRadius: BvHomeSpec.tagRadius,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: BvHomeSpec.tagGap,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: BvProjectColors.forId(project.id),
                  shape: BoxShape.circle,
                ),
                child: const SizedBox.square(dimension: BvHomeSpec.tagDot),
              ),
              Flexible(
                child: Text(
                  inOwnDirection(project.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.labelSm,
                ),
              ),
              if (place != null)
                Text(
                  place,
                  style: type.metadata.copyWith(color: BvColors.textSecondary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A post's photo through a short-lived link; null while the link loads.
/// Screens stand in for it in tests.
final postPhotoProvider = Provider.autoDispose.family<ImageProvider?, String>((
  ref,
  path,
) {
  final url = ref.watch(postPhotoUrlProvider(path)).value;
  return url == null ? null : NetworkImage(url);
});

/// One photo large; two to four in a grid. A tap opens it full screen.
class _Photos extends ConsumerWidget {
  const _Photos({required this.photos});

  final List<PostPhoto> photos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget tile(PostPhoto p) {
      final photo = ref.watch(postPhotoProvider(p.path));
      final image = Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: BvColors.surfaceSubtle),
          if (photo != null)
            Image(
              image: photo,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => const SizedBox.shrink(),
            ),
        ],
      );
      return GestureDetector(
        key: Key('post-photo-${p.path}'),
        onTap: photo == null ? null : () => _view(context, photo),
        child: image,
      );
    }

    if (photos.length == 1) {
      return ClipRRect(
        borderRadius: BvSlipSpec.photoRadius,
        child: SizedBox(
          height: BvSlipSpec.photoHeightProof,
          child: tile(photos.single),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BvSlipSpec.photoRadius,
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: BvPostSpec.photoGap,
        crossAxisSpacing: BvPostSpec.photoGap,
        children: [for (final p in photos) tile(p)],
      ),
    );
  }

  void _view(BuildContext context, ImageProvider photo) => showDialog<void>(
    context: context,
    barrierColor: BvColors.brandInk,
    builder: (context) => GestureDetector(
      key: const Key('post-photo-viewer'),
      onTap: () => Navigator.of(context).pop(),
      child: InteractiveViewer(
        maxScale: BvPreviewSpec.maxZoom,
        child: Center(
          child: Image(image: photo, fit: BoxFit.contain),
        ),
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
    return Semantics(
      button: true,
      selected: active,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // The look is small; the touch area is 44 high.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: BvSize.controlMd),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: BvHomeSpec.actionGap,
            children: [
              Icon(icon, size: BvHomeSpec.actionIcon, color: color),
              Text(label, style: type.labelSm.copyWith(color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
