import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/chat.dart';
import '../../data/models/space.dart';
import '../../data/models/work_item.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/space_repository.dart';
import '../../data/repositories/work_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_avatar.dart';
import '../../shared/widgets/bv_dialog.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../../shared/widgets/bv_text_field.dart';
import '../entry/entry_state.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../profile/widgets/profile_parts.dart';
import '../spaces/space_errors.dart';
import '../work/work_item_card.dart';
import 'chat_state.dart';
import 'chat_tab.dart';

/// S8k · the Everyone thread, S9k · a Team thread: messages live, replies,
/// work item cards, and messages kept on the phone after a weak signal.
class ThreadScreen extends ConsumerStatefulWidget {
  const ThreadScreen({
    super.key,
    required this.spaceId,
    required this.threadId,
  });

  final String spaceId;
  final String threadId;

  @override
  ConsumerState<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends ConsumerState<ThreadScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  late final ChatRepository _repo = ref.read(chatRepositoryProvider);
  ChatReply? _replyTo;
  String? _newest;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadOlder);
    unawaited(_markRead());
  }

  @override
  void dispose() {
    // Leaving counts as read too.
    unawaited(_markRead());
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _markRead() async {
    try {
      await _repo.markRead(widget.threadId);
    } on SpaceException {
      // Read state catches up next time.
    }
  }

  // The list is reversed: the oldest messages are at the far end.
  void _maybeLoadOlder() {
    if (_scroll.position.extentAfter < BvSpace.s64 * 4) {
      unawaited(
        ref.read(threadMessagesProvider(widget.threadId).notifier).loadOlder(),
      );
    }
  }

  void _toast(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.isEmpty) return;
    final m = PendingMessage(
      id: newUuid(),
      threadId: widget.threadId,
      body: body,
      createdAt: ref.read(clockProvider)(),
      reply: _replyTo,
    );
    _text.clear();
    setState(() => _replyTo = null);
    await _deliver(() => ref.read(chatOutboxProvider.notifier).send(m));
  }

  Future<void> _retry(String id) =>
      _deliver(() => ref.read(chatOutboxProvider.notifier).retry(id));

  Future<void> _deliver(Future<bool> Function() run) async {
    try {
      await run();
    } on SpaceException catch (e) {
      if (mounted) showSpaceError(context, e);
    }
  }

  Future<void> _actions(ChatMessage m, {required bool canDelete}) async {
    final l10n = AppLocalizations.of(context);
    FocusManager.instance.primaryFocus?.unfocus();
    final choice = await showBvSheet<_Action>(
      context: context,
      builder: (context) => Column(
        key: const Key('chat-actions'),
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionRow(
            key: const Key('chat-action-reply'),
            icon: BvIcons.chat,
            label: l10n.chatReply,
            onTap: () => Navigator.of(context).pop(_Action.reply),
          ),
          _ActionRow(
            key: const Key('chat-action-copy'),
            icon: BvIcons.copy,
            label: l10n.chatCopy,
            onTap: () => Navigator.of(context).pop(_Action.copy),
          ),
          if (canDelete)
            _ActionRow(
              key: const Key('chat-action-delete'),
              icon: BvIcons.delete,
              label: l10n.chatDelete,
              destructive: true,
              onTap: () => Navigator.of(context).pop(_Action.delete),
            ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case _Action.reply:
        setState(
          () => _replyTo = ChatReply(
            id: m.id,
            kind: m.kind,
            authorName: m.authorName,
            body: m.body,
          ),
        );
      case _Action.copy:
        await Clipboard.setData(ClipboardData(text: m.body ?? ''));
        if (mounted) _toast(l10n.chatCopied);
      case _Action.delete:
        final yes = await showBvDialog(
          context: context,
          title: l10n.chatDeleteTitle,
          body: l10n.chatDeleteBody,
          cancelLabel: l10n.commonCancel,
          confirmLabel: l10n.chatDeleteConfirm,
          destructive: true,
        );
        if (!yes || !mounted) return;
        try {
          await _repo.delete(m.id);
          await ref
              .read(threadMessagesProvider(widget.threadId).notifier)
              .refresh(m.id);
        } on SpaceException catch (e) {
          if (mounted) showSpaceError(context, e);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final space = ref.watch(spaceDetailProvider(widget.spaceId)).value;
    final thread = ref
        .watch(spaceThreadsProvider(widget.spaceId))
        .value
        ?.where((t) => t.id == widget.threadId)
        .firstOrNull;
    final messages = ref.watch(threadMessagesProvider(widget.threadId));
    final pending = ref
        .watch(chatOutboxProvider)
        .where((p) => p.threadId == widget.threadId)
        .toList();
    final me = ref.watch(authUserIdProvider).value;

    // A new message while the thread is open is read at once.
    final newest = messages.value?.firstOrNull?.id;
    if (newest != null && newest != _newest) {
      _newest = newest;
      unawaited(_markRead());
    }

    final name = thread == null ? '' : threadName(l10n, thread);
    final shown = messages.value ?? const <ChatMessage>[];
    final sentIds = {for (final m in shown) m.id};
    // Newest first, to match the reversed list.
    final entries = <_Entry>[
      for (final p in pending.reversed)
        if (!sentIds.contains(p.id)) _Entry.pending(p),
      for (final m in shown) _Entry.message(m),
    ];

    // One full card per item: its newest step. Older steps are a line.
    final latestCards = <String>{};
    final seenItems = <String>{};
    for (final e in entries) {
      final item = e.message?.workItemId;
      if (e.isCard && item != null && seenItems.add(item)) {
        latestCards.add(e.message!.id);
      }
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: type.titleMd,
            ),
            if (space != null && thread != null)
              Text(
                joinMeta([
                  space.name,
                  thread.isEveryone ? l10n.chatEveryone : l10n.chatTeam,
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: type.bodySm.copyWith(color: BvColors.textSecondary),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (thread != null && !thread.isEveryone)
            Container(
              key: const Key('chat-team-privacy'),
              width: double.infinity,
              color: BvColors.surfaceSubtle,
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: BvSpace.gutter,
                vertical: BvSpace.s8,
              ),
              child: Text(
                l10n.chatTeamPrivacy(name),
                style: type.bodySm.copyWith(color: BvColors.textSecondary),
              ),
            ),
          Expanded(
            child: messages.hasValue || pending.isNotEmpty
                ? entries.isEmpty
                      ? Center(child: EmptyNote(l10n.chatNoMessages))
                      : ListView.builder(
                          key: const Key('chat-messages'),
                          controller: _scroll,
                          reverse: true,
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: BvSpace.gutter,
                            vertical: BvSpace.s12,
                          ),
                          itemCount: entries.length,
                          itemBuilder: (context, i) => _EntryView(
                            spaceId: widget.spaceId,
                            entry: entries[i],
                            older: i + 1 < entries.length
                                ? entries[i + 1]
                                : null,
                            newer: i > 0 ? entries[i - 1] : null,
                            latestCards: latestCards,
                            me: me,
                            iAmAdmin: space?.iAmAdmin ?? false,
                            onActions: _actions,
                            onRetry: _retry,
                          ),
                        )
                : messages.hasError
                ? Center(child: EmptyNote(l10n.errorGeneric))
                : const Center(child: CircularProgressIndicator()),
          ),
          if (_replyTo != null)
            _ReplyBanner(
              reply: _replyTo!,
              onCancel: () => setState(() => _replyTo = null),
            ),
          _Composer(
            controller: _text,
            onChanged: () => setState(() {}),
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

enum _Action { reply, copy, delete }

/// A message from the server, or one still on this phone.
class _Entry {
  _Entry.message(ChatMessage this.message) : pending = null;
  _Entry.pending(PendingMessage this.pending) : message = null;

  final ChatMessage? message;
  final PendingMessage? pending;

  DateTime get at => message?.createdAt ?? pending!.createdAt;
  String? authorId(String? me) => message == null ? me : message!.authorId;
  bool get isCard => message?.kind == ChatKind.workItem;
}

class _EntryView extends ConsumerWidget {
  const _EntryView({
    required this.spaceId,
    required this.entry,
    required this.older,
    required this.newer,
    required this.latestCards,
    required this.me,
    required this.iAmAdmin,
    required this.onActions,
    required this.onRetry,
  });

  final String spaceId;
  final _Entry entry;

  /// The messages above and below this one, if any.
  final _Entry? older;
  final _Entry? newer;

  /// Cards that show the whole item (its newest step in the thread).
  final Set<String> latestCards;
  final String? me;
  final bool iAmAdmin;
  final Future<void> Function(ChatMessage m, {required bool canDelete})
  onActions;
  final Future<void> Function(String id) onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final now = ref.watch(clockProvider)();
    final locale = Localizations.localeOf(context).toLanguageTag();
    String time(DateTime t) => BvWesternDigitsFormatter.normalise(
      DateFormat.Hm(locale).format(t.toLocal()),
    );

    final day = DateUtils.dateOnly(entry.at.toLocal());
    final newDay =
        older == null || DateUtils.dateOnly(older!.at.toLocal()) != day;
    final author = entry.authorId(me);
    // A new run: another person, a card, or a new day above.
    final startsRun =
        newDay ||
        older!.isCard ||
        entry.isCard ||
        older!.authorId(me) != author;
    // The run ends here when the next message is someone else's, a card,
    // or on another day: the avatar goes beside its last bubble.
    final endsRun =
        newer == null ||
        newer!.isCard ||
        newer!.authorId(me) != author ||
        DateUtils.dateOnly(newer!.at.toLocal()) != day;

    final Widget body;
    final m = entry.message;
    if (m != null && m.kind == ChatKind.workItem) {
      body = _CardEntry(
        spaceId: spaceId,
        message: m,
        time: time(m.createdAt),
        full: latestCards.contains(m.id),
      );
    } else {
      final mine = author != null && author == me;
      body = _Bubble(
        mine: mine,
        name: startsRun && !mine ? (m?.authorName ?? l10n.workSomeone) : null,
        avatarName: endsRun && !mine
            ? (m?.authorName ?? l10n.workSomeone)
            : null,
        text: m == null
            ? entry.pending!.body
            : m.deleted
            ? l10n.chatDeleted
            : m.body ?? '',
        deleted: m?.deleted ?? false,
        reply: m?.reply ?? entry.pending?.reply,
        footer: m != null
            ? Text(
                time(m.createdAt),
                style: type.metadata.copyWith(color: BvColors.textSecondary),
              )
            : _PendingFooter(pending: entry.pending!, onRetry: onRetry),
        onLongPress: m == null || m.deleted
            ? null
            : () => onActions(m, canDelete: mine || iAmAdmin),
        id: m?.id ?? entry.pending!.id,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (newDay)
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              vertical: BvSpace.s12,
            ),
            child: Text(
              _dayLabel(l10n, locale, day, DateUtils.dateOnly(now)),
              textAlign: TextAlign.center,
              style: type.labelSm.copyWith(color: BvColors.textSecondary),
            ),
          )
        else
          SizedBox(height: startsRun ? BvChatSpec.groupGap : BvChatSpec.runGap),
        body,
      ],
    );
  }

  static String _dayLabel(
    AppLocalizations l10n,
    String locale,
    DateTime day,
    DateTime today,
  ) {
    if (day == today) return l10n.chatToday;
    if (today.difference(day).inDays == 1) return l10n.chatYesterday;
    return BvWesternDigitsFormatter.normalise(
      DateFormat('EEE d MMM', locale).format(day),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.id,
    required this.mine,
    required this.name,
    required this.avatarName,
    required this.text,
    required this.deleted,
    required this.reply,
    required this.footer,
    required this.onLongPress,
  });

  final String id;
  final bool mine;

  /// Above the first message of a run from someone else.
  final String? name;

  /// Beside the last message of that run.
  final String? avatarName;
  final String text;
  final bool deleted;
  final ChatReply? reply;
  final Widget footer;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final width = MediaQuery.sizeOf(context).width * BvChatSpec.bubbleMaxWidth;
    final bubble = GestureDetector(
      key: Key('chat-message-$id'),
      onLongPress: onLongPress,
      child: Container(
        constraints: BoxConstraints(maxWidth: width),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: BvChatSpec.bubblePaddingHorizontal,
          vertical: BvChatSpec.bubblePaddingVertical,
        ),
        decoration: BoxDecoration(
          color: mine ? BvColors.surfaceBrandSoft : BvColors.surfaceElevated,
          borderRadius: BvChatSpec.bubbleRadius,
          border: mine
              ? null
              : Border.all(color: BvColors.borderDefault, width: BvStroke.thin),
        ),
        // As wide as its longest line, so short messages stay small; the
        // time then sits at the end of that width.
        child: IntrinsicWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            spacing: BvSpace.s4,
            children: [
              if (reply != null) _Quote(reply: reply!),
              Text(
                text,
                // In the language it was written in, not the app's.
                textDirection: deleted ? null : directionOf(text),
                style: deleted
                    ? type.bodyMd.copyWith(
                        color: BvColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      )
                    : type.bodyMd,
              ),
              Align(alignment: AlignmentDirectional.centerEnd, child: footer),
            ],
          ),
        ),
      ),
    );

    if (mine) {
      return Align(alignment: AlignmentDirectional.centerEnd, child: bubble);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: BvSpace.s4,
      children: [
        if (name != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: BvChatSpec.avatar + BvChatSpec.avatarGap,
            ),
            child: Text(
              name!,
              style: type.labelSm.copyWith(color: BvColors.textSecondary),
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          spacing: BvChatSpec.avatarGap,
          children: [
            if (avatarName != null)
              BvAvatar(name: avatarName!, size: BvAvatarSize.sm)
            else
              const SizedBox(width: BvChatSpec.avatar),
            Flexible(child: bubble),
          ],
        ),
      ],
    );
  }
}

