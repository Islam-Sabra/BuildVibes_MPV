import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/people_library_specs.dart';
import '../../core/l10n/bidi.dart';
import '../../data/models/company_teams.dart';
import '../../data/repositories/space_repository.dart';
import '../../data/repositories/work_repository.dart' show newUuid;
import '../../data/models/space.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_avatar.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_controls.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_sheet.dart';
import 'pass_words.dart';
import 'space_errors.dart';

/// Review 111 TM2: the companies found, ticked, each with its people's
/// count and a Team admin; Create makes them all at once. [only] is the
/// one company from the Teams line. True when Teams were made.
Future<bool> showMakeTeamsSheet(
  BuildContext context, {
  required String spaceId,
  required CompanyTeamPreview preview,
  required List<SpaceTeam> teams,
  String? only,
}) async {
  final l10n = AppLocalizations.of(context);
  final state = _MakeTeams(
    CompanyTeamPlan.of(preview, only: only, teams: teams),
  );
  final made = await showBvSheet<bool>(
    context: context,
    title: l10n.teamsMakeTitle,
    subtitle: l10n.teamsMakeIntro,
    foot: (_) => _Create(spaceId: spaceId, state: state),
    builder: (_) => _Rows(state: state),
  );
  return made ?? false;
}

/// What the rows and the sheet's foot share.
class _MakeTeams extends ChangeNotifier {
  _MakeTeams(this.plan);

  final CompanyTeamPlan plan;

  /// Made once, so a retry of the same choices sends the same id; a changed
  /// choice is a new step.
  String? id;
  var saving = false;

  void changed() {
    id = null;
    notifyListeners();
  }

  void busy(bool on) {
    saving = on;
    id ??= newUuid();
    notifyListeners();
  }
}

class _Rows extends StatelessWidget {
  const _Rows({required this.state});

  final _MakeTeams state;

  Future<void> _pickAdmin(BuildContext context, CompanyPlanRow row) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showBvSheet<String>(
      context: context,
      title: l10n.teamAdminBadge,
      builder: (sheet) => Column(
        key: const Key('make-admin-sheet'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final p in state.plan.adminChoices(row))
            BvListRow(
              key: Key('make-admin-${p.id}'),
              leading: BvAvatar(name: p.name),
              title: inOwnDirection(p.name),
              subtitle: passName(l10n, p.pass),
              trailing: const BvRowTrailing.none(),
              onTap: () => Navigator.of(sheet).pop(p.id),
            ),
        ],
      ),
    );
    if (picked == null) return;
    state.plan.pickAdmin(row, picked);
    state.changed();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (context, _) => Column(
      key: const Key('make-teams-sheet'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in state.plan.shown)
          _CompanyRow(
            key: Key('make-team-${row.group.key}'),
            row: row,
            admin: state.plan.adminName(row),
            onTick: state.saving
                ? null
                : (on) {
                    row.ticked = on;
                    state.changed();
                  },
            onMerge: (key) {
              state.plan.merge(row, key);
              state.changed();
            },
            onMergeTeam: (teamId) {
              state.plan.mergeTeam(row, teamId);
              state.changed();
            },
            onTap: () => _pickAdmin(context, row),
          ),
      ],
    ),
  );
}

class _CompanyRow extends StatelessWidget {
  const _CompanyRow({
    super.key,
    required this.row,
    required this.admin,
    required this.onTick,
    required this.onMerge,
    required this.onMergeTeam,
    required this.onTap,
  });

  final CompanyPlanRow row;

  /// Who is Team admin once Create is done (V6).
  final String? admin;
  final ValueChanged<bool>? onTick;
  final ValueChanged<String> onMerge;
  final ValueChanged<String> onMergeTeam;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final quiet = type.metadata.copyWith(color: BvColors.textSecondary);
    final group = row.group;
    final name = inOwnDirection(group.shownName);
    final admin = this.admin;
    return InkWell(
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
              BvCheckbox(
                key: Key('make-team-tick-${group.key}'),
                value: row.ticked,
                onChanged: onTick,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: BvTeamsSpec.lineGap,
                  children: [
                    Row(
                      spacing: BvSpace.s4,
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: type.emphasis,
                          ),
                        ),
                        // The one count here: how many this Team takes in.
                        Text('$metaDot ${row.people.length}', style: quiet),
                      ],
                    ),
                    Row(
                      spacing: BvSpace.s4,
                      children: [
                        const Icon(
                          BvIcons.teamAdmin,
                          size: BvSize.iconSm,
                          color: BvColors.textPositive,
                        ),
                        Expanded(
                          child: Text(
                            admin == null
                                ? l10n.teamsAdminNone
                                : l10n.teamsAdminLine(inOwnDirection(admin)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: quiet,
                          ),
                        ),
                      ],
                    ),
                    for (final g in row.lookAlikes)
                      _MergeLine(
                        key: Key('make-team-merge-${g.key}'),
                        label: row.merged.contains(g.key)
                            ? l10n.teamsMergedUndo(inOwnDirection(g.name))
                            : l10n.teamsMergeOffer(
                                inOwnDirection(g.name),
                                g.people.length,
                              ),
                        onTap: () => onMerge(g.key),
                      ),
                    for (final t in row.similarTeams)
                      _MergeLine(
                        key: Key('make-team-into-${group.key}-${t.teamId}'),
                        label: row.intoTeam?.teamId == t.teamId
                            ? l10n.teamsMergedIntoTeam(
                                inOwnDirection(t.teamName),
                              )
                            : l10n.teamsMergeIntoTeam(
                                inOwnDirection(t.teamName),
                              ),
                        onTap: () => onMergeTeam(t.teamId),
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
    );
  }
}

/// "A.B.C Contracting" (2) looks the same: merge; or like the Team
/// "Delta Steel": add to it. A soft pill, tapped.
class _MergeLine extends StatelessWidget {
  const _MergeLine({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: BvTeamsSpec.mergePadding,
        decoration: const BoxDecoration(
          color: BvColors.surfaceBrandSoft,
          borderRadius: BvRadius.controlAll,
        ),
        child: Row(
          spacing: BvSpace.s6,
          children: [
            const Icon(
              BvIcons.merge,
              size: BvSize.iconSm,
              color: BvColors.textAction,
            ),
            Expanded(
              child: Text(
                label,
                style: BvType.of(
                  context,
                ).emphasisSm.copyWith(color: BvColors.textAction),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Create N Teams, at the sheet's foot.
class _Create extends ConsumerWidget {
  const _Create({required this.spaceId, required this.state});

  final String spaceId;
  final _MakeTeams state;

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    state.busy(true);
    try {
      await ref
          .read(spaceRepositoryProvider)
          .createCompanyTeams(state.id!, spaceId, state.plan.groups());
      ref
        ..invalidate(spacePeopleProvider(spaceId))
        ..invalidate(companyTeamPreviewProvider(spaceId));
      if (context.mounted) Navigator.of(context).pop(true);
    } on SpaceException catch (e) {
      state.busy(false);
      if (!context.mounted) return;
      if (e.failure == SpaceFailure.duplicate) {
        showSpaceMessage(context, l10n.spacesTeamDuplicate);
      } else {
        showSpaceError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => BvButton(
        key: const Key('make-teams-create'),
        label: l10n.teamsCreate(state.plan.ticked),
        icon: BvIcons.check,
        expand: true,
        onPressed: state.saving || !state.plan.ready
            ? null
            : () => _create(context, ref),
      ),
    );
  }
}
