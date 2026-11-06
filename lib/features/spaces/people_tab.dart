import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../data/repositories/key_people_repository.dart';
import '../../data/repositories/space_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_avatar.dart';
import '../../shared/widgets/bv_highlight.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_pill_button.dart';
import '../../shared/widgets/bv_post_bar.dart' show BvPassChip;
import '../../shared/widgets/bv_segmented.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../entry/entry_state.dart';
import '../profile/widgets/profile_parts.dart';
import 'confirm_join_sheet.dart';
import 'key_people.dart';
import 'need_you_notice.dart';
import 'need_you_sheet.dart';
import 'offer_card.dart';
import 'pass_words.dart';
import 'remove_member.dart';
import 'space_errors.dart';
import 'teams_view.dart';
import '../../core/routing/open_thread.dart';

/// P1 · Space People (2542:34824, review 105 SP8 2670:38796): the requests
/// to join on top under "Needs you" (admins only), then everyone in the
/// Space in one list, Leads first: name, title · company, the pass and
/// their Teams, and Invite with the code for people who may invite. Who is
/// here, never how many (rule 3). Review 111 TM1: People · Teams, one
/// switch; a search is always over people. Review 121 KP1: Who to call on
/// top for everyone (under the requests for admins), then Everyone.
class PeopleTab extends ConsumerStatefulWidget {
  const PeopleTab({super.key, required this.space, this.query = ''});

  final SpaceDetail space;

  /// People's search (review 105 SP8): only those whose name, role or
  /// company has it.
  final String query;

  @override
  ConsumerState<PeopleTab> createState() => _PeopleTabState();
}

class _PeopleTabState extends ConsumerState<PeopleTab> {
  var _sending = false;

  /// TM1: Teams rather than People.
  var _teams = false;

  /// The person just let in: their row is highlighted once.
  String? _flash;
  final _flashKey = GlobalKey();

  String get _spaceId => widget.space.id;

  void _refresh() {
    ref
      ..invalidate(spacePeopleProvider(_spaceId))
      ..invalidate(spaceKeyPeopleProvider(_spaceId))
      ..invalidate(mySpacesProvider);
    if (widget.space.iAmAdmin) {
      ref.invalidate(companyTeamPreviewProvider(_spaceId));
    }
  }

  /// TM4: Confirm asks on a sheet, its Team already chosen when the
  /// person's company has one. No answer about that is no choice made.
  Future<void> _confirm(SpaceJoinRequest r, List<SpaceTeam> teams) async {
    final repo = ref.read(spaceRepositoryProvider);
    CompanyTeamMatch? match;
    try {
      match = await repo.companyTeamFor(_spaceId, r.person.id);
    } on SpaceException {
      match = null;
    }
    if (!mounted) return;
    final answer = await showConfirmJoinSheet(
      context,
      request: r,
      teams: teams,
      match: match,
    );
    if (answer != null && mounted) {
      await _letIn(r, answer.pass, answer.teamIds);
    }
  }

