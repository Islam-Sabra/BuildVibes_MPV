import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/people_library_specs.dart';
import '../../core/l10n/bidi.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/company_teams.dart';
import '../../data/models/space.dart';
import '../../data/repositories/space_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import 'make_teams_sheet.dart';
import 'who_sees_sheet.dart';

/// Review 111 TM1: People's Teams side. For a Space admin, what can be made
/// from companies: the card while 2 or more companies wait, the one line
/// while one does. Then each Team and its admin, and New Team by hand.
class TeamsView extends ConsumerWidget {
  const TeamsView({super.key, required this.space, required this.teams});

  final SpaceDetail space;
  final List<SpaceTeam> teams;

  Future<void> _make(
    BuildContext context,
    CompanyTeamPreview preview, {
    String? only,
  }) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final made = await showMakeTeamsSheet(
      context,
      spaceId: space.id,
      preview: preview,
      only: only,
    );
    if (made) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.teamsMadeDone)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final admin = space.iAmAdmin;
    // The server answers a Space admin only: nobody else asks.
    final preview = admin
        ? ref.watch(companyTeamPreviewProvider(space.id)).value
        : null;
    final waiting = preview?.waiting ?? const <CompanyGroup>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (waiting.length >= 2)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              BvSpace.gutter,
              BvSpace.s8,
              BvSpace.gutter,
              0,
            ),
            child: _MakeCard(onTap: () => unawaited(_make(context, preview!))),
          ),
        if (waiting.length == 1)
          _NewLine(
            label: l10n.teamsNewLine(
              waiting.single.people.length,
              inOwnDirection(waiting.single.name),
            ),
            onTap: () =>
                unawaited(_make(context, preview!, only: waiting.single.key)),
          ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            BvSpace.gutter,
            BvPeopleSpec.sectionTop,
            BvSpace.gutter,
            BvPeopleSpec.sectionBottom,
          ),
          child: Text(
            l10n.spacesTeams,
            style: type.bodySm.copyWith(color: BvColors.textSecondary),
          ),
        ),
        for (final t in teams)
          _TeamRow(
            key: Key('team-row-${t.id}'),
            team: t,
            onTap: () => context.push(AppRoutes.spaceTeam(space.id, t.id)),
          ),
        // The server lets only the Space admin make a Team.
        if (admin)
          InkWell(
            key: const Key('people-new-team'),
            onTap: () => context.push(AppRoutes.spaceTeamNew(space.id)),
            splashFactory: NoSplash.splashFactory,
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: BvSpace.gutter,
                vertical: BvTeamsSpec.rowPaddingVertical,
              ),
              child: Row(
                spacing: BvSpace.s8,
                children: [
                  const Icon(
                    BvIcons.add,
                    size: BvSize.iconMd,
                    color: BvColors.iconSecondary,
                  ),
                  Expanded(
                    child: Text(
                      l10n.teamsNewByHand,
                      style: type.bodyMd.copyWith(
                        color: BvColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Make Teams from companies: the brand card at the top of TM1.
class _MakeCard extends StatelessWidget {
  const _MakeCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    return Material(
      key: const Key('teams-make-card'),
      color: BvColors.surfaceBrandSoft,
      shape: RoundedRectangleBorder(
        borderRadius: BvRadius.cardAll,
        side: const BorderSide(
          color: BvColors.borderSelected,
          width: BvStroke.thin,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BvRadius.cardAll,
        splashFactory: NoSplash.splashFactory,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(BvTeamsSpec.cardPadding),
          child: Row(
            spacing: BvTeamsSpec.rowGap,
            children: [
              const BvTeamDisc(
                size: BvTeamsSpec.cardDisc,
                icon: BvIcons.company,
                onCard: true,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: BvTeamsSpec.lineGap,
                  children: [
                    Text(
                      l10n.teamsMakeTitle,
                      style: type.emphasis.copyWith(color: BvColors.textAction),
                    ),
                    Text(
                      l10n.teamsMakeCardLine,
                      style: type.metadata.copyWith(
                        color: BvColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                BvIcons.caretForward,
                size: BvSize.iconMd,
                color: BvColors.iconAction,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "2 new people from Delta Steel: make a Team?"
class _NewLine extends StatelessWidget {
  const _NewLine({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    key: const Key('teams-new-line'),
    onTap: onTap,
    splashFactory: NoSplash.splashFactory,
    child: Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: BvSpace.gutter,
        vertical: BvTeamsSpec.rowPaddingVertical,
      ),
      child: Row(
        spacing: BvSpace.s8,
        children: [
          const Icon(
            BvIcons.company,
            size: BvSize.iconMd,
            color: BvColors.iconAction,
          ),
          Expanded(
            child: Text(
              label,
              style: BvType.of(
                context,
              ).bodySm.copyWith(color: BvColors.textAction),
            ),
          ),
          const Icon(
            BvIcons.caretForward,
            size: BvSize.iconMd,
            color: BvColors.iconAction,
          ),
        ],
      ),
    ),
  );
}

/// A Team: its mark, its name and its admin, in bold (TM1).
class _TeamRow extends StatelessWidget {
  const _TeamRow({super.key, required this.team, required this.onTap});

  final SpaceTeam team;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final admin = team.adminName;
    return InkWell(
      onTap: onTap,
      splashFactory: NoSplash.splashFactory,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: BvSpace.gutter,
        ),
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
                const BvTeamDisc(size: BvTeamsSpec.rowDisc, icon: BvIcons.team),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: BvTeamsSpec.lineGap,
                    children: [
                      Text(
                        inOwnDirection(team.name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: type.emphasis,
                      ),
                      if (admin != null)
                        Text.rich(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          TextSpan(
                            style: type.metadata.copyWith(
                              color: BvColors.textSecondary,
                            ),
                            children: [
                              TextSpan(text: '${l10n.teamRowAdmin} '),
                              TextSpan(
                                text: inOwnDirection(admin),
                                style: type.emphasisSm.copyWith(
                                  color: BvColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(
                  BvIcons.caretForward,
                  size: BvSize.iconMd,
                  color: BvColors.iconSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
