import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_days_specs.dart';
import '../../core/design/daybook_writing_specs.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/daybook.dart';
import '../../data/models/space.dart';
import '../../data/models/work_item.dart';
import '../../data/repositories/space_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_day_divider.dart';
import '../../shared/widgets/bv_daybook_masthead.dart';
import '../../shared/widgets/bv_daybook_spine.dart';
import '../../shared/widgets/bv_due_today_strip.dart';
import '../../shared/widgets/bv_first_page.dart';
import '../../shared/widgets/bv_month_dropdown.dart';
import '../../shared/widgets/bv_post_bar.dart';
import '../../shared/widgets/bv_writing_toolbar.dart';
import '../account/account_parts.dart' show myMarketProvider;
import '../entry/entry_state.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../profile/widgets/profile_parts.dart';
import '../spaces/pass_words.dart';
import 'daybook_draft.dart';
import 'daybook_entry.dart';
import 'daybook_state.dart';
import 'daybook_words.dart';
import 'daybook_writing.dart';
import 'work_outbox.dart';

/// The Space's Work tab: the daybook (D1). Today's masthead at the top, the
/// newest entries at the bottom; scrolling up goes back through older days
/// on the same page, each after a day divider (DY1), and the masthead
/// names the day at the top. Tapping it drops down the month (DY2). An
/// empty Space shows its first page (DY3); a Viewer reads only (V1).
///
/// The post bar's notepad writes a work item in place at "Now" (E1–E5):
/// the masthead shrinks to one line and the writing toolbar takes the post
/// bar's place. A card left with text stays as a Draft (E4).
class DaybookTab extends ConsumerStatefulWidget {
  const DaybookTab({super.key, required this.space});

  final SpaceDetail space;

  @override
  ConsumerState<DaybookTab> createState() => _DaybookTabState();
}

class _DaybookTabState extends ConsumerState<DaybookTab> {
  /// Older entries load while this much is left to scroll back.
  static const _loadAhead = 600.0;

  /// How often a post made with no signal is tried again while the
  /// daybook is open.
  static const _flushEvery = Duration(seconds: 30);

  final _scroll = ScrollController();
  final _mastheadKey = GlobalKey();
  final _viewportKey = GlobalKey();
  final _dayKeys = <DateTime, GlobalKey>{};

  /// The loaded days, oldest first.
  var _days = <DateTime>[];

  /// The day the masthead names once scrolled back: the one at the top of
  /// the page. Null at rest on the newest posts: today.
  DateTime? _shownDay;

  /// Writing in place: the card is open with the keyboard's toolbar.
  var _writing = false;
  DaybookWritingMenu? _menu;

  /// The card on the page was left from before: it says "Draft".
  late bool _fromBefore;

  late final DaybookWriter _writer = DaybookWriter(ref, _spaceId);
  late final AppLifecycleListener _life;
  late final Timer _flushTimer;

