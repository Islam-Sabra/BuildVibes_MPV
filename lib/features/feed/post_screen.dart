import 'dart:async';

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
import '../../data/repositories/work_repository.dart' show newUuid;
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_avatar.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_dialog.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../entry/entry_state.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../spaces/space_errors.dart';
import 'feed_state.dart';
import 'post_card.dart';

/// H10v2 (a visitor) and H10c (your own post): the post, its replies one
/// level deep, and "Add a comment". P6 when it's deleted or blocked.
class PostScreen extends ConsumerStatefulWidget {
  const PostScreen({super.key, required this.postId});

  final String postId;

  @override
  ConsumerState<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends ConsumerState<PostScreen> {
  final _text = TextEditingController();

  /// H17: the top-level reply this answers, and the person tapped.
  ({String id, String name, String body})? _replyTo;
  var _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.isEmpty || _sending) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _sending = true);
    try {
      await ref
          .read(postRepositoryProvider)
          .addReply(
            id: newUuid(),
            postId: widget.postId,
            replyTo: _replyTo?.id,
            body: body,
          );
      _text.clear();
      _replyTo = null;
      ref.invalidate(postRepliesProvider(widget.postId));
    } on SpaceException catch (e) {
      if (mounted) showSpaceError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final post = ref.watch(postProvider(widget.postId));
    final p = post.value;

    if (p == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.postTitle)),
        body: post.isLoading
            ? const Center(child: CircularProgressIndicator())
            : post.hasError
            ? Center(child: Text(l10n.errorGeneric))
            : const _Unavailable(),
      );
    }

    final replies = ref.watch(postRepliesProvider(widget.postId)).value;
    final top = [
      for (final r in replies ?? const <PostReply>[])
        if (r.replyTo == null) r,
    ];
    List<PostReply> under(String id) => [
      for (final r in replies ?? const <PostReply>[])
        if (r.replyTo == id) r,
    ];
    // A reply whose top-level reply is gone still shows, at the top level.
    final known = {for (final r in top) r.id};
    final orphans = [
      for (final r in replies ?? const <PostReply>[])
        if (r.replyTo != null && !known.contains(r.replyTo)) r,
    ];

    return Scaffold(
      appBar: AppBar(titleSpacing: 0, title: Text(l10n.postTitle)),
      // The reply box in the body, so it rises with the keyboard.
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
              children: [
                PostCard(
                  post: p,
                  onChanged: (changed) {
                    ref.read(feedProvider.notifier).replace(changed);
                    ref.invalidate(postProvider(widget.postId));
                  },
                  onGone: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(height: BvSpace.s16),
                Text(l10n.postReplies, style: type.titleMd),
                const SizedBox(height: BvSpace.s12),
                if (replies == null)
                  const Center(child: CircularProgressIndicator())
                else if (replies.isEmpty)
                  Text(
                    l10n.postNoReplies,
                    style: type.bodySm.copyWith(color: BvColors.textSecondary),
                  )
                else
                  for (final r in [...top, ...orphans]) ...[
                    _ReplyView(
                      reply: r,
                      onReply: () => setState(
                        () => _replyTo = (
                          id: r.id,
                          name: r.authorName,
                          body: r.body,
                        ),
                      ),
                    ),
                    for (final child in under(r.id))
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: BvSpace.s40,
                        ),
                        child: _ReplyView(
                          reply: child,
                          // One level: the answer goes under the top-level reply,
                          // named for the person tapped.
                          onReply: () => setState(
                            () => _replyTo = (
                              id: r.id,
                              name: child.authorName,
                              body: child.body,
                            ),
                          ),
                        ),
                      ),
                  ],
              ],
            ),
          ),
          _ReplyBox(
            controller: _text,
            replyTo: _replyTo,
            sending: _sending,
            onChanged: () => setState(() {}),
            onCancel: () => setState(() => _replyTo = null),
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _ReplyView extends ConsumerWidget {
  const _ReplyView({required this.reply, required this.onReply});

  final PostReply reply;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final me = ref.watch(authUserIdProvider).value;
    final now = ref.watch(clockProvider)();
    final mine = reply.authorId == me;

    Future<void> useful() async {
      try {
        await ref
            .read(postRepositoryProvider)
            .markUseful('reply', reply.id, !reply.myUseful);
        ref.invalidate(postRepliesProvider(reply.postId));
      } on SpaceException catch (e) {
        if (context.mounted) showSpaceError(context, e);
      }
    }

    Future<void> menu() async {
      final delete = await showBvSheet<bool>(
        context: context,
        builder: (sheet) => ClipRRect(
          borderRadius: BvRadius.cardAll,
          child: BvListGroup(
            rows: [
              BvListRow(
                key: const Key('reply-delete'),
                leading: const BvRowIcon(BvIcons.delete, destructive: true),
                title: l10n.postDeleteReply,
                destructive: true,
                trailing: const BvRowTrailing.none(),
                onTap: () => Navigator.of(sheet).pop(true),
              ),
            ],
          ),
        ),
      );
      if (delete != true || !context.mounted) return;
      final yes = await showBvDialog(
        context: context,
        title: l10n.postDeleteReplyTitle,
        body: l10n.postDeleteReplyBody,
        cancelLabel: l10n.commonCancel,
        confirmLabel: l10n.delete,
        destructive: true,
      );
      if (!yes || !context.mounted) return;
      try {
        await ref.read(postRepositoryProvider).deleteReply(reply.id);
        ref.invalidate(postRepliesProvider(reply.postId));
      } on SpaceException catch (e) {
        if (context.mounted) showSpaceError(context, e);
      }
    }

    return Padding(
      key: Key('reply-${reply.id}'),
      padding: const EdgeInsetsDirectional.only(bottom: BvSpace.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BvSpace.s4,
        children: [
          Container(
            padding: const EdgeInsetsDirectional.fromSTEB(
              BvSpace.s12,
              BvSpace.s8,
              BvSpace.s4,
              BvSpace.s12,
            ),
            decoration: const BoxDecoration(
              color: BvColors.surfaceSubtle,
              borderRadius: BvRadius.cardAll,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: BvSpace.s4,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            inOwnDirection(reply.authorName),
                            style: type.labelMd,
                          ),
                          if (reply.authorHeadline != null)
                            Text(
                              reply.authorHeadline!,
                              style: type.bodySm.copyWith(
                                color: BvColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Your own reply: Delete. Others get Report in week 8.
                    if (mine)
                      IconButton(
                        key: Key('reply-menu-${reply.id}'),
                        tooltip: l10n.postReplyMenu,
                        icon: const Icon(
                          BvIcons.more,
                          color: BvColors.iconSecondary,
                        ),
                        onPressed: menu,
                      ),
                  ],
                ),
                // The bubble's full width, under the menu too, so the text
                // sits on its own language's side.
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: BvSpace.s8),
                  child: Text(
                    reply.body,
                    key: Key('reply-body-${reply.id}'),
                    textDirection: directionOf(reply.body),
                    style: type.bodyMd,
                  ),
                ),
              ],
            ),
          ),
          Row(
            spacing: BvSpace.s16,
            children: [
              const SizedBox(width: BvSpace.s4),
              Text(
                formatShortAgo(
                  l10n,
                  reply.createdAt.toLocal(),
                  now,
                  Localizations.localeOf(context).toLanguageTag(),
                ),
                style: type.metadata.copyWith(color: BvColors.textSecondary),
              ),
              GestureDetector(
                key: Key('reply-useful-${reply.id}'),
                onTap: mine ? null : useful,
                child: Text(
                  l10n.postUseful,
                  style: type.labelSm.copyWith(
                    color: reply.myUseful
                        ? BvColors.textAction
                        : BvColors.textSecondary,
                  ),
                ),
              ),
              GestureDetector(
                key: Key('reply-reply-${reply.id}'),
                onTap: onReply,
                child: Text(
                  l10n.postReply,
                  style: type.labelSm.copyWith(color: BvColors.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Add a comment", with H17's "Replying to {name}" above it.
class _ReplyBox extends ConsumerWidget {
  const _ReplyBox({
    required this.controller,
    required this.replyTo,
    required this.sending,
    required this.onChanged,
    required this.onCancel,
    required this.onSend,
  });

  final TextEditingController controller;
  final ({String id, String name, String body})? replyTo;
  final bool sending;
  final VoidCallback onChanged;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final me = ref.watch(myProfileProvider).value;
    final hasText = controller.text.trim().isNotEmpty;
    final r = replyTo;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: BvColors.surfaceElevated,
        border: Border(
          top: BorderSide(color: BvColors.borderDefault, width: BvStroke.thin),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            BvSpace.gutter,
            BvSpace.s8,
            BvSpace.s4,
            BvSpace.s8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: BvSpace.s8,
            children: [
              if (r != null)
                Container(
                  key: const Key('post-replying'),
                  padding: const EdgeInsetsDirectional.only(start: BvSpace.s8),
                  decoration: const BoxDecoration(
                    border: BorderDirectional(
                      start: BorderSide(
                        color: BvColors.textAction,
                        width: BvChatSpec.replyBar,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.postReplyingTo(r.name),
                              style: type.labelSm.copyWith(
                                color: BvColors.textAction,
                              ),
                            ),
                            Text(
                              r.body,
                              key: const Key('post-replying-body'),
                              textDirection: directionOf(r.body),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: type.bodySm.copyWith(
                                color: BvColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        key: const Key('post-cancel-reply'),
                        tooltip: l10n.postCancelReply,
                        icon: const Icon(
                          BvIcons.close,
                          color: BvColors.iconSecondary,
                        ),
                        onPressed: onCancel,
                      ),
                    ],
                  ),
                ),
              Row(
                spacing: BvSpace.s8,
                children: [
                  BvAvatar(
                    name: me == null ? '' : '${me.firstName} ${me.lastName}',
                    size: BvAvatarSize.sm,
                  ),
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: BvSize.controlMd,
                      ),
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: BvSpace.s16,
                      ),
                      alignment: AlignmentDirectional.centerStart,
                      decoration: const BoxDecoration(
                        color: BvColors.surfaceSubtle,
                        borderRadius: BvRadius.roundAll,
                      ),
                      child: TextField(
                        key: const Key('post-reply-input'),
                        controller: controller,
                        minLines: 1,
                        maxLines: 5,
                        maxLength: 1000,
                        textCapitalization: TextCapitalization.sentences,
                        textDirection: controller.text.trim().isEmpty
                            ? null
                            : directionOf(controller.text),
                        style: type.bodyMd,
                        decoration: InputDecoration(
                          isCollapsed: true,
                          counterText: '',
                          contentPadding: const EdgeInsetsDirectional.symmetric(
                            vertical: BvSpace.s8,
                          ),
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          hintText: r == null
                              ? l10n.postAddComment
                              : l10n.postWriteReply,
                          hintStyle: type.bodyMd.copyWith(
                            color: BvColors.textSecondary,
                          ),
                        ),
                        onChanged: (_) => onChanged(),
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('post-reply-send'),
                    tooltip: l10n.postSendReply,
                    icon: Icon(
                      BvIcons.send,
                      color: hasText && !sending
                          ? BvColors.iconAction
                          : BvColors.iconSecondary,
                    ),
                    onPressed: hasText && !sending ? onSend : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// P6: deleted, or you may not see it.
class _Unavailable extends StatelessWidget {
  const _Unavailable();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    return Padding(
      key: const Key('post-unavailable'),
      padding: const EdgeInsetsDirectional.all(BvSpace.s24),
      child: Column(
        // Full width, so it is centred in both directions.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BvSpace.s12,
        children: [
          const Icon(
            BvIcons.unavailable,
            size: BvSize.iconLg,
            color: BvColors.iconSecondary,
          ),
          Text(
            l10n.postUnavailable,
            textAlign: TextAlign.center,
            style: type.headingMd,
          ),
          Text(
            l10n.postUnavailableBody,
            textAlign: TextAlign.center,
            style: type.bodySm.copyWith(color: BvColors.textSecondary),
          ),
          Center(
            child: BvButton(
              key: const Key('post-back-home'),
              label: l10n.postBackHome,
              style: BvButtonStyle.secondary,
              size: BvButtonSize.medium,
              onPressed: () => context.go(AppRoutes.home),
            ),
          ),
        ],
      ),
    );
  }
}
