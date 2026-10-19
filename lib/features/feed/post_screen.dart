import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../shared/widgets/bv_torn_edge.dart';
import '../../shared/widgets/bv_slip.dart';
import '../../core/design/daybook_paper_specs.dart';
import '../../core/design/daybook_days_specs.dart';
import '../../core/design/around_specs.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bv_time.dart';
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
import '../../data/repositories/safety_repository.dart';
import '../safety/report_flow.dart';
import '../spaces/space_errors.dart';
import 'feed_state.dart';
import 'post_card.dart';

/// H10v2 (a visitor) and H10c (your own post): the post as Home's card,
/// its replies as small slips two levels deep, and the reply bar (review
/// 50 F19). P6 when it's deleted or blocked.
/// The reply being answered: its [id], the top-level reply it is filed
/// under ([top], its own id when it is one), and its author and text.
typedef _ReplyTarget = ({String id, String top, String name, String body});

class PostScreen extends ConsumerStatefulWidget {
  const PostScreen({super.key, required this.postId, this.replyId});

  final String postId;

  /// Opened from a card's latest reply line (F30): the page scrolls to
  /// this reply once the replies are in.
  final String? replyId;

  @override
  ConsumerState<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends ConsumerState<PostScreen> {
  final _text = TextEditingController();

  /// Each reply's place on the page, to scroll to one.
  final _replyKeys = <String, GlobalKey>{};
  var _scrolled = false;

  GlobalKey _replyKey(String id) => _replyKeys.putIfAbsent(id, GlobalKey.new);

  void _scrollTo(String replyId) {
    final target = _replyKeys[replyId]?.currentContext;
    if (target == null) return;
    unawaited(
      Scrollable.ensureVisible(
        target,
        alignment: BvReplySpec.scrollAlignment,
        duration: BvMotion.base,
        curve: BvMotion.standard,
      ),
    );
  }

  /// H17: the reply this answers, the top-level reply it is filed under,
  /// and the person tapped.
  _ReplyTarget? _replyTo;
  var _sending = false;

  /// The reply being sent, with the id the app chose for it. Sent again
  /// unchanged (the signal dropped before the answer came), it keeps that
  /// id, so the server keeps one reply (F19).
  ({String id, String body, String? replyTo})? _attempt;

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
    final target = _replyTo;
    final replyTo = target?.id;
    final last = _attempt;
    final attempt = last != null && last.body == body && last.replyTo == replyTo
        ? last
        : (id: newUuid(), body: body, replyTo: replyTo);
    _attempt = attempt;
    final repo = ref.read(postRepositoryProvider);
    Future<void> add(String? to) => repo.addReply(
      id: attempt.id,
      postId: widget.postId,
      replyTo: to,
      body: body,
    );
    try {
      try {
        // The reply answered (review 50 F2): the server files it under its
        // top-level reply and keeps who was answered.
        await add(replyTo);
      } on SpaceException catch (e) {
        // A server before migration 25 takes answers to top-level replies
        // only: answer that one instead. Nothing was stored, so the same
        // id is still free.
        if (e.failure != SpaceFailure.badInput ||
            target == null ||
            target.top == target.id) {
          rethrow;
        }
        await add(target.top);
      }
      _attempt = null;
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
    // Opening the post sees its latest reply: the card's line is no longer
    // bold (F30).
    final latest = p.latestReply;
    if (latest != null && !ref.read(seenRepliesProvider).contains(latest.id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(seenRepliesProvider.notifier).seen(latest.id);
      });
    }
    final goTo = widget.replyId;
    if (goTo != null && replies != null && !_scrolled) {
      _scrolled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollTo(goTo);
      });
    }
    final all = replies ?? const <PostReply>[];
    final top = [
      for (final r in all)
        if (r.replyTo == null) r,
    ];
    List<PostReply> under(String id) => [
      for (final r in all)
        if (r.replyTo == id) r,
    ];
    // A reply whose top-level reply is gone still shows, at the top level.
    final known = {for (final r in top) r.id};
    final orphans = [
      for (final r in all)
        if (r.replyTo != null && !known.contains(r.replyTo)) r,
    ];
    final names = {for (final r in all) r.authorId: r.authorName};
    final byId = {for (final r in all) r.id: r};

    /// "Replying to {name}" under an answer: the person it answers, or,
    /// before migration 25, the top-level reply's author.
    String? answered(PostReply r) {
      if (r.replyTo == null) return null;
      final person = r.replyToPerson ?? byId[r.replyTo]?.authorId;
      return person == null ? null : names[person];
    }

    void replyTo(PostReply r) => setState(
      () => _replyTo = (
        id: r.id,
        // Filed under its top-level reply: itself, or the one it is under.
        top: known.contains(r.replyTo) ? r.replyTo! : r.id,
        name: r.authorName,
        body: r.body,
      ),
    );

    return Scaffold(
      appBar: AppBar(titleSpacing: 0, title: Text(l10n.postTitle)),
      // The reply box in the body, so it rises with the keyboard.
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
              children: [
                // The same card as on Home.
                // Its replies are listed under it: no reply line (review
                // 54 A2).
                PostCard(
                  post: p,
                  replyLine: false,
                  onChanged: (changed) {
                    ref.read(feedProvider.notifier).replace(changed);
                    ref.invalidate(postProvider(widget.postId));
                  },
                  onGone: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(height: BvReplySpec.sectionTop),
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: BvReplySpec.gap,
                    children: [
                      for (final r in [...top, ...orphans]) ...[
                        _ReplyView(
                          key: _replyKey(r.id),
                          reply: r,
                          answered: answered(r),
                          onReply: () => replyTo(r),
                        ),
                        // Two levels on screen; an answer to an answer sits
                        // here too, with "Replying to" naming the person.
                        for (final child in under(r.id))
                          Padding(
                            padding: const EdgeInsetsDirectional.only(
                              start: BvReplySpec.answerIndent,
                            ),
                            child: _ReplyView(
                              key: _replyKey(child.id),
                              reply: child,
                              answered: answered(child),
                              onReply: () => replyTo(child),
                            ),
                          ),
                      ],
                    ],
                  ),
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

/// A reply as a small slip: the avatar, the name and time on one line,
/// "Replying to …" under them for an answer, the text, then Useful and
/// Reply under it, all starting under the name; ⋯ level with the name.
class _ReplyView extends ConsumerWidget {
  const _ReplyView({
    super.key,
    required this.reply,
    required this.answered,
    required this.onReply,
  });

  final PostReply reply;

  /// The name of the person it answers, or null for a top-level reply.
  final String? answered;
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

    // Your reply: Delete. Someone else's: Report (R1).
    Future<void> menu() async {
      final delete = await showBvSheet<bool>(
        context: context,
        builder: (sheet) => ClipRRect(
          borderRadius: BvRadius.cardAll,
          child: BvListGroup(
            rows: [
              if (mine)
                BvListRow(
                  key: const Key('reply-delete'),
                  leading: const BvRowIcon(BvIcons.delete, destructive: true),
                  title: l10n.postDeleteReply,
                  destructive: true,
                  trailing: const BvRowTrailing.none(),
                  onTap: () => Navigator.of(sheet).pop(true),
                )
              else
                BvListRow(
                  key: const Key('reply-report'),
                  leading: const BvRowIcon(BvIcons.report),
                  title: l10n.replyReport,
                  trailing: const BvRowTrailing.none(),
                  onTap: () => Navigator.of(sheet).pop(false),
                ),
            ],
          ),
        ),
      );
      if (delete == null || !context.mounted) return;
      if (!delete) {
        final container = ProviderScope.containerOf(context, listen: false);
        await startReport(
          context,
          kind: ReportKind.reply,
          id: reply.id,
          onReported: () =>
              container.invalidate(postRepliesProvider(reply.postId)),
        );
        return;
      }
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

    final when = BvTime.of(context).moment(reply.createdAt, now);
    const underName = EdgeInsetsDirectional.only(start: BvReplySpec.indent);

    return BvSlip(
      key: Key('reply-${reply.id}'),
      tear: BvSlipBorder.forId(reply.id).variant,
      // Your own reply: Delete; someone else's: Report.
      menu: BvSlipCornerMenu(
        key: Key('reply-menu-${reply.id}'),
        label: l10n.postReplyMenu,
        onTap: menu,
      ),
      // Level with the name: the avatar's line, or, with "Replying to"
      // under it, the name's own line at the main size.
      menuLine: answered == null
          ? BvHomeSpec.authorAvatar
          : type.labelMd.fontSize! * type.labelMd.height!,
      // Under the actions' 48 row only the card's own 6, as on Home.
      paddingBottom: mine
          ? BvSlipSpec.paddingBottom
          : BvHomeSpec.cardPaddingBottom,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(
            end: BvSlipCornerMenu.reserve,
          ),
          child: Row(
            spacing: BvSpace.s8,
            children: [
              BvAvatar(
                name: reply.authorName,
                size: BvAvatarSize.xsm,
                tint: BvAvatarTints.forId(reply.authorId),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      spacing: BvReplySpec.nameGap,
                      children: [
                        Flexible(
                          child: Text(
                            inOwnDirection(reply.authorName),
                            key: Key('reply-name-${reply.id}'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: type.labelMd.copyWith(
                              color: BvColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          when,
                          key: Key('reply-time-${reply.id}'),
                          style: type.metadata.copyWith(
                            color: BvColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    if (answered != null)
                      Text(
                        l10n.postReplyingTo(inOwnDirection(answered!)),
                        key: Key('reply-to-${reply.id}'),
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
        // Every reply's text is as wide as the others', in its own
        // language's direction.
        Padding(
          padding: underName,
          child: Text(
            reply.body,
            key: Key('reply-body-${reply.id}'),
            textDirection: directionOf(reply.body),
            textAlign: TextAlign.start,
            style: type.bodyMd,
          ),
        ),
        // Each in its own 48 × 48 touch area. None on your own reply: only
        // its ⋯ (F31).
        if (!mine)
          Padding(
            padding: underName,
            child: SizedBox(
              height: BvSize.touchMin,
              child: Row(
                spacing: BvReplySpec.actionsGap,
                children: [
                  _ReplyAction(
                    key: Key('reply-useful-${reply.id}'),
                    label: l10n.postUseful,
                    active: reply.myUseful,
                    onTap: useful,
                  ),
                  _ReplyAction(
                    key: Key('reply-reply-${reply.id}'),
                    label: l10n.postReply,
                    onTap: onReply,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Useful or Reply under a reply's text: the word at the main size, in a
/// 48 × 48 touch area (review 54 A2).
class _ReplyAction extends StatelessWidget {
  const _ReplyAction({
    super.key,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return Semantics(
      button: true,
      selected: active,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: BvSize.touchMin,
            minHeight: BvSize.touchMin,
          ),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style: type.labelMd.copyWith(
                color: active ? BvColors.textAction : BvColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The reply bar, in the Daybook post bar's style: your avatar, the field,
/// and Send on the end side; H17's "Replying to {name}" above it.
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
  final _ReplyTarget? replyTo;
  final bool sending;
  final VoidCallback onChanged;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final me = ref.watch(myProfileProvider).value;
    final canSend = controller.text.trim().isNotEmpty && !sending;
    final r = replyTo;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: BvColors.surfaceApp,
        border: Border(
          top: BorderSide(
            color: BvColors.borderSubtle,
            width: BvPostBarSpec.border,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: BvPostBarSpec.paddingHorizontal,
            vertical: BvPostBarSpec.paddingVertical,
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
                spacing: BvPostBarSpec.gap,
                children: [
                  BvAvatar(
                    key: const Key('post-reply-avatar'),
                    name: me == null ? '' : '${me.firstName} ${me.lastName}',
                    size: BvAvatarSize.sm,
                    tint: me == null ? null : BvAvatarTints.forId(me.id),
                  ),
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: BvPostBarSpec.notepadHeight,
                      ),
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: BvPostBarSpec.notepadPadding,
                      ),
                      alignment: AlignmentDirectional.centerStart,
                      decoration: const BoxDecoration(
                        color: BvColors.surfaceSubtle,
                        borderRadius: BvPostBarSpec.notepadRadius,
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
                          hintText: l10n.postWriteReply,
                          hintStyle: type.bodyMd.copyWith(
                            color: BvColors.textSecondary,
                          ),
                        ),
                        onChanged: (_) => onChanged(),
                      ),
                    ),
                  ),
                  // Send on the end side, as the post bar's camera.
                  Semantics(
                    button: true,
                    enabled: canSend,
                    label: l10n.postSendReply,
                    excludeSemantics: true,
                    child: Material(
                      key: const Key('post-reply-send'),
                      color: canSend
                          ? BvColors.actionPrimary
                          : BvColors.surfaceSubtle,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: canSend ? onSend : null,
                        child: SizedBox.square(
                          dimension: BvReplySpec.sendSize,
                          child: Icon(
                            BvIcons.send,
                            size: BvReplySpec.sendIcon,
                            color: canSend
                                ? BvColors.iconInverse
                                : BvColors.iconSecondary,
                          ),
                        ),
                      ),
                    ),
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
