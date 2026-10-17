import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_days_specs.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/daybook.dart';
import '../../data/models/space.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_day_divider.dart';
import '../../shared/widgets/bv_daybook_masthead.dart';
import '../../shared/widgets/bv_daybook_spine.dart';
import '../../shared/widgets/bv_due_today_strip.dart';
import '../../shared/widgets/bv_first_page.dart';
import '../../shared/widgets/bv_month_dropdown.dart';
import '../../shared/widgets/bv_post_bar.dart';
import '../account/account_parts.dart' show myMarketProvider;
import '../entry/entry_state.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../profile/widgets/profile_parts.dart';
import '../spaces/pass_words.dart';
import 'daybook_entry.dart';
import 'daybook_state.dart';
import 'daybook_words.dart';

/// The Space's Work tab: the daybook (D1). Today's masthead at the top, the
/// newest entries at the bottom; scrolling up goes back through older days,
/// each after a day divider (DY1), and the masthead names the day at the
/// top. Tapping it drops down the month (DY2). An empty Space shows its
/// first page (DY3); a Viewer reads only (V1).
///
/// Part 1b reads only: the post bar starts writing in part 1c.
class DaybookTab extends ConsumerStatefulWidget {
  const DaybookTab({super.key, required this.space});

  final SpaceDetail space;

  @override
  ConsumerState<DaybookTab> createState() => _DaybookTabState();
}

class _DaybookTabState extends ConsumerState<DaybookTab> {
  /// Older posts load while this much is left to scroll back.
  static const _loadAhead = 600.0;

  final _scroll = ScrollController();
  final _mastheadKey = GlobalKey();
  final _viewportKey = GlobalKey();
  final _dayKeys = <DateTime, GlobalKey>{};

  /// The loaded days, oldest first.
  var _days = <DateTime>[];

  /// The day the masthead names once scrolled back: the one at the top of
  /// the page. Null at rest on the newest posts: today.
  DateTime? _shownDay;

  String get _spaceId => widget.space.id;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    _updateShownDay();
    if (_scroll.position.extentAfter < _loadAhead) {
      unawaited(ref.read(daybookPageProvider(_spaceId).notifier).loadOlder());
    }
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
      final posts = ref.read(provider).value ?? const <DaybookPost>[];
      if (posts.isEmpty ||
          !dayOf(posts.last.createdAt).isAfter(day) ||
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

    final shown = _shownDay ?? today;
    final body = switch (page) {
      AsyncData(:final value) when value.isEmpty => _FirstPage(
        space: space,
        canPost: canPost,
      ),
      AsyncData(:final value) => _diary(value, words, me, now),
      AsyncError() => Padding(
        padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
        child: EmptyNote(l10n.errorGeneric),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };

    return ColoredBox(
      color: BvColors.surfaceApp,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BvDaybookMasthead(
            key: _mastheadKey,
            weekday: words.weekday(shown),
            dateLine: words.dateLine(shown, space.siteStartDate),
            onTap: () => _openMonth(today, shown),
          ),
          if (due.isNotEmpty)
            BvDueTodayStrip(
              l10n.daybookDueTodayStrip(due.map((i) => i.title).join(' · ')),
            ),
          Expanded(key: _viewportKey, child: body),
          if (canPost)
            BvPostBar(placeholder: l10n.daybookWorkItem)
          else
            BvPostBar.viewer(
              passLabel: passName(l10n, space.myPass),
              readOnly: l10n.daybookReadOnly,
            ),
        ],
      ),
    );
  }

  Widget _diary(
    List<DaybookPost> posts,
    DaybookWords words,
    String? me,
    DateTime now,
  ) {
    final viewer = widget.space.myPass == SpacePass.viewer;
    // Oldest first, grouped by the phone's own days.
    final byDay = <DateTime, List<DaybookPost>>{};
    for (final p in posts.reversed) {
      if (!p.isWorkItem) continue;
      byDay.putIfAbsent(dayOf(p.createdAt), () => []).add(p);
    }
    _days = byDay.keys.toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateShownDay();
    });

    return LayoutBuilder(
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
                  for (final p in byDay[day]!)
                    DaybookEntry(
                      post: p,
                      words: words,
                      me: me,
                      now: now,
                      viewer: viewer,
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Day one (DY3): the first page, inset from the start over the spine.
class _FirstPage extends StatelessWidget {
  const _FirstPage({required this.space, required this.canPost});

  final SpaceDetail space;
  final bool canPost;

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
                      // Writing in place comes in part 1c.
                      if (canPost)
                        BvFirstPageAction(
                          icon: BvIcons.confirmed,
                          label: l10n.daybookFirstPost,
                          primary: true,
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
