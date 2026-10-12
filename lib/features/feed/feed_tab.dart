import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/post.dart';
import '../../data/models/space.dart';
import '../../data/repositories/market_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../entry/entry_state.dart';
import '../profile/widgets/profile_parts.dart';
import '../spaces/space_errors.dart';
import 'feed_state.dart';
import 'post_card.dart';

/// H1 v2 · Feed: posts waiting on this phone, then site updates from the
/// home market, the "Beyond {market}" divider, and the rest. H4 skeleton,
/// H5 couldn't load, H6 offline, and an empty feed with Create.
class FeedTab extends ConsumerStatefulWidget {
  const FeedTab({super.key});

  @override
  ConsumerState<FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends ConsumerState<FeedTab> {
  final _scroll = ScrollController();
  Timer? _skeletonTimer;
  var _skeletonDone = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < BvSpace.s64 * 6) {
        unawaited(ref.read(feedProvider.notifier).loadMore());
      }
    });
    _skeletonTimer = Timer(BvPostSpec.skeletonFor, () {
      if (mounted) setState(() => _skeletonDone = true);
    });
  }

  @override
  void dispose() {
    _skeletonTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final feed = ref.watch(feedProvider);
    final pending = ref.watch(postOutboxProvider);
    // After 3 seconds of loading, the copy kept on the phone (H4).
    final data =
        feed.value ??
        (_skeletonDone && feed.isLoading
            ? switch (ref.read(feedProvider.notifier).cached()) {
                final List<FeedEntry> kept => FeedState(entries: kept),
                null => null,
              }
            : null);
    final locale = Localizations.localeOf(context);
    final marketId = ref.watch(myProfileProvider).value?.homeMarketId;
    final market = ref
        .watch(marketsProvider)
        .value
        ?.where((m) => m.id == marketId)
        .firstOrNull
        ?.name
        .of(locale);

    if (data == null) {
      if (feed.hasError) {
        return _CouldntLoad(onRetry: () => ref.invalidate(feedProvider));
      }
      // H4 skeleton, no longer than it takes for the first page.
      return const _Skeleton();
    }

    final entries = data.entries;
    final firstBeyond = entries.indexWhere(
      (e) => e.section == FeedSection.beyond,
    );
    final children = <Widget>[
      for (final p in pending.reversed) _PendingBanner(post: p),
      if (data.offline)
        Container(
          key: const Key('feed-offline'),
          padding: const EdgeInsetsDirectional.all(BvSpace.s12),
          decoration: const BoxDecoration(
            color: BvColors.surfaceSubtle,
            borderRadius: BvRadius.controlAll,
          ),
          child: Text(l10n.feedOffline, style: BvType.of(context).labelMd),
        ),
      if (entries.isEmpty)
        Column(
          key: const Key('feed-empty'),
          spacing: BvSpace.s16,
          children: [
            EmptyNote(l10n.feedEmpty),
            BvButton(
              key: const Key('feed-create'),
              label: l10n.feedNewPost,
              onPressed: () => context.push(AppRoutes.postNew),
            ),
          ],
        ),
      for (var i = 0; i < entries.length; i++) ...[
        // The divider only when there were home posts above it.
        if (i == firstBeyond && i > 0)
          _Divider(label: l10n.feedBeyond(market ?? '')),
        PostCard(
          post: entries[i].post,
          onOpen: () => context.push(AppRoutes.post(entries[i].post.id)),
          onChanged: ref.read(feedProvider.notifier).replace,
        ),
      ],
      if (data.loadingMore) const Center(child: CircularProgressIndicator()),
    ];

    return RefreshIndicator(
      onRefresh: () => ref.refresh(feedProvider.future),
      child: ListView.separated(
        key: const Key('feed-list'),
        controller: _scroll,
        padding: const EdgeInsetsDirectional.all(BvSpace.s16),
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(height: BvSpace.s12),
        itemBuilder: (_, i) => children[i],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return Row(
      key: const Key('feed-beyond'),
      spacing: BvSpace.s12,
      children: [
        const Expanded(child: Divider(color: BvColors.borderDefault)),
        Text(
          label,
          style: type.labelMd.copyWith(color: BvColors.textSecondary),
        ),
        const Expanded(child: Divider(color: BvColors.borderDefault)),
      ],
    );
  }
}

/// P3 "Posting to your network…", or P3b "Couldn't post. Saved as a
/// draft." with Retry. Nothing is lost.
class _PendingBanner extends ConsumerWidget {
  const _PendingBanner({required this.post});

  final PendingPost post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final photo = post.photos.firstOrNull;
    return Container(
      key: Key('feed-pending-${post.id}'),
      padding: const EdgeInsetsDirectional.all(BvSpace.s16),
      decoration: BoxDecoration(
        color: BvColors.surfaceElevated,
        borderRadius: BvRadius.cardAll,
        border: Border.all(color: BvColors.borderDefault, width: BvStroke.thin),
      ),
      child: Row(
        spacing: BvSpace.s12,
        children: [
          if (photo != null)
            ClipRRect(
              borderRadius: BvRadius.smallAll,
              child: Image.file(
                File(photo.local),
                width: BvSize.avatarMd,
                height: BvSize.avatarMd,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const SizedBox(width: BvSize.avatarMd),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: BvSpace.s4,
              children: [
                Text(
                  post.failed ? l10n.postFailed : l10n.postPosting,
                  style: type.labelMd,
                ),
                if (post.failed)
                  Text(
                    l10n.postFailedHint,
                    style: type.bodySm.copyWith(color: BvColors.textSecondary),
                  )
                else
                  const LinearProgressIndicator(
                    color: BvColors.textAction,
                    backgroundColor: BvColors.borderDefault,
                  ),
              ],
            ),
          ),
          if (post.failed)
            BvButton(
              key: Key('feed-retry-${post.id}'),
              label: l10n.chatRetry,
              style: BvButtonStyle.tertiary,
              size: BvButtonSize.medium,
              padded: false,
              onPressed: () async {
                try {
                  await ref.read(postOutboxProvider.notifier).retry(post.id);
                } on SpaceException catch (e) {
                  if (context.mounted) showSpaceError(context, e);
                }
              },
            ),
        ],
      ),
    );
  }
}

