import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/daybook_writing_specs.dart' show BvUndoBarSpec;
import '../../core/l10n/bidi.dart';
import '../../data/models/space.dart';
import '../../data/repositories/space_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_hold_button.dart';
import '../../shared/widgets/bv_undo_bar.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../work/work_outbox.dart';
import 'removal_sheet.dart';
import 'space_errors.dart';

/// Remove from Space (review 94), from the People tab or a member's pass:
/// asked on a sheet and answered by holding. Someone who owns Open work
/// items gets the removal sheet instead (review 105 SP9): each item goes
/// to a new owner in the same step. The person leaves the list at once
/// and "Removed · Undo" shows for 5 seconds; only then does the removal
/// go, through the outbox. True once confirmed.
Future<bool> holdToRemove(
  BuildContext context,
  WidgetRef ref, {
  required String spaceId,
  required SpaceMember member,
}) async {
  final l10n = AppLocalizations.of(context);
  final name = inOwnDirection(member.person.fullName);
  final List<OpenWorkItem> open;
  try {
    open = await ref
        .read(spaceRepositoryProvider)
        .openWork(spaceId, member.person.id);
  } on SpaceException catch (e) {
    if (context.mounted) showSpaceError(context, e);
    return false;
  }
  if (!context.mounted) return false;
  var handovers = const <Handover>[];
  if (open.isEmpty) {
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
  } else {
    final given = await showHandoverSheet(
      context,
      ref,
      spaceId: spaceId,
      memberId: member.person.id,
      items: open,
      name: member.person.fullName,
      firstName: member.person.firstName,
    );
    if (given == null || !context.mounted) return false;
    handovers = given;
  }
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
      handovers: handovers,
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
