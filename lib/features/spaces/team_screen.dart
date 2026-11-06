import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/space.dart';
import '../../data/repositories/space_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_badge.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_dialog.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../../shared/widgets/bv_text_field.dart';
import '../entry/entry_state.dart';
import '../profile/widgets/profile_parts.dart';
import 'new_team_screen.dart';
import 'space_errors.dart';
import 'widgets/space_person_row.dart';

/// S11k · Team, review 111 TM3: who is in it, the Team admin first with the
/// green badge. Add people for the Team admin and the Space admin; for the
/// Space admin ⋯ on a person (Make Team admin) and on the Team (Rename,
/// Delete).
class TeamScreen extends ConsumerWidget {
  const TeamScreen({super.key, required this.spaceId, required this.teamId});

  final String spaceId;
  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final me = ref.watch(authUserIdProvider).value;
    final space = ref.watch(spaceDetailProvider(spaceId)).value;
    final people = ref.watch(spacePeopleProvider(spaceId)).value;
    final team = people?.teams.where((t) => t.id == teamId).firstOrNull;

    if (space == null || people == null || team == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final members = [
      for (final m in people.members)
        if (team.adminId == m.person.id) m,
      for (final m in people.members)
        if (team.memberIds.contains(m.person.id) && team.adminId != m.person.id)
          m,
    ];
    final admin = space.iAmAdmin;
    // The server lets the Team admin change this Team's people only.
    final manages = admin || (me != null && team.adminId == me);

    void refresh() => ref.invalidate(spacePeopleProvider(spaceId));

    Future<void> run(Future<void> Function(SpaceRepository repo) call) async {
      try {
        await call(ref.read(spaceRepositoryProvider));
        refresh();
      } on SpaceException catch (e) {
        if (!context.mounted) return;
        if (e.failure == SpaceFailure.duplicate) {
          showSpaceMessage(context, l10n.spacesTeamDuplicate);
        } else {
          showSpaceError(context, e);
        }
      }
    }

    Future<void> addPeople() async {
      final picked = await showBvSheet<Set<String>>(
        context: context,
        title: l10n.spacesTeamPeopleTitle,
        builder: (_) => _PickPeople(
          members: people.members,
          initial: team.memberIds,
          keep: team.adminId,
        ),
      );
      if (picked == null) return;
      await run((repo) => repo.setTeamMembers(teamId, picked.toList()));
    }

    Future<void> personMore(SpaceMember m) async {
      final yes = await showBvSheet<bool>(
        context: context,
        builder: (sheet) => ClipRRect(
          borderRadius: BvRadius.cardAll,
          child: BvListRow(
            key: const Key('team-make-admin'),
            leading: const BvRowIcon(BvIcons.teamAdmin),
            title: l10n.teamMakeAdmin,
            trailing: const BvRowTrailing.none(),
            onTap: () => Navigator.of(sheet).pop(true),
          ),
        ),
      );
      if (yes != true) return;
      await run((repo) => repo.setTeamAdmin(teamId, m.person.id));
    }

    Future<void> rename() async {
      final name = await showBvSheet<String>(
        context: context,
        form: true,
        title: l10n.spacesRenameTeam,
        builder: (_) => _RenameTeam(name: team.name),
      );
      if (name == null || name == team.name) return;
      await run((repo) => repo.renameTeam(teamId, name));
    }

    Future<void> delete() async {
      final yes = await showBvDialog(
        context: context,
        title: l10n.spacesDeleteTeamTitle(team.name),
        body: l10n.spacesDeleteTeamBody,
        cancelLabel: l10n.commonCancel,
        confirmLabel: l10n.spacesDeleteButton,
        destructive: true,
      );
      if (!yes || !context.mounted) return;
      final navigator = Navigator.of(context);
      try {
        await ref.read(spaceRepositoryProvider).deleteTeam(teamId);
        refresh();
        navigator.pop();
      } on SpaceException catch (e) {
        if (context.mounted) showSpaceError(context, e);
      }
    }

    Future<void> more() async {
      final pick = await showBvSheet<String>(
        context: context,
        builder: (sheetContext) => ClipRRect(
          borderRadius: BvRadius.cardAll,
          child: BvListGroup(
            rows: [
              BvListRow(
                key: const Key('team-rename'),
                leading: const BvRowIcon(BvIcons.edit),
                title: l10n.spacesRenameTeam,
                trailing: const BvRowTrailing.none(),
                onTap: () => Navigator.of(sheetContext).pop('rename'),
              ),
              BvListRow(
                key: const Key('team-delete'),
                leading: const BvRowIcon(BvIcons.delete, destructive: true),
                title: l10n.spacesDeleteTeam,
                trailing: const BvRowTrailing.none(),
                destructive: true,
                onTap: () => Navigator.of(sheetContext).pop('delete'),
              ),
            ],
          ),
        ),
      );
      if (pick == 'rename') await rename();
      if (pick == 'delete') await delete();
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: BvSpace.s2,
          children: [
            Text(team.name, style: type.titleLg),
            Text(
              l10n.daybookRowTeam,
              style: type.metadata.copyWith(color: BvColors.textSecondary),
            ),
          ],
        ),
        actions: [
          if (admin)
            IconButton(
              key: const Key('team-more'),
              tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
              icon: const Icon(BvIcons.more),
              onPressed: more,
            ),
        ],
      ),
      body: ListView(
        key: const Key('team-screen'),
        padding: const EdgeInsetsDirectional.only(bottom: BvSpace.s32),
        children: [
          if (members.isEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: BvSpace.gutter,
              ),
              child: EmptyNote(l10n.spacesNoTeamMembers),
            ),
          for (final m in members) ...[
            SpacePersonRow(
              key: Key('team-member-${m.person.id}'),
              person: m.person,
              isMe: m.person.id == me,
              onPage: true,
              nameMark: m.person.id == team.adminId
                  ? BvBadge(
                      key: const Key('team-admin-badge'),
                      label: l10n.teamAdminBadge,
                      tone: BvBadgeTone.positiveSoft,
                      icon: BvIcons.teamAdmin,
                    )
                  : null,
              trailing: admin && m.person.id != team.adminId
                  ? IconButton(
                      key: Key('team-person-more-${m.person.id}'),
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).moreButtonTooltip,
                      icon: const Icon(
                        BvIcons.more,
                        size: BvSize.iconMd,
                        color: BvColors.iconSecondary,
                      ),
                      onPressed: () => personMore(m),
                    )
                  : null,
              onTap: () =>
                  context.push(AppRoutes.spaceMember(spaceId, m.person.id)),
            ),
            const Padding(
              padding: EdgeInsetsDirectional.symmetric(
                horizontal: BvSpace.gutter,
              ),
              child: Divider(
                height: BvStroke.thin,
                thickness: BvStroke.thin,
                color: BvColors.borderDefault,
              ),
            ),
          ],
          if (manages)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: BvSpace.s8,
                ),
                child: BvButton(
                  key: const Key('team-add-people'),
                  label: l10n.spacesAddPeople,
                  icon: BvIcons.invite,
                  style: BvButtonStyle.tertiary,
                  onPressed: addPeople,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: BvSpace.gutter,
              vertical: BvSpace.s4,
            ),
            child: Text(
              l10n.teamAdminNote,
              style: type.metadata.copyWith(color: BvColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _PickPeople extends StatefulWidget {
  const _PickPeople({
    required this.members,
    required this.initial,
    required this.keep,
  });

  final List<SpaceMember> members;
  final Set<String> initial;

  /// The Team admin stays in: only the Space admin changes who that is.
  final String? keep;

  @override
  State<_PickPeople> createState() => _PickPeopleState();
}

class _PickPeopleState extends State<_PickPeople> {
  late final _picked = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      key: const Key('team-pick-sheet'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: BvSpace.s16,
      children: [
        ClipRRect(
          borderRadius: BvRadius.cardAll,
          child: TeamMemberPicker(
            members: widget.members,
            selected: _picked,
            onChanged: (id, on) => setState(() {
              if (on) {
                _picked.add(id);
              } else if (id != widget.keep) {
                _picked.remove(id);
              }
            }),
          ),
        ),
        BvButton(
          key: const Key('team-pick-save'),
          label: l10n.save,
          expand: true,
          onPressed: () => Navigator.of(context).pop(_picked),
        ),
      ],
    );
  }
}

class _RenameTeam extends StatefulWidget {
  const _RenameTeam({required this.name});

  final String name;

  @override
  State<_RenameTeam> createState() => _RenameTeamState();
}

class _RenameTeamState extends State<_RenameTeam> {
  late final _name = TextEditingController(text: widget.name);
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BvSheetForm(
      gap: BvSpace.s16,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: BvSpace.s16,
        children: [
          BvTextField(
            key: const Key('team-rename-field'),
            label: l10n.spacesTeamName,
            controller: _name,
            autofocus: true,
            maxLength: NewTeamScreen.nameMax,
            error: _error,
          ),
        ],
      ),
      action: BvButton(
        key: const Key('team-rename-save'),
        label: l10n.save,
        expand: true,
        onPressed: () {
          final name = _name.text.trim();
          if (name.isEmpty) {
            setState(() => _error = l10n.spacesTeamNameRequired);
            return;
          }
          Navigator.of(context).pop(name);
        },
      ),
    );
  }
}
