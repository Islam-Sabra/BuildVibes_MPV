import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/ago.dart';
import '../../core/l10n/bidi.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/activity.dart';
import '../../data/models/space.dart';
import '../../data/repositories/activity_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_badge.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_space_tile.dart';
import '../entry/entry_state.dart';
import '../entry/widgets/join_wall.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../profile/widgets/profile_parts.dart';
import '../spaces/pass_words.dart';
import '../spaces/space_screen.dart' show SpaceOpen;
import '../work/daybook_target.dart';
import 'activity_state.dart';
import 'needs_card.dart';

/// Activity (A1 v2): NEEDS YOU, then CHANGES TO YOUR RECORD for the last 7
/// days, grouped (each Space, Your record, Your network, Your posts). With
/// nothing at all: A2, the ledger of what will show up. Opening it marks
/// everything read.
class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  @override
  void initState() {
    super.initState();
    // Once the rows are in (unread markers as they were), mark them read.
    ref.listenManual(activityProvider, (_, next) async {
      final rows = next.value;
      if (rows == null || rows.every((r) => r.read)) return;
      try {
        await ref.read(activityRepositoryProvider).markRead();
      } on Exception {
        return;
      }
      if (mounted) ref.invalidate(unreadActivityProvider);
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final guest = ref.watch(appGateProvider) == AppGate.guest;
    final rows = ref.watch(activityProvider);
    final needs = ref.watch(needsCardsProvider);

    Widget body;
    if (guest) {
      body = _Empty(onAddProject: () => showJoinWall(context));
    } else if (!rows.hasValue || !needs.hasValue) {
      body = rows.hasError || needs.hasError
          ? Padding(
              padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
              child: Column(
                spacing: BvSpace.s12,
                children: [
                  EmptyNote(l10n.errorGeneric),
                  BvButton(
                    key: const Key('activity-retry'),
                    label: l10n.chatRetry,
                    style: BvButtonStyle.secondary,
                    size: BvButtonSize.medium,
                    onPressed: () => ref
                      ..invalidate(activityProvider)
                      ..invalidate(needsCardsProvider),
                  ),
                ],
              ),
            )
          : const Center(child: CircularProgressIndicator());
    } else {
      final cards = needs.value!;
      final changes = rows.value!;
      body = RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(activityProvider)
            ..invalidate(needsCardsProvider);
          await ref.read(activityProvider.future);
        },
        child: cards.isEmpty && changes.isEmpty
            ? _Empty(onAddProject: () => context.push(AppRoutes.projectsAdd))
            : _Lists(cards: cards, rows: changes),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navActivity), centerTitle: true),
      body: body,
    );
  }
}

class _Lists extends StatelessWidget {
  const _Lists({required this.cards, required this.rows});

  final List<NeedsCard> cards;
  final List<ActivityRow> rows;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final muted = type.overline.copyWith(color: BvColors.textSecondary);

    // Groups in order: each Space (newest first), then record, network,
    // posts. Rows newest first inside each.
    final groups = <String, List<ActivityRow>>{};
    for (final r in rows) {
      groups.putIfAbsent(r.groupKey, () => []).add(r);
    }
    int rank(ActivityRow r) => ActivityGroupKind.values.indexOf(r.group);
    final ordered = groups.values.toList()
      ..sort((a, b) {
        final byKind = rank(a.first).compareTo(rank(b.first));
        return byKind != 0
            ? byKind
            : b.first.createdAt.compareTo(a.first.createdAt);
      });

    return ListView(
      key: const Key('activity'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsetsDirectional.fromSTEB(
        BvSpace.gutter,
        BvSpace.s8,
        BvSpace.gutter,
        BvSpace.s32,
      ),
      children: [
        if (cards.isNotEmpty) ...[
          Text(l10n.activityNeedsHeader(cards.length), style: muted),
          const SizedBox(height: BvSpace.s8),
          for (final c in cards) ...[
            NeedsYouCard(card: c, activity: true),
            const SizedBox(height: BvSpace.s12),
          ],
        ] else ...[
          Text(l10n.activityEmptyTitle, style: type.headingMd),
          const SizedBox(height: BvSpace.s16),
        ],
        if (ordered.isNotEmpty) ...[
          const SizedBox(height: BvSpace.s8),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: l10n.activityChanges, style: muted),
                TextSpan(
                  text: ' · ${l10n.activityLast7}',
                  style: type.metadata.copyWith(color: BvColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: BvSpace.s8),
          for (final g in ordered) ...[
            _Group(rows: g),
            const SizedBox(height: BvSpace.s12),
          ],
        ],
      ],
    );
  }
}

/// One group: its title and line, then its rows. A Space's group starts
/// with the Space's tile, and its title opens the Space (F13).
class _Group extends StatelessWidget {
  const _Group({required this.rows});

