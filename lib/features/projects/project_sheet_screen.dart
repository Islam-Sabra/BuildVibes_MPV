import '../feed/post_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart';
import '../../core/l10n/months.dart';
import '../../data/models/project.dart';
import '../../data/repositories/project_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_badge.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_title_block.dart';
import '../entry/entry_state.dart';
import '../profile/edit/edit_common.dart';
import '../profile/widgets/profile_parts.dart';
import 'widgets/project_sheets.dart';

/// The signed-in person's CV entry and the people who show the project.
final projectPeopleProvider = FutureProvider.autoDispose
    .family<({MyCvEntry? mine, List<ProjectPerson> others}), String>((
      ref,
      projectId,
    ) async {
      final me = ref.watch(authUserIdProvider).value;
      final repo = ref.watch(projectRepositoryProvider);
      if (me == null) return (mine: null, others: const <ProjectPerson>[]);
      final results = await Future.wait<Object?>([
        repo.myCvEntry(projectId, me),
        repo.people(projectId, me: me),
      ]);
      return (
        mine: results[0] as MyCvEntry?,
        others: results[1]! as List<ProjectPerson>,
      );
    });

/// PJ1 · Project sheet: a shared record with no owner. The title block,
/// your CV entry, and people who put it on their CV and show it. Spaces,
/// companies and posts on the project come with later tasks.
class ProjectSheetScreen extends ConsumerWidget {
  const ProjectSheetScreen({super.key, required this.projectId});

  final String projectId;

