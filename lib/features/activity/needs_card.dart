import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/bidi.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/activity.dart';
import '../../l10n/gen/app_localizations.dart';
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
    NeedsKind.checklist =>
      name == null
          ? l10n.needsChecklistSelf(title)
          : l10n.needsChecklist(name, title),
    NeedsKind.joinRequest => l10n.needsJoin(
      name ?? l10n.activitySomeone,
      inOwnDirection(c.spaceName),
    ),
  };
}

/// Opens what the card is about: the work item's or the checklist's card on
/// its Space's daybook (F20), or the Space's People tab.
void openNeeds(BuildContext context, NeedsCard c) {
  final item = c.cardId;
  if (item != null) {
    openWorkCard(context, spaceId: c.spaceId, postId: item);
  } else {
    context.push(AppRoutes.space(c.spaceId), extra: SpaceOpen.people);
  }
}
