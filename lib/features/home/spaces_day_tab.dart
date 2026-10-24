import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/around_specs.dart';
import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart';
import '../../core/l10n/bv_time.dart';
import '../../core/l10n/months.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/activity.dart';
import '../../data/models/daybook.dart' show dayOf;
import '../../data/models/space.dart';
import '../../data/repositories/space_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_marked_text.dart';
import '../../shared/widgets/bv_space_emblem.dart';
import '../../shared/widgets/bv_daybook_masthead.dart';
import '../activity/activity_state.dart';
import '../activity/needs_card.dart' show needsTitle, openNeeds;
import '../entry/entry_state.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../profile/widgets/profile_parts.dart';
import '../spaces/code_sheet.dart';
import '../spaces/my_spaces_view.dart';
import '../work/daybook_words.dart';

/// Home → Spaces (H1b, review 50 F3, F10 and F28): one line with the date
/// and what needs you; New Space and Join with a code, sharing the width;
/// at most 3 things that need you, grouped by Space (its emblem and name
/// once, then its rows with a quiet ›); then Your Spaces, every Space once,
/// each with the time of its last activity. Without a Space: My Spaces'
/// empty state (H1e), where both actions are large.
class SpacesDayTab extends ConsumerWidget {
  const SpacesDayTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guest = ref.watch(appGateProvider) == AppGate.guest;
    final spaces = ref.watch(mySpacesProvider);
    if (guest || (spaces.value?.isEmpty ?? false)) return const MySpacesView();
    if (!spaces.hasValue) {
      return spaces.hasError
          ? const MySpacesView()
          : const Center(child: CircularProgressIndicator());
    }

    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final needs = ref.watch(needsCardsProvider).value ?? const <NeedsCard>[];
    final today = ref.watch(todayInSpacesProvider).value ?? const [];

    Future<void> refresh() async {
      refreshDay(ref.invalidate);
      await ref.read(needsCardsProvider.future);
    }

    Widget overline(String text) => Text(
      text,
      style: type.overline.copyWith(color: BvColors.textSecondary),
    );

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        key: const Key('spaces-day'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsetsDirectional.fromSTEB(
          BvSpace.gutter,
          BvSpace.s12,
          BvSpace.gutter,
          BvSpace.s32,
        ),
        children: [
          _Header(needs: needs.length),
          const SizedBox(height: BvSpace.s12),
          const _SpaceActions(),
          if (needs.isNotEmpty) ...[
            const SizedBox(height: BvSpace.s24),
            overline(l10n.homeNeedsYou),
            const SizedBox(height: BvSpace.s8),
            _NeedsBySpace(cards: needs.take(BvActivitySpec.needsOnHome)),
            if (needs.length > BvActivitySpec.needsOnHome)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  key: const Key('home-needs-all'),
                  onPressed: () => context.push(AppRoutes.needs),
                  child: Text(l10n.homeSeeAll),
                ),
              ),
          ],
          const SizedBox(height: BvSpace.s24),
          overline(l10n.homeYourSpaces),
          const SizedBox(height: BvSpace.s8),
          _YourSpaces(spaces: spaces.value!, today: today, needs: needs),
        ],
      ),
    );
  }
}

/// One line, as on Feed and the daybook (review 54 A6): the day in bold,
/// the date in grey, then "· 2 things need you" in the action colour
/// (F10). No capitals, no title, no place, and no other counts.
class _Header extends ConsumerWidget {
  const _Header({required this.needs});

  final int needs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final now = ref.watch(clockProvider)();
    final words = DaybookWords(
      l10n,
      Localizations.localeOf(context).toLanguageTag(),
      use24: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    return BvDaybookMasthead(
      key: const Key('home-day-header'),
      weekday: words.weekday(now),
      date: words.dayMonth(now),
      padded: false,
      after: needs > 0 ? l10n.homeDayNeedsYou(needs) : l10n.homeNothingNeedsYou,
      afterAction: needs > 0,
    );
  }
}

