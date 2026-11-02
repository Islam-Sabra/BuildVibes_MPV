import 'package:flutter/material.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/people_library_specs.dart';
import '../../core/l10n/bidi.dart';
import '../../data/models/company_teams.dart';
import '../../data/models/space.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_avatar.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_chip.dart';
import '../../shared/widgets/bv_segmented.dart';
import '../../shared/widgets/bv_sheet.dart';
import 'pass_words.dart';
import 'people_tab.dart' show RoleCompanyLine;

/// Review 111 TM4: Confirm a join request. With a [match], its Team and
/// Crew are already chosen and one tap confirms ("Chosen because … works at
/// …"). Without one nothing is chosen (review 69 1a). Null when closed.
Future<({SpacePass pass, List<String> teamIds})?> showConfirmJoinSheet(
  BuildContext context, {
  required SpaceJoinRequest request,
  required List<SpaceTeam> teams,
  required CompanyTeamMatch? match,
}) => showBvSheet(
  context: context,
  builder: (_) => _ConfirmJoin(
    request: request,
    teams: teams,
    // A Team gone since the server said so isn't offered.
    match: teams.any((t) => t.id == match?.teamId) ? match : null,
  ),
);

class _ConfirmJoin extends StatefulWidget {
  const _ConfirmJoin({
    required this.request,
    required this.teams,
    required this.match,
  });

  final SpaceJoinRequest request;
  final List<SpaceTeam> teams;
  final CompanyTeamMatch? match;

  @override
  State<_ConfirmJoin> createState() => _ConfirmJoinState();
}

class _ConfirmJoinState extends State<_ConfirmJoin> {
  late SpacePass? _pass = widget.match == null ? null : SpacePass.crew;
  late final _chosen = {?widget.match?.teamId};

  /// All the Space's Teams, not only the chosen one.
  late var _all = widget.match == null;

  void _toggle(String id) => setState(() {
    if (!_chosen.remove(id)) _chosen.add(id);
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final p = widget.request.person;
    final match = widget.match;
    final label = type.metadata.copyWith(color: BvColors.textSecondary);
    final pass = _pass;
    final shown = [
      for (final t in widget.teams)
        if (_all || _chosen.contains(t.id) || t.id == match?.teamId) t,
    ];

    return Column(
      key: const Key('confirm-sheet'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: BvTeamsSpec.confirmGap,
      children: [
        Row(
          spacing: BvPeopleSpec.requestGap,
          children: [
            BvAvatar(
              name: p.fullName,
              size: BvAvatarSize.list,
              tint: BvAvatarTints.forId(p.id),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: BvSpace.s2,
                children: [
                  Text(
                    inOwnDirection(p.fullName),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: type.emphasis,
                  ),
                  RoleCompanyLine(person: p, lang: lang),
                ],
              ),
            ),
          ],
        ),
        Text(l10n.peoplePassRow, style: label),
        BvSegmented<SpacePass?>(
          value: pass,
          onChanged: (v) => setState(() => _pass = v),
          segments: [
            for (final option in SpacePass.values)
              BvSegment(
                key: Key('request-pass-${option.name}'),
                value: option,
                label: passName(l10n, option),
              ),
          ],
        ),
        if (widget.teams.isNotEmpty) ...[
          Text(l10n.daybookRowTeam, style: label),
          Wrap(
            spacing: BvPeopleSpec.chipGap,
            runSpacing: BvPeopleSpec.chipGap,
            children: [
              for (final t in shown)
                BvChip(
                  key: Key('confirm-team-${t.id}'),
                  label: t.name,
                  selected: _chosen.contains(t.id),
                  icon: _chosen.contains(t.id) ? BvIcons.check : null,
                  onTap: () => _toggle(t.id),
                ),
              if (!_all && widget.teams.length > 1)
                BvChip(
                  key: const Key('confirm-another'),
                  label: l10n.joinAnother,
                  icon: BvIcons.add,
                  onTap: () => setState(() => _all = true),
                ),
            ],
          ),
          if (match != null && _chosen.contains(match.teamId))
            Text(
              key: const Key('confirm-why'),
              l10n.joinChosenBecause(
                inOwnDirection(p.firstName),
                inOwnDirection(match.company),
              ),
              style: label,
            ),
        ],
        BvButton(
          key: Key('request-confirm-${widget.request.id}'),
          label: pass == null ? l10n.peopleChoosePass : l10n.peopleConfirm,
          icon: pass == null ? null : BvIcons.check,
          expand: true,
          onPressed: pass == null
              ? null
              : () => Navigator.of(
                  context,
                ).pop((pass: pass, teamIds: _chosen.toList())),
        ),
      ],
    );
  }
}
