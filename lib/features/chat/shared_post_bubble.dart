import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/daybook.dart';
import '../../data/models/space.dart' show SpaceException;
import '../../data/models/work_item.dart';
import '../../data/repositories/daybook_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../entry/entry_state.dart';
import '../profile/widgets/profile_parts.dart' show EmptyNote;
import '../spaces/space_errors.dart';
import '../work/daybook_draft.dart' show DaybookKind;
import '../work/daybook_writing.dart' show kindIcon, kindName;

/// A shared post's card, as the reader may see it (daybook_card); with
/// none, whether the post was deleted (shared_post_gone) or is only hidden
/// from the reader (review 105B L8).
typedef SharedPostRead = ({DaybookCard? card, bool gone});

final sharedPostCardProvider = FutureProvider.autoDispose
    .family<SharedPostRead, String>((ref, postId) async {
      final repository = ref.watch(daybookRepositoryProvider);
      final card = await repository.card(postId);
      if (card != null) return (card: card, gone: false);
      return (card: null, gone: await repository.sharedPostGone(postId));
    });

/// A post of the Space's Work shared in a thread (review 105B,
/// share_post_to_thread): its kind, title, who it is for and its status;
/// a tap opens it in Work. The work stays in its Space (rule 8): a reader
/// who can't see it there is told so, or that it was deleted; no signal is
/// the usual error, with Try again.
class SharedPostBubble extends ConsumerWidget {
  const SharedPostBubble({
    super.key,
    required this.spaceId,
    required this.postId,
  });

  final String spaceId;
  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final read = ref.watch(sharedPostCardProvider(postId));
    if (read.hasError && !read.hasValue) {
      final e = read.error;
      return Column(
        key: const Key('chat-shared-post-error'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: BvSpace.s8,
        children: [
          EmptyNote(
            e is SpaceException ? spaceErrorText(l10n, e) : l10n.errorGeneric,
          ),
          BvButton(
            key: const Key('chat-shared-post-retry'),
            label: l10n.commonRetry,
            style: BvButtonStyle.secondary,
            size: BvButtonSize.medium,
            onPressed: () => ref.invalidate(sharedPostCardProvider(postId)),
          ),
        ],
      );
    }
    if (!read.hasValue) return const SizedBox.shrink();
    final post = read.value?.card?.post;
    if (post == null) {
      final gone = read.value?.gone ?? false;
      return EmptyNote(
        key: Key(gone ? 'chat-shared-post-gone' : 'chat-shared-post-hidden'),
        gone ? l10n.chatPostGone : l10n.chatPostHidden,
      );
    }
    final kind = DaybookKind.fromJson(post.kind);
    final item = post.item;
    final me = ref.watch(authUserIdProvider).value;
    final forLine = item == null
        ? null
        : item.ownerId != null && item.ownerId == me
        ? l10n.daybookForYou
        : item.ownerName == null
        ? null
        : l10n.daybookForPerson(item.ownerName!);
    final status = post.cancelled
        ? l10n.daybookCancelled
        : switch (item?.status) {
            WorkStatus.checked => l10n.daybookStampChecked,
            WorkStatus.done => l10n.daybookStampDone,
            // L8: every state, Open too.
            WorkStatus.open => l10n.daybookStampOpen,
            null => null,
          };
    final quiet = type.metadata.copyWith(color: BvColors.textSecondary);
    return Material(
      key: const Key('chat-shared-post'),
      color: BvColors.surfaceElevated,
      borderRadius: BvRadius.cardAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.spaceCard(spaceId, postId)),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(BvSpace.s12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: BvSpace.s12,
            children: [
              Icon(kindIcon(kind), color: BvColors.iconAction),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: BvSpace.s2,
                  children: [
                    Text(kindName(l10n, kind), style: quiet),
                    Text(
                      post.title,
                      textDirection: directionOf(post.title),
                      style: type.labelMd.copyWith(color: BvColors.textPrimary),
                    ),
                    if (forLine != null) Text(forLine, style: quiet),
                    if (status != null)
                      Text(
                        status,
                        style: type.metadata.copyWith(
                          color: item?.status == WorkStatus.checked
                              ? BvColors.textPositive
                              : BvColors.textSecondary,
                        ),
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
