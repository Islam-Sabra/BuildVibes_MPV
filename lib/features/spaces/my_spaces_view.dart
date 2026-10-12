import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/project.dart';
import '../../data/models/space.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/repositories/space_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_badge.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../entry/entry_state.dart';
import '../entry/widgets/join_wall.dart';
import '../profile/widgets/profile_parts.dart';
import 'code_sheet.dart';
import 'space_errors.dart';
import 'spaces_state.dart';

/// Home → Spaces until week 7 builds the daily Spaces tab: My Spaces
/// (S1 v2, project Spaces only), or the empty state (H1e) with "Enter an
/// invite code". Your own waiting or declined requests sit on top.
class MySpacesView extends ConsumerWidget {
  const MySpacesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guest = ref.watch(appGateProvider) == AppGate.guest;
    if (guest) {
      return _Page(
        children: [_EmptyCard(onEnterCode: () => showJoinWall(context))],
      );
    }
    final spaces = ref.watch(mySpacesProvider);
    final requests = ref.watch(myJoinRequestsProvider);
    final dismissed = ref.watch(dismissedJoinRequestsProvider);

    if (spaces.isLoading && !spaces.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }
    if (spaces.hasError && !spaces.hasValue) {
      return _Page(
        children: [EmptyNote(AppLocalizations.of(context).errorGeneric)],
      );
    }
    final mine = spaces.value ?? const <SpaceSummary>[];
    final waiting = [
      for (final r in requests.value ?? const <MyJoinRequest>[])
        if (r.status == JoinRequestStatus.pending || !dismissed.contains(r.id))
          r,
    ];

    Future<void> refresh() async {
      ref
        ..invalidate(mySpacesProvider)
        ..invalidate(myJoinRequestsProvider);
      await ref.read(mySpacesProvider.future);
    }

    return RefreshIndicator(
      onRefresh: refresh,
      child: _Page(
        children: [
          for (final r in waiting) _RequestCard(request: r),
          if (mine.isEmpty)
            _EmptyCard(onEnterCode: () => showInviteCodeSheet(context))
          else
            _SpaceList(spaces: mine),
        ],
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('my-spaces'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsetsDirectional.fromSTEB(
        BvSpace.gutter,
        BvSpace.s16,
        BvSpace.gutter,
        BvSpace.s32,
      ),
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: BvSpace.s12),
          children[i],
        ],
      ],
    );
  }
}

/// S1 v2: "PROJECT SPACES" and a card of rows. Admins see "N needs you"
/// for join requests waiting for them.
class _SpaceList extends ConsumerWidget {
  const _SpaceList({required this.spaces});

  final List<SpaceSummary> spaces;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final types = ref.watch(projectTypesProvider).value ?? const <RefOption>[];
    String? typeName(String? id) =>
        types.where((t) => t.id == id).firstOrNull?.name.of(locale);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BvSpace.s8,
      children: [
        Text(
          l10n.spacesProjectSpaces,
          style: BvType.of(
            context,
          ).overline.copyWith(color: BvColors.textSecondary),
        ),
        ProfileCard(
          padding: false,
          child: BvListGroup(
            rows: [
              for (final s in spaces)
                BvListRow(
                  key: Key('space-row-${s.id}'),
                  leading: const BvRowIcon(BvIcons.crane, ink: true),
                  title: s.name,
                  subtitle: s.projectName == null
                      ? l10n.spacesPrivateWork
                      : joinMeta([s.projectName!, ?typeName(s.projectTypeId)]),
                  trailing: s.needsYou > 0
                      ? BvRowTrailing.badge(
                          BvBadge(
                            key: Key('space-needs-${s.id}'),
                            label: l10n.spacesNeedsYou(s.needsYou),
                            tone: BvBadgeTone.action,
                          ),
                        )
                      // S1 rows have no chevron.
                      : const BvRowTrailing.none(),
                  onTap: () => context.push(AppRoutes.space(s.id)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Your own request: waiting (with Cancel request) or not confirmed (with
/// Dismiss). No reason and no name of who declined.
class _RequestCard extends ConsumerWidget {
  const _RequestCard({required this.request});

  final MyJoinRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final pending = request.status == JoinRequestStatus.pending;

    Future<void> cancel() async {
      try {
        await ref.read(spaceRepositoryProvider).cancelJoinRequest(request.id);
        ref.invalidate(myJoinRequestsProvider);
      } on SpaceException catch (e) {
        if (context.mounted) showSpaceError(context, e);
      }
    }

    return ProfileCard(
      padding: false,
      child: Column(
        key: Key('join-request-${request.id}'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BvListRow(
            leading: BvRowIcon(pending ? BvIcons.waiting : BvIcons.declined),
            title: request.spaceName,
            subtitle: pending ? l10n.spacesWaiting : l10n.spacesNotConfirmed,
            trailing: const BvRowTrailing.none(),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: BvSpace.s8,
              bottom: BvSpace.s4,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: BvButton(
                key: Key(
                  pending
                      ? 'cancel-request-${request.id}'
                      : 'dismiss-request-${request.id}',
                ),
                label: pending ? l10n.spacesCancelRequest : l10n.spacesDismiss,
                style: BvButtonStyle.tertiary,
                size: BvButtonSize.medium,
                onPressed: pending
                    ? cancel
                    : () => ref
                          .read(dismissedJoinRequestsProvider.notifier)
                          .dismiss(request.id),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// H1e, Spaces part: "Join your first Space" with Enter an invite code.
/// "Find Spaces to join" is Discover, which is not in the MVP.
class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.onEnterCode});

  final VoidCallback onEnterCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    return Column(
      key: const Key('spaces-empty'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BvSpace.s16,
      children: [
        ProfileCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: BvSpace.s12,
            children: [
              const BvRowIcon(BvIcons.team),
              Text(l10n.spacesEmptyTitle, style: type.headingMd),
              Text(
                l10n.spacesEmptyBody,
                style: type.bodyMd.copyWith(color: BvColors.textSecondary),
              ),
              BvButton(
                key: const Key('spaces-enter-code'),
                label: l10n.spacesEnterCode,
                expand: true,
                onPressed: onEnterCode,
              ),
            ],
          ),
        ),
        Text(
          l10n.spacesEmptyFeedNote,
          style: type.bodySm.copyWith(color: BvColors.textSecondary),
        ),
      ],
    );
  }
}
