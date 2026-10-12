import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/ago.dart';
import '../../core/l10n/bidi.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/activity.dart';
import '../../data/repositories/profile_page_repository.dart';
import '../../data/repositories/space_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_text_field.dart' show BvWesternDigitsFormatter;
import '../activity/activity_state.dart';
import '../activity/needs_card.dart';
import '../entry/entry_state.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../spaces/my_spaces_view.dart';

/// Home → Spaces (H1b): your day on site. The header, at most 3 things
/// that need you, and what is new today in your Spaces. Without a Space:
/// My Spaces' empty state (H1e) with "Enter an invite code".
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
    final day = ref.watch(homeDayProvider).value ?? const HomeDay();

    Future<void> refresh() async {
      refreshDay(ref.invalidate);
      ref.invalidate(mySpacesProvider);
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
          BvSpace.s8,
          BvSpace.gutter,
          BvSpace.s32,
        ),
        children: [
          _Header(day: day),
          if (needs.isNotEmpty) ...[
            const SizedBox(height: BvSpace.s24),
            overline(l10n.homeNeedsYou),
            const SizedBox(height: BvSpace.s8),
            for (final c in needs.take(BvActivitySpec.needsOnHome)) ...[
              NeedsYouCard(card: c),
              const SizedBox(height: BvSpace.s8),
            ],
            if (needs.length > BvActivitySpec.needsOnHome)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  key: const Key('home-needs-all'),
                  onPressed: () => context.go(AppRoutes.activity),
                  child: Text(l10n.homeSeeAll),
                ),
              ),
          ],
          if (today.isNotEmpty) ...[
            const SizedBox(height: BvSpace.s16),
            overline(l10n.homeTodayInSpaces),
            const SizedBox(height: BvSpace.s8),
            _TodayCard(rows: today.take(BvActivitySpec.todayRows).toList()),
          ],
          if (needs.isEmpty) ...[
            const SizedBox(height: BvSpace.s32),
            Column(
              key: const Key('home-thats-your-day'),
              spacing: BvSpace.s4,
              children: [
                const Icon(
                  BvIcons.check,
                  size: BvSize.iconMd,
                  color: BvColors.iconPrimary,
                ),
                Text(l10n.homeThatsYourDay, style: type.titleMd),
                Text(
                  l10n.homeNothingElse,
                  style: type.bodySm.copyWith(color: BvColors.textSecondary),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// "WEDNESDAY 7 OCTOBER · KUWAIT CITY", "Your day on site", and the
/// summary line. Each part of the line hides at 0.
class _Header extends ConsumerWidget {
  const _Header({required this.day});

  final HomeDay day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final locale = Localizations.localeOf(context);
    final now = ref.watch(clockProvider)();
    final me = ref.watch(authUserIdProvider).value;
    final city = me == null
        ? null
        : ref.watch(profileViewProvider(me)).value?.placeName?.of(locale);
    final date = BvWesternDigitsFormatter.normalise(
      DateFormat('EEEE d MMMM', locale.languageCode).format(now),
    ).toUpperCase();

    final rest = [
      if (day.activeSpaces > 0) l10n.homeDaySpacesActive(day.activeSpaces),
      if (day.replies > 0) l10n.homeDayReplies(day.replies),
    ];
    final muted = type.bodySm.copyWith(color: BvColors.textSecondary);
    return Column(
      key: const Key('home-day-header'),
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: BvSpace.s4,
      children: [
        Text(
          joinMeta([date, ?city]),
          style: type.overline.copyWith(color: BvColors.textSecondary),
        ),
        Text(l10n.homeDayTitle, style: type.headingXl),
        if (day.needsYou > 0 || rest.isNotEmpty)
          Text.rich(
            key: const Key('home-day-summary'),
            TextSpan(
              children: [
                if (day.needsYou > 0) ...[
                  const WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: EdgeInsetsDirectional.only(end: BvSpace.s6),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: BvColors.iconAction,
                          shape: BoxShape.circle,
                        ),
                        child: SizedBox.square(
                          dimension: BvActivitySpec.newDot,
                        ),
                      ),
                    ),
                  ),
                  TextSpan(
                    text: l10n.homeDayNeedsYou(day.needsYou),
                    style: type.labelLg.copyWith(color: BvColors.textAction),
                  ),
                ],
                if (rest.isNotEmpty)
                  TextSpan(
                    text: day.needsYou > 0
                        ? ' · ${joinMeta(rest)}'
                        : joinMeta(rest),
                    style: muted,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// TODAY IN YOUR SPACES: one row per Space, its most important change.
class _TodayCard extends ConsumerWidget {
  const _TodayCard({required this.rows});

  final List<SpaceToday> rows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final now = ref.watch(clockProvider)();

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

    void open(SpaceToday r) {
      final item = r.workItemId;
      final file = r.fileId;
      final thread = r.threadId;
      if (r.change == SpaceChange.workItem && item != null) {
        context.push(AppRoutes.workItem(r.spaceId, item));
      } else if (r.change == SpaceChange.library && file != null) {
        context.push(AppRoutes.libraryFile(r.spaceId, file));
      } else if (r.change == SpaceChange.chat && thread != null) {
        context.push(AppRoutes.spaceThread(r.spaceId, thread));
      } else {
        context.push(AppRoutes.space(r.spaceId));
      }
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: BvColors.surfaceElevated,
        borderRadius: BvRadius.cardAll,
        border: Border.all(color: BvColors.borderDefault, width: BvStroke.thin),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              const Divider(
                height: BvStroke.thin,
                thickness: BvStroke.thin,
                color: BvColors.borderDefault,
              ),
            InkWell(
              key: Key('today-${rows[i].spaceId}'),
              onTap: () => open(rows[i]),
              child: Padding(
                padding: const EdgeInsetsDirectional.all(BvSpace.s12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: BvSpace.s12,
                  children: [
                    const BvRowIcon(BvIcons.crane, ink: true),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: BvSpace.s2,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: inOwnDirection(rows[i].spaceName),
                                  style: type.titleMd,
                                ),
                                if (rows[i].projectName != null)
                                  TextSpan(
                                    text: '  ${l10n.homeProject}',
                                    style: type.metadata.copyWith(
                                      color: BvColors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            line(rows[i]),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: type.bodySm,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatShortAgo(l10n, rows[i].at.toLocal(), now, locale),
                      style: type.metadata.copyWith(
                        color: BvColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
