import 'package:flutter/material.dart';

import '../../data/models/space.dart';
import '../../l10n/gen/app_localizations.dart';
import '../work/work_outbox.dart' show workItemForSomeoneElse;

/// Plain words for a failed Space call.
String spaceErrorText(AppLocalizations l10n, SpaceException e) =>
    switch (e.failure) {
      SpaceFailure.notAllowed => l10n.spacesNotAllowed,
      SpaceFailure.network => l10n.errorNetwork,
      SpaceFailure.openWork => l10n.spacesHandOverFirst,
      SpaceFailure.teamAdminStays => l10n.spacesTeamAdminStays,
      // Review 112: a work item for yourself.
      _ when (e.message ?? '').toLowerCase().contains(workItemForSomeoneElse) =>
        l10n.workItemForSomeoneElse,
      SpaceFailure.rule ||
      SpaceFailure.badInput ||
      SpaceFailure.duplicate ||
      SpaceFailure.limit ||
      SpaceFailure.conflict ||
      SpaceFailure.unknown => l10n.errorGeneric,
    };

void showSpaceError(BuildContext context, SpaceException e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(spaceErrorText(AppLocalizations.of(context), e))),
  );
}

void showSpaceMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
