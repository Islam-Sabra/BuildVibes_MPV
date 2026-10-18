import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/around_specs.dart';
import '../../core/design/bv_icons.dart';
import '../../core/design/daybook_paper_specs.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/post.dart';
import '../../data/models/space.dart';
import '../../data/repositories/post_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_avatar.dart';
import '../../shared/widgets/bv_dialog.dart';
import '../../shared/widgets/bv_latest_reply.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_project_tag.dart';
import '../../shared/widgets/bv_slip.dart';
import '../../shared/widgets/bv_tap_target.dart';
import '../../shared/widgets/bv_torn_edge.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../../data/repositories/safety_repository.dart';
import '../activity/activity_state.dart';
import '../entry/entry_state.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../safety/report_flow.dart';
import '../spaces/space_errors.dart';
import '../work/daybook_photos.dart' show localPhotoProvider;
import '../work/daybook_words.dart';
import 'feed_state.dart';
import 'post_draft.dart';

/// Whether a card shows its project tag: yes (Home, profile, post
/// detail), or not on the project's own sheet.
enum PostTag { shown, none }

/// A site update as a full-width Daybook card (H1 v4 2587:35875, AR
/// 2588:429): the author with their line and the time, the text in its own
/// language, the photos, the project tag, who found it useful (names,
/// never a count), the latest reply with up to three faces (F30, never a
/// count), then Useful · Reply.
///
/// [PostCard.waiting] is a post still on this phone (H5): its photos from
/// the phone, "Waiting to send" and nothing to do on it yet; or, refused
/// while another post was being written, "Couldn't send. Tap to fix".
class PostCard extends ConsumerWidget {
  const PostCard({
    super.key,
    required this.post,
    this.tag = PostTag.shown,
    this.onOpen,
    this.onReplyLine,
    this.onChanged,
    this.onGone,
    this.replyLine = true,
  }) : waiting = false,
       couldNotSend = false,
       sent = false;

  const PostCard.waiting({
    super.key,
    required this.post,
    this.couldNotSend = false,
    this.sent = false,
    this.onOpen,
  }) : waiting = true,
       tag = PostTag.shown,
       onReplyLine = null,
       onChanged = null,
       onGone = null,
       replyLine = false;

  /// On the phone, not on the server yet: [post]'s photo paths are the
  /// phone's own.
  final bool waiting;

  /// The server refused it: tapping fixes it ([onOpen]).
  final bool couldNotSend;

  /// It reached the server and the feed hasn't read it yet: no "Waiting to
  /// send" (F17).
  final bool sent;

  final Post post;
  final PostTag tag;

  /// Opens the post (Reply, a tap on the text). Null on the post page.
  final VoidCallback? onOpen;

  /// The latest reply line was tapped: the post opens at that reply
  /// ([AppRoutes.post]'s reply).
  final ValueChanged<String>? onReplyLine;

  /// The latest reply line shows. Not on the post page, where the replies
  /// are listed right under the post (review 54 A2).
  final bool replyLine;

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
    final names = waiting
        ? const <String>[]
        : ref.watch(usefulNamesProvider(post.id)).value ?? const [];
    final words = DaybookWords(
      l10n,
      Localizations.localeOf(context).toLanguageTag(),
      use24: MediaQuery.alwaysUse24HourFormatOf(context),
    );

    final byline = joinMeta([
      [?post.authorHeadline, ?post.authorCompany].join(', '),
      if (post.editedAt != null) l10n.postEdited,
    ]);
    final latest = waiting || !replyLine ? null : post.latestReply;

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