  Future<void> _suggest(
    BuildContext context,
    WidgetRef ref,
    ProjectRecord project,
  ) async {
    final result = await showSuggestEditSheet(
      context,
      projectName: project.name,
    );
    if (result == null || !context.mounted) return;
    try {
      await ref
          .read(projectRepositoryProvider)
          .suggestEdit(project.id, result.$1, result.$2);
    } on Exception {
      if (context.mounted) showSaveError(context);
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).suggestionSent)),
    );
  }

  Future<void> _addToCv(
    BuildContext context,
    WidgetRef ref,
    ProjectRecord project,
  ) async {
    final input = await showCvEntrySheet(
      context,
      projectName: project.name,
      role: ref.read(myProfileProvider).value?.headline,
    );
    if (input == null || !context.mounted) return;
    try {
      await ref.read(projectRepositoryProvider).addToCv(project.id, input);
    } on Exception {
      if (context.mounted) showSaveError(context);
      return;
    }
    if (!context.mounted) return;
    ref.invalidate(projectPeopleProvider(project.id));
    afterSave(context, ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final locale = Localizations.localeOf(context);
    final tag = locale.toLanguageTag();
    final project = ref.watch(projectProvider(projectId));
    final peopleAsync = ref.watch(projectPeopleProvider(projectId));
    final people = peopleAsync.value;

    Widget sectionLabel(String text) => Padding(
      padding: const EdgeInsetsDirectional.only(
        top: BvSpace.s24,
        bottom: BvSpace.s8,
      ),
      child: Text(
        text,
        style: type.overline.copyWith(color: BvColors.textSecondary),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(l10n.projectTitle, style: type.titleLg),
      ),
      body: project.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: BvButton(
            label: l10n.commonRetry,
            style: BvButtonStyle.secondary,
            onPressed: () => ref.invalidate(projectProvider(projectId)),
          ),
        ),
        data: (p) {
          if (p == null) return Center(child: EmptyNote(l10n.errorGeneric));
          final mine = people?.mine;
          return ListView(
            key: const Key('project-sheet'),
            padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
            children: [
              BvTitleBlock(
                label: l10n.projectRecordLabel,
                stamp: l10n.sharedRecordStamp,
                rows: [
                  [BvTitleCell(label: l10n.cellProjectName, value: p.name)],
                  [
                    BvTitleCell(
                      label: l10n.cellType,
                      value: p.typeName?.of(locale),
                    ),
                    BvTitleCell(
                      label: l10n.cellLocation,
                      value: p.location(locale.languageCode),
                    ),
                  ],
                  [
                    BvTitleCell(
                      label: l10n.cellStarted,
                      value: p.start == null
                          ? null
                          : formatMonth(p.start!, tag),
                    ),
                    BvTitleCell(
                      label: l10n.cellEnded,
                      value: p.end == null
                          ? l10n.present
                          : p.endExpected
                          ? l10n.expectedMonth(formatMonth(p.end!, tag))
                          : formatMonth(p.end!, tag),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: BvSpace.s12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: BvSpace.s12,
                children: [
                  Expanded(
                    child: Text(
                      l10n.projectNoOwnerNote,
                      style: type.bodySm.copyWith(
                        color: BvColors.textSecondary,
                      ),
                    ),
                  ),
                  BvButton(
                    key: const Key('project-suggest'),
                    label: l10n.suggestEdit,
                    style: BvButtonStyle.tertiary,
                    size: BvButtonSize.medium,
                    padded: false,
                    onPressed: () => _suggest(context, ref, p),
                  ),
                ],
              ),
              sectionLabel(l10n.onYourCv),
              if (peopleAsync.hasError)
                BvButton(
                  key: const Key('project-people-retry'),
                  label: l10n.commonRetry,
                  style: BvButtonStyle.secondary,
                  expand: true,
                  onPressed: () =>
                      ref.invalidate(projectPeopleProvider(projectId)),
                )
              else if (mine == null)
                BvButton(
                  key: const Key('project-add-to-cv'),
                  label: l10n.addToCv,
                  style: BvButtonStyle.secondary,
                  expand: true,
                  onPressed: people == null
                      ? null
                      : () => _addToCv(context, ref, p),
                )
              else
                ProfileCard(
                  child: Column(
                    key: const Key('project-my-cv'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: BvSpace.s4,
                    children: [
                      Text(mine.role, style: type.titleMd),
                      Text(
                        formatMonthRange(
                          l10n,
                          tag,
                          start: mine.start,
                          end: mine.end,
                        ),
                        style: type.bodySm.copyWith(
                          color: BvColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: BvSpace.s4),
                      BvBadge(
                        label: mine.confirmed
                            ? l10n.proofConfirmed
                            : l10n.proofWaiting,
                        tone: mine.confirmed
                            ? BvBadgeTone.positive
                            : BvBadgeTone.neutral,
                      ),
                    ],
                  ),
                ),
              sectionLabel(l10n.peopleOnProject),
              Text(
                l10n.peopleOnProjectNote,
                style: type.bodySm.copyWith(color: BvColors.textSecondary),
              ),
              const SizedBox(height: BvSpace.s8),
              if (people == null)
                const SizedBox.shrink()
              else if (people.others.isEmpty)
                ProfileCard(child: EmptyNote(l10n.peopleOnProjectEmpty))
              else
                ProfileCard(
                  padding: false,
                  child: DividedColumn(
                    children: [
                      for (final person in people.others)
                        InkWell(
                          key: Key('project-person-${person.profileId}'),
                          onTap: () =>
                              context.push('/people/${person.profileId}'),
                          child: Padding(
                            padding: const EdgeInsetsDirectional.all(
                              BvProfileSpec.cardPadding,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: BvSpace.s2,
                              children: [
                                Text(person.fullName, style: type.titleMd),
                                Text(
                                  joinMeta([
                                    person.role,
                                    formatMonthRange(
                                      l10n,
                                      tag,
                                      start: person.start,
                                      end: person.end,
                                    ),
                                  ]),
                                  style: type.bodySm.copyWith(
                                    color: BvColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              // Site updates tagged with this project (review 16).
              sectionLabel(l10n.projectPosts),
              PostList(
                source: PostSource.project(p.id),
                empty: l10n.projectPostsEmpty,
              ),
            ],
          );
        },
      ),
    );
  }
}
