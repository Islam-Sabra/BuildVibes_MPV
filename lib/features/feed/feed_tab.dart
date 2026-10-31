import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/around_specs.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_writing_specs.dart';
import '../../core/push/push_state.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/post.dart';
import '../../data/models/space.dart';
import '../../data/repositories/market_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_daybook_masthead.dart';
import '../../shared/widgets/bv_new_chip.dart';
import '../../shared/widgets/bv_writing_toolbar.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../notebook/notebook_page_screen.dart' show reminderWhen;
import '../work/daybook_words.dart';
import '../work/post_later_sheet.dart';
import '../entry/entry_state.dart';
import '../profile/widgets/profile_parts.dart';
import '../spaces/space_errors.dart';
import 'feed_state.dart';
import 'post_card.dart';
import 'post_draft.dart';
import 'post_writing.dart';

/// H1 v4 · Feed (2587:35849, AR 2588:412): today's one-line date, then
/// full-width cards: the post being written at Now (H2), posts waiting on
/// this phone, and site updates from the home market, the "Beyond
/// {market}" divider, and the rest. H4 skeleton, H5 couldn't load, H6 offline, and an empty feed with
/// Create.
///
/// Create (from every tab) writes a post in place at Now (H2): the writing
/// toolbar sits on the keyboard. A card with anything in it stays as a
/// Draft; with no signal a post waits on the phone ("Waiting to send") and
/// sends when the signal is back; a refused one comes back to its Draft
/// ("Couldn't send. Tap to fix").
class FeedTab extends ConsumerStatefulWidget {
  const FeedTab({super.key});

