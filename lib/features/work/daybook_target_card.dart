import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_page_specs.dart';
import '../../core/l10n/bidi.dart';
import '../../data/models/daybook.dart';
import '../../data/models/space.dart';
import '../../data/models/work_item.dart';
import '../../data/repositories/daybook_repository.dart';
import '../../data/repositories/space_repository.dart' show spacePeopleProvider;
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_avatar.dart';
import '../../shared/widgets/bv_checklist_point.dart' show BvChecklistProgress;
import '../../shared/widgets/bv_stamp.dart';
import '../entry/entry_state.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../profile/widgets/profile_parts.dart';
import '../spaces/former_member.dart';
import 'daybook_card.dart';
import 'daybook_loop.dart';
import 'daybook_photos.dart';
import 'daybook_words.dart';
import 'work_outbox.dart';

/// A target's work items (a walk's photos) on its card (R1b, slice 6): the
/// photos in a row, a row per work item, and "N of M checked". The target
/// itself asks nobody to sign or check it: its progress is theirs.
class DaybookTargetRows extends ConsumerWidget {
  const DaybookTargetRows({
    super.key,
    required this.post,
    required this.waiting,
    this.viewer = false,
    this.onOpenChild,
    this.onShowAll,
  });

  final DaybookPost post;

  /// Not on the server yet: the photos are the phone's own.
  final bool waiting;
  final bool viewer;
  final ValueChanged<String>? onOpenChild;
  final VoidCallback? onShowAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final children = post.children;
    if (children == null) return const SizedBox.shrink();
    final rows = children.rows;
    final covers = [
      for (final r in rows)
        if (r.coverPath != null) r.coverPath!,
    ];
    final shown = rows.take(BvTargetSpec.rowsShown).toList();
    return Column(
      key: Key('target-rows-${post.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BvTargetSpec.rowGap,
      children: [
        // A walk: each photo is a work item (a fact about this post).
        if (covers.isNotEmpty && covers.length == children.total)
          Text(
            l10n.walkEachItem(children.total),
            style: BvType.of(
              context,
            ).bodySm.copyWith(color: BvColors.textSecondary),
          ),
        if (covers.isNotEmpty)
          Row(
            spacing: BvTargetSpec.photoGap,
            children: [
              for (final path in covers.take(BvTargetSpec.photosShown))
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: ClipRRect(
                      borderRadius: BvTargetSpec.photoRadius,
                      child: _Cover(path: path, local: waiting),
                    ),
                  ),
                ),
            ],
          ),
        for (final r in shown)
          DaybookChildRow(
            key: Key('target-row-${r.id}'),
            child: r,
            viewer: viewer,
            onTap: onOpenChild == null ? null : () => onOpenChild!(r.id),
          ),
        if (rows.length > shown.length && onShowAll != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: Key('target-show-all-${post.id}'),
              onPressed: onShowAll,
              child: Text(l10n.walkShowAll),
            ),
          ),
        BvChecklistProgress(
          ticked: children.checked,
          total: children.total,
          label: l10n.pageUnderChecked(children.checked, children.total),
        ),
      ],
    );
  }
}

class _Cover extends ConsumerWidget {
  const _Cover({required this.path, required this.local});

  final String path;
  final bool local;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = local
        ? ref.watch(localPhotoProvider(path))
        : ref.watch(daybookPhotoProvider(path));
    return image == null
        ? const ColoredBox(color: BvColors.surfaceSubtle)
        : Image(image: image, fit: BoxFit.cover);
  }
}

/// One work item under a target: its state, its words, its stamp (DONE,
/// CHECKED), what it needs of the reader ("Sign as done", "Check"), and
/// its owner's face. A tap opens its own card.
class DaybookChildRow extends StatelessWidget {
  const DaybookChildRow({
    super.key,
    required this.child,
    this.viewer = false,
    this.onTap,
  });

