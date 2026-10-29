import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/daybook.dart';
import '../../data/models/work_item.dart';
import '../../data/repositories/daybook_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../entry/entry_state.dart';
import '../profile/widgets/profile_parts.dart' show EmptyNote;
import '../work/daybook_draft.dart' show DaybookKind;
import '../work/daybook_writing.dart' show kindIcon, kindName;

/// A shared post's card, as the reader may see it (daybook_card).
final sharedPostCardProvider = FutureProvider.autoDispose
    .family<DaybookCard?, String>(
      (ref, postId) => ref.watch(daybookRepositoryProvider).card(postId),
    );

/// A post of the Space's Work shared in a thread (review 105B,
/// share_post_to_thread): its kind, title, who it is for and its status;
/// a tap opens it in Work. The work stays in its Space (rule 8): a reader
/// who can't see it there sees that it isn't there.
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
    if (read.isLoading && !read.hasValue) {
      return const SizedBox.shrink();
    }
    final post = read.value?.post;
    if (post == null) {
      return EmptyNote(
        key: const Key('chat-shared-post-gone'),
        l10n.chatPostGone,
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
            _ => null,
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