  Future<void> _letIn(
    SpaceJoinRequest r,
    SpacePass pass,
    List<String> teamIds,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    try {
      await ref
          .read(spaceRepositoryProvider)
          .confirmJoin(r.id, pass, teamIds: teamIds);
      // The admin may have left the tab while it went.
      if (!mounted) return;
      _refresh();
      await ref.read(spacePeopleProvider(_spaceId).future);
      if (!mounted) return;
      setState(() => _flash = r.person.id);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              l10n.peopleLetInDone(
                inOwnDirection(r.person.fullName),
                passName(l10n, pass),
              ),
            ),
          ),
        );
      // Into their section: brought into view, then the ring.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final row = _flashKey.currentContext;
        if (row != null && row.mounted) {
          Scrollable.ensureVisible(
            row,
            alignment: 0.5,
            duration: BvMotion.base,
          );
        }
      });
    } on SpaceException catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _decline(SpaceJoinRequest r) async {
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(spaceRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await repo.declineJoin(r.id);
      if (!mounted) return;
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

  /// F79: a person, on a short sheet: their face, name, role and company
  /// and their pass; View profile and Message for everyone; Pass and Remove
  /// from Space only for a Space admin. For yourself, View profile only.
  Future<void> _openPerson(SpaceMember m, {required bool isMe}) async {
    final l10n = AppLocalizations.of(context);
    final router = GoRouter.of(context);
    final admin = widget.space.iAmAdmin && !isMe;
    // Review 113 (18): hidden where the server would refuse.
    final people = ref.read(spacePeopleProvider(_spaceId)).value;
    final blocked = await needYouBlocked(ref);
    if (!mounted) return;
    final mayCall =
        people != null &&
        mayCallNeedYou(
          space: widget.space,
          people: people,
          me: ref.read(authUserIdProvider).value,
          target: m.person.id,
          blocked: blocked,
        );
    final picked = await showBvSheet<_PersonAction>(
      context: context,
      builder: (sheet) => Column(
        key: Key('person-sheet-${m.person.id}'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PersonHead(member: m),
          const SizedBox(height: BvSpace.s8),
          BvListRow(
            key: const Key('person-profile'),
            leading: const BvRowIcon(BvIcons.profile),
            title: l10n.settingsViewProfile,
            onTap: () => Navigator.of(sheet).pop(_PersonAction.profile),
          ),
          if (mayCall)
            BvListRow(
              key: const Key('person-need-you'),
              leading: const BvRowIcon(BvIcons.needYou),
              title: l10n.needYouNow,
              onTap: () => Navigator.of(sheet).pop(_PersonAction.needYou),
            ),
          if (!isMe)
            BvListRow(
              key: const Key('person-message'),
              leading: const BvRowIcon(BvIcons.chat),
              title: l10n.profileMessage,
              onTap: () => Navigator.of(sheet).pop(_PersonAction.message),
            ),
          if (admin) ...[
            BvListRow(
              key: const Key('person-pass'),
              leading: const BvRowIcon(BvIcons.pass),
              title: l10n.peoplePassRow,
              subtitle: passName(l10n, m.pass),
              onTap: () => Navigator.of(sheet).pop(_PersonAction.pass),
            ),
            BvListRow(
              key: const Key('person-remove'),
              leading: const BvRowIcon(BvIcons.delete, destructive: true),
              title: l10n.spacesRemove,
              destructive: true,
              trailing: const BvRowTrailing.none(),
              onTap: () => Navigator.of(sheet).pop(_PersonAction.remove),
            ),
          ],
        ],
      ),
    );
    if (!mounted) return;
    switch (picked) {
      case _PersonAction.profile:
        await router.push(AppRoutes.person(m.person.id));
      case _PersonAction.needYou:
        await showNeedYouSheet(context, spaceId: _spaceId, member: m);
      case _PersonAction.message:
        await openDmThread(router, AppRoutes.messagesWith(m.person.id));
      case _PersonAction.pass:
        await router.push(AppRoutes.spaceMember(_spaceId, m.person.id));
        if (mounted) _refresh();
      case _PersonAction.remove:
        await _remove(m);
      case null:
        break;
    }
  }

  Future<void> _remove(SpaceMember member) =>
      holdToRemove(context, ref, spaceId: _spaceId, member: member);

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

  Future<void> _copyCode(SpaceInvite invite) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: invite.code));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.spacesCodeCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final me = ref.watch(authUserIdProvider).value;
    final people = ref.watch(spacePeopleProvider(_spaceId));
    final data = people.value;
    // Who to call: nothing shows while it loads or if it can't be read.
    final keyPeople = ref.watch(spaceKeyPeopleProvider(_spaceId)).value;
    // Removed here, its undo bar still showing: gone at once (review 94).
    final removing = beingRemoved(ref, _spaceId);
    // Who may invite follows Space info; the rest see no code (review 67).
    final invite = widget.space.canInvite
        ? ref.watch(spaceInviteProvider(_spaceId)).value
        : null;

    if (data == null) {
      return people.hasError
          ? Padding(
              padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
              child: EmptyNote(l10n.errorGeneric),
            )
          : const Center(child: CircularProgressIndicator());
    }

    Widget section(String label) => Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        BvSpace.gutter,
        BvPeopleSpec.sectionTop,
        BvSpace.gutter,
        BvPeopleSpec.sectionBottom,
      ),
      child: Text(
        label,
        style: type.bodySm.copyWith(color: BvColors.textSecondary),
      ),
    );

    final lang = Localizations.localeOf(context).languageCode;
    final query = widget.query.trim().toLowerCase();
    bool found(SpacePerson p) =>
        query.isEmpty ||
        [
          p.fullName,
          ?p.roleLabel(lang),
          ?p.companyLabel,
        ].any((t) => t.toLowerCase().contains(query));
    // One list (SP8), Leads, then Crew, then Viewers.
    final members = [
      for (final pass in SpacePass.values)
        for (final m in data.members)
          if (m.pass == pass &&
              !removing.contains(m.person.id) &&
              found(m.person))
            m,
    ];
    final requests = [
      for (final r in data.requests)
        if (found(r.person)) r,
    ];

    final teams = data.teams;
    final admin = widget.space.iAmAdmin;
    final hasTeams = teams.isNotEmpty || admin;
    final showTeams = _teams && hasTeams && query.isEmpty;
    final whoToCall =
        !showTeams && query.isEmpty && (keyPeople?.hasAnyone ?? false)
        ? keyPeople!.toCall
        : null;
    // Review 122 KP0: the Space admin, while there are no key roles.
    final setWhoToCall =
        admin &&
        !showTeams &&
        query.isEmpty &&
        keyPeople != null &&
        keyPeople.roles.isEmpty;

    return RefreshIndicator(
      onRefresh: () async {
        _refresh();
        await ref.read(spacePeopleProvider(_spaceId).future);
      },
      child: ListView(
        key: const Key('space-people'),
        padding: const EdgeInsetsDirectional.only(bottom: BvSpace.s32),
        children: [
          if (hasTeams && query.isEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                BvSpace.gutter,
                BvSpace.s8,
                BvSpace.gutter,
                0,
              ),
              child: BvSegmented<bool>(
                value: showTeams,
                onChanged: (v) => setState(() => _teams = v),
                segments: [
                  BvSegment(
                    key: const Key('people-view-people'),
                    value: false,
                    label: l10n.spacesTabPeople,
                  ),
                  BvSegment(
                    key: const Key('people-view-teams'),
                    value: true,
                    label: l10n.spacesTeams,
                  ),
                ],
              ),
            ),
          if (showTeams)
            TeamsView(
              space: widget.space,
              teams: teams,
              members: data.members,
              keyPeople: keyPeople,
            ),
          if (!showTeams && requests.isNotEmpty)
            section(l10n.peopleNeedsYouRequests),
          if (!showTeams)
            for (final r in requests)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  BvSpace.gutter,
                  BvPeopleSpec.requestTop,
                  BvSpace.gutter,
                  0,
                ),
                child: _RequestCard(
                  request: r,
                  sending: _sending,
                  onDecline: () => _decline(r),
                  onOpen: () => unawaited(_confirm(r, teams)),
                ),
              ),
          if (whoToCall != null)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                BvSpace.gutter,
                BvPeopleSpec.sectionTop,
                BvSpace.gutter,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: BvKeyPeopleSpec.cardGap,
                children: [
                  const KeyPeopleHead(),
                  KeyPeopleCards(spaceId: _spaceId, toCall: whoToCall),
                ],
              ),
            ),
          if (setWhoToCall)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                BvSpace.gutter,
                BvPeopleSpec.sectionTop,
                BvSpace.gutter,
                0,
              ),
              child: OfferCard(
                key: const Key('kp0-set-who-to-call'),
                icon: BvIcons.shieldCheck,
                title: l10n.keyPeopleSetTitle,
                onTap: () => context.push(AppRoutes.spaceKeyPeople(_spaceId)),
              ),
            ),
          if (!showTeams && members.isNotEmpty)
            section(
              whoToCall != null || setWhoToCall
                  ? l10n.keyPeopleEveryone
                  : l10n.peopleInThisSpace,
            ),
          if (!showTeams)
            for (final m in members)
              _MemberRow(
                key: m.person.id == _flash ? _flashKey : null,
                member: m,
                teams: [
                  for (final t in teams)
                    if (t.memberIds.contains(m.person.id)) t,
                ],
                isMe: m.person.id == me,
                flash: m.person.id == _flash ? _flash : null,
                onTap: () => unawaited(_openPerson(m, isMe: m.person.id == me)),
              ),
          if (query.isNotEmpty && members.isEmpty && requests.isEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
              child: EmptyNote(l10n.peopleSearchNothing(widget.query.trim())),
            ),
          if (invite != null && query.isEmpty && !showTeams)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                BvSpace.gutter,
                BvPeopleSpec.inviteTop,
                BvSpace.gutter,
                0,
              ),
              child: _InviteRow(
                code: invite.grouped,
                onTap: () => _copyCode(invite),
              ),
            ),
        ],
      ),
    );
  }
}

