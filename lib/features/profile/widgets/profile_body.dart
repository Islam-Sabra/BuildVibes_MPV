import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/around_specs.dart';
import '../../../core/design/bv_icons.dart';
import '../../../core/design/bv_specs.dart';
import '../../../core/design/bv_tokens.dart';
import '../../../core/routing/app_routes.dart';
import '../../../data/models/profile.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../shared/widgets/bv_button.dart';
import '../../../shared/widgets/bv_list_row.dart';
import '../../../shared/widgets/bv_tabs.dart';
import '../../feed/post_list.dart';
import '../delivered_work.dart';
import 'profile_parts.dart';

/// Tabs and their content under a profile header: Overview, Posts,
/// Projects, Experience. [own] adds the proof card, "Finish your profile"
/// and the add buttons.
class ProfileBody extends StatefulWidget {
  const ProfileBody({super.key, required this.profile, required this.own});

  final ProfileView profile;
  final bool own;

  @override
  State<ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<ProfileBody> {
  var _tab = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BvTabs.small(
          labels: [
            l10n.profileTabOverview,
            l10n.profileTabPosts,
            l10n.profileTabProjects,
            l10n.profileTabExperience,
          ],
          selectedIndex: _tab,
          onSelect: (i) => setState(() => _tab = i),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            BvSpace.gutter,
            BvProfileHeadSpec.bodyPaddingTop,
            BvSpace.gutter,
            BvSpace.s32,
          ),
          child: switch (_tab) {
            0 => _Overview(
              profile: widget.profile,
              own: widget.own,
              onSeeAllProjects: () => setState(() => _tab = 2),
            ),
            1 => PostList(source: PostSource.person(widget.profile.id)),
            2 => _Projects(profile: widget.profile, own: widget.own),
            _ => _Experience(profile: widget.profile, own: widget.own),
          },
        ),
      ],
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({
    required this.profile,
    required this.own,
    required this.onSeeAllProjects,
  });

  final ProfileView profile;
  final bool own;
  final VoidCallback onSeeAllProjects;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final (done, total) = profile.completion;
    final projects = profile.projects
        .where((p) => own || p.showOnProfile)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BvProfileSpec.sectionGap,
      children: [
        ProofOfWork(
          key: const Key('work-delivered'),
          profileId: profile.id,
          own: own,
        ),
        if (own || projects.isNotEmpty)
          Column(
            key: Key(own ? 'proof-card' : 'profile-projects'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: BvProjectProofSpec.gap,
            children: [
              Text(
                l10n.profileProjectsConfirmed,
                style: type.labelMd.copyWith(color: BvColors.textSecondary),
              ),
              if (projects.isEmpty) ...[
                Text(l10n.proofEmptyTitle, style: type.titleMd),
                EmptyNote(l10n.proofEmptyBody),
                BvButton(
                  key: const Key('proof-add-project'),
                  label: l10n.addProject,
                  style: BvButtonStyle.secondary,
                  expand: true,
                  onPressed: () => context.push(AppRoutes.projectsAdd),
                ),
              ] else ...[
                for (final p in projects.take(3)) ProjectProofRow(entry: p),
                if (projects.length > 3)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: BvButton(
                      label: l10n.profileSeeAllProjects,
                      style: BvButtonStyle.tertiary,
                      size: BvButtonSize.medium,
                      padded: false,
                      onPressed: onSeeAllProjects,
                    ),
                  ),
              ],
            ],
          ),
        if (own && done < total)
          ClipRRect(
            borderRadius: BvRadius.cardAll,
            child: BvListRow(
              key: const Key('finish-profile'),
              leading: const BvRowIcon(BvIcons.workItems),
              title: l10n.finishProfileTitle,
              subtitle: l10n.finishProfileProgress(done, total),
              onTap: () => context.push(AppRoutes.profileEdit),
            ),
          ),
        if (profile.openTo != null && !profile.openTo!.isEmpty)
          OpenToSection(openTo: profile.openTo!, own: own),
        if ((profile.about ?? '').isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: BvSpace.s8,
            children: [
              SectionTitle(l10n.profileAbout),
              UserText(profile.about!, style: type.bodyMd),
            ],
          ),
      ],
    );
  }
}

class _Projects extends StatelessWidget {
  const _Projects({required this.profile, required this.own});

  final ProfileView profile;
  final bool own;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final projects = profile.projects
        .where((p) => own || p.showOnProfile)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BvSpace.s12,
      children: [
        if (projects.isEmpty)
          EmptyNote(l10n.projectsEmpty)
        else
          DividedColumn(
            children: [
              for (final p in projects) CvProjectRow(entry: p, showProof: true),
            ],
          ),
        if (own)
          BvButton(
            key: const Key('projects-add'),
            label: l10n.addProject,
            icon: BvIcons.create,
            style: BvButtonStyle.secondary,
            expand: true,
            onPressed: () => context.push(AppRoutes.projectsAdd),
          ),
      ],
    );
  }
}

class _Experience extends StatelessWidget {
  const _Experience({required this.profile, required this.own});

  final ProfileView profile;
  final bool own;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BvSpace.s12,
      children: [
        if (profile.experience.isEmpty)
          EmptyNote(l10n.experienceEmpty)
        else
          DividedColumn(
            children: [
              for (final e in profile.experience) ExperienceRow(entry: e),
            ],
          ),
        if (own)
          BvButton(
            key: const Key('experience-add-tab'),
            label: l10n.experienceAdd,
            icon: BvIcons.create,
            style: BvButtonStyle.secondary,
            expand: true,
            onPressed: () => context.push(AppRoutes.profileEditExperienceForm),
          ),
      ],
    );
  }
}
