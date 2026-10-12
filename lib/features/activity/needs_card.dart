import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart';
import '../../core/l10n/months.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/activity.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../spaces/space_screen.dart' show SpaceOpen;

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

/// A1's overline: "WORK ITEM · FOR YOU".
String needsOverline(AppLocalizations l10n, NeedsKind kind) => switch (kind) {
  NeedsKind.forYou => l10n.needsOverForYou,
  NeedsKind.youCheck => l10n.needsOverCheck,
  NeedsKind.sentBack => l10n.needsOverSentBack,
  NeedsKind.ownerLeft => l10n.needsOverOwnerLeft,
  NeedsKind.joinRequest => l10n.needsOverJoin,
};

/// Opens what the card is about: the work item, or the Space's People tab.
void openNeeds(BuildContext context, NeedsCard c) {
  final item = c.workItemId;
  if (item != null) {
    context.push(AppRoutes.workItem(c.spaceId, item));
  } else {
    context.push(AppRoutes.space(c.spaceId), extra: SpaceOpen.people);
  }
}

/// One thing that needs you. On Home (H1b): an orange card with one Open
/// button. In Activity (A1): an overline and the button that fits (Open,
/// Check, Review request).
class NeedsYouCard extends StatelessWidget {
  const NeedsYouCard({super.key, required this.card, this.activity = false});

  final NeedsCard card;
  final bool activity;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final due = card.due;
    final line = card.kind == NeedsKind.joinRequest
        ? null
        : joinMeta([
            if (card.workItemRef != null) ltrRun(card.workItemRef!),
            inOwnDirection(card.spaceName),
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
    return Container(
      key: Key('needs-$id'),
      padding: const EdgeInsetsDirectional.all(BvSpace.s16),
      decoration: BoxDecoration(
        color: BvColors.surfaceElevated,
        borderRadius: BvRadius.cardAll,
        border: Border.all(
          color: activity ? BvColors.borderDefault : BvColors.borderSelected,
          width: BvStroke.thin,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: BvSpace.s8,
        children: [
          if (activity)
            Text(
              needsOverline(l10n, card.kind),
              style: type.overline.copyWith(color: BvColors.textAction),
            ),
          Text(needsTitle(l10n, card), style: type.titleMd),
          if (line != null)
            Text(
              line,
              style: type.bodySm.copyWith(color: BvColors.textSecondary),
            ),
          const SizedBox(height: BvSpace.s4),
          BvButton(
            key: Key('needs-open-$id'),
            label: label,
            size: BvButtonSize.medium,
            onPressed: () => openNeeds(context, card),
          ),
        ],
      ),
    );
  }
}