/// A request to join: quiet and bordered (P1). Confirm opens TM4's sheet.
class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.sending,
    required this.onDecline,
    required this.onOpen,
  });

  final SpaceJoinRequest request;
  final bool sending;
  final VoidCallback onDecline;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final p = request.person;

    return Container(
      key: Key('request-${request.id}'),
      padding: const EdgeInsetsDirectional.all(BvPeopleSpec.requestPadding),
      decoration: BoxDecoration(
        color: BvColors.surfaceElevated,
        borderRadius: BvPeopleSpec.requestRadius,
        border: Border.all(color: BvColors.borderDefault, width: BvStroke.thin),
      ),
      child: Row(
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
                  p.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.bodyMd,
                ),
                RoleCompanyLine(person: p, lang: lang),
              ],
            ),
          ),
          // SP8: Decline · Confirm; Confirm asks for the pass.
          BvPillButton(
            key: Key('request-decline-${request.id}'),
            label: l10n.spacesDecline,
            quiet: true,
            onTap: sending ? null : onDecline,
          ),
          BvPillButton(
            key: Key('request-let-in-${request.id}'),
            label: l10n.peopleConfirm,
            strong: true,
            onTap: sending ? null : onOpen,
          ),
        ],
      ),
    );
  }
}

/// A member: avatar, name, role (and "admin"), and the pass tag in its
/// colour on the end side (P1).
class _MemberRow extends StatelessWidget {
  const _MemberRow({
    super.key,
    required this.member,
    required this.teams,
    required this.isMe,
    required this.flash,
    required this.onTap,
  });

