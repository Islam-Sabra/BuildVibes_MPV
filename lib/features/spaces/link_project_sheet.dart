import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/profile_page_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_search_field.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../profile/widgets/profile_parts.dart';

/// What the person chose in "Link a project".
sealed class LinkPick {
  const LinkPick();
}

/// A project from their CV. Tapping the linked one again unlinks it
/// ([entry] null).
class LinkProject extends LinkPick {
  const LinkProject(this.entry);
  final CvProjectEntry? entry;
}

/// "Add a project": the P13 flow, then back to New Space.
class LinkAddProject extends LinkPick {
  const LinkAddProject();
}

/// Overlay "Link a project" (Figma S5): your CV projects with your role,
/// searchable, and Add a project.
Future<LinkPick?> showLinkProjectSheet(
  BuildContext context, {
  required String me,
  String? selectedProjectId,
}) => showBvSheet<LinkPick>(
  context: context,
  title: AppLocalizations.of(context).spacesLinkTitle,
  builder: (_) => _LinkProject(me: me, selectedProjectId: selectedProjectId),
);

class _LinkProject extends ConsumerStatefulWidget {
  const _LinkProject({required this.me, this.selectedProjectId});

  final String me;
  final String? selectedProjectId;

  @override
  ConsumerState<_LinkProject> createState() => _LinkProjectState();
}

class _LinkProjectState extends ConsumerState<_LinkProject> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final projects =
        ref.watch(profileViewProvider(widget.me)).value?.projects ??
        const <CvProjectEntry>[];
    final q = _query.trim().toLowerCase();
    final shown = [
      for (final p in projects)
        if (q.isEmpty || p.projectName.toLowerCase().contains(q)) p,
    ];

    return Column(
      key: const Key('link-project-sheet'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: BvSpace.s12,
      children: [
        if (projects.isNotEmpty)
          BvSearchField(
            key: const Key('link-project-search'),
            placeholder: l10n.spacesLinkSearch,
            onChanged: (v) => setState(() => _query = v),
          ),
        if (projects.isEmpty) EmptyNote(l10n.projectsEmpty),
        if (shown.isNotEmpty)
          BvListGroup(
            rows: [
              for (final p in shown)
                BvListRow(
                  key: Key('link-project-${p.projectId}'),
                  title: p.projectName,
                  subtitle: l10n.spacesYourRole(p.role),
                  trailing: BvRowTrailing.check(
                    selected: p.projectId == widget.selectedProjectId,
                  ),
                  onTap: () => Navigator.of(context).pop(
                    LinkProject(
                      p.projectId == widget.selectedProjectId ? null : p,
                    ),
                  ),
                ),
            ],
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: BvButton(
            key: const Key('link-project-add'),
            label: l10n.addProject,
            icon: BvIcons.create,
            style: BvButtonStyle.tertiary,
            padded: false,
            onPressed: () => Navigator.of(context).pop(const LinkAddProject()),
          ),
        ),
      ],
    );
  }
}