  @override
  ConsumerState<FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends ConsumerState<FeedTab> {
  final _scroll = ScrollController();
  final _listKey = GlobalKey();

  /// Each post's place on the page, to keep the one being read still when
  /// new posts come in above it.
  final _entryKeys = <String, GlobalKey>{};
  Timer? _skeletonTimer;
  var _skeletonDone = false;
  late final AppLifecycleListener _life;

  /// New posts came in at the top while the reader was further down
  /// (F11): the "New" chip shows until they go to the top.
  var _newAbove = false;

  /// Whether Home was on screen at the last look ([TickerMode]): shown
  /// again, it reads again.
  bool? _shown;

  PostWritingMenu? _menu;

  /// The card on the page was left from before: it says "Draft".
  late bool _fromBefore;

  @override
  void initState() {
    super.initState();
    _fromBefore = ref.read(postDraftProvider) != null;
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < BvSpace.s64 * 6) {
        unawaited(ref.read(feedProvider.notifier).loadMore());
      }
      if (_newAbove && !_away) setState(() => _newAbove = false);
    });
    _skeletonTimer = Timer(BvPostSpec.skeletonFor, () {
      if (mounted) setState(() => _skeletonDone = true);
    });
    // The feed is never stale (F11, F18): it reads the newest posts when
    // the app comes back to the front, when Home is shown again, and when
    // a push arrives with Home open (build). A post made with no signal
    // sends when it's back (the outbox also tries by itself).
    _life = AppLifecycleListener(
      onResume: () {
        _flush();
        _refresh();
      },
    );
    // Kept from before (Feed shown again after Spaces): read again. A
    // first load is already reading.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(feedProvider).hasValue) _refresh();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Home shown again: back from another tab, or a page on top closed.
    final shown = TickerMode.valuesOf(context).enabled;
    if (_shown == false && shown) _refresh();
    _shown = shown;
  }

  @override
  void dispose() {
    _skeletonTimer?.cancel();
    _life.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _flush() {
    if (mounted) unawaited(ref.read(postOutboxProvider.notifier).flushAll());
  }

  void _refresh() {
    if (mounted) unawaited(ref.read(feedProvider.notifier).refreshNewest());
  }

  /// The reader is further down, away from the newest posts.
  bool get _away =>
      _scroll.hasClients && _scroll.offset > BvNewChipSpec.awayFromNow;

  /// The top of the post on top of the page, and which one it is.
  (String, double)? _anchor(List<FeedEntry> entries) {
    final list = _listKey.currentContext?.findRenderObject() as RenderBox?;
    if (list == null || !list.hasSize) return null;
    final top = list.localToGlobal(Offset.zero).dy;
    for (final e in entries) {
      final box =
          _entryKeys[e.post.id]?.currentContext?.findRenderObject()
              as RenderBox?;
      if (box == null || !box.attached || !box.hasSize) continue;
      final y = box.localToGlobal(Offset.zero).dy;
      if (y + box.size.height > top) return (e.post.id, y);
    }
    return null;
  }

  /// New posts above while the reader is further down: the post being
  /// read stays where it is, and the "New" chip shows.
  void _arrivedAbove(FeedState? before, FeedState now) {
    if (before == null || before.entries.isEmpty || !_away) return;
    final known = {for (final e in before.entries) e.post.id};
    final mine = {for (final p in ref.read(postOutboxProvider)) p.id};
    // Older pages come in at the end: they aren't new.
    final lastKnown = now.entries.lastIndexWhere(
      (e) => known.contains(e.post.id),
    );
    final fresh = now.entries
        .take(math.max(0, lastKnown))
        .any((e) => !known.contains(e.post.id) && !mine.contains(e.post.id));
    if (!fresh) return;
    final anchor = _anchor(before.entries);
    setState(() => _newAbove = true);
    if (anchor == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final box =
          _entryKeys[anchor.$1]?.currentContext?.findRenderObject()
              as RenderBox?;
      if (box == null || !box.attached || !box.hasSize) return;
      final moved = box.localToGlobal(Offset.zero).dy - anchor.$2;
      if (moved == 0) return;
      final position = _scroll.position;
      _scroll.jumpTo(
        (position.pixels + moved).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
      );
    });
  }

  void _toTop() {
    setState(() => _newAbove = false);
    if (_scroll.hasClients) {
      unawaited(
        _scroll.animateTo(0, duration: BvMotion.base, curve: BvMotion.standard),
      );
    }
  }

  GlobalKey _keyOf(String postId) =>
      _entryKeys.putIfAbsent(postId, GlobalKey.new);

  PostWriting get _mode => ref.read(postWritingProvider);
  bool get _editing => _mode == PostWriting.editing;
  PostWriter get _writer => PostWriter(ref, editing: _editing);

  void _write() => ref.read(postWritingProvider.notifier).write();

  /// Puts the card down: with anything in it, it stays as the Draft;
  /// empty, it goes. An edit put down leaves the post as it was.
  void _stopWriting() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_editing) {
      ref.read(postEditProvider.notifier).stop();
    } else {
      final draft = ref.read(postDraftProvider);
      unawaited(ref.read(postDraftProvider.notifier).close());
      if (draft != null && !draft.isEmpty) _fromBefore = true;
    }
    ref.read(postWritingProvider.notifier).stop();
    setState(() => _menu = null);
  }

  void _setMenu(PostWritingMenu? menu) => setState(() => _menu = menu);

  Future<void> _addPhoto({required bool camera}) async {
    _setMenu(null);
    if (!_writer.roomForPhoto) {
      showSpaceMessage(
        context,
        AppLocalizations.of(context).postWritingPhotosMax,
      );
      return;
    }
    final refused = await _writer.addPhoto(camera: camera);
    if (refused > 0 && mounted) {
      showSpaceMessage(context, AppLocalizations.of(context).photoCannotOpen);
    }
  }

  /// Post later (review 108 PL1): the time, then "Scheduled for …".
  Future<void> _postLater() async {
    final at = await showPostLaterSheet(context);
    if (at == null || !mounted) return;
    final l10n = AppLocalizations.of(context);
    final now = ref.read(clockProvider)();
    await _post(at: at);
    if (!mounted) return;
    final words = DaybookWords(
      l10n,
      Localizations.localeOf(context).toLanguageTag(),
      use24: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    showSpaceMessage(
      context,
      l10n.plScheduledFor(reminderWhen(l10n, words, at, now)),
    );
  }

  Future<void> _post({DateTime? at}) async {
    await _writer.post(at: at);
    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    ref.read(postWritingProvider.notifier).stop();
    setState(() {
      _menu = null;
      _fromBefore = false;
    });
  }

  Future<void> _save() async {
    try {
      await _writer.save();
    } on SpaceException catch (e) {
      if (mounted) showSpaceError(context, e);
      return;
    }
    if (mounted) _stopWriting();
  }

  /// A refused post that waited while another card was written: back into
  /// the Draft when the card is free, and writing reopens.
  Future<void> _reopen(PendingPost p) async {
    final moved = await ref.read(postOutboxProvider.notifier).reopenRefused(p);
    if (!mounted || !moved) return;
    _fromBefore = true;
    _write();
  }

  /// A post still on the phone, as its card at the time Post was tapped.
  Post _waitingPost(PendingPost p, String me, String myName) => Post(
    id: p.id,
    authorId: me,
    authorName: myName,
    body: p.body.isEmpty ? null : p.body,
    lang: p.lang,
    project: p.project,
    createdAt: p.madeAt,
    photos: [for (final ph in p.photos) PostPhoto(path: ph.local)],
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final feed = ref.watch(feedProvider);
    // Post later's go to the server, never to Home (review 108 PL1).
    final pending = [
      for (final p in ref.watch(postOutboxProvider))
        if (p.scheduleAt == null) p,
    ];
    final mode = ref.watch(postWritingProvider);
    final draft = ref.watch(postDraftProvider);
    final edit = ref.watch(postEditProvider);
    // A push with Home open: read again (a Space's push is the daybook's).
    ref.listen(pushArrivalProvider, (_, push) {
      if (push != null && push.spaceId == null) _refresh();
    });
    ref.listen(feedProvider, (was, now) {
      final value = now.value;
      if (now.hasValue && value != null) _arrivedAbove(was?.value, value);
    });
    final writing = mode != PostWriting.none;
    final editing = mode == PostWriting.editing;
    // The card at Now: open, or a Draft left with anything in it.
    final card = writing || (draft != null && !draft.isEmpty);
    // Opening the card shows Now, at the top.
    ref.listen(postWritingProvider, (was, now) {
      if (now == PostWriting.none) return;
      setState(() => _menu = null);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(0);
      });
    });
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
    final profile = ref.watch(myProfileProvider).value;
    final me = ref.watch(authUserIdProvider).value ?? '';
    final myName = profile == null
        ? ''
        : '${profile.firstName} ${profile.lastName}';
    final market = ref
        .watch(marketsProvider)
        .value
        ?.where((m) => m.id == profile?.homeMarketId)
        .firstOrNull
        ?.name
        .of(locale);

    if (data == null && !card) {
      if (feed.hasError) {
        return _CouldntLoad(onRetry: () => ref.invalidate(feedProvider));
      }
      // H4 skeleton, no longer than it takes for the first page.
      return const _Skeleton();
    }

    final entries = data?.entries ?? const <FeedEntry>[];
    final firstBeyond = entries.indexWhere(
      (e) => e.section == FeedSection.beyond,
    );
    final words = DaybookWords(
      l10n,
      locale.toLanguageTag(),
      use24: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final now = ref.watch(clockProvider)();
    final onServer = {for (final e in entries) e.post.id};
    final waiting = [
      for (final p in pending.reversed)
        if (!onServer.contains(p.id)) p,
    ];
    final cardDraft = editing ? edit : draft;
    final children = <Widget>[
      // The one-line date (H1 v4): the date alone, as the feed isn't only
      // people you follow (review 48).
      BvDaybookMasthead(weekday: words.weekday(now), date: words.dayMonth(now)),
      if (data?.offline ?? false)
        Container(
          key: const Key('feed-offline'),
          margin: const EdgeInsetsDirectional.symmetric(
            horizontal: BvSpace.gutter,
            vertical: BvSpace.s6,
          ),
          padding: const EdgeInsetsDirectional.all(BvSpace.s12),
          decoration: const BoxDecoration(
            color: BvColors.surfaceSubtle,
            borderRadius: BvRadius.controlAll,
          ),
          child: Text(l10n.feedOffline, style: BvType.of(context).labelMd),
        ),
      if (entries.isEmpty && !card && waiting.isEmpty)
        Padding(
          padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
          child: Column(
            key: const Key('feed-empty'),
            spacing: BvSpace.s16,
            children: [
              EmptyNote(l10n.feedEmpty),
              BvButton(
                key: const Key('feed-create'),
                label: l10n.feedNewPost,
                onPressed: _write,
              ),
            ],
          ),
        )
      else
        // H1 v4: full-width cards, newest first, 16 from each edge; the
        // card at Now above them (H2). No hour spine: each card has its
        // time.
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            BvSpace.gutter,
            BvHomeSpec.feedPaddingTop,
            BvSpace.gutter,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: BvHomeSpec.cardGap,
            children: [
              if (card)
                PostWritingCard(
                  // An edit's card is its own.
                  key: ValueKey(editing),
                  writing: writing,
                  editing: editing,
                  // A refused post is back as the Draft (review 46).
                  fromBefore:
                      (_fromBefore || (draft?.couldNotSend ?? false)) &&
                      !editing,
                  onOpen: _write,
                ),
              for (final p in waiting)
                PostCard.waiting(
                  post: _waitingPost(p, me, myName),
                  couldNotSend: p.refused,
                  // Sent: no label, though the feed hasn't read it yet
                  // (F17).
                  sent: p.sent,
                  onOpen: p.refused ? () => unawaited(_reopen(p)) : null,
                ),
              for (var i = 0; i < entries.length; i++) ...[
                // The divider only when there were home posts above it.
                if (i == firstBeyond && i > 0)
                  _Divider(label: l10n.feedBeyond(market ?? '')),
                PostCard(
                  key: _keyOf(entries[i].post.id),
                  post: entries[i].post,
                  onOpen: () =>
                      context.push(AppRoutes.post(entries[i].post.id)),
                  onReplyLine: (reply) => context.push(
                    AppRoutes.post(entries[i].post.id, reply: reply),
                  ),
                  onChanged: ref.read(feedProvider.notifier).replace,
                ),
              ],
            ],
          ),
        ),
      if (data?.loadingMore ?? false)
        const Center(child: CircularProgressIndicator()),
    ];

    final list = RefreshIndicator(
      onRefresh: () => ref.refresh(feedProvider.future),
      child: ListView(
        key: const Key('feed-list'),
        controller: _scroll,
        // With its own controller a list doesn't pull when it's shorter
        // than the page: pull to refresh must always work (F18).
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsetsDirectional.only(bottom: BvSpace.s16),
        children: children,
      ),
    );

    return PopScope(
      canPop: !writing,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _menu != null ? _setMenu(null) : _stopWriting();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => Stack(
                children: [
                  Positioned.fill(
                    key: _listKey,
                    child: GestureDetector(
                      // While writing, a tap off the card puts it down.
                      behavior: HitTestBehavior.opaque,
                      onTap: writing ? _stopWriting : null,
                      child: list,
                    ),
                  ),
                  if (_newAbove && !writing)
                    PositionedDirectional(
                      start: 0,
                      end: 0,
                      top: BvNewChipSpec.offset,
                      child: Center(
                        child: BvNewChip(
                          key: const Key('feed-new'),
                          label: l10n.feedNew,
                          below: false,
                          onTap: _toTop,
                        ),
                      ),
                    ),
                  if (_menu != null) ...[
                    // No dim: a tap anywhere else closes it (E2).
                    Positioned.fill(
                      child: GestureDetector(
                        key: const Key('post-menu-away'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _setMenu(null),
                      ),
                    ),
                    PositionedDirectional(
                      start: BvPopoverMenuSpec.writingStart,
                      bottom: BvPopoverMenuSpec.writingGap,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: math.max(
                            0,
                            constraints.maxHeight -
                                2 * BvPopoverMenuSpec.writingGap,
                          ),
                        ),
                        child: PostWritingPopover(
                          key: ValueKey((_menu, editing)),
                          menu: _menu!,
                          editing: editing,
                          onMenu: _setMenu,
                          onClose: () => _setMenu(null),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (writing)
            BvWritingToolbar(
              cameraLabel: l10n.daybookCamera,
              // An edit keeps its photos (edit_post).
              onCamera: editing ? null : () => _addPhoto(camera: true),
              attachLabel: l10n.daybookAddPhoto,
              onAttach: editing ? null : () => _addPhoto(camera: false),
              moreLabel: l10n.daybookMore,
              onMore: () => _setMenu(
                _menu == PostWritingMenu.more ? null : PostWritingMenu.more,
              ),
              moreActive: _menu == PostWritingMenu.more,
              postLabel: editing ? l10n.daybookSave : l10n.daybookPost,
              // Text or a photo (create_post); an edit keeps its photos.
              onPost:
                  (cardDraft?.canPost ?? false) ||
                      (editing &&
                          (ref
                                  .read(postEditProvider.notifier)
                                  .original
                                  ?.photos
                                  .isNotEmpty ??
                              false))
                  ? (editing ? _save : _post)
                  : null,
              // Review 108 PL1: Post later, once it could go now.
              laterLabel: editing ? null : l10n.plTitle,
              onLater: !editing && (cardDraft?.canPost ?? false)
                  ? () => unawaited(_postLater())
                  : null,
            ),
        ],
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
