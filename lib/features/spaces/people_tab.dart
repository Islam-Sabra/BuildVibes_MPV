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
import '../../data/models/space.dart';
import '../../data/repositories/space_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_avatar.dart';
import '../../shared/widgets/bv_controls.dart';
import '../../shared/widgets/bv_highlight.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_pill_button.dart';
import '../../shared/widgets/bv_post_bar.dart' show BvPassChip;
import '../../shared/widgets/bv_sheet.dart';
import '../entry/entry_state.dart';
import '../profile/widgets/profile_parts.dart';
import 'pass_words.dart';
import 'remove_member.dart';
import 'space_errors.dart';
import '../../core/routing/open_thread.dart';

/// P1 · Space People (2542:34824, review 105 SP8 2670:38796): the requests
/// to join on top under "Needs you" (admins only), then everyone in the
/// Space in one list, Leads first: name, title · company, the pass and
/// their Teams; then the Teams as chips, and Invite with the code for
/// people who may invite. Who is here, never how many (rule 3).
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
  /// The request opened in place (P2), and the pass chosen there: none
  /// at first (review 69 1a).
  String? _open;
  SpacePass? _pass;
  var _sending = false;

  /// The person just let in: their row is highlighted once.
  String? _flash;
  final _flashKey = GlobalKey();

  String get _spaceId => widget.space.id;

  void _refresh() {
    ref
      ..invalidate(spacePeopleProvider(_spaceId))
      ..invalidate(mySpacesProvider);
  }

  Future<void> _letIn(SpaceJoinRequest r, SpacePass pass) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    try {
      await ref.read(spaceRepositoryProvider).confirmJoin(r.id, pass);
      // The admin may have left the tab while it went.
      if (!mounted) return;
      _refresh();
      await ref.read(spacePeopleProvider(_spaceId).future);
      if (!mounted) return;
      setState(() {
        _open = null;
        _pass = null;
        _flash = r.person.id;
      });
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
      if (_open == r.id) setState(() => _open = null);
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
      setState(() => _open = null);
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

    return RefreshIndicator(
      onRefresh: () async {
        _refresh();
        await ref.read(spacePeopleProvider(_spaceId).future);
      },
      child: ListView(
        key: const Key('space-people'),
        padding: const EdgeInsetsDirectional.only(bottom: BvSpace.s32),
        children: [
          if (requests.isNotEmpty) section(l10n.peopleNeedsYouRequests),
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
                open: _open == r.id,
                pass: _open == r.id ? _pass : null,
                sending: _sending,
                onDecline: () => _decline(r),
                onOpen: () => setState(() {
                  _open = r.id;
                  _pass = null;
                }),
                onPass: (p) => setState(() => _pass = p),
                onLetIn: (p) => _letIn(r, p),
              ),
            ),
          if (members.isNotEmpty) section(l10n.peopleInThisSpace),
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
          if (query.isEmpty && (teams.isNotEmpty || admin)) ...[
            section(l10n.spacesTeams),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: BvSpace.gutter,
                vertical: BvSpace.s4,
              ),
              child: Wrap(
                spacing: BvPeopleSpec.chipGap,
                runSpacing: BvPeopleSpec.chipGap,
                children: [
                  for (final t in teams)
                    _TeamChip(
                      key: Key('team-chip-${t.id}'),
                      label: t.name,
                      onTap: () =>
                          context.push(AppRoutes.spaceTeam(_spaceId, t.id)),
                    ),
                  // The server lets only the Space admin make a Team.
                  if (admin)
                    _TeamChip(
                      key: const Key('people-new-team'),
                      label: l10n.peopleNewTeam,
                      outlined: true,
                      onTap: () =>
                          context.push(AppRoutes.spaceTeamNew(_spaceId)),
                    ),
                ],
              ),
            ),
          ],
          if (invite != null && query.isEmpty)
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

