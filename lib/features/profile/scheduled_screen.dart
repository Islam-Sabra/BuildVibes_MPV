import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/space.dart';
import '../../data/repositories/schedule_repository.dart';
import '../../data/repositories/space_repository.dart' show spaceDetailProvider;
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_pill_button.dart';
import '../notebook/notebook_page_screen.dart' show reminderWhen;
import '../spaces/space_errors.dart';
import '../work/daybook_words.dart';
import '../work/post_later_sheet.dart';
import 'edit/experience_screens.dart' show clockProvider;

/// Scheduled (review 108 PL2, 2701:39329): my posts waiting to go out,
/// soonest first, each with when and where, then Post now · Edit (its
/// time) · Cancel. One that couldn't go says why.
class ScheduledScreen extends ConsumerWidget {
  const ScheduledScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final posts = ref.watch(myScheduledProvider);
    return Scaffold(
      key: const Key('scheduled-screen'),
      backgroundColor: BvColors.surfaceApp,
      appBar: AppBar(
        title: Text(l10n.plScheduled),
        backgroundColor: BvColors.surfaceApp,
      ),
      body: posts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: BvButton(
            label: l10n.commonRetry,
            style: BvButtonStyle.secondary,
            onPressed: () => ref.invalidate(myScheduledProvider),
          ),
        ),
        data: (posts) => posts.isEmpty
            ? Center(
                child: Text(
                  l10n.plEmpty,
                  style: type.bodyMd.copyWith(color: BvColors.textSecondary),
                ),
              )
            : ListView(
                padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
                children: [
                  for (final p in posts)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        bottom: BvSpace.s12,
                      ),
                      child: _ScheduledCard(post: p),
                    ),
                ],
              ),
      ),
    );
  }
}

class _ScheduledCard extends ConsumerWidget {
  const _ScheduledCard({required this.post});

  final ScheduledPost post;

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function(ScheduleRepository repo) run,
  ) async {
    try {
      await run(ref.read(scheduleRepositoryProvider));
    } on SpaceException catch (e) {
      if (context.mounted) showSpaceError(context, e);
    }
    ref.invalidate(myScheduledProvider);
  }

  /// Another time, on the Space's clock and calendar for a Space's (V3).
  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final space = switch (post.spaceId) {
      final id? => await ref.read(spaceDetailProvider(id).future),
      null => null,
    };
    if (!context.mounted) return;
    final later = await showPostLaterSheet(
      context,
      zone: space?.timeZone,
      marketId: space?.marketId,
    );
    if (later == null || !context.mounted) return;
    await _run(context, ref, (repo) => repo.reschedule(post.id, later.at));
  }

  String _reason(AppLocalizations l10n) => switch (post.error) {
    'not_allowed' => l10n.plReasonNotAllowed,
    'not_valid' => l10n.plReasonNotValid,
    _ => l10n.plReasonOther,
  };

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
    final failed = post.state == ScheduledState.failed;
    return Container(
      key: Key('scheduled-${post.id}'),
      padding: const EdgeInsetsDirectional.all(BvSpace.s12),
      decoration: BoxDecoration(
        color: BvColors.surfaceElevated,
        borderRadius: BvRadius.cardAll,
        border: Border.all(color: BvColors.borderSubtle, width: BvStroke.thin),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BvSpace.s8,
        children: [
          Row(
            spacing: BvSpace.s6,
            children: [
              Icon(
                BvIcons.clock,
                size: BvSize.iconSm,
                color: failed ? BvColors.iconSecondary : BvColors.iconAction,
              ),
              Expanded(
                child: Text(
                  reminderWhen(l10n, words, post.publishAt, now),
                  style: type.labelSm.copyWith(
                    color: failed
                        ? BvColors.textSecondary
                        : BvColors.textAction,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  post.spaceId == null
                      ? l10n.plFeed
                      : inOwnDirection(post.spaceName ?? ''),
                  style: type.metadata.copyWith(color: BvColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(
            post.title,
            style: type.titleMd,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (failed)
            Text(
              l10n.plFailed(_reason(l10n)),
              style: type.metadata.copyWith(color: BvColors.textDestructive),
            ),
          Wrap(
            spacing: BvSpace.s8,
            children: [
              BvPillButton(
                key: Key('scheduled-post-now-${post.id}'),
                label: l10n.plPostNow,
                soft: true,
                onTap: () => unawaited(
                  _run(context, ref, (repo) => repo.postNow(post.id)),
                ),
              ),
              // V2: a failed one is tried again or cleared.
              if (!failed)
                BvPillButton(
                  key: Key('scheduled-edit-${post.id}'),
                  label: l10n.plEdit,
                  grey: true,
                  onTap: () => unawaited(_edit(context, ref)),
                ),
              BvPillButton(
                key: Key('scheduled-cancel-${post.id}'),
                label: l10n.plCancel,
                quiet: true,
                onTap: () => unawaited(
                  _run(context, ref, (repo) => repo.cancel(post.id)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Review 108 PL2: the small "{n} scheduled" line in a Space when I have
/// some waiting there; it opens Scheduled.
class ScheduledLine extends StatelessWidget {
  const ScheduledLine({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    return InkWell(
      key: const Key('space-scheduled'),
      onTap: () => context.push(AppRoutes.scheduledPosts),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: BvSpace.gutter,
          vertical: BvSpace.s8,
        ),
        child: Row(
          spacing: BvSpace.s6,
          children: [
            const Icon(
              BvIcons.clock,
              size: BvSize.iconSm,
              color: BvColors.iconAction,
            ),
            Text(
              l10n.plCount(count),
              style: type.labelSm.copyWith(color: BvColors.textAction),
            ),
          ],
        ),
      ),
    );
  }
}
