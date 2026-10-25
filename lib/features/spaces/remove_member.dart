import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/daybook_writing_specs.dart' show BvUndoBarSpec;
import '../../core/l10n/bidi.dart';
import '../../data/models/space.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_hold_button.dart';
import '../../shared/widgets/bv_undo_bar.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../work/work_outbox.dart';

/// Remove from Space (review 94), from the People tab or a member's pass:
/// asked on a sheet and answered by holding. The person leaves the list at
/// once and "Removed · Undo" shows for 5 seconds; only then does the
/// removal go, through the outbox. True once held.
Future<bool> holdToRemove(
  BuildContext context,
  WidgetRef ref, {
  required String spaceId,
  required SpaceMember member,
}) async {
  final l10n = AppLocalizations.of(context);
  final name = inOwnDirection(member.person.fullName);
  final held = await showBvHoldSheet(
    context,
    title: l10n.spacesRemoveTitle(name),
    body: l10n.spacesRemoveBody,
    label: l10n.holdToRemove,
    hint: l10n.holdKeepHolding,
    icon: BvIcons.close,
    destructive: true,
  );
  if (!held || !context.mounted) return false;
  final outbox = ref.read(workOutboxProvider.notifier);
  await outbox.hold(
    PendingItem(
      kind: PendingKind.remove,
      id: member.person.id,
      spaceId: spaceId,
      title: member.person.fullName,
      ownerId: member.person.id,
      ownerName: member.person.fullName,
      madeAt: ref.read(clockProvider)(),
    ),
    BvUndoBarSpec.duration,
  );
  if (!context.mounted) return true;
  showBvUndoBar(
    context,
    message: l10n.spacesRemovedUndo,
    actionLabel: l10n.daybookUndo,
    onAction: () => outbox.undo(PendingKind.remove, member.person.id),
    bottom: 0,
  );
  return true;
}

/// The people of [spaceId] being removed from it on this phone: not shown.
Set<String> beingRemoved(WidgetRef ref, String spaceId) => {
  for (final i in ref.watch(workOutboxProvider))
    if (i.kind == PendingKind.remove && i.spaceId == spaceId && !i.refused)
      i.id,
};