  final DaybookChild child;
  final bool viewer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final checked = child.status == WorkStatus.checked;
    final stamp = switch (child.status) {
      WorkStatus.checked => BvInkStamp(
        label: l10n.daybookStampChecked,
        size: BvInkStampSize.xs,
        tone: BvInkStampTone.positive,
      ),
      WorkStatus.done => BvInkStamp(
        label: l10n.daybookStampDone,
        size: BvInkStampSize.xs,
      ),
      WorkStatus.open => null,
    };
    final need = viewer
        ? null
        : switch (child.need) {
            DaybookNeed.toSign => l10n.daybookSignAsDone,
            DaybookNeed.toCheck => l10n.daybookCheck,
            DaybookNeed.giveTo => l10n.daybookGiveTo,
            _ => null,
          };
    return Material(
      color: BvColors.surfaceSubtle,
      borderRadius: BvTargetSpec.rowRadius,
      child: InkWell(
        borderRadius: BvTargetSpec.rowRadius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(BvTargetSpec.rowPadding),
          child: Row(
            spacing: BvSpace.s12,
            children: [
              if (checked)
                const Icon(
                  BvIcons.checkCircle,
                  size: BvTargetSpec.statusSize,
                  color: BvColors.textPositive,
                )
              else
                Container(
                  width: BvTargetSpec.statusSize,
                  height: BvTargetSpec.statusSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: BvColors.borderDefault,
                      width: BvStroke.medium,
                    ),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: BvSpace.s2,
                  children: [
                    Text(
                      child.title,
                      textDirection: directionOf(child.title),
                      style: type.bodyMd,
                    ),
                    if (need != null)
                      Text(
                        need,
                        key: Key('target-row-need-${child.id}'),
                        style: type.labelSm.copyWith(
                          color: BvColors.textAction,
                        ),
                      ),
                  ],
                ),
              ),
              ?stamp,
              BvAvatar(
                name: personName(l10n, child.ownerName),
                size: BvAvatarSize.face,
                tint: child.ownerId == null
                    ? BvAvatarTints.plain
                    : BvAvatarTints.forId(child.ownerId!),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A work item under a target, opened from its row (or Needs you,
/// Activity, a push): its own card on a sheet, with everything the card
/// offers there (sign as done, check, send back, updates).
Future<void> showDaybookChild(
  BuildContext context, {
  required DaybookLoop loop,
  required String childId,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: BvColors.surfaceApp,
    barrierColor: BvColors.overlayScrim,
    builder: (_) => _ChildSheet(loop: loop, childId: childId),
  );
  await loop.refresh();
}

class _ChildSheet extends ConsumerWidget {
  const _ChildSheet({required this.loop, required this.childId});

  final DaybookLoop loop;
  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final card = ref.watch(daybookChildCardProvider(childId));
    final me = ref.watch(authUserIdProvider).value;
    final now = ref.watch(clockProvider)();
    // What this phone did and hasn't sent yet shows at once, so the same
    // action isn't offered twice.
    final held = {
      for (final i in ref.watch(workOutboxProvider))
        if (i.id == childId && !i.refused) i.kind: i,
    };
    final pending = held.keys;
    final outbox = ref.read(workOutboxProvider.notifier);
    final myName = ref
        .watch(spacePeopleProvider(loop.space.id))
        .value
        ?.member(me ?? '')
        ?.person
        .fullName;
    var c = card.value;
    var landing = false;
    // Review 94: a check or a cancel made here shows at once, as on the
    // daybook: the CHECKED stamp lands, or the card is cancelled.
    final check = held[PendingKind.check];
    if (c != null && check != null) {
      final at = check.madeAt ?? now;
      c = c.copyWith(
        post: c.post.shownAs(status: WorkStatus.checked),
        proof: c.proof?.withOutcome(
          DaybookOutcome(
            kind: DaybookOutcomeKind.checked,
            at: at,
            byId: me,
            byName: myName,
          ),
        ),
        history: [
          DaybookEvent(
            id: 'check_item-$childId',
            kind: DaybookEventKind.checked,
            at: at,
            byId: me,
            byName: myName,
          ),
          ...c.history,
        ],
        clearNeed: true,
      );
      landing = outbox.isHeld(PendingKind.check, childId);
    } else if (c != null && held.containsKey(PendingKind.cancel)) {
      c = c.copyWith(post: c.post.shownAs(cancelled: true), clearNeed: true);
    } else if (c != null &&
        pending.contains(PendingKind.signOff) &&
        c.post.isOpen) {
      c = c.copyWith(
        post: c.post.shownAs(status: WorkStatus.done),
        clearNeed: true,
      );
    }
    final Widget body;
    if (c == null) {
      body = Padding(
        padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
        child: card.isLoading
            ? const Center(child: CircularProgressIndicator())
            : EmptyNote(
                card.hasError ? l10n.errorGeneric : l10n.daybookRemoved,
              ),
      );
    } else {
      final view = DaybookCardView(
        card: c,
        words: DaybookWords(
          l10n,
          Localizations.localeOf(context).toLanguageTag(),
          use24: MediaQuery.alwaysUse24HourFormatOf(context),
        ),
        me: me,
        now: now,
        activityAt: c.lastActivityAt,
        viewer: loop.space.myPass == SpacePass.viewer,
        landing: landing,
      );
      // Under the sheet's own messenger, so its undo bar shows on the
      // sheet, where it can be tapped.
      body = Builder(
        builder: (sheet) => Padding(
          padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
          child: loop.withActions(
            sheet,
            view,
            me: me,
            signing: {if (pending.contains(PendingKind.signOff)) childId},
          ),
        ),
      );
    }
    // Its own messenger: Undo shows on the sheet.
    return FractionallySizedBox(
      heightFactor: BvPageSpec.heightFactor,
      child: ScaffoldMessenger(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SingleChildScrollView(
            key: Key('daybook-child-$childId'),
            child: body,
          ),
        ),
      ),
    );
  }
}
