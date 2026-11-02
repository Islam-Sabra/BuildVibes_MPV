import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/around_specs.dart';
import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart' show BvStroke;
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_days_specs.dart' show BvNeedsYouSpec;
import '../../core/design/messages_specs.dart';
import '../../core/design/spaces_tab_specs.dart';
import '../../core/l10n/bidi.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/activity.dart';
import '../../data/models/space.dart';
import '../../data/repositories/dm_repository.dart';
import '../../data/repositories/space_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_badge.dart';
import '../../shared/widgets/bv_list_row.dart' show BvRowIcon;
import '../../shared/widgets/bv_mute_sheet.dart';
import '../../shared/widgets/bv_needs_you_line.dart';
import '../activity/activity_state.dart';
import '../entry/entry_state.dart';
import '../entry/widgets/join_wall.dart';
import '../profile/widgets/profile_parts.dart' show EmptyNote;
import '../settings/push_fix.dart';
import 'code_sheet.dart';
import 'my_spaces_view.dart' show SpaceRequestCard;
import 'pass_words.dart';
import 'space_mute.dart';
import 'spaces_state.dart';

/// Review 113 ST1 (2730:40062): the Spaces tab, the first tab while the
/// feed is hidden. "Spaces" with Messages and My notebook on top (no
/// Search: it lives in Explore), then [SpacesTabList].
class SpacesTabScreen extends ConsumerWidget {
  const SpacesTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final guest = ref.watch(appGateProvider) == AppGate.guest;
    final unread =
        !guest && (ref.watch(dmInboxProvider).value?.anyUnread ?? false);
    Widget icon(String key, IconData glyph, String label, VoidCallback onTap) =>
        Semantics(
          button: true,
          label: label,
          excludeSemantics: true,
          child: InkResponse(
            key: Key(key),
            radius: BvSize.touchMin / 2,
            onTap: onTap,
            child: SizedBox.square(
              dimension: BvHomeSpec.barButton,
              child: Icon(
                glyph,
                size: BvSize.iconLg,
                color: BvColors.iconPrimary,
              ),
            ),
          ),
        );
    return Scaffold(
      backgroundColor: BvColors.surfaceApp,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                BvSpacesTabSpec.barPaddingStart,
                BvSpacesTabSpec.barPaddingVertical,
                BvSpacesTabSpec.barPaddingEnd,
                BvSpacesTabSpec.barPaddingVertical,
              ),
              child: Row(
                key: const Key('spaces-tab-bar'),
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        l10n.homeSpaces,
                        style: type.titleLg.copyWith(
                          color: BvColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  if (!guest)
                    Stack(
                      children: [
                        icon(
                          'home-messages',
                          BvIcons.chat,
                          l10n.messagesTitle,
                          () => context.push(AppRoutes.messages),
                        ),
                        if (unread)
                          const PositionedDirectional(
                            top: BvHomeSpec.dotInset,
                            end: BvHomeSpec.dotInset,
                            child: SizedBox.square(
                              key: Key('home-messages-dot'),
                              dimension: BvMessagesSpec.dot,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: BvColors.actionPrimary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  if (!guest)
                    icon(
                      'home-notebook',
                      BvIcons.notebook,
                      l10n.notebookTitle,
                      () => context.push(AppRoutes.notebook),
                    ),
                ],
              ),
            ),
            // F9: pushes can't reach this phone; Fix it says how.
            const PushNotReachingLine(),
            const Expanded(child: SpacesTabList()),
          ],
        ),
      ),
    );
  }
}

/// ST1's list (review 113 (2), (3)): one "N need you · in 2 Spaces" line
/// at the top, which opens everything across Spaces that needs me; my own
/// waiting requests; each Space once, with its pass, whether anything is
/// new there today, and its small needs-you mark; then New Space · Join
/// with a code as small word buttons. Without a Space: the same word
/// buttons under a short note. No separate highlighted block of activity.
class SpacesTabList extends ConsumerWidget {
  const SpacesTabList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final guest = ref.watch(appGateProvider) == AppGate.guest;
    if (guest) {
      return _Page(
        children: [
          _Empty(
            onNewSpace: () => showJoinWall(context),
            onCode: () => showJoinWall(context),
          ),
        ],
      );
    }
    final spaces = ref.watch(mySpacesProvider);
    if (spaces.isLoading && !spaces.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }
    if (spaces.hasError && !spaces.hasValue) {
      return _Page(children: [EmptyNote(l10n.errorGeneric)]);
    }
    final mine = spaces.value ?? const <SpaceSummary>[];
    final needs = ref.watch(needsCardsProvider).value ?? const <NeedsCard>[];
    final today = {
      for (final t in ref.watch(todayInSpacesProvider).value ?? const [])
        t.spaceId,
    };
    final requests = ref.watch(myJoinRequestsProvider).value ?? const [];
    final dismissed = ref.watch(dismissedJoinRequestsProvider);
    final waiting = [
      for (final r in requests)
        if (r.status == JoinRequestStatus.pending || !dismissed.contains(r.id))
          r,
    ];

    Future<void> refresh() async {
      refreshDay(ref.invalidate);
      ref
        ..invalidate(mySpacesProvider)
        ..invalidate(myJoinRequestsProvider);
      await ref.read(mySpacesProvider.future);
    }

    void newSpace() => context.push(AppRoutes.spacesNew);
    void code() => showInviteCodeSheet(context);
    final inSpaces = {for (final c in needs) c.spaceId}.length;

