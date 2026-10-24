import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/messages_specs.dart';
import '../../core/l10n/bidi.dart';
import '../../core/l10n/bv_time.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/chat.dart';
import '../../data/models/dm.dart';
import '../../data/models/space.dart';
import '../../data/models/work_item.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/space_repository.dart';
import '../../data/repositories/work_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_avatar.dart';
import '../../shared/widgets/bv_give_to_picker.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../../shared/widgets/bv_text_field.dart';
import '../entry/entry_state.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../profile/widgets/profile_parts.dart';
import '../spaces/former_member.dart';
import 'thread_screen.dart' show ChatActionRow;
import '../../core/routing/open_thread.dart';

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
      ChatKind.report => l10n.weekReportTitle,
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
    final spaceName = inOwnDirection(space.name);
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => ref.refresh(spaceThreadsProvider(space.id).future),
          child: ListView(
            key: const Key('chat-threads'),
            padding: const EdgeInsetsDirectional.only(
              bottom: BvMessagesSpec.fab + 2 * BvMessagesSpec.fabMargin,
            ),
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
                  '${space.iAmAdmin ? l10n.chatThreadsNoteAdmin : l10n.chatThreadsNote} '
                  '${l10n.chatThreadsDmNote(spaceName)}',
                  style: type.bodySm.copyWith(color: BvColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
        // S7 v4 (2480:30957): New chat, at the end over the list.
        PositionedDirectional(
          end: BvMessagesSpec.fabMargin,
          bottom: BvMessagesSpec.fabMargin,
          child: SizedBox(
            height: BvMessagesSpec.fab,
            child: FloatingActionButton.extended(
              key: const Key('chat-new'),
              heroTag: null,
              backgroundColor: BvColors.actionPrimary,
              foregroundColor: BvColors.actionPrimaryForeground,
              elevation: 0,
              shape: const StadiumBorder(),
              icon: const Icon(BvIcons.add),
              label: Text(
                l10n.chatNewChat,
                style: type.titleMd.copyWith(
                  color: BvColors.actionPrimaryForeground,
                ),
              ),
              onPressed: () => unawaited(newChat(context, ref, space)),
            ),
          ),
        ),
      ],
    );
  }
}

/// S7-N v4 (2480:31036): a new group (a Team; the Space admin only, as
/// the server allows) or a message to one person, which opens in
/// Messages. Work is given in the Work tab.
Future<void> newChat(
  BuildContext context,
  WidgetRef ref,
  SpaceDetail space,
) async {
  final l10n = AppLocalizations.of(context);
  final spaceName = inOwnDirection(space.name);
  final choice = await showBvSheet<int>(
    context: context,
    title: l10n.chatNewChat,
    builder: (sheet) => Column(
      key: const Key('chat-new-sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (space.iAmAdmin)
          ChatActionRow(
            key: const Key('chat-new-group'),
            icon: BvIcons.team,
            label: l10n.chatNewGroup,
            help: l10n.chatNewGroupNote,
            onTap: () => Navigator.of(sheet).pop(0),
          ),
        ChatActionRow(
          key: const Key('chat-new-person'),
          icon: BvIcons.person,
          label: l10n.chatOnePerson,
          help: l10n.chatOnePersonNote(spaceName),
          onTap: () => Navigator.of(sheet).pop(1),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(top: BvSpace.s12),
          child: Text(
            l10n.chatWorkNote,
            style: BvType.of(
              context,
            ).metadata.copyWith(color: BvColors.textSecondary),
          ),
        ),
      ],
    ),
  );
  if (!context.mounted || choice == null) return;
  if (choice == 0) {
    await context.push(AppRoutes.spaceTeamNew(space.id));
    return;
  }
  // One person of this Space, then their conversation in Messages.
  final me = ref.read(authUserIdProvider).value;
  final people = await ref.read(spacePeopleProvider(space.id).future);
  if (!context.mounted) return;
  final picked = await showBvSheet<BvGiveToPerson>(
    context: context,
    title: l10n.chatOnePerson,
    builder: (sheet) => BvGiveToPicker(
      key: const Key('chat-new-person-picker'),
      inSheet: true,
      people: [
        for (final m in people.members)
          if (m.person.id != me)
            BvGiveToPerson(
              id: m.person.id,
              name: m.person.fullName,
              team: people.teamsOf(m.person.id).firstOrNull?.name,
            ),
      ],
      currentOwnerId: null,
      currentLabel: '',
      searchPlaceholder: l10n.messagesSearch,
      onPick: (p) => Navigator.of(sheet).pop(p),
    ),
  );
  if (!context.mounted || picked == null) return;
  await openDmThread(
    GoRouter.of(context),
    AppRoutes.messagesWith(picked.id),
    extra: DmPerson(id: picked.id, name: picked.name),
  );
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
        await openSpaceThread(GoRouter.of(context), space.id, thread.id);
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
                      // A dot, as in Messages: never a number (rule 3).
                      if (unread)
                        Semantics(
                          label: l10n.messagesUnread,
                          child: Container(
                            key: Key('chat-unread-${thread.id}'),
                            width: BvMessagesSpec.dot,
                            height: BvMessagesSpec.dot,
                            decoration: const BoxDecoration(
                              color: BvColors.actionPrimary,
                              shape: BoxShape.circle,
                            ),
                          ),
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
