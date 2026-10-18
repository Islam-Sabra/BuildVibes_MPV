import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart';
import '../../core/l10n/bv_time.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/chat.dart';
import '../../data/models/space.dart';
import '../../data/models/work_item.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/space_repository.dart';
import '../../data/repositories/work_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_avatar.dart';
import '../../shared/widgets/bv_badge.dart';
import '../../shared/widgets/bv_text_field.dart';
import '../entry/entry_state.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../profile/widgets/profile_parts.dart';
import '../spaces/former_member.dart';

/// A thread's name: "Everyone" or the Team's.
String threadName(AppLocalizations l10n, ChatThread t) =>
    t.isEveryone ? l10n.chatEveryone : (t.teamName ?? l10n.chatTeam);

/// What a message is, in one line: its text, or "Photo", "Voice note"…
String chatSnippet(AppLocalizations l10n, ChatKind? kind, String? body) =>
    switch (kind) {
      ChatKind.photo when (body ?? '').isEmpty => l10n.chatPhoto,
      ChatKind.file when (body ?? '').isEmpty => l10n.chatFile,
      ChatKind.voice => l10n.chatVoice,
      ChatKind.workItem => l10n.chatWorkItemUpdate,
      _ => body ?? '',
    };

/// S7k · Space chat: Everyone first, then the Teams you may see, each with
/// its last message, its time and what you haven't read.
class ChatTab extends ConsumerWidget {
  const ChatTab({super.key, required this.space});

  final SpaceDetail space;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final threads = ref.watch(spaceThreadsProvider(space.id));
    final list = threads.value;

    if (list == null) {
      return threads.hasError
          ? Padding(
              padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
              child: EmptyNote(l10n.errorGeneric),
            )
          : const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: () => ref.refresh(spaceThreadsProvider(space.id).future),
      child: ListView(
        key: const Key('chat-threads'),
        children: [
          ColoredBox(
            color: BvColors.surfaceElevated,
            child: Column(
              children: [
                for (final t in list) _ThreadRow(space: space, thread: t),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
            child: Text(
              space.iAmAdmin ? l10n.chatThreadsNoteAdmin : l10n.chatThreadsNote,
              style: type.bodySm.copyWith(color: BvColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreadRow extends ConsumerWidget {
  const _ThreadRow({required this.space, required this.thread});

  final SpaceDetail space;
  final ChatThread thread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final me = ref.watch(authUserIdProvider).value;
    final people = ref.watch(spacePeopleProvider(space.id)).value;
    final now = ref.watch(clockProvider)();
    final name = threadName(l10n, thread);
    final unread = thread.unread > 0;

    // A card as the last message: what happened, to which item.
    final card =
        thread.lastKind == ChatKind.workItem && thread.lastMessageId != null
        ? ref.watch(chatMessageProvider(thread.lastMessageId!)).value
        : null;
    final cardRef = card == null
        ? null
        : ref
              .watch(workItemsProvider(space.id))
              .value
              ?.where((i) => i.id == card.workItemId)
              .firstOrNull
              ?.ref;

    String? cardLine() {
      if (card == null || cardRef == null) return null;
      final who = personFirstName(l10n, card.authorName);
      return switch (card.eventKind) {
        WorkEventKind.done => l10n.chatLastDone(who, cardRef),
        WorkEventKind.checked => l10n.chatLastChecked(who, cardRef),
        WorkEventKind.sentBack => l10n.chatLastSentBack(who, cardRef),
        WorkEventKind.reassigned => l10n.chatLastReassigned(who, cardRef),
        _ => l10n.chatLastRaised(who, cardRef),
      };
    }

    String last() {
      if (thread.lastKind == null) return l10n.chatNoMessages;
      final text = thread.lastDeleted
          ? l10n.chatDeleted
          : chatSnippet(l10n, thread.lastKind, thread.lastBody);
      // Cards say what happened; messages say who wrote them.
      if (thread.lastKind == ChatKind.workItem) return cardLine() ?? text;
      final author = thread.lastAuthorId == null
          ? null
          : thread.lastAuthorId == me
          ? l10n.chatYou
          : people?.member(thread.lastAuthorId!)?.person.firstName;
      // The text keeps its own direction (its full stop stays at its end);
      // the name follows the app's, so it comes first in both languages.
      return author == null
          ? inOwnDirection(text)
          : l10n.chatLastLine(author, inOwnDirection(text));
    }

    return InkWell(
      key: Key('chat-thread-${thread.id}'),
      onTap: () async {
        await context.push(AppRoutes.spaceThread(space.id, thread.id));
        ref.invalidate(spaceThreadsProvider(space.id));
      },
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: BvSpace.gutter,
          vertical: BvSpace.s12,
        ),
        child: Row(
          spacing: BvSpace.s12,
          children: [
            // Everyone is a group, not initials ("الجميع" reads oddly).
            if (thread.isEveryone)
              const _GroupTile()
            else
              BvAvatar(
                name: name,
                company: true,
                twoLetters: true,
                size: BvAvatarSize.lg,
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: BvSpace.s2,
                children: [
                  Row(
                    spacing: BvSpace.s8,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: type.titleMd,
                        ),
                      ),
                      if (thread.lastAt != null)
                        Text(
                          listTime(context, l10n, thread.lastAt!, now),
                          style: type.metadata.copyWith(
                            color: unread
                                ? BvColors.textAction
                                : BvColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                  Row(
                    spacing: BvSpace.s8,
                    children: [
                      Expanded(
                        child: Text(
                          last(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: type.bodySm.copyWith(
                            color: unread
                                ? BvColors.textPrimary
                                : BvColors.textSecondary,
                          ),
                        ),
                      ),
                      if (unread)
                        BvBadge(
                          key: Key('chat-unread-${thread.id}'),
                          label: '${thread.unread}',
                          tone: BvBadgeTone.action,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Everyone thread's tile: the group icon on the avatar tile.
class _GroupTile extends StatelessWidget {
  const _GroupTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('chat-everyone-tile'),
      width: BvAvatarSpec.lg,
      height: BvAvatarSpec.lg,
      decoration: BoxDecoration(
        color: BvColors.surfaceSubtle,
        borderRadius: BvAvatar.companyRadius(BvAvatarSize.lg),
        border: Border.all(color: BvColors.borderDefault, width: BvStroke.thin),
      ),
      child: const Icon(
        BvIcons.team,
        size: BvSize.iconLg,
        color: BvColors.iconPrimary,
      ),
    );
  }
}

/// Today: the time. Yesterday: "Yesterday". Older: the day.
String listTime(
  BuildContext context,
  AppLocalizations l10n,
  DateTime at,
  DateTime now,
) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final local = at.toLocal();
  final today = DateUtils.dateOnly(now);
  final day = DateUtils.dateOnly(local);
  if (day == today) return BvTime.of(context).clock(at);
  if (today.difference(day).inDays == 1) return l10n.chatYesterday;
  return BvWesternDigitsFormatter.normalise(
    DateFormat('d MMM', locale).format(local),
  );
}