  final List<ActivityRow> rows;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final first = rows.first;
    final space = first.group == ActivityGroupKind.space ? first.spaceId : null;
    final (title, line) = switch (first.group) {
      ActivityGroupKind.space => (
        inOwnDirection(first.spaceName ?? ''),
        first.myPass == null
            ? null
            : l10n.activitySpaceLine(
                passName(l10n, SpacePass.fromJson(first.myPass)),
              ),
      ),
      ActivityGroupKind.record => (l10n.activityGroupRecord, null),
      ActivityGroupKind.network => (l10n.activityGroupNetwork, null),
      ActivityGroupKind.posts => (l10n.activityGroupPosts, null),
    };

    return ProfileCard(
      padding: false,
      child: Column(
        key: Key('activity-group-${first.groupKey}'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: Key('activity-group-open-${first.groupKey}'),
            onTap: space == null
                ? null
                : () => context.push(AppRoutes.space(space)),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                BvSpace.s16,
                BvSpace.s12,
                BvSpace.s12,
                BvSpace.s8,
              ),
              child: Row(
                spacing: BvSpace.s8,
                children: [
                  if (space != null) BvSpaceTile(name: first.spaceName ?? ''),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: type.titleMd),
                        if (line != null)
                          Text(
                            line,
                            style: type.metadata.copyWith(
                              color: BvColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          for (final r in rows) _Row(row: r),
        ],
      ),
    );
  }
}

class _Row extends ConsumerWidget {
  const _Row({required this.row});

  final ActivityRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final now = ref.watch(clockProvider)();
    final name = inOwnDirection(row.actorName ?? l10n.activitySomeone);
    final ref0 = ltrRun(row.workItemRef ?? '');
    final item = row.workItemTitle == null
        ? null
        : inOwnDirection(row.workItemTitle!);

    final (text, context0, chip) = switch (row.kind) {
      ActivityKind.itemAssigned => (
        l10n.activityAssigned(name, ref0),
        item,
        (l10n.chipAssigned, BvBadgeTone.brand),
      ),
      ActivityKind.itemDone => (
        l10n.activityDone(name, ref0),
        item,
        (l10n.chipDone, BvBadgeTone.positive),
      ),
      ActivityKind.itemChecked => (
        l10n.activityChecked(name, ref0),
        item,
        (l10n.chipChecked, BvBadgeTone.positive),
      ),
      ActivityKind.itemSentBack => (
        l10n.activitySentBack(name, ref0),
        item,
        (l10n.chipSentBack, BvBadgeTone.warning),
      ),
      ActivityKind.itemComment => (
        l10n.activityComment(name, ref0),
        item,
        (l10n.chipComment, BvBadgeTone.neutral),
      ),
      ActivityKind.joinRequest => (
        l10n.activityJoinRequest(name),
        null,
        row.requestStatus == 'confirmed'
            ? (l10n.chipApproved, BvBadgeTone.positive)
            : null,
      ),
      ActivityKind.joinConfirmed => (
        l10n.activityJoinConfirmed(inOwnDirection(row.spaceName ?? '')),
        l10n.activityConfirmedBy(name),
        (l10n.chipApproved, BvBadgeTone.positive),
      ),
      ActivityKind.roleConfirmed => (
        l10n.activityRoleConfirmed(name),
        row.projectName == null ? null : inOwnDirection(row.projectName!),
        (l10n.chipConfirmed, BvBadgeTone.positive),
      ),
      ActivityKind.follow => (l10n.activityFollow(name), null, null),
      ActivityKind.contentRemoved => (
        l10n.activityRemoved(row.targetKind ?? 'post'),
        null,
        (l10n.chipRemoved, BvBadgeTone.warning),
      ),
      ActivityKind.appealDecided => (
        l10n.activityAppealResult(row.result ?? 'upheld'),
        null,
        row.result == 'reversed'
            ? (l10n.chipRestored, BvBadgeTone.positive)
            : (l10n.chipRemoved, BvBadgeTone.warning),
      ),
      ActivityKind.postReply => (
        row.toReply
            ? l10n.activityReplyReply(name)
            : l10n.activityReplyPost(name),
        row.context == null ? null : inOwnDirection(row.context!),
        null,
      ),
      ActivityKind.postUseful => (
        switch (row.usefulNames) {
          [] => l10n.activityUseful0,
          [final a] => l10n.activityUseful1(inOwnDirection(a)),
          [final a, final b, ...] => l10n.activityUseful2(
            inOwnDirection(a),
            inOwnDirection(b),
          ),
        },
        row.context == null ? null : inOwnDirection(row.context!),
        null,
      ),
    };

