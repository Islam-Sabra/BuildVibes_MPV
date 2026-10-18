import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_days_specs.dart';
import '../../core/design/daybook_paper_specs.dart';
import '../../core/design/daybook_writing_specs.dart';
import '../../core/push/push_state.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/daybook.dart';
import '../../data/models/space.dart';
import '../../data/models/work_item.dart';
import '../../data/repositories/space_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_day_divider.dart';
import '../../shared/widgets/bv_daybook_masthead.dart';
import '../../shared/widgets/bv_due_today_strip.dart';
import '../../shared/widgets/bv_first_page.dart';
import '../../shared/widgets/bv_highlight.dart';
import '../../shared/widgets/bv_month_dropdown.dart';
import '../../shared/widgets/bv_new_chip.dart';
import '../../shared/widgets/bv_post_bar.dart';
import '../../shared/widgets/bv_trace_row.dart';
import '../../shared/widgets/bv_writing_toolbar.dart';
import '../account/account_parts.dart' show myMarketProvider;
import '../entry/entry_state.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../profile/widgets/profile_parts.dart';
import '../spaces/former_member.dart';
import '../spaces/pass_words.dart';
import '../spaces/space_errors.dart';
import 'daybook_card.dart';
import 'daybook_draft.dart';
import 'daybook_loop.dart';
import 'daybook_state.dart';
import 'daybook_target.dart';
import 'daybook_words.dart';
import 'daybook_writing.dart';
import 'work_outbox.dart';

/// The Space's Work tab: the daybook (v13, review 53 Part B). The day on
/// one line at the top; one card per work item, full width, newest
/// activity at the bottom ("Now"). A card with new activity moves to Now;
/// each earlier day it had something happen keeps a one-line trace that
/// goes back to it. Scrolling up goes back through older days on the same
/// page, each after a day divider, and the masthead names the day at the
/// top. Tapping it drops down the month (DY2). An empty Space shows its
/// first page (DY3); a Viewer reads only (V1).
///
/// The post bar's notepad writes a work item in place at "Now" (E1–E5):
/// the writing toolbar takes the post bar's place. A card with anything
/// in it stays as a Draft (E4).
///
/// The loop lives on the cards: Sign as done, double-tap to check, the
/// menu on a long-press or a tap, swipe to add an update ([DaybookLoop]).
class DaybookTab extends ConsumerStatefulWidget {
  const DaybookTab({
    super.key,
    required this.space,
    this.startWriting = false,
    this.target,
  });

  final SpaceDetail space;

  /// Opened from an Activity row, a push or a Needs you card (F20): the
  /// page loads down to that card, scrolls to it and highlights it, its
  /// history open at the event's line. Gone: "This was removed".
  final DaybookTarget? target;

  /// Opened from Create's "Work item in a Space" (F1): the card opens at
  /// Now, when the reader may write work items here.
  final bool startWriting;

  @override
  ConsumerState<DaybookTab> createState() => _DaybookTabState();
}

/// A card as the page shows it: with what waits on the phone, at its
/// latest activity.
class _Shown {
  const _Shown({
    required this.card,
    required this.at,
    this.waiting = false,
    this.unsent,
    this.refusedProof,
    this.localPhoto,
    this.landing = false,
  });

  final DaybookCard card;
  final DateTime at;
  final bool waiting;

  /// A new work item not on the server yet.
  final PendingItem? unsent;

  /// A sign-off the server refused: a tap reopens its proof.
  final PendingItem? refusedProof;
  final String? localPhoto;
  final bool landing;

  bool get refused => (unsent?.refused ?? false) || refusedProof != null;
}

/// A trace: on an earlier day, the latest thing that happened to a card
/// that has moved on.
typedef _Trace = ({DaybookCard card, DaybookEvent event});

class _DaybookTabState extends ConsumerState<DaybookTab> {
  /// Older cards load while this much is left to scroll back.
  static const _loadAhead = 600.0;

  final _scroll = ScrollController();
  final _mastheadKey = GlobalKey();
  final _viewportKey = GlobalKey();
  final _dayKeys = <DateTime, GlobalKey>{};
  final _cardKeys = <String, GlobalKey>{};
  final _lineKeys = <String, GlobalKey>{};

  /// Cards whose whole history is open (Show earlier, or a trace).
  final _expanded = <String>{};

  /// The card to open at, until the page has it (F20).
  late DaybookTarget? _target = widget.target;
  var _revealing = false;

  /// The card highlighted last, and how many times one was (each reveal
  /// flashes again).
  String? _highlighted;
  var _flashes = 0;

