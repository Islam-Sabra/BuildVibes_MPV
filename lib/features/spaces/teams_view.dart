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
import '../../data/models/key_people.dart';
import '../../data/models/space.dart';
import '../../data/repositories/space_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_avatar.dart';
import '../../shared/widgets/bv_badge.dart';
import '../../shared/widgets/bv_card.dart';
import 'key_people.dart';
import 'make_teams_sheet.dart';
import 'offer_card.dart';
import 'who_sees_sheet.dart';

/// Review 111 TM1, review 121 OC1: People's Teams side, the Space as an
/// organisation. For a Space admin first, what can be made from companies:
/// the card while 2 or more companies wait, the one line while one does.
/// Then who runs the Space, Who to call as chips, and each Team as a card
/// with its Team admin and up to 5 faces, never a count (rule 3). New Team
/// by hand for the Space admin.
class TeamsView extends ConsumerWidget {
  const TeamsView({
    super.key,
    required this.space,
    required this.teams,
    this.members = const [],
    this.keyPeople,
  });

  final SpaceDetail space;
  final List<SpaceTeam> teams;
  final List<SpaceMember> members;
  final KeyPeople? keyPeople;

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
      teams: teams,
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
    final admins = [
      for (final m in members)
        if (m.isAdmin) m,
    ];
    final toCall = keyPeople?.toCall ?? const [];

    Widget label(String text) => Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        BvSpace.gutter,
        BvPeopleSpec.sectionTop,
        BvSpace.gutter,
        BvPeopleSpec.sectionBottom,
      ),
      child: Text(
        text,
        style: type.bodySm.copyWith(color: BvColors.textSecondary),
      ),
    );

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
            child: OfferCard(
              key: const Key('teams-make-card'),
              icon: BvIcons.company,
              title: l10n.teamsMakeTitle,
              line: l10n.teamsMakeCardLine,
              onTap: () => unawaited(_make(context, preview!)),
            ),
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
        if (admins.isNotEmpty) ...[
          label(l10n.orgRunsThisSpace),
          Padding(
            padding: _gutter,
            child: _Admins(admins: admins),
          ),
        ],
        if (toCall.isNotEmpty) ...[
          label(l10n.keyPeopleWhoToCall),
          Padding(
            padding: _gutter,
            child: Wrap(
              spacing: BvKeyPeopleSpec.chipGap,
              runSpacing: BvKeyPeopleSpec.chipGap,
              children: [
                for (final c in toCall)
                  _CallChip(
                    key: Key('org-call-${c.role.id}-${c.holder.person.id}'),
                    role: c.role,
                    person: c.holder.person,
                    onTap: () => showKeyPersonSheet(
                      context,
                      spaceId: space.id,
                      role: c.role,
                      holder: c.holder,
                    ),
                  ),
              ],
            ),
          ),
        ],
        label(l10n.spacesTeams),
        // Review 122 TM0: why nothing is offered yet.
        if (preview != null && waiting.isEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              BvSpace.gutter,
              0,
              BvSpace.gutter,
              BvKeyPeopleSpec.cardGap,
            ),
            child: _CompanyHint(text: l10n.teamsCompanyHint),
          ),
        for (final t in teams)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              BvSpace.gutter,
              0,
              BvSpace.gutter,
              BvKeyPeopleSpec.cardGap,
            ),
            child: _TeamCard(
              key: Key('team-row-${t.id}'),
              team: t,
              members: members,
              onTap: () => context.push(AppRoutes.spaceTeam(space.id, t.id)),
            ),
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

/// TM0: a quiet note with the info mark.
class _CompanyHint extends StatelessWidget {
  const _CompanyHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    key: const Key('teams-company-hint'),
    decoration: BoxDecoration(
      color: BvColors.surfaceElevated,
      borderRadius: BvKeyPeopleSpec.hintRadius,
      border: Border.all(color: BvColors.borderSubtle, width: BvStroke.thin),
    ),
    child: Padding(
      padding: BvKeyPeopleSpec.hintPadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: BvKeyPeopleSpec.hintGap,
        children: [
          const Icon(
            BvIcons.info,
            size: BvSize.iconSm,
            color: BvColors.iconSecondary,
          ),
          Expanded(
            child: Text(
              text,
              style: BvType.of(
                context,
              ).metadata.copyWith(color: BvColors.textSecondary),
            ),
          ),
        ],
      ),
    ),
  );
}