  String get _spaceId => widget.space.id;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _fromBefore = ref.read(daybookDraftProvider(_spaceId)) != null;
    // A post made with no signal sends when it's back: on opening, on
    // coming back to the app, and every little while.
    _life = AppLifecycleListener(onResume: _flush);
    _flushTimer = Timer.periodic(_flushEvery, (_) => _flush());
    WidgetsBinding.instance.addPostFrameCallback((_) => _flush());
  }

  @override
  void dispose() {
    _flushTimer.cancel();
    _life.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _flush() {
    if (!mounted) return;
    unawaited(ref.read(workOutboxProvider.notifier).flush(_spaceId));
  }

  void _onScroll() {
    _updateShownDay();
    _loadOlderIfNear();
  }

  /// Older days hang above today on the same page (review 45 B1): load
  /// them while the top is near, including when the page isn't full yet.
  void _loadOlderIfNear() {
    if (!_scroll.hasClients || _scroll.position.extentAfter >= _loadAhead) {
      return;
    }
    unawaited(ref.read(daybookPageProvider(_spaceId).notifier).loadOlder());
  }

  void _updateShownDay() {
    final viewport =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewport == null || !viewport.hasSize || _days.isEmpty) return;
    if (!_scroll.hasClients || _scroll.offset <= 0) {
      if (_shownDay != null) setState(() => _shownDay = null);
      return;
    }
    final top = viewport.localToGlobal(Offset.zero).dy;
    DateTime? shown = _days.first;
    for (final day in _days) {
      final box =
          _dayKeys[day]?.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      if (box.localToGlobal(Offset.zero).dy <= top) shown = day;
    }
    if (shown != _shownDay) setState(() => _shownDay = shown);
  }

  /// Shows [day]: loads older pages until it is reached, then puts the
  /// latest day on or before it at the top.
  Future<void> _jumpTo(DateTime day) async {
    final provider = daybookPageProvider(_spaceId);
    final pages = ref.read(provider.notifier);
    for (;;) {
      final entries = ref.read(provider).value ?? const <DaybookRecord>[];
      if (entries.isEmpty ||
          !dayOf(entries.last.at).isAfter(day) ||
          !pages.hasOlder ||
          !await pages.loadOlder()) {
        break;
      }
    }
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || _days.isEmpty) return;
    final target = _days.lastWhere(
      (d) => !d.isAfter(day),
      orElse: () => _days.first,
    );
    final context = _dayKeys[target]?.currentContext;
    if (context == null || !context.mounted) return;
    // The list runs bottom up: 1 puts the day's top at the page's top.
    await Scrollable.ensureVisible(context, alignment: 1);
    _updateShownDay();
  }

  Future<void> _openMonth(DateTime today, DateTime shown) async {
    final masthead =
        _mastheadKey.currentContext?.findRenderObject() as RenderBox?;
    if (masthead == null) return;
    final top = masthead.localToGlobal(Offset.zero).dy;
    final firstWeekday =
        ref.read(myMarketProvider)?.weekStart ??
        MaterialLocalizations.of(context).firstDayOfWeekIndex;
    final container = ProviderScope.containerOf(context);
    final picked = await showGeneralDialog<DateTime>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: BvColors.overlayDim,
      pageBuilder: (_, _, _) => UncontrolledProviderScope(
        container: container,
        child: Padding(
          padding: EdgeInsetsDirectional.only(top: top),
          child: Align(
            alignment: AlignmentDirectional.topCenter,
            child: DaybookMonthDrop(
              spaceId: _spaceId,
              today: today,
              selected: shown,
              firstWeekday: firstWeekday,
            ),
          ),
        ),
      ),
    );
    if (picked != null && mounted) await _jumpTo(picked);
  }

  /// Opens the card at "Now", with a new post id (or the Draft's).
  void _startWriting() {
    ref
        .read(daybookDraftProvider(_spaceId).notifier)
        .open(ref.read(newPostIdProvider)());
    setState(() {
      _writing = true;
      _menu = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  /// Puts the card down: with text it stays as the Draft; empty, it goes.
  void _stopWriting() {
    FocusManager.instance.primaryFocus?.unfocus();
    final draft = ref.read(daybookDraftProvider(_spaceId));
    unawaited(ref.read(daybookDraftProvider(_spaceId).notifier).close());
    setState(() {
      _writing = false;
      _menu = null;
      if (draft != null && !draft.isEmpty) _fromBefore = true;
    });
  }

  void _setMenu(DaybookWritingMenu? menu) => setState(() => _menu = menu);

  Future<void> _pickDue() async {
    _setMenu(null);
    final draft = _writer.draft;
    final picked = await ref.read(pickDueProvider)(
      context,
      now: ref.read(clockProvider)(),
      day: draft?.dueDate,
      at: draft?.dueAt,
    );
    if (picked != null) await _writer.setDue(picked);
  }

  Future<void> _post(String? myName) async {
    await _writer.post(authorName: myName);
    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _writing = false;
      _menu = null;
      _fromBefore = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final words = DaybookWords(
      l10n,
      Localizations.localeOf(context).toLanguageTag(),
      use24: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final now = ref.watch(clockProvider)();
    final today = dayOf(now);
    final me = ref.watch(authUserIdProvider).value;
    final space = widget.space;
    final canPost = space.myRights.createItems;
    final page = ref.watch(daybookPageProvider(_spaceId));
    final due =
        ref.watch(daybookDueTodayProvider(_spaceId)).value ??
        const <CalendarWorkItem>[];
    final draft = ref.watch(daybookDraftProvider(_spaceId));
    final waiting = [
      for (final i in ref.watch(workOutboxProvider))
        if (i.kind == PendingKind.workItem && i.spaceId == _spaceId) i,
    ];
    final myName = canPost
        ? ref
              .watch(spacePeopleProvider(_spaceId))
              .value
              ?.member(me ?? '')
              ?.person
              .fullName
        : null;
    final card = canPost && (_writing || (draft != null && !draft.isEmpty));

    final shown = _shownDay ?? today;
    final body = switch (page) {
      AsyncData(:final value) when value.isEmpty && !card && waiting.isEmpty =>
        _FirstPage(space: space, canPost: canPost, onPost: _startWriting),
      AsyncData(:final value) => _diary(
        value,
        waiting,
        words,
        me: me,
        now: now,
        card: card,
      ),
      AsyncError() => Padding(
        padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
        child: EmptyNote(l10n.errorGeneric),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };

    return PopScope(
      canPop: !_writing,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _menu != null ? _setMenu(null) : _stopWriting();
      },
      child: ColoredBox(
        color: BvColors.surfaceApp,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_writing)
              BvDaybookMasthead.compact(
                key: _mastheadKey,
                title: words.compactDate(today),
              )
            else
              BvDaybookMasthead(
                key: _mastheadKey,
                weekday: words.weekday(shown),
                dateLine: words.dateLine(shown, space.siteStartDate),
                onTap: () => _openMonth(today, shown),
              ),
            if (due.isNotEmpty && !_writing)
              BvDueTodayStrip(
                l10n.daybookDueTodayStrip(due.map((i) => i.title).join(' · ')),
              ),
            Expanded(
              key: _viewportKey,
              child: LayoutBuilder(
                builder: (context, constraints) => Stack(
                  children: [
                    Positioned.fill(child: body),
                    if (_menu != null) ...[
                      // No dim: a tap anywhere else closes it (E2).
                      Positioned.fill(
                        child: GestureDetector(
                          key: const Key('writing-menu-away'),
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
                          child: DaybookWritingPopover(
                            key: ValueKey(_menu),
                            spaceId: _spaceId,
                            menu: _menu!,
                            me: me,
                            onMenu: _setMenu,
                            onPickDue: _pickDue,
                            onClose: () => _setMenu(null),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (!canPost)
              BvPostBar.viewer(
                passLabel: passName(l10n, space.myPass),
                readOnly: l10n.daybookReadOnly,
              )
            else if (_writing)
              BvWritingToolbar(
                cameraLabel: l10n.daybookCamera,
                onCamera: () => _writer.addPhoto(camera: true),
                attachLabel: l10n.daybookAddPhoto,
                onAttach: () => _writer.addPhoto(camera: false),
                moreLabel: l10n.daybookMore,
                onMore: () => _setMenu(
                  _menu == DaybookWritingMenu.more
                      ? null
                      : DaybookWritingMenu.more,
                ),
                moreActive: _menu == DaybookWritingMenu.more,
                postLabel: l10n.daybookPost,
                onPost: draft?.canPost ?? false ? () => _post(myName) : null,
                // A title but nobody to do it: choose someone.
                onPostBlocked: draft?.titleFits ?? false
                    ? () => _setMenu(DaybookWritingMenu.assign)
                    : null,
              )
            // A Draft on the page takes the post bar's place until it is
            // posted or emptied (E4).
            else if (!card)
              BvPostBar(
                placeholder: l10n.daybookWorkItem,
                onWrite: _startWriting,
              ),
          ],
        ),
      ),
    );
  }

  /// A post still in the outbox, as its slip at the time Post was tapped.
  DaybookPost _waitingPost(PendingItem i, String? me, DateTime now) =>
      DaybookPost(
        id: i.id,
        kind: DaybookPost.workItemKind,
        createdAt: i.madeAt ?? now,
        title: i.title,
        authorId: me,
        authorName: i.authorName,
        place: i.place,
        dueDate: i.dueDate,
        dueAt: i.dueAt,
        item: DaybookItem(
          status: WorkStatus.open,
          ownerId: i.ownerId,
          ownerName: i.ownerName,
        ),
      );

  Widget _diary(
    List<DaybookRecord> records,
    List<PendingItem> waiting,
    DaybookWords words, {
    required String? me,
    required DateTime now,
    required bool card,
  }) {
    final l10n = AppLocalizations.of(context);
    final viewer = widget.space.myPass == SpacePass.viewer;
    final today = dayOf(now);
    // Work items, and their sign-offs and updates (other kinds of post
    // come in slice 2), with the posts still waiting for a signal.
    final shown = [
      for (final r in records)
        if (r is! DaybookPost || r.isWorkItem) r,
    ];
    final onServer = {for (final r in shown) r.id};
    final unsent = {
      for (final i in waiting)
        if (!onServer.contains(i.id)) i.id: i,
    };
    final all =
        [...shown, for (final i in unsent.values) _waitingPost(i, me, now)]
          ..sort((a, b) {
            final t = a.at.compareTo(b.at);
            return t != 0 ? t : a.id.compareTo(b.id);
          });
    // Oldest first, grouped by the phone's own days; the card is today's.
    final byDay = <DateTime, List<DaybookRecord>>{};
    for (final r in all) {
      byDay.putIfAbsent(dayOf(r.at), () => []).add(r);
    }
    if (card) byDay.putIfAbsent(today, () => []);
    _days = byDay.keys.toList()..sort();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateShownDay();
      _loadOlderIfNear();
    });

    return GestureDetector(
      // While writing, a tap off the card puts it down.
      behavior: HitTestBehavior.opaque,
      onTap: _writing ? _stopWriting : null,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          key: const Key('daybook'),
          controller: _scroll,
          reverse: true,
          child: BvDaybookSpine(
            minHeight: constraints.maxHeight,
            children: [
              for (final (i, day) in _days.indexed)
                Column(
                  key: _dayKeys.putIfAbsent(day, GlobalKey.new),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: BvSpineSpec.entryGap,
                  children: [
                    // The first day loaded sits under the masthead.
                    if (i > 0)
                      BvDayDivider(
                        weekday: words.weekday(day),
                        date: words.dayMonth(day),
                      ),
                    for (final r in byDay[day]!)
                      DaybookEntry(
                        record: r,
                        words: words,
                        me: me,
                        now: now,
                        viewer: viewer,
                        waiting: unsent.containsKey(r.id),
                        localCover: unsent[r.id]?.photos.firstOrNull?.local,
                      ),
                    if (card && day == today)
                      BvSpineEntry(
                        key: const Key('daybook-now'),
                        time: l10n.daybookNow,
                        dot: BvSpineDot.now,
                        child: DaybookWritingCard(
                          spaceId: _spaceId,
                          writing: _writing,
                          words: words,
                          fromBefore: _fromBefore,
                          onOpen: _startWriting,
                          onMenu: _setMenu,
                          onPickDue: _pickDue,
                        ),
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

/// Day one (DY3): the first page, inset from the start over the spine.
class _FirstPage extends StatelessWidget {
  const _FirstPage({
    required this.space,
    required this.canPost,
    required this.onPost,
  });

  final SpaceDetail space;
  final bool canPost;
  final VoidCallback onPost;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: BvDaybookSpine(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: math.max(
                  0,
                  constraints.maxHeight -
                      BvSpineSpec.paddingTop -
                      BvSpineSpec.paddingBottom,
                ),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: BvFirstPageSpec.insetStart,
                  ),
                  child: BvFirstPage(
                    key: const Key('daybook-first-page'),
                    title: l10n.daybookFirstTitle,
                    body: l10n.daybookFirstBody,
                    actions: [
                      if (canPost)
                        BvFirstPageAction(
                          icon: BvIcons.confirmed,
                          label: l10n.daybookFirstPost,
                          primary: true,
                          onTap: onPost,
                        ),
                      if (space.canInvite)
                        BvFirstPageAction(
                          icon: BvIcons.team,
                          label: l10n.daybookFirstInvite,
                          onTap: () =>
                              context.push(AppRoutes.spaceInvite(space.id)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The month drop-down's content (DY2): its own month, and the marks from
/// the server. Pops with the day picked.
class DaybookMonthDrop extends ConsumerStatefulWidget {
  const DaybookMonthDrop({
    super.key,
    required this.spaceId,
    required this.today,
    required this.selected,
    required this.firstWeekday,
  });

  final String spaceId;
  final DateTime today;
  final DateTime selected;
  final int firstWeekday;

  @override
  ConsumerState<DaybookMonthDrop> createState() => _DaybookMonthState();
}

class _DaybookMonthState extends ConsumerState<DaybookMonthDrop> {
  late var _month = DateTime(widget.selected.year, widget.selected.month);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final marks = ref
        .watch(daybookMonthProvider((spaceId: widget.spaceId, month: _month)))
        .value;
    Set<int> inMonth(Set<DateTime>? days) => {
      for (final d in days ?? const <DateTime>{})
        if (d.year == _month.year && d.month == _month.month) d.day,
    };
    return BvMonthDropdown(
      month: _month,
      today: widget.today,
      selected: widget.selected,
      firstWeekday: widget.firstWeekday,
      postsLabel: l10n.daybookMonthPosts,
      dueLabel: l10n.daybookMonthDue,
      postDays: inMonth(marks?.postDays),
      dueDays: inMonth(marks?.dueDays),
      onDay: (day) => Navigator.of(context).pop(day),
      onPrevious: () =>
          setState(() => _month = DateTime(_month.year, _month.month - 1)),
      onNext: () =>
          setState(() => _month = DateTime(_month.year, _month.month + 1)),
    );
  }
}
