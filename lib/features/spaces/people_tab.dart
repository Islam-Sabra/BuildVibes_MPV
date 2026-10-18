import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/ago.dart';
import '../../core/l10n/bidi.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/space.dart';
import '../../data/repositories/space_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_search_field.dart';
import '../entry/entry_state.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../profile/widgets/profile_parts.dart';
import 'confirm_sheet.dart';
import 'member_pass_screen.dart';
import 'pass_words.dart';
import 'space_errors.dart';
import 'widgets/space_person_row.dart';

/// S10k · Space People: search, the requests to join (admins only), the
/// Teams (each with up to three faces, never a number: rule 3), then the
/// Space admins and Members.
class PeopleTab extends ConsumerStatefulWidget {
  const PeopleTab({super.key, required this.space});

  final SpaceDetail space;

  @override
  ConsumerState<PeopleTab> createState() => _PeopleTabState();
}

class _PeopleTabState extends ConsumerState<PeopleTab> {
  var _query = '';

  String get _spaceId => widget.space.id;

  void _refresh() {
    ref
      ..invalidate(spacePeopleProvider(_spaceId))
      ..invalidate(mySpacesProvider);
  }

  String _askedLine(SpaceJoinRequest r) {
    final l10n = AppLocalizations.of(context);
    final now = ref.read(clockProvider)();
    return joinMeta([
      l10n.spacesAsked(formatAgo(l10n, r.createdAt.toLocal(), now)),
      r.invitedByName == null
          ? l10n.spacesViaCode
          : l10n.spacesViaCodeFrom(inOwnDirection(r.invitedByName!)),
    ]);
  }

  Future<void> _confirm(SpaceJoinRequest r) async {
    final choice = await showConfirmSheet(
      context,
      request: r,
      askedLine: _askedLine(r),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case DeclineRequest():
        await _decline(r);
      case ConfirmWithPass(:final pass):
        final l10n = AppLocalizations.of(context);
        try {
          await ref.read(spaceRepositoryProvider).confirmJoin(r.id, pass);
          _refresh();
          if (!mounted) return;
          context.push(
            AppRoutes.spaceMember(_spaceId, r.person.id),
            extra: MemberPassOpen(
              message: l10n.spacesJoinedAs(
                r.person.fullName,
                passName(l10n, pass),
              ),
            ),
          );
        } on SpaceException catch (e) {
          if (mounted) _showError(e);
        }
    }
  }