  final SpaceMember member;

  /// The Teams they are in, as chips beside the pass (SP8).
  final List<SpaceTeam> teams;

  static const _teamsShown = 2;
  final bool isMe;
  final Object? flash;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final p = member.person;
    return BvHighlight(
      flash: flash,
      child: InkWell(
        key: Key('member-${p.id}'),
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
                vertical: BvPeopleSpec.rowPaddingVertical,
              ),
              child: Row(
                spacing: BvPeopleSpec.rowGap,
                children: [
                  BvAvatar(
                    name: p.fullName,
                    size: BvAvatarSize.md,
                    tint: BvAvatarTints.forId(p.id),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: BvPeopleSpec.lineGap,
                      children: [
                        Text(
                          isMe
                              ? joinMeta([p.fullName, l10n.spacesYouTag])
                              : p.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: type.labelLg,
                        ),
                        RoleCompanyLine(person: p, lang: lang),
                        Wrap(
                          spacing: BvPeopleSpec.tagGap,
                          runSpacing: BvPeopleSpec.tagGap,
                          children: [
                            BvPassChip(
                              key: Key('member-pass-${p.id}'),
                              label: passName(l10n, member.pass),
                              tone: passTone(member.pass),
                            ),
                            if (member.isAdmin)
                              _TeamTag(
                                key: Key('member-admin-${p.id}'),
                                label: l10n.peopleAdmin,
                              ),
                            // Review 121: every Team they're in; past two,
                            // "+1".
                            for (final t in teams.take(_teamsShown))
                              _TeamTag(
                                key: Key('member-team-${p.id}-${t.id}'),
                                icon: BvIcons.team,
                                label: t.name,
                              ),
                            if (teams.length > _teamsShown)
                              _TeamTag(
                                key: Key('member-teams-more-${p.id}'),
                                // "+1", not "1+", in Arabic too.
                                label: ltrRun(
                                  l10n.peopleTeamsMore(
                                    '${teams.length - _teamsShown}',
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "BIM Manager · AECOX" (SP8): the title (the headline, otherwise the
/// trade), then the company: a registered company in ink, medium; a typed
/// one plain grey, as typed (rule 4). Nothing when neither is known.
class RoleCompanyLine extends StatelessWidget {
  const RoleCompanyLine({super.key, required this.person, required this.lang});

  final SpacePerson person;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final quiet = type.metadata.copyWith(color: BvColors.textSecondary);
    final role = person.roleLabel(lang);
    final company = person.companyLabel;
    if (role == null && company == null) return const SizedBox.shrink();
    return Row(
      spacing: BvSpace.s4,
      children: [
        if (role != null)
          Flexible(
            child: Text(
              role,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: quiet,
            ),
          ),
        if (role != null && company != null) Text(metaDot, style: quiet),
        if (company != null)
          Flexible(
            child: Text(
              company,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: person.companyRegistered
                  ? type.emphasisSm.copyWith(color: BvColors.textPrimary)
                  : quiet,
            ),
          ),
      ],
    );
  }
}

/// A Team the person is in, beside their pass (SP8): white, bordered, the
/// people icon first.
class _TeamTag extends StatelessWidget {
  const _TeamTag({super.key, required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: BvPeopleSpec.tagPadding,
    decoration: BoxDecoration(
      color: BvColors.surfaceElevated,
      borderRadius: BvRadius.smallAll,
      border: Border.all(color: BvColors.borderSubtle, width: BvStroke.thin),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      spacing: BvSpace.s6,
      children: [
        if (icon != null)
          Icon(icon, size: BvSize.iconSm, color: BvColors.iconPrimary),
        Text(
          label,
          style: BvType.of(
            context,
          ).labelSm.copyWith(color: BvColors.textPrimary),
        ),
      ],
    ),
  );
}

/// "Invite with the code K7Q 4MD": a tap copies the code (P1).
class _InviteRow extends StatelessWidget {
  const _InviteRow({required this.code, required this.onTap});

  final String code;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    return Material(
      key: const Key('people-invite-code'),
      color: BvColors.surfaceElevated,
      borderRadius: BvRadius.controlAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: BvRadius.controlAll,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(BvPeopleSpec.invitePadding),
          child: Row(
            spacing: BvPeopleSpec.inviteGap,
            children: [
              const Icon(
                BvIcons.copy,
                size: BvPeopleSpec.inviteIcon,
                color: BvColors.iconPrimary,
              ),
              Expanded(
                child: Text(
                  // The code is Latin, in every language.
                  l10n.peopleInviteCode(inOwnDirection(code)),
                  style: type.bodySm,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _PersonAction { profile, needYou, message, pass, remove }

/// F79: the top of a person's sheet: face, name, role · company, pass.
class _PersonHead extends StatelessWidget {
  const _PersonHead({required this.member});

  final SpaceMember member;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final p = member.person;
    // A typed company stays plain text (rule 4).
    final line = joinMeta([?p.roleLabel(lang), ?p.companyLabel]);
    return Row(
      spacing: BvPeopleSpec.rowGap,
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
              if (line.isNotEmpty)
                Text(
                  line,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.bodySm.copyWith(color: BvColors.textSecondary),
                ),
            ],
          ),
        ),
        BvPassChip(
          label: passName(l10n, member.pass),
          tone: passTone(member.pass),
        ),
      ],
    );
  }
}