  /// The loaded days, oldest first.
  var _days = <DateTime>[];

  /// The day the masthead names: the one at the top of the page (F23).
  /// Null with no days: today.
  DateTime? _shownDay;

  /// Writing in place: the card is open with the keyboard's toolbar.
  var _writing = false;

  /// The card is a posted work item's, being edited (X1 Edit).
  var _editing = false;
  DaybookWritingMenu? _menu;

  /// Post was tapped with nobody to do it: picking someone posts it.
  var _postOnAssign = false;

  /// The card on the page was left from before: it says "Draft".
  late bool _fromBefore;

  late final DaybookWriter _writer = DaybookWriter(ref, _spaceId);
  late final DaybookWriter _editor = DaybookWriter(
    ref,
    _spaceId,
    editing: true,
  );
  late final AppLifecycleListener _life;

  /// New activity came in at Now while the reader was up in older days
  /// (F11): the "New" chip shows until they go to Now.
  var _newBelow = false;

  /// Whether this page was on screen at the last look ([TickerMode]): a
  /// page shown again reads again.
  bool? _shown;

  String get _spaceId => widget.space.id;
  DaybookWriter get _card => _editing ? _editor : _writer;

  /// The reader's open items on the page, for the proof screen's list.
  var _openItems = const <DaybookPost>[];

