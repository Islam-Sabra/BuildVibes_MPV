import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart';
import '../../data/models/chat.dart';
import '../../data/models/daybook.dart';
import '../../data/models/space.dart' show SpaceException;
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/daybook_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../chat/chat_tab.dart' show threadName;
import '../chat/thread_screen.dart' show ChatActionRow;
import 'daybook_writing.dart' show newPostIdProvider;

/// Share in the hold bar (review 105B, the lead's ruling Q2): [posts]'
/// cards into one of [spaceId]'s Chat threads, picked on a sheet; the work
/// stays in its Space (rule 8). A Team's post goes only into that Team's
/// thread, so the sheet lists only the threads every post may go in.
Future<void> shareToThread(
  BuildContext context,
  Ref ref,
  String spaceId,
  List<DaybookPost> posts,
) async {
  final l10n = AppLocalizations.of(context);
  final type = BvType.of(context);
  final threads = await ref.read(spaceThreadsProvider(spaceId).future);
  if (!context.mounted) return;
  final teams = {for (final p in posts) p.teamId};
  final open = [
    for (final t in threads)
      if (teams.every((team) => team == null || team == t.teamId)) t,
  ];
  final thread = await showBvSheet<ChatThread>(
    context: context,
    builder: (sheet) => Column(
      key: const Key('share-threads'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: BvSpace.gutter,
            vertical: BvSpace.s8,
          ),
          child: Text(
            l10n.workShareIn,
            style: type.labelMd.copyWith(color: BvColors.textSecondary),
          ),
        ),
        for (final t in open)
          ChatActionRow(
            key: Key('share-thread-${t.id}'),
            icon: t.isEveryone ? BvIcons.chat : BvIcons.team,
            label: threadName(l10n, t),
            onTap: () => Navigator.of(sheet).pop(t),
          ),
      ],
    ),
  );
  if (thread == null || !context.mounted) return;
  final repo = ref.read(daybookRepositoryProvider);
  final newId = ref.read(newPostIdProvider);
  // L5: each post's message id is made once, for this choice of thread, so
  // Try again sends the same one and the server posts it once.
  final ids = {for (final p in posts) p.id: newId()};
  final messenger = ScaffoldMessenger.of(context);
  Future<void> send(List<DaybookPost> those) async {
    // Every one is tried; what failed is said after (L10, as H5).
    final failed = <DaybookPost>[];
    for (final p in those) {
      try {
        await repo.sharePost(
          messageId: ids[p.id]!,
          postId: p.id,
          threadId: thread.id,
        );
      } on SpaceException {
        failed.add(p);
      }
    }
    ref.invalidate(spaceThreadsProvider(spaceId));
    messenger.hideCurrentSnackBar();
    if (failed.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.workSharedIn(threadName(l10n, thread)))),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          l10n.workShareFailed(joinMeta(failed.map((p) => p.title))),
        ),
        action: SnackBarAction(
          label: l10n.commonRetry,
          onPressed: () => unawaited(send(failed)),
        ),
      ),
    );
  }

  await send(posts);
}