/// New Space and Join with a code, side by side above the list, sharing
/// the width (F3, F28): a foreman with a code is one tap from joining.
class _SpaceActions extends StatelessWidget {
  const _SpaceActions();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      spacing: BvActivitySpec.actionsGap,
      children: [
        Expanded(
          child: BvButton(
            key: const Key('home-new-space'),
            label: l10n.spacesNewTitle,
            style: BvButtonStyle.secondary,
            size: BvButtonSize.medium,
            expand: true,
            onPressed: () => context.push(AppRoutes.spacesNew),
          ),
        ),
        Expanded(
          child: BvButton(
            key: const Key('home-enter-code'),
            label: l10n.homeJoinWithCode,
            style: BvButtonStyle.secondary,
            size: BvButtonSize.medium,
            expand: true,
            onPressed: () => showInviteCodeSheet(context),
          ),
        ),
      ],
    );
  }
}

/// YOUR SPACES (F3, F10, F28): every Space once, with its emblem. Spaces
/// with news today come first, newest first, each with its latest news
/// unless Needs you already shows it; then the rest, by their last
/// activity. Every Space shows when it last had activity. Never a count.
class _YourSpaces extends ConsumerWidget {
  const _YourSpaces({
    required this.spaces,
    required this.today,
    required this.needs,
  });

  final List<SpaceSummary> spaces;
  final List<SpaceToday> today;
  final List<NeedsCard> needs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final now = ref.watch(clockProvider)();
    final news = {for (final t in today) t.spaceId: t};
    final inNeeds = {
      for (final c in needs)
        if (c.workItemId != null) c.workItemId!,
    };
    // The latest of today's news and the daybook's last activity.
    DateTime? lastAt(SpaceSummary s) {
      final a = news[s.id]?.at;
      final b = s.lastActivityAt;
      if (a == null || b == null) return a ?? b;
      return a.isAfter(b) ? a : b;
    }

    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    final ordered = [
      ...spaces.where((s) => news.containsKey(s.id)).toList()
        ..sort((a, b) => news[b.id]!.at.compareTo(news[a.id]!.at)),
      // Equal times (none at all) keep my_spaces()' order.
      ...newestFirst(
        spaces.where((s) => !news.containsKey(s.id)).toList(),
        (s) => lastAt(s) ?? epoch,
      ),
    ];

    String line(SpaceToday r) {
      final name = inOwnDirection(r.actorName ?? l10n.activitySomeone);
      return switch (r.change) {
        SpaceChange.workItem => l10n.todayItem(
          r.eventKind ?? 'raised',
          name,
          ltrRun(r.workItemRef ?? ''),
          inOwnDirection(r.workItemTitle ?? ''),
        ),
        SpaceChange.library => l10n.todayFile(
          name,
          inOwnDirection(r.fileName ?? ''),
        ),
        SpaceChange.chat =>
          r.messageKind == 'text' && (r.messageBody ?? '').isNotEmpty
              ? l10n.todayChat(name, inOwnDirection(r.messageBody!))
              : l10n.todayChatKind(r.messageKind ?? 'text', name),
      };
    }

    // Where the news is: a Library file, a chat thread, or the daybook,
    // where work items live.
    void open(String spaceId, SpaceToday? r) {
      final file = r?.fileId;
      final thread = r?.threadId;
      if (r?.change == SpaceChange.library && file != null) {
        context.push(AppRoutes.libraryFile(spaceId, file));
      } else if (r?.change == SpaceChange.chat && thread != null) {
        context.push(AppRoutes.spaceThread(spaceId, thread));
      } else {
        context.push(AppRoutes.space(spaceId));
      }
    }

