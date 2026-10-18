import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/activity.dart';
import '../../data/models/daybook.dart' show dayOf;
import '../../data/repositories/activity_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_avatar.dart';
import '../../shared/widgets/bv_button.dart';
import '../entry/entry_state.dart';
import '../entry/widgets/join_wall.dart';
import '../home/home_screen.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../profile/widgets/profile_parts.dart';
import '../spaces/space_screen.dart' show SpaceOpen;
import '../work/daybook_target.dart';
import '../work/daybook_words.dart';
import 'activity_state.dart';

/// Activity v3 (A1 v3 2587:76920, AR 2589:445; review 50 F32): one list,
/// newest first, grouped only by day ("Today", "Yesterday", "Wednesday 14
/// October"). Spaces, your posts, people and your record are mixed in time
/// order. At the top, one slim line while something needs you, which opens
/// Home → Spaces, where Needs you lives. Every row opens what it is about
/// (F13, F20); a row that still needs you carries the paper clip. Never a
/// count of rows. With nothing at all: A2, the ledger of what will show up.
/// Opening it marks everything read.
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
    final type = BvType.of(context);
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
            : _List(cards: cards, rows: changes),
      );
    }

    return Scaffold(
      backgroundColor: BvColors.surfaceApp,
      appBar: AppBar(
        backgroundColor: BvColors.surfaceApp,
        centerTitle: false,
        titleSpacing: BvSpace.gutter,
        title: Text(l10n.navActivity, style: type.titleLg),
      ),
      body: body,
    );
  }
}

class _List extends ConsumerWidget {
  const _List({required this.cards, required this.rows});

  final List<NeedsCard> cards;
  final List<ActivityRow> rows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final now = ref.watch(clockProvider)();
    final words = DaybookWords(
      l10n,
      Localizations.localeOf(context).toLanguageTag(),
      use24: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    // The work items that still need you: their rows carry the clip.
    final needing = {
      for (final c in cards)
        if (c.workItemId != null) c.workItemId!,
    };
    final today = dayOf(now);

    String dayName(DateTime day) => switch (today.difference(day).inDays) {
      0 => l10n.chatToday,
      1 => l10n.chatYesterday,
      _ => words.compactDate(day),
    };

    const divider = Divider(
      height: BvStroke.thin,
      thickness: BvStroke.thin,
      color: BvColors.borderSubtle,
    );
    final children = <Widget>[
      if (cards.isNotEmpty) _NeedsLine(things: cards.length),
    ];
    DateTime? shownDay;
    // Newest first, whatever the source (the server sends them so; sorted
    // again here so a row never sits under an older one).
    final ordered = [...rows]
      ..sort((a, b) {
        final byTime = b.createdAt.compareTo(a.createdAt);
        return byTime != 0 ? byTime : b.id.compareTo(a.id);
      });
    for (final r in ordered) {
      final day = dayOf(r.createdAt.toLocal());
      if (day != shownDay) {
        shownDay = day;
        children.add(
          Padding(
            key: Key('activity-day-${day.toIso8601String()}'),
            padding: const EdgeInsetsDirectional.only(
              top: BvActivitySpec.dayPaddingTop,
              bottom: BvActivitySpec.dayPaddingBottom,
            ),
            child: Text(
              dayName(day),
              style: type.overline.copyWith(color: BvColors.textSecondary),
            ),
          ),
        );
      }
      children
        ..add(
          ActivityRowView(
            row: r,
            time: words.clock(r.createdAt),
            needsYou: r.workItemId != null && needing.contains(r.workItemId),
          ),
        )
        ..add(divider);
    }

    return ListView.separated(
      key: const Key('activity'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsetsDirectional.fromSTEB(
        BvSpace.gutter,
        BvActivitySpec.listPaddingTop,
        BvSpace.gutter,
        BvSpace.s32,
      ),
      itemCount: children.length,
      separatorBuilder: (_, _) =>
          const SizedBox(height: BvActivitySpec.listGap),
      itemBuilder: (_, i) => children[i],
    );
  }
}

/// "2 things need you ›" (F32): the one way to Needs you from Activity. It
/// opens Home → Spaces, where Needs you lives.
class _NeedsLine extends ConsumerWidget {
  const _NeedsLine({required this.things});