/// The message a reply answers, quoted at the top of the bubble.
class _Quote extends StatelessWidget {
  const _Quote({required this.reply});

  final ChatReply reply;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    return Container(
      key: const Key('chat-quote'),
      padding: const EdgeInsetsDirectional.only(start: BvSpace.s8),
      decoration: const BoxDecoration(
        border: BorderDirectional(
          start: BorderSide(
            color: BvColors.textAction,
            width: BvChatSpec.replyBar,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            reply.authorName ?? l10n.workSomeone,
            style: type.labelSm.copyWith(color: BvColors.textAction),
          ),
          Text(
            reply.deleted
                ? l10n.chatDeleted
                : inOwnDirection(chatSnippet(l10n, reply.kind, reply.body)),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: type.bodySm.copyWith(color: BvColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// "Sending…", or "Not sent · Retry".
class _PendingFooter extends StatelessWidget {
  const _PendingFooter({required this.pending, required this.onRetry});

  final PendingMessage pending;
  final Future<void> Function(String id) onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    if (!pending.failed) {
      return Text(
        l10n.chatSending,
        style: type.metadata.copyWith(color: BvColors.textSecondary),
      );
    }
    // Wraps rather than overflows in a narrow bubble.
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '${l10n.chatNotSent} · ',
          style: type.metadata.copyWith(color: BvColors.textDestructive),
        ),
        GestureDetector(
          key: Key('chat-retry-${pending.id}'),
          onTap: () => onRetry(pending.id),
          child: Text(
            l10n.chatRetry,
            style: type.labelSm.copyWith(color: BvColors.textAction),
          ),
        ),
      ],
    );
  }
}

/// A work item step, posted by the server: who did what, then the item's
/// card as it is now (S8k).
class _CardEntry extends ConsumerWidget {
  const _CardEntry({
    required this.spaceId,
    required this.message,
    required this.time,
    required this.full,
  });

  final String spaceId;
  final ChatMessage message;
  final String time;

  /// False for an older step of an item shown further down: one line.
  final bool full;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final items = ref.watch(workItemsProvider(spaceId)).value;
    final needs =
        ref.watch(workNeedsProvider(spaceId)).value ?? const WorkNeeds();
    final me = ref.watch(authUserIdProvider).value;
    final item = items?.where((i) => i.id == message.workItemId).firstOrNull;
    // Always the name: "You" doesn't fit the Arabic noun forms.
    final who = message.authorName ?? l10n.workSomeone;
    final line = switch (message.eventKind) {
      WorkEventKind.done => l10n.chatCardDone(who),
      WorkEventKind.checked => l10n.chatCardChecked(who),
      WorkEventKind.sentBack => l10n.chatCardSentBack(who),
      WorkEventKind.reassigned => l10n.chatCardReassigned(who),
      _ => l10n.chatCardRaised(who),
    };

    if (!full) {
      return InkWell(
        key: Key('chat-card-${message.id}'),
        onTap: item == null
            ? null
            : () => context.push(AppRoutes.workItem(spaceId, item.id)),
        child: Text(
          // The reference first: two Latin parts side by side would merge
          // and swap places in a right-to-left line.
          joinMeta([?item?.ref, line, time]),
          style: type.bodySm.copyWith(color: BvColors.textSecondary),
        ),
      );
    }
    return Column(
      key: Key('chat-card-${message.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BvSpace.s8,
      children: [
        Text(
          joinMeta([line, time]),
          style: type.bodySm.copyWith(color: BvColors.textSecondary),
        ),
        if (item != null)
          WorkItemCard(item: item, needs: needs, me: me)
        else if (items != null)
          EmptyNote(l10n.chatItemGone),
      ],
    );
  }
}

class _ReplyBanner extends StatelessWidget {
  const _ReplyBanner({required this.reply, required this.onCancel});

  final ChatReply reply;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    return Container(
      key: const Key('chat-replying'),
      color: BvColors.surfaceElevated,
      padding: const EdgeInsetsDirectional.only(
        start: BvSpace.gutter,
        top: BvSpace.s8,
      ),
      child: Row(
        spacing: BvSpace.s8,
        children: [
          const Icon(
            BvIcons.reply,
            size: BvSize.iconMd,
            color: BvColors.iconAction,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.chatReplyingTo(reply.authorName ?? l10n.workSomeone),
                  style: type.labelSm.copyWith(color: BvColors.textAction),
                ),
                Text(
                  inOwnDirection(chatSnippet(l10n, reply.kind, reply.body)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.bodySm.copyWith(color: BvColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            key: const Key('chat-cancel-reply'),
            tooltip: l10n.chatCancelReply,
            icon: const Icon(BvIcons.close, color: BvColors.iconSecondary),
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

/// The message box: one pill that grows, with Send inside when there is
/// text. Photos and voice notes come in parts 2 and 3.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.onChanged,
    required this.onSend,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final hasText = controller.text.trim().isNotEmpty;
    return Container(
      decoration: const BoxDecoration(
        color: BvColors.surfaceElevated,
        border: Border(
          top: BorderSide(color: BvColors.borderDefault, width: BvStroke.thin),
        ),
      ),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: BvSpace.gutter,
        vertical: BvSpace.s8,
      ),
      child: SafeArea(
        top: false,
        child: Container(
          key: const Key('chat-composer'),
          constraints: const BoxConstraints(minHeight: BvSize.controlMd),
          padding: const EdgeInsetsDirectional.only(
            start: BvSpace.s16,
            end: BvSpace.s4,
          ),
          decoration: const BoxDecoration(
            color: BvColors.surfaceSubtle,
            borderRadius: BvRadius.roundAll,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('chat-input'),
                  controller: controller,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 4000,
                  textCapitalization: TextCapitalization.sentences,
                  style: type.bodyMd,
                  // The pill is the field: no theme border or padding.
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
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    hintText: l10n.chatMessageHint,
                    hintStyle: type.bodyMd.copyWith(
                      color: BvColors.textSecondary,
                    ),
                  ),
                  onChanged: (_) => onChanged(),
                ),
              ),
              if (hasText)
                IconButton(
                  key: const Key('chat-send'),
                  tooltip: l10n.chatSend,
                  icon: const Icon(BvIcons.send, color: BvColors.iconAction),
                  onPressed: onSend,
                )
              else
                const SizedBox(height: BvSize.controlMd),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final color = destructive ? BvColors.textDestructive : BvColors.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: BvSpace.s12),
        child: Row(
          spacing: BvSpace.s16,
          children: [
            Container(
              width: BvSize.avatarMd,
              height: BvSize.avatarMd,
              decoration: const BoxDecoration(
                color: BvColors.surfaceBrandSoft,
                borderRadius: BvRadius.controlAll,
              ),
              child: Icon(
                icon,
                size: BvSize.iconMd,
                color: destructive
                    ? BvColors.textDestructive
                    : BvColors.iconPrimary,
              ),
            ),
            Text(label, style: type.bodyLg.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
