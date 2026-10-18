import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/ago.dart';
import '../../core/l10n/bidi.dart';
import '../../core/l10n/months.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/activity.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_space_tile.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../spaces/space_screen.dart' show SpaceOpen;
import '../work/daybook_target.dart';

/// "Sara Al-Mutairi gave you a work item: confirm the beam schedule".
String needsTitle(AppLocalizations l10n, NeedsCard c) {
  final title = inOwnDirection(c.workItemTitle ?? '');
  final name = c.actorName == null ? null : inOwnDirection(c.actorName!);
  return switch (c.kind) {
    NeedsKind.forYou =>
      name == null
          ? l10n.needsForYouSelf(title)
          : l10n.needsForYou(name, title),
    NeedsKind.youCheck =>
      name == null
          ? l10n.needsYouCheckSelf(title)
          : l10n.needsYouCheck(name, title),
    NeedsKind.sentBack =>
      name == null
          ? l10n.needsSentBackSelf(title)
          : l10n.needsSentBack(name, title),
    NeedsKind.ownerLeft => l10n.needsOwnerLeft(title),
    NeedsKind.joinRequest => l10n.needsJoin(
      name ?? l10n.activitySomeone,
      inOwnDirection(c.spaceName),
    ),
  };
}

/// Opens what the card is about: the work item's card on its Space's
/// daybook (F20), or the Space's People tab.
void openNeeds(BuildContext context, NeedsCard c) {
  final item = c.workItemId;
  if (item != null) {
    openWorkCard(context, spaceId: c.spaceId, postId: item);
  } else {
    context.push(AppRoutes.space(c.spaceId), extra: SpaceOpen.people);
  }
}

/// One thing that needs you (F10). The Space first, with its tile; then
/// what happened; then the ref, the time and the due date, small. The
/// whole card opens it; the button sits on the end side, level with the
/// text: Open on Home, and in Activity (A1) the one that fits (Check,
/// Review request).
class NeedsYouCard extends ConsumerWidget {
  const NeedsYouCard({super.key, required this.card, this.activity = false});

  final NeedsCard card;
  final bool activity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final now = ref.watch(clockProvider)();
    final due = card.due;
    final line = joinMeta([
      if (card.workItemRef != null) ltrRun(card.workItemRef!),
      formatRowAgo(l10n, card.at.toLocal(), now),
      if (due != null) l10n.needsDue(formatDay(due, locale)),
    ]);
    final label = !activity
        ? l10n.needsOpen
        : switch (card.kind) {
            NeedsKind.youCheck => l10n.needsCheck,
            NeedsKind.joinRequest => l10n.needsReview,
            _ => l10n.needsOpen,
          };
    final id = card.workItemId ?? card.requestId ?? card.spaceId;
    void open() => openNeeds(context, card);
    return Material(
      key: Key('needs-$id'),
      color: BvColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BvRadius.cardAll,
        side: BorderSide(
          color: activity ? BvColors.borderDefault : BvColors.borderSelected,
          width: BvStroke.thin,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: open,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: BvActivitySpec.cardMinHeight,
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              BvActivitySpec.cardPaddingStart,
              BvActivitySpec.cardPadding,
              BvActivitySpec.cardPadding,
              BvActivitySpec.cardPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: BvSpace.s6,
              children: [
                Row(
                  spacing: BvSpace.s8,
                  children: [
                    BvSpaceTile(name: card.spaceName),
                    Expanded(
                      child: Text(
                        inOwnDirection(card.spaceName),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: type.titleMd,
                      ),
                    ),
                  ],
                ),
                Row(
                  spacing: BvActivitySpec.cardGap,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: BvActivitySpec.lineGap,
                        children: [
                          Text(needsTitle(l10n, card), style: type.bodyMd),
                          Text(
                            line,
                            style: type.metadata.copyWith(
                              color: BvColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    BvButton(
                      key: Key('needs-open-$id'),
                      label: label,
                      size: BvButtonSize.medium,
                      onPressed: open,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