    Widget row(SpaceSummary s) {
      final r = news[s.id];
      // Already in Needs you: only the name and when it happened.
      final repeat =
          r != null &&
          r.change == SpaceChange.workItem &&
          inNeeds.contains(r.workItemId);
      final shown = repeat ? null : r;
      return InkWell(
        key: Key('home-space-${s.id}'),
        onTap: () => open(s.id, shown),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: BvActivitySpec.cardMinHeight,
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.all(
              BvActivitySpec.cardPadding,
            ),
            child: Row(
              spacing: BvActivitySpec.cardGap,
              children: [
                const BvSpaceEmblem(height: BvSpaceEmblemSpec.tile),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: BvActivitySpec.lineGap,
                    children: [
                      Text(
                        inOwnDirection(s.name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: type.titleMd,
                      ),
                      if (shown != null)
                        Text(
                          line(shown),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: type.bodySm,
                        ),
                    ],
                  ),
                ),
                if (lastAt(s) case final at?)
                  Text(
                    BvTime.of(context).moment(at, now),
                    key: Key('home-space-time-${s.id}'),
                    style: type.metadata.copyWith(
                      color: BvColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return ProfileCard(
      padding: false,
      child: Column(
        key: const Key('home-your-spaces'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, s) in ordered.indexed) ...[
            if (i > 0)
              const Divider(
                height: BvStroke.thin,
                thickness: BvStroke.thin,
                color: BvColors.borderDefault,
              ),
            row(s),
          ],
        ],
      ),
    );
  }
}

/// [items] newest first by [at]; equal times keep their order.
List<T> newestFirst<T>(List<T> items, DateTime Function(T) at) {
  final indexed = items.indexed.toList()
    ..sort((a, b) {
      final byTime = at(b.$2).compareTo(at(a.$2));
      return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
    });
  return [for (final (_, item) in indexed) item];
}

/// NEEDS YOU on Home (F28): grouped by Space, as review 48 asked. Each
/// Space's emblem and name once, then its things as rows: what happened,
/// the ref and the time, and a quiet › at the end. The whole row opens the
/// work item's card (F20). Never a count.
class _NeedsBySpace extends ConsumerWidget {
  const _NeedsBySpace({required this.cards});

  final Iterable<NeedsCard> cards;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final now = ref.watch(clockProvider)();
    // Each Space once, in the order its first thing came.
    final bySpace = <String, List<NeedsCard>>{};
    for (final c in cards) {
      bySpace.putIfAbsent(c.spaceId, () => []).add(c);
    }
    const divider = Divider(
      height: BvStroke.thin,
      thickness: BvStroke.thin,
      color: BvColors.borderDefault,
    );

    Widget row(NeedsCard c) {
      final due = c.due;
      final dueText = due == null
          ? null
          : l10n.needsDue(formatDay(due, locale));
      final meta = joinMeta([
        if (c.workItemRef != null) ltrRun(c.workItemRef!),
        BvTime.of(context).moment(c.at, now),
        ?dueText,
      ]);
      final quiet = type.metadata.copyWith(color: BvColors.textSecondary);
      // F34, F57: the due is ink today and the action colour once passed.
      final late =
          due != null &&
          (c.dueAt != null ? now.isAfter(c.dueAt!) : dayOf(now).isAfter(due));
      final tone = late
          ? BvDueTone.passed
          : due == dayOf(now)
          ? BvDueTone.today
          : BvDueTone.quiet;
      final title = needsTitle(l10n, c);
      final name = c.actorName == null ? null : inOwnDirection(c.actorName!);
      return InkWell(
        key: Key('needs-${c.cardId ?? c.requestId ?? c.spaceId}'),
        onTap: () => openNeeds(context, c),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: BvActivitySpec.cardMinHeight,
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              BvActivitySpec.cardPaddingStart,
              BvActivitySpec.cardPadding,
              BvActivitySpec.cardPadding,
              BvActivitySpec.cardPadding,
            ),
            child: Row(
              spacing: BvActivitySpec.cardGap,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: BvActivitySpec.lineGap,
                    children: [
                      // F34: the name stands out in the sentence.
                      Text.rich(
                        TextSpan(
                          children: bvMarkedSpans(title, type.bodyMd, [
                            if (name != null)
                              (
                                part: name,
                                style: type.emphasis.copyWith(
                                  color: BvColors.textPrimary,
                                ),
                              ),
                          ]),
                        ),
                      ),
                      Text.rich(
                        TextSpan(
                          children: bvMarkedSpans(meta, quiet, [
                            if (dueText != null)
                              (
                                part: dueText,
                                style: quiet.copyWith(color: bvDueColor(tone)),
                              ),
                          ]),
                        ),
                      ),
                    ],
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

    return Column(
      key: const Key('home-needs'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BvSpace.s8,
      children: [
        for (final group in bySpace.values)
          ProfileCard(
            padding: false,
            child: Column(
              key: Key('home-needs-space-${group.first.spaceId}'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    BvActivitySpec.cardPaddingStart,
                    BvActivitySpec.cardPadding,
                    BvActivitySpec.cardPadding,
                    BvSpace.s4,
                  ),
                  child: Row(
                    spacing: BvSpace.s8,
                    children: [
                      const BvSpaceEmblem(height: BvSpaceEmblemSpec.tile),
                      Expanded(
                        child: Text(
                          inOwnDirection(group.first.spaceName),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: type.titleMd,
                        ),
                      ),
                    ],
                  ),
                ),
                for (final (i, c) in group.indexed) ...[
                  if (i > 0) divider,
                  row(c),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