    // What the row is about (F13): never a dead end.
    final space = row.spaceId;
    final post = row.postId;
    final actor = row.actorId;
    final removal = row.removalId;
    final workItem = row.workItemId;
    final VoidCallback? open = switch (row.kind) {
      ActivityKind.joinRequest when space != null => () => context.push(
        AppRoutes.space(space),
        extra: SpaceOpen.people,
      ),
      ActivityKind.roleConfirmed => () => context.go(AppRoutes.profile),
      ActivityKind.contentRemoved || ActivityKind.appealDecided
          when removal != null =>
        () => context.push(AppRoutes.removal(removal)),
      ActivityKind.follow when actor != null => () => context.push(
        '${AppRoutes.people}/$actor',
      ),
      ActivityKind.postReply || ActivityKind.postUseful when post != null =>
        () => context.push(AppRoutes.post(post)),
      // A work item opens at its card on its Space's daybook, at the line
      // the row is about (F20); a confirmed join opens the Space.
      _ when space != null && workItem != null => () => openWorkCard(
        context,
        spaceId: space,
        postId: workItem,
        eventId: row.eventId,
      ),
      _ when space != null => () => context.push(AppRoutes.space(space)),
      _ => null,
    };

    return InkWell(
      key: Key('activity-row-${row.id}'),
      onTap: open,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          BvSpace.s16,
          BvSpace.s8,
          BvSpace.s12,
          BvSpace.s12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: BvSpace.s8,
          children: [
            // Unread: a small orange dot, as on the Activity tab.
            Padding(
              padding: const EdgeInsetsDirectional.only(top: BvSpace.s8),
              child: SizedBox.square(
                dimension: BvActivitySpec.newDot,
                child: row.read
                    ? null
                    : const DecoratedBox(
                        key: Key('activity-unread'),
                        decoration: BoxDecoration(
                          color: BvColors.iconAction,
                          shape: BoxShape.circle,
                        ),
                      ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: BvSpace.s2,
                children: [
                  Text(text, style: type.bodyMd),
                  if (context0 != null)
                    // Its own direction, so "…" ends it on the right side.
                    SizedBox(
                      width: double.infinity,
                      child: Text(
                        context0,
                        textDirection: directionOf(context0),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: type.bodySm.copyWith(
                          color: BvColors.textSecondary,
                        ),
                      ),
                    ),
                  if (chip != null) ...[
                    const SizedBox(height: BvSpace.s2),
                    BvBadge(label: chip.$1, tone: chip.$2),
                  ],
                ],
              ),
            ),
            Text(
              formatShortAgo(l10n, row.createdAt.toLocal(), now, locale),
              style: type.metadata.copyWith(color: BvColors.textSecondary),
            ),
            if (open != null)
              const Icon(
                BvIcons.caretForward,
                size: BvSize.iconSm,
                color: BvColors.iconSecondary,
              ),
          ],
        ),
      ),
    );
  }
}

/// A2: nothing at all yet. What will show up, and one thing to do.
class _Empty extends StatelessWidget {
  const _Empty({required this.onAddProject});

  final VoidCallback onAddProject;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final muted = type.overline.copyWith(color: BvColors.textSecondary);
    const divider = Divider(
      height: BvStroke.thin,
      thickness: BvStroke.thin,
      color: BvColors.borderDefault,
    );
    Widget entry(String head, String line) => Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: BvSpace.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: BvSpace.s4,
        children: [
          Text(head, style: muted),
          Text(line, style: type.bodyMd),
        ],
      ),
    );
    return ListView(
      key: const Key('activity-empty'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsetsDirectional.fromSTEB(
        BvSpace.gutter,
        BvSpace.s24,
        BvSpace.gutter,
        BvSpace.s32,
      ),
      children: [
        Text(l10n.activityEmptyTitle, style: type.headingMd),
        const SizedBox(height: BvSpace.s8),
        Text(
          l10n.activityEmptyBody,
          style: type.bodyMd.copyWith(color: BvColors.textSecondary),
        ),
        const SizedBox(height: BvSpace.s16),
        divider,
        entry(l10n.ledgerWork, l10n.ledgerWorkLine),
        divider,
        entry(l10n.ledgerRequests, l10n.ledgerRequestsLine),
        divider,
        entry(l10n.ledgerPosts, l10n.ledgerPostsLine),
        divider,
        entry(l10n.ledgerNetwork, l10n.ledgerNetworkLine),
        const SizedBox(height: BvSpace.s16),
        Text(l10n.ledgerWait, style: muted),
        const SizedBox(height: BvSpace.s8),
        divider,
        InkWell(
          key: const Key('activity-add-project'),
          onTap: onAddProject,
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              vertical: BvSpace.s12,
            ),
            child: Text(
              l10n.ledgerAddProject,
              style: type.titleMd.copyWith(color: BvColors.textAction),
            ),
          ),
        ),
      ],
    );
  }
}