  Future<void> _decline(SpaceJoinRequest r) async {
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(spaceRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await repo.declineJoin(r.id);
      _refresh();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.spacesDeclined(inOwnDirection(r.person.firstName)),
          ),
          action: SnackBarAction(
            key: const Key('decline-undo'),
            label: l10n.spacesUndo,
            onPressed: () async {
              try {
                await repo.undoDecline(r.id);
              } on SpaceException {
                // Already asked again, or answered by another admin.
              }
              if (mounted) _refresh();
            },
          ),
        ),
      );
    } on SpaceException catch (e) {
      if (mounted) _showError(e);
    }
  }

  void _showError(SpaceException e) {
    final l10n = AppLocalizations.of(context);
    if (e.failure == SpaceFailure.rule) {
      // Another admin answered first.
      showSpaceMessage(context, l10n.spacesAlreadyAnswered);
      _refresh();
    } else {
      showSpaceError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final me = ref.watch(authUserIdProvider).value;
    final people = ref.watch(spacePeopleProvider(_spaceId));
    final data = people.value;

    if (data == null) {
      return people.hasError
          ? Padding(
              padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
              child: EmptyNote(l10n.errorGeneric),
            )
          : const Center(child: CircularProgressIndicator());
    }

    final q = _query.trim().toLowerCase();
    bool matches(SpacePerson p) =>
        q.isEmpty ||
        p.fullName.toLowerCase().contains(q) ||
        (p.roleLabel(lang) ?? '').toLowerCase().contains(q) ||
        (p.companyLabel ?? '').toLowerCase().contains(q);

    final requests = [
      for (final r in data.requests)
        if (matches(r.person)) r,
    ];
    final owners = [
      for (final m in data.members)
        if (m.isAdmin && matches(m.person)) m,
    ];
    final members = [
      for (final m in data.members)
        if (!m.isAdmin && matches(m.person)) m,
    ];
    final teams = data.teams;

    Widget section(String label) => Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        BvSpace.gutter,
        BvSpace.s16,
        BvSpace.gutter,
        BvSpace.s8,
      ),
      child: Text(
        label,
        style: type.labelMd.copyWith(color: BvColors.textSecondary),
      ),
    );

    String? memberLine(SpaceMember m) {
      if (m.isAdmin) return l10n.spacesAdminTag;
      return joinMeta([
        l10n.spacesPassLine(passName(l10n, m.pass)),
        for (final t in data.teamsOf(m.person.id)) t.name,
      ]);
    }

    return RefreshIndicator(
      onRefresh: () async {
        _refresh();
        await ref.read(spacePeopleProvider(_spaceId).future);
      },
      child: ListView(
        key: const Key('space-people'),
        padding: const EdgeInsetsDirectional.only(bottom: BvSpace.s32),
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              BvSpace.gutter,
              BvSpace.s12,
              BvSpace.gutter,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: BvSpace.s12,
              children: [
                BvSearchField(
                  key: const Key('people-search'),
                  placeholder: l10n.spacesSearchMembers,
                  onChanged: (v) => setState(() => _query = v),
                ),
                if (widget.space.canInvite && q.isEmpty)
                  BvButton(
                    key: const Key('space-invite'),
                    label: l10n.spacesInvitePeople,
                    icon: BvIcons.people,
                    style: BvButtonStyle.secondary,
                    expand: true,
                    onPressed: () =>
                        context.push(AppRoutes.spaceInvite(_spaceId)),
                  ),
              ],
            ),
          ),
          if (requests.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                BvSpace.gutter,
                BvSpace.s16,
                BvSpace.gutter,
                BvSpace.s8,
              ),
              child: Text(
                l10n.spacesRequestsTitle,
                style: type.overline.copyWith(color: BvColors.textAction),
              ),
            ),
            for (var i = 0; i < requests.length; i++) ...[
              if (i > 0) const _Divider(),
              _RequestCard(
                request: requests[i],
                askedLine: _askedLine(requests[i]),
                onDecline: () => _decline(requests[i]),
                onConfirm: () => _confirm(requests[i]),
              ),
            ],
          ],
          if (q.isEmpty && (teams.isNotEmpty || widget.space.iAmAdmin)) ...[
            section(l10n.spacesTeams),
            for (var i = 0; i < teams.length; i++) ...[
              if (i > 0) const SpaceRowDivider(),
              BvListRow(
                key: Key('team-row-${teams[i].id}'),
                leading: const BvRowIcon(BvIcons.team, ink: true),
                title: teams[i].name,
                subtitle: teams[i].memberIds.contains(me)
                    ? l10n.spacesInTeam
                    : null,
                // Who is in it, never how many (review 54 A4).
                trailing: BvRowTrailing.faces([
                  for (final m in data.members)
                    if (teams[i].memberIds.contains(m.person.id))
                      (
                        name: m.person.fullName,
                        tint: BvAvatarTints.forId(m.person.id),
                      ),
                ]),
                onTap: () =>
                    context.push(AppRoutes.spaceTeam(_spaceId, teams[i].id)),
              ),
            ],
            if (widget.space.iAmAdmin)
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: BvSpace.s8,
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: BvButton(
                    key: const Key('people-new-team'),
                    label: l10n.spacesNewTeam,
                    style: BvButtonStyle.tertiary,
                    size: BvButtonSize.medium,
                    onPressed: () =>
                        context.push(AppRoutes.spaceTeamNew(_spaceId)),
                  ),
                ),
              ),
          ],
          if (owners.isNotEmpty) ...[
            section(l10n.spacesAdminSection),
            for (var i = 0; i < owners.length; i++) ...[
              if (i > 0) const SpaceRowDivider(),
              SpacePersonRow(
                key: Key('member-${owners[i].person.id}'),
                person: owners[i].person,
                line: memberLine(owners[i]),
                isMe: owners[i].person.id == me,
                onTap: () => context.push(
                  AppRoutes.spaceMember(_spaceId, owners[i].person.id),
                ),
              ),
            ],
          ],
          if (members.isNotEmpty) ...[
            section(l10n.spacesMembers),
            for (var i = 0; i < members.length; i++) ...[
              if (i > 0) const SpaceRowDivider(),
              SpacePersonRow(
                key: Key('member-${members[i].person.id}'),
                person: members[i].person,
                line: memberLine(members[i]),
                isMe: members[i].person.id == me,
                onTap: () => context.push(
                  AppRoutes.spaceMember(_spaceId, members[i].person.id),
                ),
              ),
            ],
          ],
          if (q.isNotEmpty &&
              requests.isEmpty &&
              owners.isEmpty &&
              members.isEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
              child: EmptyNote(l10n.spacesNoMatch),
            ),
        ],
      ),
    );
  }
}

/// Between requests on the peach band.
class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: BvColors.surfaceBrandSoft,
    child: Divider(
      height: BvStroke.thin,
      thickness: BvStroke.thin,
      color: BvColors.borderDefault,
    ),
  );
}

/// A request on the peach band: name, role · company, when and how they
/// asked, then Decline and Confirm.
class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.askedLine,
    required this.onDecline,
    required this.onConfirm,
  });

  final SpaceJoinRequest request;
  final String askedLine;
  final VoidCallback onDecline;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final p = request.person;
    final role = joinMeta([?p.roleLabel(lang), ?p.companyLabel]);
    return ColoredBox(
      key: Key('request-${request.id}'),
      color: BvColors.surfaceBrandSoft,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: BvSpace.gutter,
          vertical: BvSpace.s16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: BvSpace.s4,
          children: [
            Text(p.fullName, style: type.titleMd),
            if (role.isNotEmpty)
              Text(
                role,
                style: type.bodySm.copyWith(color: BvColors.textSecondary),
              ),
            Text(
              askedLine,
              style: type.metadata.copyWith(color: BvColors.textSecondary),
            ),
            const SizedBox(height: BvSpace.s8),
            Row(
              spacing: BvSpace.s12,
              children: [
                Expanded(
                  child: BvButton(
                    key: Key('request-decline-${request.id}'),
                    label: l10n.spacesDecline,
                    style: BvButtonStyle.secondary,
                    size: BvButtonSize.medium,
                    expand: true,
                    onPressed: onDecline,
                  ),
                ),
                Expanded(
                  child: BvButton(
                    key: Key('request-confirm-${request.id}'),
                    label: l10n.spacesConfirm,
                    size: BvButtonSize.medium,
                    expand: true,
                    onPressed: onConfirm,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
