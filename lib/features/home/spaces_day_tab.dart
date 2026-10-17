import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/ago.dart';
import '../../core/l10n/bidi.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/activity.dart';
import '../../data/models/space.dart';
import '../../data/repositories/space_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_space_tile.dart';
import '../../shared/widgets/bv_text_field.dart' show BvWesternDigitsFormatter;
import '../activity/activity_state.dart';
import '../activity/needs_card.dart';
import '../entry/entry_state.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../profile/widgets/profile_parts.dart';
import '../spaces/code_sheet.dart';
import '../spaces/my_spaces_view.dart';

/// Home → Spaces (H1b, review 50 F3 + F10): one line with the date and
/// what needs you; New Space and Enter an invite code; at most 3 things
/// that need you; then Your Spaces, every Space once. Without a Space:
/// My Spaces' empty state (H1e), where both actions are large.
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
            for (final c in needs.take(BvActivitySpec.needsOnHome)) ...[
              NeedsYouCard(card: c),
              const SizedBox(height: BvSpace.s8),
            ],
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

/// One small line: "SATURDAY 17 OCTOBER · 1 thing needs you" (F10). No
/// title, no place, and no other counts.
class _Header extends ConsumerWidget {
  const _Header({required this.needs});

  final int needs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final locale = Localizations.localeOf(context);
    final now = ref.watch(clockProvider)();
    final date = BvWesternDigitsFormatter.normalise(
      DateFormat('EEEE d MMMM', locale.languageCode).format(now),
    ).toUpperCase();
    final muted = type.labelSm.copyWith(color: BvColors.textSecondary);
    return Text.rich(
      key: const Key('home-day-header'),
      TextSpan(
        children: [
          TextSpan(
            text: date,
            style: type.overline.copyWith(color: BvColors.textSecondary),
          ),
          TextSpan(text: ' · ', style: muted),
          if (needs > 0) ...[
            const WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: EdgeInsetsDirectional.only(end: BvSpace.s6),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: BvColors.iconAction,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(dimension: BvActivitySpec.newDot),
                ),
              ),
            ),
            TextSpan(
              text: l10n.homeDayNeedsYou(needs),
              style: type.labelSm.copyWith(color: BvColors.textAction),
            ),
          ] else
            TextSpan(text: l10n.homeNothingNeedsYou, style: muted),
        ],
      ),
    );
  }
}

/// New Space and Enter an invite code, side by side above the list (F3):
/// a foreman with a code is one tap from joining.
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
            label: l10n.spacesEnterCode,
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

/// YOUR SPACES (F3, F10): every Space once. Spaces with news today come
/// first, newest first, each with its latest news unless Needs you
/// already shows it; then the rest, as my_spaces() orders them. Never a
/// count.
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
    final ordered = [
      ...spaces.where((s) => news.containsKey(s.id)).toList()
        ..sort((a, b) => news[b.id]!.at.compareTo(news[a.id]!.at)),
      ...spaces.where((s) => !news.containsKey(s.id)),
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
                BvSpaceTile(name: s.name),
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
                if (r != null)
                  Text(
                    formatRowAgo(l10n, r.at.toLocal(), now),
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