    final muted = type.metadata.copyWith(color: BvColors.textSecondary);
    return BvSlip(
      key: Key('post-${post.id}'),
      tear: BvSlipBorder.forId(post.id).variant,
      onTap: onOpen,
      paddingTop: BvHomeSpec.cardPaddingTop,
      // Under the actions' row only its own 6; with no actions, as at the
      // top.
      paddingBottom: waiting
          ? BvHomeSpec.cardPaddingTop
          : BvHomeSpec.cardPaddingBottom,
      children: [
        // H1 v4: the avatar, the name with the headline under it, the time
        // and ⋯ at the end, level with the name.
        Row(
          spacing: BvHomeSpec.authorGap,
          children: [
            Expanded(
              child: GestureDetector(
                key: Key('post-author-${post.id}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => _openAuthor(context, me),
                child: Row(
                  spacing: BvHomeSpec.authorGap,
                  children: [
                    BvAvatar(
                      name: post.authorName,
                      size: BvAvatarSize.post,
                      tint: BvAvatarTints.forId(post.authorId),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            inOwnDirection(post.authorName),
                            key: Key('post-name-${post.id}'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: type.titleMd,
                          ),
                          if (byline.isNotEmpty)
                            Text(
                              byline,
                              key: Key('post-byline-${post.id}'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: muted,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Text(
              words.time.moment(post.createdAt, now),
              key: Key('post-time-${post.id}'),
              style: muted,
            ),
            if (!waiting)
              BvTapTarget(
                child: Semantics(
                  button: true,
                  label: l10n.postMenu,
                  excludeSemantics: true,
                  child: GestureDetector(
                    key: Key('post-menu-${post.id}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _menu(context, ref, mine),
                    child: const Icon(
                      BvIcons.more,
                      size: BvHomeSpec.menuIcon,
                      color: BvColors.iconSecondary,
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
        if (post.photos.isNotEmpty)
          _Photos(photos: post.photos, local: waiting),
        if (project != null && tag == PostTag.shown)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: BvProjectTag(
              key: Key('post-project-${project.id}'),
              projectId: project.id,
              name: project.name,
              place: project.place(Localizations.localeOf(context)),
              onTap: waiting
                  ? null
                  : () => context.push('${AppRoutes.projects}/${project.id}'),
            ),
          ),
        if (waiting && !sent)
          Text(
            couldNotSend ? l10n.daybookCouldNotSend : l10n.daybookWaitingToSend,
            key: Key('post-waiting-${post.id}'),
            style: couldNotSend
                ? type.labelSm.copyWith(color: BvColors.textDestructive)
                : muted,
          ),
        if (names.isNotEmpty)
          Text(
            names.length == 1
                ? l10n.postUsefulOne(names.first)
                : l10n.postUsefulTwo(names[0], names[1]),
            key: Key('post-proof-${post.id}'),
            style: muted,
          ),
        if (latest != null)
          BvLatestReply(
            key: Key('post-latest-reply-${post.id}'),
            name: inOwnDirection(latest.authorName),
            words: latest.body,
            faces: [
              for (final f in post.replyFaces)
                (name: f.name, tint: BvAvatarTints.forId(f.id)),
            ],
            // A reply to you is bold until this post is opened (F30).
            unseen:
                latest.toMe &&
                !ref.watch(seenRepliesProvider).contains(latest.id),
            onTap: onReplyLine == null ? null : () => onReplyLine!(latest.id),
          ),
        // Useful and Reply, each with a 48 touch area. No share arrow:
        // sharing a post isn't built.
        if (!waiting)
          SizedBox(
            height: BvHomeSpec.cardActionsHeight,
            child: Row(
              spacing: BvHomeSpec.cardActionsGap,
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
        // In place on Home, at Now: one card for writing and editing
        // (review 48). Saving puts the card back everywhere it shows.
        ref.read(postWritingProvider.notifier).edit(post);
        context.go(AppRoutes.home);
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
  const _Photos({required this.photos, this.local = false});

  final List<PostPhoto> photos;

  /// Still on the phone: [PostPhoto.path] is the phone's copy.
  final bool local;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget tile(PostPhoto p) {
      final photo = local
          ? ref.watch(localPhotoProvider(p.path))
          : ref.watch(postPhotoProvider(p.path));
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
          height: BvHomeSpec.photoHeight,
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
    // The look is small; the touch area is 48 × 48 (outside everything
    // else, so a touch beside the words reaches them).
    return BvTapTarget(
      child: Semantics(
        button: true,
        selected: active,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: BvHomeSpec.actionGap,
            children: [
              Icon(icon, size: BvHomeSpec.actionIcon, color: color),
              Text(label, style: type.labelMd.copyWith(color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
