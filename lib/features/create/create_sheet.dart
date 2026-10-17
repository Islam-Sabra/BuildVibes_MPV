import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/space.dart';
import '../../data/repositories/space_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../../shared/widgets/bv_space_tile.dart';
import '../profile/widgets/profile_parts.dart';
import '../spaces/code_sheet.dart';
import '../spaces/space_screen.dart' show SpaceOpen;
import '../spaces/spaces_state.dart';

/// Opened by Create in the My Spaces header (S1): New Space or Enter an
/// invite code.
Future<void> showSpacesCreateSheet(BuildContext context) => showBvSheet(
  context: context,
  title: AppLocalizations.of(context).navCreate,
  builder: (_) => const CreateSheet(),
);

class CreateSheet extends StatelessWidget {
  const CreateSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ClipRRect(
      key: const Key('create-sheet'),
      borderRadius: BvRadius.cardAll,
      child: BvListGroup(rows: _spaceStarts(context, l10n)),
    );
  }
}

/// New Space and Enter an invite code, as rows of the sheet at
/// [context]. The sheet closes first; then the next step opens from the
/// page below.
List<BvListRow> _spaceStarts(BuildContext context, AppLocalizations l10n) => [
  BvListRow(
    key: const Key('create-new-space'),
    leading: const BvRowIcon(BvIcons.crane),
    title: l10n.spacesNewTitle,
    onTap: () {
      final router = GoRouter.of(context);
      Navigator.of(context).pop();
      router.push(AppRoutes.spacesNew);
    },
  ),
  BvListRow(
    key: const Key('create-enter-code'),
    leading: const BvRowIcon(BvIcons.team),
    title: l10n.spacesEnterCode,
    onTap: () {
      final navigator = Navigator.of(context);
      final page = navigator.context;
      navigator.pop();
      showInviteCodeSheet(page);
    },
  ),
];

/// The bottom bar's Create (review 50 F1): a small choice, "Post to
/// everyone" (the Home feed, H2) or "Work item in a Space ▸". A work item
/// never leaves its Space, so it is written there: the Space's daybook
/// opens with the card at Now.
Future<void> showCreateChoice(
  BuildContext context, {
  required VoidCallback onPost,
}) => showBvSheet<void>(
  context: context,
  title: AppLocalizations.of(context).navCreate,
  builder: (_) => _CreateChoice(onPost: onPost),
);

class _CreateChoice extends StatelessWidget {
  const _CreateChoice({required this.onPost});

  final VoidCallback onPost;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    return ClipRRect(
      key: const Key('create-choice'),
      borderRadius: BvRadius.cardAll,
      child: BvListGroup(
        rows: [
          BvListRow(
            key: const Key('create-post'),
            leading: const BvRowIcon(BvIcons.everyone),
            title: l10n.createPostToEveryone,
            subtitle: l10n.createPostToEveryoneLine,
            trailing: const BvRowTrailing.none(),
            onTap: () {
              navigator.pop();
              onPost();
            },
          ),
          BvListRow(
            key: const Key('create-work-item'),
            leading: const BvRowIcon(BvIcons.workItems),
            title: l10n.createWorkItem,
            subtitle: l10n.createWorkItemLine,
            onTap: () {
              final page = navigator.context;
              navigator.pop();
              showBvSheet<void>(
                context: page,
                title: l10n.createPickSpace,
                builder: (_) => const _PickSpace(),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// The Spaces where you may write work items (a Viewer's never show),
/// the one you opened last first, then as My Spaces orders them. The
/// server decides each Space's rights (custom passes too).
final workItemSpacesProvider = FutureProvider.autoDispose<List<SpaceSummary>>((
  ref,
) async {
  final spaces = await ref.watch(mySpacesProvider.future);
  final last = ref.watch(lastSpaceProvider);
  Future<bool> canWrite(SpaceSummary s) async {
    try {
      final detail = await ref.watch(spaceDetailProvider(s.id).future);
      return detail?.myRights.createItems ?? false;
    } on SpaceException {
      return false;
    }
  }

  final allowed = await Future.wait(spaces.map(canWrite));
  final mine = [
    for (final (i, s) in spaces.indexed)
      if (allowed[i]) s,
  ];
  return [
    ...mine.where((s) => s.id == last),
    ...mine.where((s) => s.id != last),
  ];
});

/// "Which Space?": picking one opens its daybook with the card open. With
/// none, how to get one: an invite code or a new Space.
class _PickSpace extends ConsumerWidget {
  const _PickSpace();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final spaces = ref.watch(workItemSpacesProvider);
    final last = ref.watch(lastSpaceProvider);

    return switch (spaces) {
      AsyncData(value: final list) when list.isEmpty => Column(
        key: const Key('create-no-spaces'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BvSpace.s16,
        children: [
          Text(
            l10n.createNoWorkSpaces,
            style: type.bodyMd.copyWith(color: BvColors.textSecondary),
          ),
          ClipRRect(
            borderRadius: BvRadius.cardAll,
            child: BvListGroup(rows: _spaceStarts(context, l10n)),
          ),
        ],
      ),
      AsyncData(value: final list) => ClipRRect(
        key: const Key('create-spaces'),
        borderRadius: BvRadius.cardAll,
        child: BvListGroup(
          rows: [
            for (final s in list)
              BvListRow(
                key: Key('create-space-${s.id}'),
                leading: BvSpaceTile(name: s.name),
                title: s.name,
                subtitle: s.id == last
                    ? l10n.createLastSpace
                    : s.projectName ?? l10n.spacesPrivateWork,
                onTap: () {
                  final router = GoRouter.of(context);
                  Navigator.of(context).pop();
                  router.push(AppRoutes.space(s.id), extra: SpaceOpen.write);
                },
              ),
          ],
        ),
      ),
      AsyncError() => EmptyNote(l10n.errorGeneric),
      _ => const Padding(
        padding: EdgeInsetsDirectional.all(BvSpace.s24),
        child: Center(child: CircularProgressIndicator()),
      ),
    };
  }
}