    return RefreshIndicator(
      onRefresh: refresh,
      child: _Page(
        children: [
          if (needs.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                bottom: BvSpacesTabSpec.needsGap,
              ),
              child: BvNeedsYouLine(
                key: const Key('spaces-needs-you'),
                need: l10n.daybookNeedYou(needs.length),
                due: l10n.spacesTabNeedsIn(inSpaces),
                on: false,
                offLabel: l10n.daybookNeedYouShowAll,
                onTap: () => context.push(AppRoutes.needs),
              ),
            ),
          for (final r in waiting)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: BvSpace.s8),
              child: SpaceRequestCard(request: r),
            ),
          if (mine.isEmpty)
            _Empty(onNewSpace: newSpace, onCode: code)
          else ...[
            for (final (i, s) in mine.indexed) ...[
              if (i > 0)
                const Divider(
                  height: BvStroke.thin,
                  thickness: BvStroke.thin,
                  color: BvColors.borderDefault,
                ),
              _SpaceRow(space: s, newToday: today.contains(s.id)),
            ],
            const Divider(
              height: BvStroke.thin,
              thickness: BvStroke.thin,
              color: BvColors.borderDefault,
            ),
            const SizedBox(height: BvSpacesTabSpec.wordsTop),
            _Words(onNewSpace: newSpace, onCode: code),
          ],
        ],
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ListView(
    key: const Key('spaces-tab'),
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsetsDirectional.fromSTEB(
      BvSpace.gutter,
      BvSpacesTabSpec.listPaddingTop,
      BvSpace.gutter,
      BvSpacesTabSpec.listPaddingBottom,
    ),
    children: children,
  );
}

/// One Space: the crane, its name (and the bell-slash while muted), its
/// pass and "new today" or "quiet", then its small needs-you mark and ›.
/// A tap opens it; a hold mutes it (F102).
class _SpaceRow extends ConsumerWidget {
  const _SpaceRow({required this.space, required this.newToday});

  final SpaceSummary space;
  final bool newToday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final s = space;
    return InkWell(
      key: Key('space-row-${s.id}'),
      onTap: () => context.push(AppRoutes.space(s.id)),
      onLongPress: () => muteSpaceFromList(context, ref, s),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: BvSpacesTabSpec.rowMinHeight,
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            vertical: BvSpacesTabSpec.rowPaddingVertical,
          ),
          child: Row(
            spacing: BvSpacesTabSpec.rowGap,
            children: [
              const BvRowIcon(BvIcons.crane, ink: true),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: BvSpacesTabSpec.lineGap,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            inOwnDirection(s.name),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: type.titleMd.copyWith(
                              color: BvColors.textPrimary,
                            ),
                          ),
                        ),
                        if (s.muted)
                          BvMutedMark(key: Key('space-muted-${s.id}')),
                      ],
                    ),
                    Text(
                      joinMeta([
                        passName(l10n, s.pass),
                        newToday ? l10n.spacesTabNewToday : l10n.spacesTabQuiet,
                      ]),
                      key: Key('space-line-${s.id}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: type.metadata.copyWith(
                        color: BvColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (s.needsYou > 0)
                Semantics(
                  label: l10n.spacesNeedsYou(s.needsYou),
                  excludeSemantics: true,
                  child: BvBadge(
                    key: Key('space-needs-${s.id}'),
                    label: '${s.needsYou}',
                    tone: BvBadgeTone.action,
                  ),
                ),
              const Icon(
                BvIcons.caretForward,
                size: BvSize.iconSm,
                color: BvColors.iconSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "+ New Space · Join with a code" (review 113 (3)): small word buttons,
/// never big cards.
class _Words extends StatelessWidget {
  const _Words({required this.onNewSpace, required this.onCode});

  final VoidCallback onNewSpace;
  final VoidCallback onCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final style = type.labelMd.copyWith(color: BvColors.textAction);
    Widget word(
      String key,
      String label,
      VoidCallback onTap, {
      IconData? icon,
    }) => Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        key: Key(key),
        onTap: onTap,
        borderRadius: BvNeedsYouSpec.radius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: BvSize.touchMin),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: BvSpacesTabSpec.wordGap,
            children: [
              if (icon != null)
                Icon(
                  icon,
                  size: BvSpacesTabSpec.wordIcon,
                  color: BvColors.iconAction,
                ),
              Text(label, style: style),
            ],
          ),
        ),
      ),
    );
    return Wrap(
      key: const Key('spaces-words'),
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: BvSpace.s12,
      children: [
        word(
          'spaces-new-space',
          l10n.spacesNewTitle,
          onNewSpace,
          icon: BvIcons.add,
        ),
        Text('·', style: type.labelMd.copyWith(color: BvColors.textSecondary)),
        word('spaces-enter-code', l10n.homeJoinWithCode, onCode),
      ],
    );
  }
}

/// No Space yet: a short note, then the same word buttons.
class _Empty extends StatelessWidget {
  const _Empty({required this.onNewSpace, required this.onCode});

  final VoidCallback onNewSpace;
  final VoidCallback onCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    return Padding(
      key: const Key('spaces-empty'),
      padding: const EdgeInsetsDirectional.only(top: BvSpacesTabSpec.emptyTop),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: BvSpacesTabSpec.emptyGap,
        children: [
          const BvRowIcon(BvIcons.team),
          Text(
            l10n.spacesEmptyTitle,
            style: type.headingMd.copyWith(color: BvColors.textPrimary),
          ),
          Text(
            l10n.spacesEmptyBody,
            style: type.bodyMd.copyWith(color: BvColors.textSecondary),
          ),
          _Words(onNewSpace: onNewSpace, onCode: onCode),
        ],
      ),
    );
  }
}