  final int things;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    return Semantics(
      button: true,
      child: Material(
        color: BvColors.surfaceBrandSoft,
        borderRadius: BvActivitySpec.needsLineRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('activity-needs-you'),
          onTap: () {
            ref.read(homeTabProvider.notifier).show(HomeScreen.spacesTab);
            context.go(AppRoutes.home);
          },
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              BvActivitySpec.needsLinePaddingStart,
              BvActivitySpec.needsLinePaddingVertical,
              BvActivitySpec.needsLinePaddingEnd,
              BvActivitySpec.needsLinePaddingVertical,
            ),
            child: Row(
              spacing: BvActivitySpec.needsLineGap,
              children: [
                const Icon(
                  BvIcons.attach,
                  size: BvActivitySpec.needsLineIcon,
                  color: BvColors.iconAction,
                ),
                Expanded(
                  child: Text(
                    l10n.homeDayNeedsYou(things),
                    style: type.labelMd.copyWith(color: BvColors.textAction),
                  ),
                ),
                const Icon(
                  BvIcons.caretForward,
                  size: BvActivitySpec.needsLineIcon,
                  color: BvColors.iconAction,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What one Activity row says: the line ("{name} signed as done: {title}")
/// with the person's name in it, and where it happened.
typedef ActivityWords = ({String text, String? name, String? where});

ActivityWords activityWords(AppLocalizations l10n, ActivityRow row) {
  final name = inOwnDirection(row.actorName ?? l10n.activitySomeone);
  final title = inOwnDirection(row.workItemTitle ?? row.workItemRef ?? '');
  final space = row.spaceName == null ? null : inOwnDirection(row.spaceName!);
  final text = row.context == null ? null : inOwnDirection(row.context!);
  String yourPost() => text == null
      ? l10n.activityWherePost
      : joinMeta([l10n.activityWherePost, text]);
  return switch (row.kind) {
    ActivityKind.itemAssigned => (
      text: l10n.needsForYou(name, title),
      name: name,
      where: space,
    ),
    ActivityKind.itemDone => (
      text: l10n.activityItemDone(name, title),
      name: name,
      where: space,
    ),
    ActivityKind.itemChecked => (
      text: l10n.activityItemChecked(name, title),
      name: name,
      where: space,
    ),
    ActivityKind.itemSentBack => (
      text: l10n.activityItemSentBack(name, title),
      name: name,
      where: space,
    ),
    ActivityKind.itemComment => (
      text: l10n.activityItemUpdate(name, title),
      name: name,
      where: space,
    ),
    ActivityKind.joinRequest => (
      text: l10n.activityJoinRequest(name),
      name: name,
      where: space,
    ),
    ActivityKind.joinConfirmed => (
      text: l10n.activityJoinConfirmed(space ?? ''),
      name: null,
      where: row.actorName == null ? null : l10n.activityConfirmedBy(name),
    ),
    ActivityKind.roleConfirmed => (
      text: row.projectName == null
          ? l10n.activityRoleConfirmed(name)
          : l10n.activityRoleConfirmedOn(
              name,
              inOwnDirection(row.projectName!),
            ),
      name: name,
      where: l10n.activityWhereProfile,
    ),
    ActivityKind.follow => (
      text: l10n.activityFollow(name),
      name: name,
      where: l10n.activityGroupNetwork,
    ),
    // The reply's own words; the post it is on isn't in the row.
    ActivityKind.postReply => (
      text: switch ((row.toReply, text)) {
        (true, final t?) => l10n.activityReplyReplyText(name, t),
        (false, final t?) => l10n.activityReplyPostText(name, t),
        (true, null) => l10n.activityReplyReply(name),
        (false, null) => l10n.activityReplyPost(name),
      },
      name: name,
      where: l10n.activityWherePost,
    ),
    ActivityKind.postUseful => switch (row.usefulNames) {
      [] => (text: l10n.activityUseful0, name: null, where: yourPost()),
      [final a] => (
        text: l10n.activityUseful1(inOwnDirection(a)),
        name: inOwnDirection(a),
        where: yourPost(),
      ),
      [final a, final b, ...] => (
        text: l10n.activityUseful2(inOwnDirection(a), inOwnDirection(b)),
        name: inOwnDirection(a),
        where: yourPost(),
      ),
    },
    ActivityKind.contentRemoved => (
      text: l10n.activityRemoved(row.targetKind ?? 'post'),
      name: null,
      where: null,
    ),
    ActivityKind.appealDecided => (
      text: l10n.activityAppealResult(row.result ?? 'upheld'),
      name: null,
      where: null,
    ),
  };
}

/// One Activity row (A1 v3): the person's face, what happened (the name
/// bold while unread), where it happened in small grey, and at the end the
/// time with the unread dot and, while it still needs you, the paper clip.
/// The whole row opens the exact thing (F13, F20).
class ActivityRowView extends StatelessWidget {
  const ActivityRowView({
    super.key,
    required this.row,
    required this.time,
    this.needsYou = false,
  });

  final ActivityRow row;
  final String time;
  final bool needsYou;

  /// What the row is about (F13): never a dead end.
  static VoidCallback? opener(BuildContext context, ActivityRow row) {
    final space = row.spaceId;
    final post = row.postId;
    final actor = row.actorId;
    final removal = row.removalId;
    final workItem = row.workItemId;
    return switch (row.kind) {
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
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final words = activityWords(l10n, row);
    final unread = !row.read;
    final nameStyle = (unread ? type.headingMd : type.labelMd).copyWith(
      color: BvColors.textPrimary,
    );
    final restStyle = type.bodyMd.copyWith(
      color: unread ? BvColors.textPrimary : BvColors.textSecondary,
    );
    // The name where the language puts it, in its own weight.
    final name = words.name;
    final at = name == null ? -1 : words.text.indexOf(name);
    final spans = at < 0
        ? [TextSpan(text: words.text, style: restStyle)]
        : [
            if (at > 0)
              TextSpan(text: words.text.substring(0, at), style: restStyle),
            TextSpan(text: name, style: nameStyle),
            TextSpan(
              text: words.text.substring(at + name!.length),
              style: restStyle,
            ),
          ];
    // Useful rows have no actor: the first person who found it useful.
    final who =
        row.actorName ??
        (row.kind == ActivityKind.postUseful
            ? row.usefulNames.firstOrNull
            : null);

    return InkWell(
      key: Key('activity-row-${row.id}'),
      onTap: opener(context, row),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: BvActivitySpec.cardMinHeight,
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            vertical: BvActivitySpec.rowPaddingVertical,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: BvActivitySpec.rowGap,
            children: [
              who == null
                  ? const _NoFace()
                  : BvAvatar(
                      name: who,
                      size: BvAvatarSize.md,
                      tint: BvAvatarTints.forId(row.actorId ?? who),
                    ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: BvActivitySpec.lineGap,
                  children: [
                    Text.rich(
                      TextSpan(children: spans),
                      key: Key('activity-text-${row.id}'),
                    ),
                    if (words.where case final where?)
                      // Its own direction, so "…" ends it on the right side.
                      SizedBox(
                        width: double.infinity,
                        child: Text(
                          where,
                          key: Key('activity-where-${row.id}'),
                          textDirection: directionOf(where),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: type.metadata.copyWith(
                            color: BvColors.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                spacing: BvActivitySpec.rowEndGap,
                children: [
                  Text(
                    time,
                    style: type.metadata.copyWith(
                      color: BvColors.textSecondary,
                    ),
                  ),
                  if (unread)
                    const DecoratedBox(
                      key: Key('activity-unread'),
                      decoration: BoxDecoration(
                        color: BvColors.iconAction,
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox.square(dimension: BvActivitySpec.rowDot),
                    ),
                  if (needsYou)
                    const Icon(
                      BvIcons.attach,
                      key: Key('activity-needs-clip'),
                      size: BvActivitySpec.rowClip,
                      color: BvColors.iconAction,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A row with no person (a removal, an appeal): the app's quiet circle.
class _NoFace extends StatelessWidget {
  const _NoFace();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      color: BvColors.surfaceSubtle,
      shape: BoxShape.circle,
    ),
    child: SizedBox.square(
      dimension: BvSize.avatarMd,
      child: Icon(
        BvIcons.activity,
        size: BvSize.iconMd,
        color: BvColors.iconSecondary,
      ),
    ),
  );
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