const _gutter = EdgeInsetsDirectional.symmetric(horizontal: BvSpace.gutter);

/// Runs this Space: every Space admin, with the Space admin tag.
class _Admins extends StatelessWidget {
  const _Admins({required this.admins});

  final List<SpaceMember> admins;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    return BvCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BvKeyPeopleSpec.cardGap,
        children: [
          for (final m in admins)
            Row(
              key: Key('org-admin-${m.person.id}'),
              spacing: BvKeyPeopleSpec.faceGap,
              children: [
                BvAvatar(
                  name: m.person.fullName,
                  size: BvAvatarSize.post,
                  tint: BvAvatarTints.forId(m.person.id),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: BvKeyPeopleSpec.lineGap,
                    children: [
                      Text(
                        inOwnDirection(m.person.fullName),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: type.emphasis,
                      ),
                      BvBadge(
                        label: l10n.spacesAdminRow,
                        tone: BvBadgeTone.brand,
                        icon: BvIcons.checkCircle,
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Who to call, compact: the face, the first name and the role.
class _CallChip extends StatelessWidget {
  const _CallChip({
    super.key,
    required this.role,
    required this.person,
    required this.onTap,
  });

  final KeyRole role;
  final SpacePerson person;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return Material(
      color: BvColors.surfaceBrandSoft,
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        splashFactory: NoSplash.splashFactory,
        child: Padding(
          padding: BvKeyPeopleSpec.chipPadding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: BvSpace.s8,
            children: [
              BvAvatar(
                name: person.fullName,
                size: BvAvatarSize.xsm,
                tint: BvAvatarTints.forId(person.id),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    inOwnDirection(person.firstName),
                    style: type.emphasisSm,
                  ),
                  Text(
                    inOwnDirection(role.name),
                    style: type.metadata.copyWith(color: BvColors.textAction),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A Team (OC1): its mark and name, its Team admin, and up to 5 faces of
/// its other people. A person in several Teams shows in each.
class _TeamCard extends StatelessWidget {
  const _TeamCard({
    super.key,
    required this.team,
    required this.members,
    required this.onTap,
  });

  final SpaceTeam team;
  final List<SpaceMember> members;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final adminName = team.adminName;
    final adminId = team.adminId;
    final faces = [
      for (final m in members)
        if (team.memberIds.contains(m.person.id) && m.person.id != adminId)
          m.person,
    ].take(BvKeyPeopleSpec.faces);
    return BvCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BvKeyPeopleSpec.cardGap,
        children: [
          Row(
            spacing: BvTeamsSpec.rowGap,
            children: [
              const BvTeamDisc(size: BvTeamsSpec.whoDisc, icon: BvIcons.team),
              Expanded(
                child: Text(
                  inOwnDirection(team.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.emphasis,
                ),
              ),
              const Icon(
                BvIcons.caretForward,
                size: BvSize.iconMd,
                color: BvColors.iconSecondary,
              ),
            ],
          ),
          if (adminName != null && adminId != null)
            Row(
              spacing: BvSpace.s8,
              children: [
                BvAvatar(
                  name: adminName,
                  size: BvAvatarSize.xs,
                  tint: BvAvatarTints.forId(adminId),
                ),
                Flexible(
                  child: Text(
                    inOwnDirection(adminName),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: type.labelSm.copyWith(color: BvColors.textPrimary),
                  ),
                ),
                BvBadge(
                  label: l10n.teamAdminBadge,
                  tone: BvBadgeTone.positiveSoft,
                  icon: BvIcons.teamAdmin,
                ),
              ],
            ),
          if (faces.isNotEmpty)
            Row(
              spacing: BvKeyPeopleSpec.faceSpacing,
              children: [
                for (final p in faces)
                  BvAvatar(
                    key: Key('org-face-${team.id}-${p.id}'),
                    name: p.fullName,
                    size: BvAvatarSize.xs,
                    tint: BvAvatarTints.forId(p.id),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
