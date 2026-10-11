import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/bv_icons.dart';
import '../../../core/design/bv_tokens.dart';
import '../../../core/l10n/bidi.dart';
import '../../../core/l10n/months.dart';
import '../../../core/routing/app_routes.dart';
import '../../../data/models/profile.dart';
import '../../../data/repositories/profile_page_repository.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../shared/widgets/bv_button.dart';
import '../../../shared/widgets/bv_list_row.dart';
import '../../entry/widgets/entry_scaffold.dart';
import '../widgets/profile_parts.dart';
import 'edit_common.dart';

/// Projects on the CV, each with "Show on my profile", and Add a project.
class CvProjectsScreen extends ConsumerWidget {
  const CvProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final me = myId(ref);
    final p = me == null ? null : ref.watch(profileViewProvider(me)).value;
    final projects = p?.projects ?? const <CvProjectEntry>[];

    Future<void> toggle(CvProjectEntry e, bool show) async {
      await ref.read(profilePageRepositoryProvider).setCvVisibility(e.id, show);
      if (me != null) ref.invalidate(profileViewProvider(me));
    }

    return EntryScaffold(
      title: l10n.profileTabProjects,
      bodyPadding: const EdgeInsetsDirectional.symmetric(vertical: BvSpace.s16),
      footer: BvButton(
        key: const Key('cv-add-project'),
        label: l10n.addProject,
        icon: BvIcons.create,
        expand: true,
        onPressed: () => context.push(AppRoutes.projectsAdd),
      ),
      body: projects.isEmpty
          ? Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: BvSpace.gutter,
              ),
              child: EmptyNote(l10n.projectsEmpty),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // What the switches mean.
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    BvSpace.gutter,
                    0,
                    BvSpace.gutter,
                    BvSpace.s8,
                  ),
                  child: Text(
                    l10n.cvShowOnProfile,
                    textAlign: TextAlign.end,
                    style: BvType.of(
                      context,
                    ).labelMd.copyWith(color: BvColors.textSecondary),
                  ),
                ),
                BvListGroup(
                  rows: [
                    for (final e in projects)
                      BvListRow(
                        key: Key('cv-row-${e.id}'),
                        leading: const BvRowIcon(BvIcons.crane),
                        title: e.projectName,
                        subtitle: joinMeta([
                          e.role,
                          formatMonthRange(
                            l10n,
                            locale,
                            start: e.start,
                            end: e.end,
                          ),
                        ]),
                        trailing: BvRowTrailing.toggle(
                          value: e.showOnProfile,
                          onChanged: (v) => toggle(e, v),
                        ),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}