/// A request to join: quiet and bordered (P1). "Let in" opens the three
/// passes in place (P2); nothing is chosen first, so the pill says
/// "Choose a pass" until one is.
class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.open,
    required this.pass,
    required this.sending,
    required this.onDecline,
    required this.onOpen,
    required this.onPass,
    required this.onLetIn,
  });

  final SpaceJoinRequest request;
  final bool open;
  final SpacePass? pass;
  final bool sending;
  final VoidCallback onDecline;
  final VoidCallback onOpen;
  final ValueChanged<SpacePass> onPass;
  final ValueChanged<SpacePass> onLetIn;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final p = request.person;
    final chosen = pass;

    return Container(
      key: Key('request-${request.id}'),
      padding: const EdgeInsetsDirectional.all(BvPeopleSpec.requestPadding),
      decoration: BoxDecoration(
        color: BvColors.surfaceElevated,
        borderRadius: BvPeopleSpec.requestRadius,
        border: Border.all(color: BvColors.borderDefault, width: BvStroke.thin),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
              if (!open)
                BvPillButton(
                  key: Key('request-let-in-${request.id}'),
                  label: l10n.peopleConfirm,
                  strong: true,
                  onTap: onOpen,
                ),
            ],
          ),
          if (open) ...[
            const SizedBox(height: BvPeopleSpec.optionsTop),
            for (final option in SpacePass.values) ...[
              if (option != SpacePass.values.first)
                const SizedBox(height: BvPeopleSpec.optionsGap),
              _PassOption(
                key: Key('request-pass-${option.name}'),
                label: passName(l10n, option),
                selected: option == chosen,
                onTap: sending ? null : () => onPass(option),
              ),
            ],
            const SizedBox(height: BvPeopleSpec.optionsTop),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: BvPillButton(
                key: Key('request-confirm-${request.id}'),
                label: chosen == null
                    ? l10n.peopleChoosePass
                    : l10n.peopleLetInAs(passName(l10n, chosen)),
                onTap: chosen == null || sending ? null : () => onLetIn(chosen),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One of P2's passes: a radio and its name, the chosen one outlined in
/// orange. One single choice (rule 6).
class _PassOption extends StatelessWidget {
  const _PassOption({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      child: Material(
        color: BvColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BvPeopleSpec.optionRadius,
          side: selected
              ? const BorderSide(
                  color: BvColors.borderSelected,
                  width: BvStroke.medium,
                )
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BvPeopleSpec.optionRadius,
          splashFactory: NoSplash.splashFactory,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: BvPeopleSpec.optionHeight,
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: BvPeopleSpec.optionPadding,
              ),
              child: Row(
                spacing: BvPeopleSpec.optionGap,
                children: [
                  ExcludeSemantics(
                    child: BvRadio(selected: selected, small: true),
                  ),
                  Expanded(child: Text(label, style: type.bodyMd)),
                ],
              ),
            ),
          ),
        ),
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
                            for (final t in teams)
                              _TeamTag(
                                key: Key('member-team-${p.id}-${t.id}'),
                                icon: BvIcons.team,
                                label: t.name,
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
    final quiet = BvType.of(
      context,
    ).metadata.copyWith(color: BvColors.textSecondary);
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
                  ? quiet.copyWith(
                      color: BvColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    )
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

/// A Team as a chip (opens the Team, S11k); "+ New team" is [outlined].
class _TeamChip extends StatelessWidget {
  const _TeamChip({
    super.key,
    required this.label,
    required this.onTap,
    this.outlined = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return Material(
      color: outlined ? BvColors.surfaceElevated : BvColors.surfaceSubtle,
      shape: RoundedRectangleBorder(
        borderRadius: BvRadius.roundAll,
        side: outlined
            ? const BorderSide(
                color: BvColors.borderDefault,
                width: BvStroke.thin,
              )
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: SizedBox(
          height: BvPeopleSpec.chipHeight,
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: BvPeopleSpec.chipPadding,
            ),
            child: Center(
              widthFactor: 1,
              child: Text(label, style: type.bodySm),
            ),
          ),
        ),
      ),
    );
  }
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

enum _PersonAction { profile, message, pass, remove }

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
