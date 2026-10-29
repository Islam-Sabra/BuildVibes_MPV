import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/people_library_specs.dart' show BvHandoverSpec;
import '../../core/l10n/bidi.dart';
import '../../data/models/space.dart';
import '../../data/repositories/space_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_avatar.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_give_to_picker.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../work/daybook_writing.dart' show assignablePeople;

/// Review 105 SP9: someone who owns Open work items is removed, or leaves.
/// Each item is listed with a Give to row, its maker chosen by default when
/// they may own it; then Cancel · Give and remove (Give and leave). Their
/// Done and Checked work stays. The handovers once every item has a new
/// owner, or null when cancelled. The server does it all in one step and
/// checks every choice again (remove_member_with_handover,
/// leave_space_with_handover).
Future<List<Handover>?> showHandoverSheet(
  BuildContext context,
  WidgetRef ref, {
  required String spaceId,
  required String memberId,
  required List<OpenWorkItem> items,

  /// The person removed, and their profile's first name; null when I
  /// leave.
  String? name,
  String? firstName,
}) async {
  final l10n = AppLocalizations.of(context);
  final SpacePeople people;
  try {
    people = await ref.read(spacePeopleProvider(spaceId).future);
  } on SpaceException {
    return null;
  }
  if (!context.mounted) return null;
  return showBvSheet<List<Handover>>(
    context: context,
    title: name == null ? null : l10n.spacesRemoveTitle(inOwnDirection(name)),
    builder: (sheet) => HandoverSheet(
      people: people,
      memberId: memberId,
      items: items,
      name: name == null ? null : (firstName ?? name),
      onDone: (handovers) => Navigator.of(sheet).pop(handovers),
      onCancel: () => Navigator.of(sheet).pop(),
    ),
  );
}

/// Who may take [item] from [memberId]: Lead or Crew, of its Team (or an
/// admin) when it has one, never the person leaving.
List<BvGiveToPerson> handoverPeople(
  SpacePeople people,
  OpenWorkItem item,
  String memberId,
) {
  final team = people.teams.where((t) => t.id == item.teamId).firstOrNull;
  return [
    for (final p in assignablePeople(people))
      if (p.id != memberId &&
          (item.teamId == null ||
              (team?.memberIds.contains(p.id) ?? false) ||
              (people.member(p.id)?.isAdmin ?? false)))
        p,
  ];
}

class HandoverSheet extends StatefulWidget {
  const HandoverSheet({
    super.key,
    required this.people,
    required this.memberId,
    required this.items,
    required this.onDone,
    required this.onCancel,
    this.name,
  });

  final SpacePeople people;
  final String memberId;
  final List<OpenWorkItem> items;

  /// The first name of the person removed, from their profile; null when
  /// I leave.
  final String? name;
  final ValueChanged<List<Handover>> onDone;
  final VoidCallback onCancel;

  @override
  State<HandoverSheet> createState() => _HandoverSheetState();
}

class _HandoverSheetState extends State<HandoverSheet> {
  /// Each item's new owner, by item.
  late final Map<String, BvGiveToPerson?> _to = {
    for (final i in widget.items)
      i.id: i.makerMayOwn
          ? _candidates(i).where((p) => p.id == i.makerId).firstOrNull
          : null,
  };

  List<BvGiveToPerson> _candidates(OpenWorkItem item) =>
      handoverPeople(widget.people, item, widget.memberId);

  bool get _ready => _to.values.every((p) => p != null);

  Future<void> _pick(OpenWorkItem item) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showBvSheet<BvGiveToPerson>(
      context: context,
      title: l10n.handoverGiveTo,
      builder: (sheet) => BvGiveToPicker(
        key: const Key('handover-picker'),
        people: _candidates(item),
        currentOwnerId: _to[item.id]?.id,
        searchPlaceholder: l10n.daybookGiveToSearch,
        inSheet: true,
        onPick: (person) => Navigator.of(sheet).pop(person),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _to[item.id] = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final first = widget.name;
    final count = widget.items.length;
    return Column(
      key: const Key('handover-sheet'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BvHandoverSpec.gap,
      children: [
        Text(
          first == null
              ? l10n.handoverLeaveBody(count)
              : l10n.handoverRemoveBody(inOwnDirection(first), count),
          style: type.bodyMd.copyWith(color: BvColors.textSecondary),
        ),
        for (final item in widget.items) _item(item, type, l10n),
        Text(
          first == null ? l10n.handoverMyChecked : l10n.handoverTheirChecked,
          style: type.metadata.copyWith(color: BvColors.textSecondary),
        ),
        Row(
          spacing: BvSheetSpec.footerGap,
          children: [
            Expanded(
              child: BvButton(
                key: const Key('handover-cancel'),
                label: l10n.commonCancel,
                style: BvButtonStyle.secondary,
                expand: true,
                onPressed: widget.onCancel,
              ),
            ),
            Expanded(
              child: BvButton(
                key: const Key('handover-confirm'),
                label: first == null
                    ? l10n.handoverGiveAndLeave
                    : l10n.handoverGiveAndRemove,
                style: BvButtonStyle.destructive,
                expand: true,
                onPressed: _ready
                    ? () => widget.onDone([
                        for (final i in widget.items)
                          (item: i.id, owner: _to[i.id]!.id),
                      ])
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _item(OpenWorkItem item, BvTypeSet type, AppLocalizations l10n) {
    final to = _to[item.id];
    return Column(
      key: Key('handover-item-${item.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BvHandoverSpec.itemGap,
      children: [
        Row(
          spacing: BvHandoverSpec.refGap,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            if (item.ref case final ref?)
              Text(
                ref,
                textDirection: TextDirection.ltr,
                style: BvType.latin.metadata.copyWith(
                  color: BvColors.textSecondary,
                ),
              ),
            Expanded(
              child: Text(
                item.title,
                textDirection: directionOf(item.title),
                style: type.bodyMd,
              ),
            ),
          ],
        ),
        Material(
          color: BvColors.surfaceSubtle,
          borderRadius: BvHandoverSpec.rowRadius,
          child: InkWell(
            key: Key('handover-give-${item.id}'),
            borderRadius: BvHandoverSpec.rowRadius,
            onTap: () => _pick(item),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: BvHandoverSpec.rowPaddingHorizontal,
                vertical: BvHandoverSpec.rowPaddingVertical,
              ),
              child: Row(
                spacing: BvHandoverSpec.rowGap,
                children: [
                  Text(
                    l10n.handoverGiveTo,
                    style: type.bodyMd.copyWith(color: BvColors.textSecondary),
                  ),
                  if (to != null)
                    BvAvatar(
                      name: to.name,
                      size: BvAvatarSize.face,
                      twoLetters: true,
                    ),
                  Expanded(
                    child: Text(
                      to == null ? l10n.handoverChoose : inOwnDirection(to.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: to == null
                          ? type.bodyMd.copyWith(color: BvColors.textSecondary)
                          : type.bodyMd,
                    ),
                  ),
                  const Icon(
                    BvIcons.caretForward,
                    size: BvSize.iconSm,
                    color: BvColors.iconSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
