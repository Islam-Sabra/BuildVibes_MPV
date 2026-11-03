import 'package:flutter/material.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/people_library_specs.dart';
import '../../core/l10n/bidi.dart';
import '../../data/models/space.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_sheet.dart';

/// Review 111 TM5: Who sees it. Everyone in the Space, then what the person
/// may post to, their own Teams first; each Team says why it is there. One
/// single choice (rule 6). Null when the sheet is closed without a choice;
/// otherwise the choice, whose [team] is null for Everyone.
Future<({SpaceTeam? team})?> pickWhoSees(
  BuildContext context, {
  required SpacePeople people,
  required String me,
  required bool spaceAdmin,
  required String? chosen,
}) {
  final l10n = AppLocalizations.of(context);
  final teams = people.mayPostTo(me, admin: spaceAdmin);
  final ordered = [
    ...teams.where((t) => t.memberIds.contains(me)),
    ...teams.where((t) => !t.memberIds.contains(me)),
  ];
  // V13: the Space admin's own word first, also for one who is a Team admin.
  String why(SpaceTeam t) => t.memberIds.contains(me)
      ? l10n.whoSeesYourTeam
      : spaceAdmin
      ? l10n.whoSeesAsSpaceAdmin
      : l10n.whoSeesAsTeamAdmin;

  return showBvSheet<({SpaceTeam? team})>(
    context: context,
    title: l10n.whoSeesTitle,
    builder: (sheet) => Column(
      key: const Key('who-sees-sheet'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _Row(
          key: const Key('who-sees-everyone'),
          title: l10n.whoSeesEveryone,
          selected: chosen == null,
          onTap: () => Navigator.of(sheet).pop((team: null)),
        ),
        for (final t in ordered)
          _Row(
            key: Key('who-sees-${t.id}'),
            title: inOwnDirection(t.name),
            subtitle: why(t),
            selected: t.id == chosen,
            onTap: () => Navigator.of(sheet).pop((team: t)),
          ),
        Padding(
          padding: const EdgeInsetsDirectional.only(top: BvSpace.s12),
          child: Text(
            l10n.whoSeesFoot,
            style: BvType.of(
              context,
            ).metadata.copyWith(color: BvColors.textSecondary),
          ),
        ),
      ],
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: BvColors.borderDefault,
                width: BvStroke.thin,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              vertical: BvTeamsSpec.rowPaddingVertical,
            ),
            child: Row(
              spacing: BvTeamsSpec.rowGap,
              children: [
                BvTeamDisc(
                  size: BvTeamsSpec.whoDisc,
                  icon: BvIcons.team,
                  chosen: selected,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: BvTeamsSpec.lineGap,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: selected
                            ? type.emphasis.copyWith(color: BvColors.textAction)
                            : type.bodyMd,
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: type.metadata.copyWith(
                            color: BvColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(
                    BvIcons.check,
                    size: BvSize.iconMd,
                    color: BvColors.iconAction,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A round mark for a Team or a company (TM1, TM5).
class BvTeamDisc extends StatelessWidget {
  const BvTeamDisc({
    super.key,
    required this.size,
    required this.icon,
    this.chosen = false,
    this.onCard = false,
  });

  final double size;
  final IconData icon;

  /// Tinted with the action colour.
  final bool chosen;

  /// White, on the brand card.
  final bool onCard;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: onCard
          ? BvColors.surfaceElevated
          : chosen
          ? BvColors.surfaceBrandSoft
          : BvColors.surfaceSubtle,
    ),
    child: Icon(
      icon,
      size: BvSize.iconMd,
      color: chosen || onCard ? BvColors.iconAction : BvColors.iconPrimary,
    ),
  );
}