  DaybookLoop get _loop =>
      DaybookLoop(ref, widget.space, onEdit: _startEdit, openItems: _openItems);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _fromBefore = ref.read(daybookDraftProvider(_spaceId)) != null;
    // What was made with no signal sends when it's back: on opening and
    // on coming back to the app (the outbox also tries by itself). The
    // page is never stale (F11): it reads the newest cards when it opens
    // (from a push too), when the app comes back to the front, and when a
    // push for this Space arrives (build).
    _life = AppLifecycleListener(
      onResume: () {
        _flush();
        unawaited(_refresh());
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.startWriting && widget.space.myRights.createItems) {
        _startWriting();
      }
      _flush();
      // Kept from an earlier visit (another page of this Space is open
      // underneath): read again. A first load is already reading.
      if (mounted && ref.read(daybookCardsProvider(_spaceId)).hasValue) {
        unawaited(_refresh());
      }
    });
  }

  @override
  void didUpdateWidget(DaybookTab old) {
    super.didUpdateWidget(old);
    if (widget.target != old.target) _target = widget.target;
  }

  /// Opens the page at [_target]'s card (F20), once the first page is in:
  /// loads down to it ([DaybookCards.find]), opens its history at the
  /// event's line (reading "Show earlier" if it is older), scrolls to it
  /// and highlights it. A post that was deleted, or can't be seen any
  /// more, says "This was removed".
  Future<void> _reveal() async {
    final target = _target;
    if (target == null || _revealing || !mounted) return;
    _revealing = true;
    _target = null;
    try {
      final l10n = AppLocalizations.of(context);
      final pages = ref.read(daybookCardsProvider(_spaceId).notifier);
      final bool found;
      try {
        found = await pages.find(target.postId);
      } on SpaceException catch (e) {
        if (mounted) showSpaceError(context, e);
        return;
      }
      if (!mounted) return;
      if (!found) {
        showSpaceMessage(context, l10n.daybookRemoved);
        return;
      }
      var line = target.eventId;
      if (line != null) {
        try {
          if (!await pages.findLine(target.postId, line)) line = null;
        } on SpaceException {
          // Opens at the card.
          line = null;
        }
        if (!mounted) return;
      }
      setState(() {
        if (line != null) _expanded.add(target.postId);
        _newBelow = false;
      });
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final at =
          (line == null ? null : _lineKeys[line]?.currentContext) ??
          _cardKeys[target.postId]?.currentContext;
      if (at != null && at.mounted) {
        await Scrollable.ensureVisible(at, alignment: 0.5);
      }
      if (!mounted) return;
      setState(() {
        _highlighted = target.postId;
        _flashes++;
      });
      _updateShownDay();
    } finally {
      _revealing = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Back on screen after a page on top of it closed: read again.
    final shown = TickerMode.valuesOf(context).enabled;
    if (_shown == false && shown) unawaited(_refresh());
    _shown = shown;
  }

  @override
  void dispose() {
    _life.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _flush() {
    if (!mounted) return;
    unawaited(ref.read(workOutboxProvider.notifier).flush(_spaceId));
  }

  /// Reads the newest cards again, quietly; with no signal the page stays
  /// as it was.
  Future<void> _refresh() async {
    if (!mounted) return;
    try {
      await ref.read(daybookCardsProvider(_spaceId).notifier).refresh();
    } on SpaceException catch (e) {
      debugPrint('daybook refresh: $e');
    }
  }

  /// The reader is up in older days, away from Now.
  bool get _away =>
      _scroll.hasClients && _scroll.offset > BvNewChipSpec.awayFromNow;

  /// Cards moved to Now (new activity on the server, or something done
  /// here) while the reader is up in older days: the page stays where it
  /// is, held on a card that didn't move, and the "New" chip shows.
  void _keepPlace(Set<String> moved) {
    if (moved.isEmpty || !_away) return;
    final viewport =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewport == null || !viewport.hasSize) return;
    final top = viewport.localToGlobal(Offset.zero).dy;
    final bottom = top + viewport.size.height;
    String? anchor;
    double? anchorY;
    for (final e in _cardKeys.entries) {
      if (moved.contains(e.key)) continue;
      final box = e.value.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached || !box.hasSize) continue;
      final y = box.localToGlobal(Offset.zero).dy;
      if (y + box.size.height < top || y > bottom) continue;
      if (anchorY == null || (y - top).abs() < (anchorY - top).abs()) {
        anchor = e.key;
        anchorY = y;
      }
    }
    setState(() => _newBelow = true);
    if (anchor == null) return;
    final was = anchorY!;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final box =
          _cardKeys[anchor]?.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) return;
      final shift = was - box.localToGlobal(Offset.zero).dy;
      if (shift == 0) return;
      final position = _scroll.position;
      _scroll.jumpTo(
        (_scroll.offset + shift).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
      );
    });
  }

  /// The cards with new activity since [before].
  static Set<String> _movedOn(
    List<DaybookCard>? before,
    List<DaybookCard> now,
  ) {
    if (before == null || before.isEmpty) return const {};
    final was = {for (final c in before) c.id: c.lastActivityAt};
    final newest = before
        .map((c) => c.lastActivityAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    return {
      for (final c in now)
        if (c.post.isWorkItem &&
            (was[c.id] == null
                ? !c.lastActivityAt.isBefore(newest)
                : c.lastActivityAt.isAfter(was[c.id]!)))
          c.id,
    };
  }

  void _toNow() {
    setState(() => _newBelow = false);
    if (_scroll.hasClients) {
      unawaited(
        _scroll.animateTo(0, duration: BvMotion.base, curve: BvMotion.standard),
      );
    }
  }

  void _onScroll() {
    _updateShownDay();
    _loadOlderIfNear();
    if (_newBelow && !_away) setState(() => _newBelow = false);
  }

  /// Older days hang above today on the same page (review 45 B1): load
  /// them while the top is near, including when the page isn't full yet.
  void _loadOlderIfNear() {
    if (!_scroll.hasClients || _scroll.position.extentAfter >= _loadAhead) {
      return;
    }
    unawaited(ref.read(daybookCardsProvider(_spaceId).notifier).loadOlder());
  }

  /// The masthead names the day of what is at the top of the page (F23),
  /// at Now too: the latest day whose divider has reached the reading line
  /// just under the top, else the first day on the page. That day's divider is then hidden, so the
  /// same day never shows twice in a row ([_dividerHidden]).
  void _updateShownDay() {
    final viewport =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewport == null || !viewport.hasSize) return;
    if (_days.isEmpty) {
      if (_shownDay != null) setState(() => _shownDay = null);
      return;
    }
    final top = viewport.localToGlobal(Offset.zero).dy;
    DateTime? shown;
    for (final day in _days) {
      final box =
          _dayKeys[day]?.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached || !box.hasSize) continue;
      // The first day laid out is the top one, even below the top edge.
      shown ??= day;
      if (box.localToGlobal(Offset.zero).dy <=
          top + BvMastheadSpec.readingLine) {
        shown = day;
      }
    }
    if (shown != _shownDay) setState(() => _shownDay = shown);
  }

  /// The divider of the day the masthead names: the masthead says it.
  bool _dividerHidden(DateTime day) => !_writing && day == _shownDay;

  /// Shows [day]: loads older pages until it is reached, then puts the
  /// latest day on or before it at the top.
  Future<void> _jumpTo(DateTime day) async {
    final provider = daybookCardsProvider(_spaceId);
    final pages = ref.read(provider.notifier);
    for (;;) {
      final cards = ref.read(provider).value ?? const <DaybookCard>[];
      if (cards.isEmpty ||
          !dayOf(cards.last.lastActivityAt).isAfter(day) ||
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

  /// A trace's ›: the card, with its history open at that event.
  Future<void> _openAt(_Trace trace) async {
    setState(() => _expanded.add(trace.card.id));
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final context =
        (trace.event.shown ? _lineKeys[trace.event.id] : null)
            ?.currentContext ??
        _cardKeys[trace.card.id]?.currentContext;
    if (context == null || !context.mounted) return;
    await Scrollable.ensureVisible(
      context,
      alignment: 0.5,
      duration: BvMotion.base,
      curve: BvMotion.standard,
    );
  }

  /// Show earlier: the rest of the loaded lines in place; past them, the
  /// next ones from the server.
  void _earlier(DaybookCard card) {
    final open = _expanded.contains(card.id);
    final lines = card.history.where((e) => e.shown).length;
    setState(() => _expanded.add(card.id));
    if (open || lines <= DaybookCardView.shownLines) {
      unawaited(_loadEarlier(card.id));
    }
  }

  Future<void> _loadEarlier(String postId) async {
    try {
      await ref
          .read(daybookCardsProvider(_spaceId).notifier)
          .loadEarlier(postId);
    } on SpaceException catch (e) {
      if (mounted) showSpaceError(context, e);
    }
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
      _editing = false;
      _menu = null;
      _postOnAssign = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  /// Edit a posted work item: its card opens at "Now", filled (X1 Edit).
  void _startEdit(DaybookPost post) {
    ref.read(daybookEditProvider(_spaceId).notifier).start(post);
    setState(() {
      _writing = true;
      _editing = true;
      _menu = null;
      _postOnAssign = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  /// Puts the card down: with anything in it, it stays as the Draft;
  /// empty, it goes. An edit put down leaves the post as it was.
  void _stopWriting() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_editing) {
      ref.read(daybookEditProvider(_spaceId).notifier).stop();
    } else {
      final draft = ref.read(daybookDraftProvider(_spaceId));
      unawaited(ref.read(daybookDraftProvider(_spaceId).notifier).close());
      if (draft != null && !draft.isEmpty) _fromBefore = true;
    }
    setState(() {
      _writing = false;
      _editing = false;
      _menu = null;
      _postOnAssign = false;
    });
  }

  void _setMenu(DaybookWritingMenu? menu) => setState(() {
    _menu = menu;
    if (menu != DaybookWritingMenu.assign) _postOnAssign = false;
  });

  Future<void> _pickDue() async {
    _setMenu(null);
    final draft = _card.draft;
    final picked = await ref.read(pickDueProvider)(
      context,
      now: ref.read(clockProvider)(),
      day: draft?.dueDate,
      at: draft?.dueAt,
    );
    if (picked != null) await _card.setDue(picked);
  }

  /// Post with a title but nobody to do it: the assign picker opens, and
  /// picking someone posts it (review 46).
  void _postOrAssign(String? myName) {
    final draft = _writer.draft;
    if (draft == null || !draft.titleFits) return;
    if (draft.ownerId != null) {
      unawaited(_post(myName));
      return;
    }
    setState(() {
      _menu = DaybookWritingMenu.assign;
      _postOnAssign = true;
    });
  }

  void _assigned(String? myName) {
    if (_postOnAssign) {
      unawaited(_post(myName));
    } else {
      _setMenu(null);
    }
  }

  Future<void> _post(String? myName) async {
    await _writer.post(authorName: myName);
    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _writing = false;
      _menu = null;
      _postOnAssign = false;
      _fromBefore = false;
    });
  }

  Future<void> _save() async {
    try {
      await _editor.save();
    } on SpaceException catch (e) {
      if (mounted) showSpaceError(context, e);
      return;
    }
    if (!mounted) return;
    _stopWriting();
    await _loop.refresh();
  }

  /// A refused post that waited while another card was written: back into
  /// the Draft when the card is free, and writing reopens.
  Future<void> _reopen(PendingItem item) async {
    final moved = await ref
        .read(workOutboxProvider.notifier)
        .reopenRefused(item);
    if (!mounted || !moved) return;
    _fromBefore = true;
    _startWriting();
  }

  /// The reader's open work items, due first (late first), else the
  /// oldest. A hold of the post bar's camera proves the first; the proof
  /// screen lists them all (review 47, answer 3).
  List<DaybookPost> _toProve(
    List<DaybookCard> cards,
    String? me,
    Set<String> signing,
  ) {
    final mine = [
      for (final c in cards)
        if (c.post.isWorkItem &&
            c.post.isOpen &&
            c.post.item?.ownerId == me &&
            !signing.contains(c.id))
          c.post,
    ];
    DateTime due(DaybookPost p) =>
        p.dueAt ??
        (p.dueDate == null
            ? DateTime(_farFuture)
            : p.dueDate!.add(const Duration(days: 1)));
    mine.sort((a, b) {
      final d = due(a).compareTo(due(b));
      return d != 0 ? d : a.createdAt.compareTo(b.createdAt);
    });
    return mine;
  }

  static const _farFuture = 9999;

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
    // A refused check, send-back or cancel says why; the page has read
    // again (review 47, answer 5).
    ref.listen(refusalsProvider, (_, r) {
      if (r == null || r.spaceId != _spaceId) return;
      showSpaceMessage(
        context,
        DaybookLoop.refusalText(
          l10n,
          r,
          ref.read(daybookCardsProvider(_spaceId)).value ?? const [],
        ),
      );
    });
    // A push about this Space while it's open: read again (F11).
    ref.listen(pushArrivalProvider, (_, push) {
      if (push?.spaceId == _spaceId) unawaited(_refresh());
    });
    ref.listen(daybookCardsProvider(_spaceId), (was, now) {
      final value = now.value;
      if (now.hasValue && value != null) {
        _keepPlace(_movedOn(was?.value, value));
      }
    });
    // Something done here moves its card to Now at once, too.
    ref.listen(workOutboxProvider, (was, now) {
      final known = {for (final i in was ?? const <PendingItem>[]) i.id};
      _keepPlace({
        for (final i in now)
          if (i.spaceId == _spaceId && !known.contains(i.id)) i.id,
      });
    });
    final canPost = space.myRights.createItems;
    final page = ref.watch(daybookCardsProvider(_spaceId));
    final due =
        ref.watch(daybookDueTodayProvider(_spaceId)).value ??
        const <CalendarWorkItem>[];
    final draft = ref.watch(daybookDraftProvider(_spaceId));
    final edit = ref.watch(daybookEditProvider(_spaceId));
    final pending = [
      for (final i in ref.watch(workOutboxProvider))
        if (i.spaceId == _spaceId) i,
    ];
    final myName = ref
        .watch(spacePeopleProvider(_spaceId))
        .value
        ?.member(me ?? '')
        ?.person
        .fullName;
    final card =
        canPost && (_writing || _editing || (draft != null && !draft.isEmpty));
    final signing = {
      for (final i in pending)
        if (i.kind == PendingKind.signOff) i.id,
    };
    final cards = page.value ?? const <DaybookCard>[];
    if (_target != null && page.hasValue && !_revealing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_reveal()));
    }

    final shown = _shownDay ?? today;
    final waitingPosts = [
      for (final i in pending)
        if (i.kind == PendingKind.workItem) i,
    ];
    final body = switch (page) {
      AsyncData(:final value)
          when value.isEmpty && !card && waitingPosts.isEmpty =>
        RefreshIndicator(
          onRefresh: _refresh,
          child: _FirstPage(
            space: space,
            canPost: canPost,
            onPost: _startWriting,
          ),
        ),
      AsyncData(:final value) => _diary(
        value,
        pending,
        words,
        me: me,
        myName: myName,
        now: now,
        card: card,
        signing: signing,
      ),
      // Pull down to try again.
      AsyncError() => RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
          children: [EmptyNote(l10n.errorGeneric)],
        ),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
    _openItems = canPost ? _toProve(cards, me, signing) : const [];
    final prove = _openItems.firstOrNull;
    final cardDraft = _editing ? edit : draft;
    // While writing, the masthead is today's and opens nothing.
    final day = _writing ? today : shown;

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
            BvDaybookMasthead(
              key: _mastheadKey,
              weekday: words.weekday(day),
              date: words.dayMonth(day),
              onTap: _writing ? null : () => _openMonth(today, shown),
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
                    if (_newBelow && !_writing)
                      PositionedDirectional(
                        start: 0,
                        end: 0,
                        bottom: BvNewChipSpec.offset,
                        child: Center(
                          child: BvNewChip(
                            key: const Key('daybook-new'),
                            label: l10n.daybookNew,
                            onTap: _toNow,
                          ),
                        ),
                      ),
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
                            key: ValueKey((_menu, _editing)),
                            spaceId: _spaceId,
                            menu: _menu!,
                            me: me,
                            editing: _editing,
                            onMenu: _setMenu,
                            onPickDue: _pickDue,
                            onClose: () => _setMenu(null),
                            onAssigned: () => _assigned(myName),
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
                // An edit keeps its photos (slice 5 opens a post in place).
                onCamera: _editing
                    ? null
                    : () => _writer.addPhoto(camera: true),
                attachLabel: l10n.daybookAddPhoto,
                onAttach: _editing
                    ? null
                    : () => _writer.addPhoto(camera: false),
                moreLabel: l10n.daybookMore,
                onMore: () => _setMenu(
                  _menu == DaybookWritingMenu.more
                      ? null
                      : DaybookWritingMenu.more,
                ),
                moreActive: _menu == DaybookWritingMenu.more,
                postLabel: _editing ? l10n.daybookSave : l10n.daybookPost,
                // Post turns on with a title (review 46); with nobody to
                // do it, it opens the assign picker first.
                onPost: cardDraft?.titleFits ?? false
                    ? (_editing ? _save : () => _postOrAssign(myName))
                    : null,
              )
            // A Draft on the page takes the post bar's place until it is
            // posted or emptied (E4).
            else if (!card)
              BvPostBar(
                placeholder: l10n.daybookWorkItem,
                onWrite: _startWriting,
                cameraLabel: l10n.daybookHoldToProve,
                // A tap writes a work item with a photo; holding proves
                // your open work item (O1 → O2).
                onCamera: () {
                  _startWriting();
                  unawaited(_writer.addPhoto(camera: true));
                },
                onProve: prove == null
                    ? null
                    : () => unawaited(_loop.signDone(context, prove)),
              ),
          ],
        ),
      ),
    );
  }

  /// A work item still in the outbox, as its card at the time Post was
  /// tapped.
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

  /// [c] with what the phone did that waits to be sent: a cancel fades
  /// it, a check stamps it CHECKED, a sign-off marks it DONE with its
  /// photo from the phone; each is a line in its history at once, and the
  /// card moves to Now.
  _Shown _asShown(
    DaybookCard c,
    Map<String, PendingItem> cancels,
    Map<String, PendingItem> checks,
    Map<String, PendingItem> signOffs, {
    required String? me,
    required String? myName,
    required DateTime now,
  }) {
    final outbox = ref.read(workOutboxProvider.notifier);
    var card = c;
    var at = c.lastActivityAt;
    var waiting = false;
    var landing = false;
    String? localPhoto;
    PendingItem? refusedProof;
    final lines = <DaybookEvent>[];
    DateTime made(PendingItem i) => i.madeAt ?? now;
    void later(DateTime t) {
      if (t.isAfter(at)) at = t;
    }

    DaybookEvent mine(PendingItem i, DaybookEventKind kind, {String? note}) =>
        DaybookEvent(
          id: '${i.kind.json}-${i.id}',
          kind: kind,
          at: made(i),
          byId: me,
          byName: myName,
          note: note,
        );

    final signOff = signOffs[c.id];
    if (signOff != null && signOff.refused) {
      // A refused proof isn't done: the card stays as the server has it.
      refusedProof = signOff;
      localPhoto = signOff.photos.firstOrNull?.local;
      later(made(signOff));
    } else if (signOff != null && c.post.item?.status == WorkStatus.open) {
      // Until the server has the item as done.
      card = card.copyWith(
        post: card.post.shownAs(status: WorkStatus.done),
        proof: DaybookProof(
          at: made(signOff),
          byId: me,
          byName: myName,
          note: signOff.note,
          outcome: DaybookOutcome(
            kind: DaybookOutcomeKind.done,
            at: made(signOff),
            byId: me,
            byName: myName,
          ),
        ),
        clearNeed: true,
      );
      lines.add(mine(signOff, DaybookEventKind.done, note: signOff.note));
      localPhoto = signOff.photos.firstOrNull?.local;
      // Sent, it no longer waits, though the page hasn't read it yet
      // (F17). Under its undo bar, it isn't waiting for a signal (F7).
      waiting =
          !signOff.sent && !outbox.isHeld(PendingKind.signOff, signOff.id);
      later(made(signOff));
    }
    final check = checks[c.id];
    if (check != null) {
      final proof = card.proof;
      card = card.copyWith(
        post: card.post.shownAs(status: WorkStatus.checked),
        proof: proof?.withOutcome(
          DaybookOutcome(
            kind: DaybookOutcomeKind.checked,
            at: made(check),
            byId: me,
            byName: myName,
          ),
        ),
        clearNeed: true,
      );
      lines.add(mine(check, DaybookEventKind.checked));
      landing = outbox.isHeld(PendingKind.check, c.id);
      later(made(check));
    }
    final cancel = cancels[c.id];
    if (cancel != null) {
      final proof = card.proof;
      card = card.copyWith(
        post: card.post.shownAs(cancelled: true),
        proof: proof?.withOutcome(
          DaybookOutcome(
            kind: DaybookOutcomeKind.cancelled,
            at: made(cancel),
            byId: me,
            byName: myName,
          ),
        ),
        clearNeed: true,
      );
      lines.add(mine(cancel, DaybookEventKind.cancelled));
      later(made(cancel));
    }
    if (lines.isNotEmpty) {
      card = card.copyWith(history: [...lines.reversed, ...card.history]);
    }
    return _Shown(
      card: card,
      at: at,
      waiting: waiting,
      refusedProof: refusedProof,
      localPhoto: localPhoto,
      landing: landing,
    );
  }

  /// For each card, every earlier day (the phone's) on which something
  /// happened to it: that day's latest event.
  static List<(DateTime, _Trace)> _traces(_Shown s) {
    final cardDay = dayOf(s.at);
    final seen = <DateTime>{};
    return [
      // Newest first: the first of each day is its latest.
      for (final e in s.card.history)
        if (e.kind != DaybookEventKind.unknown &&
            dayOf(e.at).isBefore(cardDay) &&
            seen.add(dayOf(e.at)))
          (e.at, (card: s.card, event: e)),
    ];
  }

  Widget _diary(
    List<DaybookCard> cards,
    List<PendingItem> pending,
    DaybookWords words, {
    required String? me,
    required String? myName,
    required DateTime now,
    required bool card,
    required Set<String> signing,
  }) {
    final l10n = AppLocalizations.of(context);
    final viewer = widget.space.myPass == SpacePass.viewer;
    final today = dayOf(now);
    Map<String, PendingItem> byKind(PendingKind kind) => {
      for (final i in pending)
        if (i.kind == kind) i.id: i,
    };
    final cancels = byKind(PendingKind.cancel);
    final checks = byKind(PendingKind.check);
    final signOffs = byKind(PendingKind.signOff);
    final onServer = {for (final c in cards) c.id};
    // Work items (other kinds of post come in slice 2), with what still
    // waits for a signal.
    final shown = <_Shown>[
      for (final c in cards)
        if (c.post.isWorkItem)
          _asShown(
            c,
            cancels,
            checks,
            signOffs,
            me: me,
            myName: myName,
            now: now,
          ),
      // A new work item not on the server yet: a card at the time Post
      // was tapped.
      for (final i in pending)
        if (i.kind == PendingKind.workItem && !onServer.contains(i.id))
          _Shown(
            card: DaybookCard(
              post: _waitingPost(i, me, now),
              lastActivityAt: i.madeAt ?? now,
            ),
            at: i.madeAt ?? now,
            waiting: !i.sent,
            unsent: i,
            localPhoto: i.photos.firstOrNull?.local,
          ),
      // A proof for an item on an older page, not loaded: its own card.
      for (final i in signOffs.values)
        if (!onServer.contains(i.id))
          _asShown(
            DaybookCard(
              post: DaybookPost(
                id: i.id,
                kind: DaybookPost.workItemKind,
                createdAt: i.madeAt ?? now,
                title: i.title,
                item: DaybookItem(
                  status: WorkStatus.open,
                  ownerId: me,
                  ownerName: myName,
                ),
              ),
              lastActivityAt: i.madeAt ?? now,
            ),
            cancels,
            checks,
            signOffs,
            me: me,
            myName: myName,
            now: now,
          ),
    ];
    // Oldest first, grouped by the phone's own days; the writing card is
    // today's. A card is at its latest activity, its traces on the days
    // before.
    final byDay = <DateTime, List<(DateTime, String, Object)>>{};
    for (final s in shown) {
      byDay.putIfAbsent(dayOf(s.at), () => []).add((s.at, s.card.id, s));
      for (final (at, t) in _traces(s)) {
        byDay.putIfAbsent(dayOf(at), () => []).add((
          at,
          '${t.card.id}-${t.event.id}',
          t,
        ));
      }
    }
    for (final rows in byDay.values) {
      rows.sort((a, b) {
        final t = a.$1.compareTo(b.$1);
        return t != 0 ? t : a.$2.compareTo(b.$2);
      });
    }
    if (card) byDay.putIfAbsent(today, () => []);
    _days = byDay.keys.toList()..sort();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateShownDay();
      _loadOlderIfNear();
    });

    Widget cardOf(_Shown s) {
      final c = s.card;
      final unsent = s.unsent;
      final refusedProof = s.refusedProof;
      final view = DaybookCardView(
        card: c,
        words: words,
        me: me,
        now: now,
        activityAt: s.at,
        viewer: viewer,
        waiting: s.waiting,
        couldNotSend: s.refused,
        localPhoto: s.localPhoto,
        landing: s.landing,
        expanded: _expanded.contains(c.id),
        onEarlier: () => _earlier(c),
        lineKey: (id) => _lineKeys.putIfAbsent(id, GlobalKey.new),
        // While writing, a tap on a card puts the card down, as anywhere
        // off it; a refused one reopens to fix; otherwise a short press
        // shows the card's menu (F16).
        onTap: _writing
            ? _stopWriting
            : unsent != null && unsent.refused
            ? () => unawaited(_reopen(unsent))
            : refusedProof != null
            ? () => unawaited(
                _loop.reopenProof(context, refusedProof, post: c.post),
              )
            : null,
      );
      return KeyedSubtree(
        key: _cardKeys.putIfAbsent(c.id, GlobalKey.new),
        child: KeyedSubtree(
          key: Key('daybook-card-${c.id}'),
          // The card a row or a push opened (F20).
          child: BvHighlight(
            flash: _highlighted == c.id ? _flashes : null,
            // A post not on the server yet has nothing to do on it.
            child: unsent != null
                ? view
                : _loop.withActions(context, view, me: me, signing: signing),
          ),
        ),
      );
    }

    Widget traceOf(_Trace t) {
      final e = t.event;
      final by = e.byId;
      return BvTraceRow(
        key: Key('daybook-trace-${t.card.id}-${dayOf(e.at).toIso8601String()}'),
        name: personName(l10n, e.byName),
        tint: by == null ? BvAvatarTints.plain : BvAvatarTints.forId(by),
        text: l10n.daybookTrace(
          words.eventPhrase(e, me: me, now: now, trace: true),
          t.card.post.title,
        ),
        time: words.time.clock(e.at),
        onTap: _writing ? _stopWriting : () => unawaited(_openAt(t)),
      );
    }

    return GestureDetector(
      // While writing, a tap off the card puts it down.
      behavior: HitTestBehavior.opaque,
      onTap: _writing ? _stopWriting : null,
      // Pull down to read again; it always pulls, however short the page
      // (F11). The list runs bottom up: the pull is at its top.
      child: LayoutBuilder(
        builder: (context, constraints) => RefreshIndicator(
          onRefresh: _refresh,
          child: SingleChildScrollView(
            key: const Key('daybook'),
            controller: _scroll,
            reverse: true,
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: BvCardSpec.paddingSide,
                  end: BvCardSpec.paddingSide,
                  top: BvCardSpec.paddingTop,
                  bottom: BvCardSpec.paddingBottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: BvCardSpec.gap,
                  children: [
                    for (final day in _days)
                      Column(
                        key: _dayKeys.putIfAbsent(day, GlobalKey.new),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: BvCardSpec.gap,
                        children: [
                          // Under a masthead naming the same day, it keeps
                          // its place but doesn't show (F23).
                          Visibility(
                            key: Key(
                              'daybook-divider-${day.toIso8601String()}',
                            ),
                            visible: !_dividerHidden(day),
                            maintainSize: true,
                            maintainAnimation: true,
                            maintainState: true,
                            child: BvDayDivider(
                              label: day == today
                                  ? l10n.daybookTodayDivider
                                  : words.compactDate(day),
                            ),
                          ),
                          for (final (_, _, row) in byDay[day]!)
                            switch (row) {
                              _Shown s => cardOf(s),
                              _ => traceOf(row as _Trace),
                            },
                          if (card && day == today)
                            KeyedSubtree(
                              key: const Key('daybook-now'),
                              child: DaybookWritingCard(
                                // An edit's card is its own.
                                key: ValueKey(_editing),
                                spaceId: _spaceId,
                                writing: _writing,
                                editing: _editing,
                                words: words,
                                fromBefore: _fromBefore && !_editing,
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
          ),
        ),
      ),
    );
  }
}

/// Day one (DY3): the first page, 16 from each edge.
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
        // Pull down to read again (F11).
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: BvCardSpec.paddingSide,
            ),
            child: Center(
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
