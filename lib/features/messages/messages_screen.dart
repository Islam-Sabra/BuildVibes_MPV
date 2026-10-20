import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/messages_specs.dart';
import '../../core/l10n/bidi.dart';
import '../../core/l10n/bv_time.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/chat.dart' show ChatKind;
import '../../data/models/dm.dart';
import '../../data/repositories/dm_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_avatar.dart';
import '../../shared/widgets/bv_search_field.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../profile/widgets/profile_parts.dart';
import '../spaces/former_member.dart';

/// Messages (DM1 2560:35524, AR 2564:745): the newest Message request on
/// top, then the threads, Today and Earlier. An unread thread is a white
/// card with its time in the action colour and a dot: never a number
/// (rule 3). Search finds a name; + finds someone new (people search).
class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  var _searching = false;
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final inbox = ref.watch(dmInboxProvider);
    final now = ref.watch(clockProvider)();
    final q = _query.text.trim().toLowerCase();
    bool matches(DmRow r) =>
        q.isEmpty || (r.person.name ?? '').toLowerCase().contains(q);

    Widget body(DmInbox box) {
      final today = DateTime(now.year, now.month, now.day);
      final rows = [
        for (final r in box.threads)
          if (matches(r)) r,
      ];
      final todays = [
        for (final r in rows)
          if (!r.lastMessageAt.toLocal().isBefore(today)) r,
      ];
      final earlier = [
        for (final r in rows)
          if (r.lastMessageAt.toLocal().isBefore(today)) r,
      ];
      final request = box.newestRequest;
      if (rows.isEmpty && request == null) {
        return Padding(
          padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
          child: EmptyNote(l10n.messagesEmpty),
        );
      }
      Widget group(String label) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          BvSpace.gutter + BvMessagesSpec.listInset,
          BvMessagesSpec.groupPaddingTop,
          BvSpace.gutter,
          BvMessagesSpec.groupPaddingBottom,
        ),
        child: Text(
          label,
          style: type.metadata.copyWith(color: BvColors.textSecondary),
        ),
      );
      return ListView(
        key: const Key('messages-list'),
        padding: const EdgeInsetsDirectional.only(
          start: BvMessagesSpec.listInset,
          end: BvMessagesSpec.listInset,
          bottom: BvMessagesSpec.fab + 2 * BvMessagesSpec.fabMargin,
        ),
        children: [
          if (request != null && q.isEmpty)
            DmRequestCard(
              row: request,
              onTap: () => context.push(AppRoutes.messagesRequests),
            ),
          if (todays.isNotEmpty) ...[
            group(l10n.messagesToday),
            for (final r in todays) DmListRow(row: r, now: now),
          ],
          if (earlier.isNotEmpty) ...[
            group(l10n.messagesEarlier),
            for (final r in earlier) DmListRow(row: r, now: now),
          ],
        ],
      );
    }

    return Scaffold(
      backgroundColor: BvColors.surfaceApp,
      appBar: AppBar(
        backgroundColor: BvColors.surfaceApp,
        title: _searching
            ? BvSearchField(
                key: const Key('messages-search'),
                controller: _query,
                placeholder: l10n.messagesSearch,
                autofocus: true,
                onChanged: (_) => setState(() {}),
              )
            : Text(l10n.messagesTitle, style: type.titleMd),
        actions: [
          IconButton(
            key: const Key('messages-search-toggle'),
            tooltip: _searching ? l10n.commonCancel : l10n.messagesSearch,
            icon: Icon(
              _searching ? BvIcons.close : BvIcons.search,
              color: BvColors.iconPrimary,
            ),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _query.clear();
            }),
          ),
        ],
      ),
      floatingActionButton: SizedBox.square(
        dimension: BvMessagesSpec.fab,
        child: FloatingActionButton(
          key: const Key('messages-new'),
          tooltip: l10n.messagesNew,
          backgroundColor: BvColors.actionPrimary,
          foregroundColor: BvColors.actionPrimaryForeground,
          elevation: 0,
          shape: const CircleBorder(),
          // Someone new: find them, then Message on their profile.
          onPressed: () => context.go(AppRoutes.explore),
          child: const Icon(BvIcons.add, size: BvSize.iconLg),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(dmInboxProvider.future),
        child: switch (inbox) {
          AsyncData(:final value) => body(value),
          AsyncError() => ListView(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
                child: EmptyNote(l10n.errorGeneric),
              ),
            ],
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

/// Every Message request, newest first; each opens its thread.
class MessageRequestsScreen extends ConsumerWidget {
  const MessageRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final now = ref.watch(clockProvider)();
    final rows = ref.watch(dmRequestsProvider);
    return Scaffold(
      backgroundColor: BvColors.surfaceApp,
      appBar: AppBar(
        backgroundColor: BvColors.surfaceApp,
        title: Text(l10n.messagesRequests, style: BvType.of(context).titleMd),
      ),
      body: switch (rows) {
        AsyncData(:final value) => ListView(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: BvMessagesSpec.listInset,
          ),
          children: [for (final r in value) DmListRow(row: r, now: now)],
        ),
        AsyncError() => Padding(
          padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
          child: EmptyNote(l10n.errorGeneric),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// What the last message says on a row: "You: …", "Voice note · 0:24",
/// a file's name, "Photo", or "Message deleted".
String dmPreviewText(AppLocalizations l10n, DmPreview p) {
  final String what;
  if (p.deleted) {
    what = l10n.chatDeleted;
  } else {
    what = switch (p.kind) {
      ChatKind.voice => l10n.messagesVoice(voiceLength(p.durationMs ?? 0)),
      ChatKind.file => inOwnDirection(p.fileName ?? l10n.chatFile),
      ChatKind.photo when (p.text ?? '').isEmpty => l10n.dmPhoto,
      _ => inOwnDirection(p.text ?? ''),
    };
  }
  return p.fromMe && !p.deleted ? l10n.messagesYou(what) : what;
}

/// "0:24", "1:05": a voice note's length.
String voiceLength(int ms) {
  final s = (ms / 1000).round();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// One thread on the list (DM1): the face, the name, the last message on
/// one line, and the time. Unread: a white card, the time in the action
/// colour, and a dot.
class DmListRow extends StatelessWidget {
  const DmListRow({super.key, required this.row, required this.now});

  final DmRow row;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final name = personName(l10n, row.person.former ? null : row.person.name);
    final last = row.last;
    final unread = row.unread && !row.muted;
    return Material(
      key: Key('messages-row-${row.threadId}'),
      color: unread ? BvColors.surfaceElevated : Colors.transparent,
      borderRadius: BvMessagesSpec.rowRadius,
      child: InkWell(
        borderRadius: BvMessagesSpec.rowRadius,
        onTap: () => context.push(AppRoutes.messagesThread(row.threadId)),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(BvMessagesSpec.rowPadding),
          child: Row(
            spacing: BvMessagesSpec.rowGap,
            children: [
              BvAvatar(name: name, tint: BvAvatarTints.forId(row.person.id)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            inOwnDirection(name),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: type.titleMd,
                          ),
                        ),
                        Text(
                          BvTime.of(context).moment(row.lastMessageAt, now),
                          style: type.metadata.copyWith(
                            color: unread
                                ? BvColors.textAction
                                : BvColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        if (last?.kind == ChatKind.voice && !last!.deleted)
                          const Padding(
                            padding: EdgeInsetsDirectional.only(
                              end: BvSpace.s4,
                            ),
                            child: Icon(
                              BvIcons.microphone,
                              size: BvSize.iconSm,
                              color: BvColors.iconSecondary,
                            ),
                          ),
                        if (last?.kind == ChatKind.file && !last!.deleted)
                          const Padding(
                            padding: EdgeInsetsDirectional.only(
                              end: BvSpace.s4,
                            ),
                            child: Icon(
                              BvIcons.attach,
                              size: BvSize.iconSm,
                              color: BvColors.iconSecondary,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            last == null ? '' : dmPreviewText(l10n, last),
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
                          Semantics(
                            label: l10n.messagesUnread,
                            child: Container(
                              key: const Key('messages-unread-dot'),
                              width: BvMessagesSpec.dot,
                              height: BvMessagesSpec.dot,
                              margin: const EdgeInsetsDirectional.only(
                                start: BvSpace.s8,
                              ),
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
      ),
    );
  }
}

/// The newest Message request (DM1, top): brand-soft, "Message request"
/// in the action colour, the name and its first words, and a chevron to
/// every request. Never a count.
class DmRequestCard extends StatelessWidget {
  const DmRequestCard({super.key, required this.row, required this.onTap});

  final DmRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final name = personName(l10n, row.person.former ? null : row.person.name);
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        top: BvMessagesSpec.requestMargin,
      ),
      child: Material(
        key: const Key('messages-request'),
        color: BvColors.surfaceBrandSoft,
        borderRadius: BvMessagesSpec.requestRadius,
        child: InkWell(
          borderRadius: BvMessagesSpec.requestRadius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(BvMessagesSpec.rowPadding),
            child: Row(
              spacing: BvMessagesSpec.rowGap,
              children: [
                BvAvatar(name: name),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.messagesRequest,
                        style: type.metadata.copyWith(
                          color: BvColors.textAction,
                        ),
                      ),
                      Text(
                        inOwnDirection(name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: type.titleMd,
                      ),
                      if (row.last != null)
                        Text(
                          dmPreviewText(l10n, row.last!),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: type.bodySm.copyWith(
                            color: BvColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(BvIcons.caretForward, color: BvColors.iconPrimary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