class _CouldntLoad extends StatelessWidget {
  const _CouldntLoad({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    return Padding(
      key: const Key('feed-error'),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: BvSpace.gutter,
        vertical: BvSpace.s64,
      ),
      child: Column(
        spacing: BvSpace.s12,
        children: [
          Container(
            width: BvSize.avatarLg,
            height: BvSize.avatarLg,
            decoration: const BoxDecoration(
              color: BvColors.surfaceBrandSoft,
              borderRadius: BvRadius.cardAll,
            ),
            child: const Icon(
              BvIcons.explore,
              size: BvSize.iconMd,
              color: BvColors.iconPrimary,
            ),
          ),
          Text(
            l10n.feedCouldntLoad,
            textAlign: TextAlign.center,
            style: type.headingMd,
          ),
          Text(
            l10n.feedCouldntLoadBody,
            textAlign: TextAlign.center,
            style: type.bodySm.copyWith(color: BvColors.textSecondary),
          ),
          BvButton(
            key: const Key('feed-try-again'),
            label: l10n.commonRetry,
            size: BvButtonSize.medium,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

/// H4: two grey cards while the first page loads.
class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: const BoxDecoration(
        color: BvColors.surfaceSubtle,
        borderRadius: BvRadius.smallAll,
      ),
    );
    Widget card(double media) => Container(
      padding: const EdgeInsetsDirectional.all(BvSpace.s16),
      decoration: BoxDecoration(
        color: BvColors.surfaceElevated,
        borderRadius: BvRadius.cardAll,
        border: Border.all(color: BvColors.borderDefault, width: BvStroke.thin),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: BvSpace.s16,
        children: [
          Row(
            spacing: BvSpace.s12,
            children: [
              Container(
                width: BvSize.avatarMd,
                height: BvSize.avatarMd,
                decoration: const BoxDecoration(
                  color: BvColors.surfaceSubtle,
                  shape: BoxShape.circle,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: BvSpace.s8,
                children: [
                  bar(BvSpace.s64 * 2, BvSpace.s8),
                  bar(BvSpace.s64 * 1.4, BvSpace.s8),
                ],
              ),
            ],
          ),
          bar(double.infinity, media),
          bar(BvSpace.s64 * 3, BvSpace.s8),
        ],
      ),
    );
    return ListView(
      key: const Key('feed-skeleton'),
      padding: const EdgeInsetsDirectional.all(BvSpace.s16),
      children: [
        card(BvSpace.s64 * 2.3),
        const SizedBox(height: BvSpace.s12),
        card(BvSpace.s64),
      ],
    );
  }
}
